#!/bin/bash

# Скрипт мониторинга здоровья сервисов

echo "=========================================="
echo "Service Health Monitoring"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция проверки
check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
    
    if [ "$status" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $name: $status"
        return 0
    else
        echo -e "${RED}✗${NC} $name: $status (expected $expected_code)"
        return 1
    fi
}

echo ""
echo "=== Service Status ==="

# Проверка Supabase Studio
check_service "Supabase Studio" "http://localhost:3000/health"

# Проверка Supabase REST API
check_service "Supabase REST API" "http://localhost:8000/health"

# Проверка n8n
check_service "n8n" "http://localhost:5678/health"

# Проверка Docker контейнеров
echo ""
echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "supabase|n8n|postgres"

# Проверка ресурсов
echo ""
echo "=== Resource Usage ==="
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{printf "  Used: %.1f%%\n", 100-$1}'

echo "Memory Usage:"
free | awk '/^Mem/ {printf "  Used: %.1f%% (%.1f GB / %.1f GB)\n", ($3/$2)*100, $3/1024/1024, $2/1024/1024}'

echo "Disk Usage:"
df / | awk '/\// {printf "  Used: %s (%.1f%%)\n", $3, ($3/$2)*100}'

# Проверка портов
echo ""
echo "=== Port Status ==="
for port in 3000 8000 5432 5678 5679 80 443; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} Port $port: ACTIVE"
    else
        echo -e "${YELLOW}○${NC} Port $port: inactive"
    fi
done

# Проверка процессов Docker
echo ""
echo "=== Docker Process Status ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | \
    grep -E "supabase|n8n|postgres" || echo "No containers running"

# Проверка логов на ошибки
echo ""
echo "=== Recent Errors (last 10 minutes) ==="
for service in supabase_postgres supabase_api n8n n8n_postgres; do
    error_count=$(docker logs --since 10m $service 2>/dev/null | grep -i "error" | wc -l)
    if [ $error_count -gt 0 ]; then
        echo -e "${RED}$service: $error_count errors${NC}"
        docker logs --since 10m $service 2>/dev/null | grep -i "error" | head -3
    fi
done

echo ""
echo "=========================================="
echo "Monitoring completed"
echo "=========================================="
