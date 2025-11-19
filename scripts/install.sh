#!/bin/bash

# Скрипт для первоначальной установки Supabase и n8n

set -e

echo "=========================================="
echo "Supabase + n8n Installation Script"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода ошибок
error() {
    echo -e "${RED}✗ Error: $1${NC}"
    exit 1
}

# Функция для вывода успеха
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Функция для вывода информации
info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Проверка прав администратора
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# 1. Проверка системных требований
info "Checking system requirements..."

# Проверка ОС
if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS"
fi

source /etc/os-release
info "Detected OS: $PRETTY_NAME"

# Проверка CPU
CPU_COUNT=$(nproc)
if [ "$CPU_COUNT" -lt 2 ]; then
    error "Minimum 2 CPUs required, found: $CPU_COUNT"
fi
success "CPU count: $CPU_COUNT"

# Проверка памяти
RAM_GB=$(free -g | awk 'NR==2 {print $2}')
if [ "$RAM_GB" -lt 4 ]; then
    error "Minimum 4GB RAM required, found: ${RAM_GB}GB"
fi
success "RAM: ${RAM_GB}GB"

# Проверка диска
DISK_AVAILABLE=$(df / | awk 'NR==2 {print $4}')
DISK_GB=$((DISK_AVAILABLE / 1024 / 1024))
if [ "$DISK_GB" -lt 20 ]; then
    error "Minimum 20GB free disk space required, found: ${DISK_GB}GB"
fi
success "Free disk space: ${DISK_GB}GB"

# 2. Обновление системы
info "Updating system packages..."
apt-get update
apt-get upgrade -y
success "System updated"

# 3. Установка Docker
if ! command -v docker &> /dev/null; then
    info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    success "Docker installed"
else
    success "Docker already installed: $(docker --version)"
fi

# 4. Установка Docker Compose
if ! command -v docker-compose &> /dev/null; then
    info "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    success "Docker Compose installed"
else
    success "Docker Compose already installed: $(docker-compose --version)"
fi

# 5. Добавление текущего пользователя в группу docker
if ! groups $SUDO_USER | grep -q docker; then
    info "Adding user $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
    success "User added to docker group"
fi

# 6. Создание директорий
info "Creating directories..."
mkdir -p /opt/supabase/docker
mkdir -p /opt/n8n
mkdir -p /backups/supabase
mkdir -p /backups/n8n
mkdir -p /var/log/supabase
mkdir -p /var/log/n8n
success "Directories created"

# 7. Копирование конфигов
info "Copying configuration files..."

if [ ! -f /opt/supabase/docker/.env ]; then
    cp .env.example /opt/supabase/docker/.env
    info "Created Supabase .env (edit with your values)"
else
    info "Supabase .env already exists"
fi

if [ ! -f /opt/n8n/.env ]; then
    cp .env.example /opt/n8n/.env
    info "Created n8n .env (edit with your values)"
else
    info "n8n .env already exists"
fi

# 8. Установка утилит
info "Installing utilities..."
apt-get install -y \
    curl \
    wget \
    git \
    postgresql-client \
    net-tools \
    htop \
    ca-certificates \
    gnupg \
    lsb-release
success "Utilities installed"

# 9. Установка Nginx (reverse proxy)
if ! command -v nginx &> /dev/null; then
    info "Installing Nginx..."
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    success "Nginx installed"
else
    success "Nginx already installed"
fi

# 10. Установка Certbot для SSL
if ! command -v certbot &> /dev/null; then
    info "Installing Certbot..."
    apt-get install -y certbot python3-certbot-nginx
    success "Certbot installed"
else
    success "Certbot already installed"
fi

# 11. Установка мониторинга
info "Installing monitoring tools..."
apt-get install -y ufw fail2ban
systemctl enable fail2ban
systemctl start fail2ban
success "Monitoring tools installed"

# 12. Firewall настройка
info "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp  # Supabase Studio
ufw allow 8000/tcp  # Supabase API
ufw allow 5678/tcp  # n8n
ufw allow 5679/tcp  # n8n webhook
ufw --force enable
success "Firewall configured"

# 13. Создание скриптов резервного копирования
info "Creating backup scripts..."
cp scripts/backup-supabase.sh /opt/supabase/backup.sh
cp scripts/backup-n8n.sh /opt/n8n/backup.sh
chmod +x /opt/supabase/backup.sh
chmod +x /opt/n8n/backup.sh
success "Backup scripts created"

# 14. Создание скрипта мониторинга
cp scripts/monitor.sh /opt/monitor.sh
chmod +x /opt/monitor.sh
success "Monitoring script created"

# 15. Информация для следующих шагов
echo ""
echo "=========================================="
echo -e "${GREEN}Installation completed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Edit configuration files:"
echo "   - /opt/supabase/docker/.env"
echo "   - /opt/n8n/.env"
echo ""
echo "2. Add cron jobs:"
echo "   sudo crontab -e"
echo "   # Add:"
echo "   0 2 * * * /opt/supabase/backup.sh >> /var/log/supabase-backup.log 2>&1"
echo "   0 3 * * * /opt/n8n/backup.sh >> /var/log/n8n-backup.log 2>&1"
echo "   */5 * * * * /opt/monitor.sh >> /var/log/monitor.log 2>&1"
echo ""
echo "3. Start services:"
echo "   cd /opt/supabase/docker && docker-compose up -d"
echo "   cd /opt/n8n && docker-compose up -d"
echo ""
echo "4. Configure SSL certificates:"
echo "   sudo certbot certonly --standalone -d your-domain.com"
echo ""
echo "5. Check status:"
echo "   /opt/monitor.sh"
echo ""
echo "=========================================="
