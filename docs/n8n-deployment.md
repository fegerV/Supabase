# Развертывание n8n на собственном сервере

## Введение

n8n - это workflow automation tool (инструмент для автоматизации процессов) с большой библиотекой интеграций. Это руководство описывает установку n8n на том же сервере, что и Supabase.

## Вариант 1: Развертывание с Docker Compose

### 1. Подготовка директории

```bash
mkdir -p /opt/n8n
cd /opt/n8n

# Создание необходимых директорий
mkdir -p data logs
chmod 777 data logs
```

### 2. Создание docker-compose.yml

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    
    ports:
      - "5678:5678"
      - "5679:5679"  # Webhook port
    
    environment:
      - NODE_ENV=production
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=n8n-postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD:-n8n_secure_password}
      - DB_POSTGRESDB_SSL_ENABLED=true
      - WEBHOOK_URL=https://n8n.yourdomain.com/
      - GENERIC_TIMEZONE=UTC
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=336  # 2 недели
      - LOG_LEVEL=info
      - N8N_ANALYTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
    
    volumes:
      - ./data:/home/node/.n8n
      - ./logs:/logs
    
    depends_on:
      - n8n-postgres
    
    networks:
      - n8n-network
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5678/health"]
      interval: 30s
      timeout: 10s
      retries: 5
  
  n8n-postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: always
    
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${DB_PASSWORD:-n8n_secure_password}
    
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    
    networks:
      - n8n-network
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  n8n-network:
    driver: bridge
```

### 3. Создание .env файла

```bash
# /opt/n8n/.env

# Основные настройки
DB_PASSWORD=your_secure_database_password_here
NODE_ENV=production

# Домены
N8N_HOST=0.0.0.0
N8N_PORT=5678
WEBHOOK_URL=https://n8n.yourdomain.com/

# Безопасность
N8N_ENCRYPTION_KEY=your_encryption_key_at_least_32_characters

# Email (для уведомлений)
SMTP_HOST=smtp.your-mail-provider.com
SMTP_PORT=587
SMTP_USER=your-email@example.com
SMTP_PASS=your-smtp-password
SMTP_SENDER=n8n@yourdomain.com

# Лимиты
N8N_EXECUTION_TIMEOUT=3600
N8N_EXECUTION_TIMEOUT_WARNING=3000

# Логирование
LOG_LEVEL=info
AUDIT_LOG_ENABLED=true
```

### 4. Запуск контейнеров

```bash
cd /opt/n8n

# Генерация шифровального ключа
openssl rand -base64 32

# Добавьте ключ в .env как N8N_ENCRYPTION_KEY

# Запуск сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f n8n
```

### 5. Ожидание инициализации

```bash
# Ждите сообщения вроде:
# "Editor is now available at http://localhost:5678"

# Проверка здоровья
curl http://localhost:5678/health

# Проверка готовности БД
docker-compose exec n8n-postgres psql -U n8n -d n8n -c "SELECT version();"
```

## Вариант 2: Развертывание с Supabase в одном Docker Compose

Если вы хотите развернуть n8n и Supabase вместе:

```yaml
# Добавьте к docker-compose.yml Supabase

services:
  # ... существующие сервисы Supabase ...

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
      - "5679:5679"
    environment:
      - NODE_ENV=production
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres  # Используйте Supabase postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${N8N_DB_PASSWORD}
      - WEBHOOK_URL=https://n8n.yourdomain.com/
    volumes:
      - ./n8n_data:/home/node/.n8n
    networks:
      - default  # Используйте одну сеть с Supabase
```

## Конфигурация Nginx Reverse Proxy

### 1. Создание конфигурации Nginx

```bash
sudo nano /etc/nginx/sites-available/n8n
```

### 2. Конфиг с SSL (Let's Encrypt)

```nginx
# HTTP - перенаправление на HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name n8n.yourdomain.com;
    
    return 301 https://$server_name$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name n8n.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Увеличенный лимит размера тела
    client_max_body_size 50M;

    # Основной интерфейс n8n
    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    # Webhook endpoint
    location /webhook/ {
        proxy_pass http://localhost:5679/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
    }

    # WebSocket для real-time обновлений
    location /push {
        proxy_pass http://localhost:5678/push;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # REST API endpoints
    location /api/ {
        proxy_pass http://localhost:5678/api/;
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

# Активирование конфигурации
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Перезагрузка Nginx
sudo systemctl restart nginx
```

## Первоначальная настройка

### 1. Доступ к интерфейсу

```bash
# Откройте в браузере
https://n8n.yourdomain.com

# При первом входе создайте администраторский аккаунт
# Email: admin@example.com
# Password: your_strong_password
```

### 2. Базовые настройки

1. **Settings** → **General**:
   - Timezone: выберите ваш часовой пояс
   - Language: выберите язык интерфейса

2. **Settings** → **Users**:
   - Пригласите других пользователей
   - Установите роли (Admin, Editor, Viewer)

3. **Settings** → **API Keys**:
   - Создайте API ключ для программного доступа
   - Сохраните ключ в безопасном месте

## Оптимизация

### 1. Параметры баз данных

```bash
# В .env файле для n8n:

# Размер буфера памяти для выполнений
N8N_EXECUTION_BUFFER_SIZE=100

# Количество параллельных выполнений
N8N_EXECUTION_PROCESS_POOL_SIZE=4

# Сохранение данных выполнений
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336  # 2 недели

# Максимум выполнений в памяти
N8N_EXECUTION_BUFFER_SIZE=100
```

### 2. Лимиты выполнения

```bash
# Таймауты в секундах
N8N_EXECUTION_TIMEOUT=3600           # 1 час
N8N_EXECUTION_TIMEOUT_WARNING=3000   # Предупреждение за 50 минут
```

### 3. Масштабирование

Для больших объемов используйте несколько workers:

```yaml
services:
  n8n-main:
    image: n8nio/n8n:latest
    environment:
      - EXECUTIONS_MODE=queue
      - DB_TYPE=postgresdb
      # ... другие параметры ...

  n8n-worker-1:
    image: n8nio/n8n:latest
    environment:
      - EXECUTIONS_MODE=queue
      - N8N_MODE=worker
      - DB_TYPE=postgresdb
      # ... другие параметры ...

  n8n-worker-2:
    image: n8nio/n8n:latest
    environment:
      - EXECUTIONS_MODE=queue
      - N8N_MODE=worker
      - DB_TYPE=postgresdb
      # ... другие параметры ...

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

## Мониторинг и логирование

### 1. Уровни логирования

```bash
# В .env файле

# Уровни: error, warn, info, debug, trace
LOG_LEVEL=info

# Включение аудита
AUDIT_LOG_ENABLED=true

# Сохранение логов
N8N_LOG_OUTPUT=file
```

### 2. Просмотр логов

```bash
# Все логи
docker-compose logs -f n8n

# Последние 100 строк
docker-compose logs --tail=100 n8n

# Логи с временными метками
docker-compose logs -f --timestamps n8n
```

### 3. Метрики (опционально)

```bash
# Используйте Prometheus для сбора метрик
# Endpoint: http://localhost:5678/metrics

curl http://localhost:5678/metrics
```

## Резервное копирование и восстановление

### 1. Резервная копия данных n8n

```bash
#!/bin/bash
# /opt/n8n/backup.sh

BACKUP_DIR="/backups/n8n"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Дамп БД n8n
docker-compose exec -T n8n-postgres pg_dump -U n8n n8n | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Резервная копия конфигурации и данных
tar -czf $BACKUP_DIR/data_$DATE.tar.gz data/

# Удаление старых резервных копий (старше 30 дней)
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/db_$DATE.sql.gz"
```

### 2. Восстановление из резервной копии

```bash
# Восстановление БД
gunzip < backup.sql.gz | docker-compose exec -T n8n-postgres psql -U n8n -d n8n

# Восстановление данных
tar -xzf data_backup.tar.gz
docker-compose restart n8n
```

### 3. Автоматическое резервное копирование

```bash
# Добавьте в crontab
sudo crontab -e

# Ежедневно в 3:00 AM
0 3 * * * /opt/n8n/backup.sh
```

## Обновление n8n

### 1. Обновление образа Docker

```bash
cd /opt/n8n

#停止текущей версии
docker-compose down

# Загрузить новый образ
docker-compose pull

# Запуск новой версии
docker-compose up -d

# Проверка логов на ошибки
docker-compose logs -f n8n
```

### 2. Автоматическое обновление (опционально)

Используйте инструмент вроде Watchtower для автоматических обновлений:

```yaml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400  # Проверка раз в сутки
    restart: always
```

## Решение проблем

### Проблема: n8n недоступен

```bash
# Проверка статуса контейнеров
docker-compose ps

# Проверка логов
docker-compose logs -f n8n

# Проверка портов
sudo netstat -tlnp | grep 5678

# Перезагрузка
docker-compose restart n8n
```

### Проблема: Медленное выполнение workflows

```bash
# Проверьте использование ресурсов
docker stats n8n

# Ограничьте количество параллельных выполнений
# Редактируйте .env:
N8N_EXECUTION_PROCESS_POOL_SIZE=2  # Уменьшите с 4

# Увеличьте таймауты
N8N_EXECUTION_TIMEOUT=7200
```

### Проблема: Ошибка подключения к БД

```bash
# Проверка соединения с PostgreSQL
docker-compose exec n8n-postgres psql -U n8n -d n8n -c "SELECT 1"

# Проверка переменных окружения
docker-compose config | grep DB_

# Перезагрузка
docker-compose down
docker-compose up -d
```

## Следующие шаги

- Перейдите к [Настройке n8n](./n8n-configuration.md)
- Изучите [Справочник нод n8n](./n8n-nodes-guide.md)
- Настройте [Интеграцию с Supabase](./supabase-n8n-integration.md)
