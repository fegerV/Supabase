# Развертывание Supabase на собственном сервере

## Введение

Supabase - это open-source альтернатива Firebase с полнофункциональной PostgreSQL базой данных. Это руководство описывает процесс развертывания Supabase на собственном сервере.

## Подготовка

### 1. Обновление системы

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 2. Установка Docker и Docker Compose

```bash
# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавление текущего пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Установка Docker Compose (v2)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Проверка версий
docker --version
docker-compose --version
```

### 3. Клонирование Supabase репозитория

```bash
cd /opt
sudo git clone https://github.com/supabase/supabase.git
cd supabase/docker
sudo chown -R $USER:$USER /opt/supabase
```

## Конфигурация

### 1. Подготовка переменных окружения

```bash
cd /opt/supabase/docker

# Скопируйте пример конфигурации
cp .env.example .env

# Отредактируйте .env файл
nano .env
```

### 2. Ключевые переменные окружения

```bash
# Основные настройки
POSTGRES_PASSWORD=your_strong_password_here
JWT_SECRET=your_jwt_secret_at_least_32_characters
ANON_KEY=your_anon_key
SERVICE_ROLE_KEY=your_service_role_key
DASHBOARD_USERNAME=admin@example.com
DASHBOARD_PASSWORD=your_strong_dashboard_password

# Домены
API_EXTERNAL_URL=https://supabase.yourdomain.com
STUDIO_DEFAULT_ORGANIZATION=MyOrganization
STUDIO_DEFAULT_PROJECT=production

# Email (для отправки писем)
SMTP_ADMIN_EMAIL=noreply@supabase.local
SMTP_HOST=smtp.your-mail-provider.com
SMTP_PORT=587
SMTP_USER=your-email@example.com
SMTP_PASS=your-smtp-password
SMTP_SENDER_NAME=Supabase

# Прочие параметры
SITE_URL=https://yourdomain.com
ADDITIONAL_REDIRECT_URLS=https://yourdomain.com/auth/callback
LOG_LEVEL=info
```

### 3. Генерация JWT и ключей

```bash
# Генерация JWT_SECRET (минимум 32 символа)
openssl rand -base64 32

# Генерация ANON_KEY (JWT с ролью anon)
# Используйте https://jwt.io или создайте скрипт:

python3 << 'EOF'
import jwt
import os
from datetime import datetime, timedelta

secret = os.environ.get('JWT_SECRET', 'your-super-secret-key-here')

# ANON_KEY - неограниченный доступ для анонимных пользователей
anon_payload = {
    "iss": "supabase",
    "sub": "authenticated",
    "aud": "authenticated",
    "role": "anon",
    "iat": int(datetime.now().timestamp()),
    "exp": int((datetime.now() + timedelta(days=365*10)).timestamp())
}

# SERVICE_ROLE_KEY - полный доступ (хранить в безопасности!)
service_role_payload = {
    "iss": "supabase",
    "sub": "service_role",
    "aud": "authenticated",
    "role": "service_role",
    "iat": int(datetime.now().timestamp()),
    "exp": int((datetime.now() + timedelta(days=365*10)).timestamp())
}

anon_key = jwt.encode(anon_payload, secret, algorithm="HS256")
service_role_key = jwt.encode(service_role_payload, secret, algorithm="HS256")

print(f"ANON_KEY={anon_key}")
print(f"SERVICE_ROLE_KEY={service_role_key}")
EOF
```

## Развертывание

### 1. Запуск Docker Compose

```bash
cd /opt/supabase/docker

# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps
```

### 2. Ожидание инициализации

```bash
# Посмотрите логи инициализации
docker-compose logs -f

# Ждите появления строки вроде:
# supabase_postgres_1 | LOG: database system is ready to accept connections
```

### 3. Первоначальная проверка

```bash
# Проверка доступности портов
curl http://localhost:3000        # Supabase Studio
curl http://localhost:8000/health # REST API

# Проверка базы данных
psql -h localhost -U postgres -d postgres
# Пароль: значение POSTGRES_PASSWORD из .env
```

## Конфигурация Reverse Proxy (Nginx)

### 1. Установка Nginx

```bash
sudo apt-get install -y nginx

# Создание конфигурации
sudo nano /etc/nginx/sites-available/supabase
```

### 2. Конфиг Nginx с SSL

```nginx
# HTTP - перенаправление на HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name supabase.yourdomain.com;
    
    return 301 https://$server_name$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name supabase.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Supabase Studio
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Отдельный server block для REST API
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.supabase.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3. Активация конфигурации

```bash
# Проверка синтаксиса
sudo nginx -t

# Включение конфигурации
sudo ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Перезагрузка Nginx
sudo systemctl restart nginx
```

## SSL сертификаты

### Let's Encrypt с Certbot

```bash
# Установка
sudo apt-get install -y certbot python3-certbot-nginx

# Получение сертификата (Nginx режим)
sudo certbot --nginx \
  -d supabase.yourdomain.com \
  -d api.supabase.yourdomain.com \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive

# Автоматическое обновление
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Проверка обновлений
sudo certbot renew --dry-run
```

## Проверка работы

### 1. Доступ к Supabase Studio

```bash
# Откройте браузер
https://supabase.yourdomain.com

# Логин
Email: admin@example.com (из DASHBOARD_USERNAME)
Password: ваш пароль (из DASHBOARD_PASSWORD)
```

### 2. Тестирование REST API

```bash
# Получение информации о проекте
curl -X GET https://api.supabase.yourdomain.com \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"

# Создание таблицы (через SQL Editor в Studio)
# Или через psql:
psql -h localhost -U postgres -d postgres -c "
CREATE TABLE IF NOT EXISTS public.test (
    id SERIAL PRIMARY KEY,
    name TEXT
);
"
```

### 3. Проверка логов

```bash
# Все логи
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f postgres
docker-compose logs -f studio
docker-compose logs -f api
```

## Производительность и оптимизация

### 1. Ограничение ресурсов Docker

Отредактируйте `docker-compose.yml`:

```yaml
services:
  postgres:
    # ... другие настройки
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

### 2. Optimized PostgreSQL настройки

```bash
# Редактируйте /opt/supabase/docker/volumes/db/postgresql.conf
# или создайте custom.conf

# shared_buffers = 256MB (1/4 от RAM для виртуальных машин)
# effective_cache_size = 1GB
# maintenance_work_mem = 64MB
# checkpoint_completion_target = 0.9
# wal_buffers = 16MB
# default_statistics_target = 100
# max_wal_size = 4GB
```

### 3. Pooling соединений (PgBouncer)

Суpabase уже включает PgBouncer для управления соединениями.

## Резервное копирование

### 1. Резервная копия базы данных

```bash
# Полный дамп
docker-compose exec postgres pg_dump -U postgres postgres > backup.sql

# С сжатием
docker-compose exec postgres pg_dump -U postgres -F c postgres > backup.dump

# Восстановление
docker-compose exec -T postgres pg_restore -U postgres < backup.dump
```

### 2. Резервная копия конфигурации

```bash
# Архивируйте .env и volumes
tar -czf supabase-backup-$(date +%Y%m%d).tar.gz \
  /opt/supabase/docker/.env \
  /opt/supabase/docker/volumes/
```

### 3. Автоматическое резервное копирование

```bash
#!/bin/bash
# /opt/supabase/backup.sh

BACKUP_DIR="/backups/supabase"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Дамп БД
cd /opt/supabase/docker
docker-compose exec -T postgres pg_dump -U postgres postgres | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Конфигурация
tar -czf $BACKUP_DIR/config_$DATE.tar.gz .env volumes/

# Удаление старых резервных копий (старше 30 дней)
find $BACKUP_DIR -type f -mtime +30 -delete
```

Добавьте в crontab:

```bash
sudo crontab -e

# Ежедневно в 2:00 AM
0 2 * * * /opt/supabase/backup.sh
```

## Проблемы и решения

### Порт уже занят

```bash
# Проверка какой процесс использует порт
sudo lsof -i :3000
sudo lsof -i :8000

# Перенаправление на другие порты в docker-compose.yml
ports:
  - "3001:3000"
  - "8001:8000"
```

### Проблемы с памятью

```bash
# Проверка использования памяти
docker stats

# Увеличьте лимиты в docker-compose.yml или в системе
docker run --memory=2g ...
```

### Ошибки подключения

```bash
# Проверка сетевого подключения между контейнерами
docker network ls
docker network inspect supabase_docker_default

# Перезагрузка контейнеров
docker-compose restart
```

## Следующие шаги

- Перейдите к [Настройке Supabase](./supabase-configuration.md)
- Настройте [Интеграцию с n8n](./supabase-n8n-integration.md)
