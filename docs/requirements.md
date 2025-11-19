# Системные требования

## Требования к серверу

### Минимальные требования

| Параметр | Значение |
|----------|----------|
| Процессор | 2 ядра (4 ядра рекомендуется) |
| ОЗУ | 4 GB минимум (8 GB рекомендуется) |
| Диск | 20 GB SSD (50 GB+ рекомендуется) |
| ОС | Ubuntu 20.04+ / Debian 11+ |
| Сеть | Стабильное интернет-соединение, открытые порты |

### Рекомендуемые требования для production

| Параметр | Значение |
|----------|----------|
| Процессор | 4-8 ядер |
| ОЗУ | 16-32 GB |
| Диск | 100+ GB SSD с RAID-конфигурацией |
| Вычисления | 4+ CPU cores для параллельной обработки |
| Сеть | 100+ Mbps |
| Резервная копия | Отдельный диск/сервер |

## Требования к ПО

### Docker и Docker Compose

```bash
# Версия Docker: 20.10+
# Версия Docker Compose: 2.0+

docker --version
docker-compose --version
```

### Зависимости ОС

```bash
# Для Ubuntu/Debian

sudo apt-get update
sudo apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  libssl-dev \
  libffi-dev \
  python3-dev \
  postgresql-client \
  net-tools \
  ufw \
  fail2ban
```

## Открытые порты и firewall

### Порты по умолчанию

| Сервис | Порт | Протокол | Описание |
|--------|------|----------|---------|
| Supabase Studio | 3000 | HTTP/HTTPS | Web-интерфейс Supabase |
| Supabase API | 8000 | HTTP/HTTPS | REST API |
| PostgreSQL | 5432 | TCP | База данных (внутренняя сеть) |
| n8n | 5678 | HTTP/HTTPS | Web-интерфейс n8n |
| n8n webhook | 5679 | HTTP/HTTPS | Webhook обработчик |
| PgBouncer | 6543 | TCP | Connection pooler (опционально) |

### Настройка firewall (UFW)

```bash
# Разрешить SSH
sudo ufw allow 22/tcp

# Разрешить Supabase Studio
sudo ufw allow 3000/tcp

# Разрешить REST API
sudo ufw allow 8000/tcp

# Разрешить n8n
sudo ufw allow 5678/tcp
sudo ufw allow 5679/tcp

# Если используется nginx в качестве reverse proxy
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Включить firewall
sudo ufw enable
```

## Сетевые требования

- **Доступ в интернет**: для загрузки образов Docker и обновлений
- **DNS**: корректная конфигурация DNS для доменов
- **SSL/TLS**: сертификаты для HTTPS (Let's Encrypt рекомендуется)
- **Bandwidth**: минимум 10 Mbps для нормальной работы

## Требования к доменам

- Основной домен для Supabase (например, supabase.yourdomain.com)
- Домен/поддомен для n8n (например, n8n.yourdomain.com)
- SSL сертификаты (можно использовать Let's Encrypt бесплатно)

## Проверка готовности сервера

Используйте скрипт для проверки:

```bash
#!/bin/bash

echo "=== Проверка системных требований ==="

# Проверка ОС
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)"

# Проверка CPU
echo "CPUs: $(nproc)"

# Проверка памяти
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"

# Проверка диска
echo "Disk: $(df -h / | awk '/\// {print $2}')"

# Проверка Docker
if command -v docker &> /dev/null; then
    echo "Docker: $(docker --version)"
else
    echo "Docker: НЕ УСТАНОВЛЕН"
fi

# Проверка Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose: $(docker-compose --version)"
else
    echo "Docker Compose: НЕ УСТАНОВЛЕН"
fi

# Проверка портов
echo "Проверка доступности портов:"
for port in 3000 8000 5432 5678 5679; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "  Порт $port: ЗАНЯТ"
    else
        echo "  Порт $port: СВОБОДЕН"
    fi
done
```

## Сертификаты SSL

### Использование Let's Encrypt

```bash
# Установка Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Получение сертификата
sudo certbot certonly --standalone \
  -d supabase.yourdomain.com \
  -d n8n.yourdomain.com \
  --email your-email@example.com \
  --agree-tos

# Сертификаты будут расположены в:
# /etc/letsencrypt/live/yourdomain.com/
```

## Дополнительно

- **Redis** (опционально): для кеширования и очередей
- **Monitoring**: Prometheus, Grafana для мониторинга
- **Logging**: ELK Stack или Loki для логирования
