# Обновление, поддержка и администрирование

## Обновление компонентов

### 1. Обновление Supabase

#### Способ 1: Через Docker Compose

```bash
cd /opt/supabase/docker

# Проверьте текущую версию
docker-compose images

# Остановите сервисы
docker-compose down

# Обновите образы
docker-compose pull

# Запустите новую версию
docker-compose up -d

# Проверьте логи на ошибки
docker-compose logs -f

# Убедитесь что все работает
curl http://localhost:3000  # Studio
curl http://localhost:8000/health  # API
```

#### Способ 2: Миграция данных при обновлении

```bash
# Перед обновлением делайте резервную копию
docker-compose exec postgres pg_dump -U postgres postgres | \
  gzip > supabase_backup_$(date +%Y%m%d_%H%M%S).sql.gz

# После обновления проверьте миграции
docker-compose logs postgres | grep -i migrate

# Если есть ошибки миграции
docker-compose exec postgres psql -U postgres -d postgres -c \
  "SELECT * FROM pg_catalog.pg_extension WHERE extname LIKE '%';"
```

### 2. Обновление n8n

#### Способ 1: Автоматическое обновление (Watchtower)

```yaml
# Добавьте в docker-compose.yml n8n

services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: 
      - --interval
      - "86400"  # Проверка раз в сутки
      - --cleanup  # Удалять старые образы
    restart: always
```

#### Способ 2: Ручное обновление

```bash
cd /opt/n8n

# Сделайте резервную копию данных
docker-compose exec -T n8n-postgres pg_dump -U n8n n8n | \
  gzip > n8n_backup_$(date +%Y%m%d_%H%M%S).sql.gz

tar -czf n8n_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz data/

# Остановите n8n
docker-compose down

# Обновите образ
docker-compose pull n8n

# Запустите новую версию
docker-compose up -d

# Проверьте логи
docker-compose logs -f n8n

# Убедитесь что версия обновилась
curl http://localhost:5678/health
```

#### Способ 3: Обновление отдельного сервиса

```bash
# Обновить только n8n (оставить БД без изменений)
docker-compose pull n8n
docker-compose up -d n8n

# Обновить только PostgreSQL
docker-compose pull n8n-postgres
docker-compose up -d n8n-postgres
```

### 3. Обновление Docker и Docker Compose

```bash
# Обновление Docker
sudo apt-get update
sudo apt-get upgrade docker-ce docker-ce-cli

# Проверка версии
docker --version

# Обновление Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Проверка версии
docker-compose --version

# Перезагрузка Docker демона
sudo systemctl restart docker
```

## Резервное копирование

### 1. Стратегия резервного копирования

```
Рекомендуемые интервалы:

- Почасовое: для активных сервисов (Supabase)
- Ежедневное: полная резервная копия
- Еженедельное: долгосрочное архивирование
- Ежемесячное: compliance требования

Хранилище:
- Локальное: /backups/
- Облачное: S3, Google Cloud Storage
- Внешний сервер: SFTP, rsync
```

### 2. Резервная копия Supabase

```bash
#!/bin/bash
# /opt/supabase/backup.sh

BACKUP_DIR="/backups/supabase"
REMOTE_BACKUP_DIR="backup@backup-server:/remote/backups/supabase"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

echo "Starting Supabase backup..."

# 1. Дамп базы данных
cd /opt/supabase/docker
docker-compose exec -T postgres pg_dump -U postgres -Fc postgres > \
  $BACKUP_DIR/supabase_db_$DATE.dump

if [ $? -eq 0 ]; then
    echo "✓ Database backup completed"
else
    echo "✗ Database backup failed"
    exit 1
fi

# 2. Резервная копия конфигурации
tar -czf $BACKUP_DIR/supabase_config_$DATE.tar.gz \
  .env volumes/ \
  --exclude=postgres_data/base

if [ $? -eq 0 ]; then
    echo "✓ Configuration backup completed"
else
    echo "✗ Configuration backup failed"
    exit 1
fi

# 3. Отправка на удаленный сервер (если настроено)
if [ -n "$REMOTE_BACKUP_DIR" ]; then
    rsync -avz --delete \
      $BACKUP_DIR/ \
      $REMOTE_BACKUP_DIR \
      --remove-source-files-on-demand

    if [ $? -eq 0 ]; then
        echo "✓ Remote backup completed"
    else
        echo "✗ Remote backup failed"
    fi
fi

# 4. Удаление старых резервных копий
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -type f -name "*.dump" -o -name "*.tar.gz" | \
  sort -r | tail -n +6 | xargs rm -f

# 5. Проверка целостности последней резервной копии
latest_dump=$(ls -t $BACKUP_DIR/*.dump | head -1)
pg_restore --list $latest_dump > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Backup integrity verified"
else
    echo "✗ Backup integrity check failed"
fi

echo "Backup completed at $(date)"
```

### 3. Резервная копия n8n

```bash
#!/bin/bash
# /opt/n8n/backup.sh

BACKUP_DIR="/backups/n8n"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

echo "Starting n8n backup..."

cd /opt/n8n

# 1. Дамп базы данных n8n
docker-compose exec -T n8n-postgres pg_dump -U n8n n8n -Fc > \
  $BACKUP_DIR/n8n_db_$DATE.dump

# 2. Резервная копия данных (workflows, credentials)
tar -czf $BACKUP_DIR/n8n_data_$DATE.tar.gz \
  data/ .env \
  --exclude=data/n8n_sqlite.db

# 3. Удаление старых резервных копий
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

echo "n8n backup completed at $(date)"
```

### 4. Автоматическое резервное копирование

```bash
# Добавьте оба скрипта резервного копирования в crontab

sudo crontab -e

# Суpabase: ежедневно в 2:00 AM
0 2 * * * /opt/supabase/backup.sh >> /var/log/supabase-backup.log 2>&1

# n8n: ежедневно в 3:00 AM
0 3 * * * /opt/n8n/backup.sh >> /var/log/n8n-backup.log 2>&1

# Проверка целостности резервных копий: еженедельно (воскресенье в 4:00 AM)
0 4 * * 0 /opt/check-backups.sh >> /var/log/backup-check.log 2>&1
```

### 5. Восстановление из резервной копии

#### Восстановление Supabase

```bash
# Остановка сервисов
cd /opt/supabase/docker
docker-compose down

# Восстановление БД
docker-compose up -d postgres

sleep 10

# Восстановление дамп
docker-compose exec -T postgres pg_restore -U postgres -Fc -d postgres \
  < /backups/supabase/supabase_db_20240115_140000.dump

# Восстановление конфигурации
tar -xzf /backups/supabase/supabase_config_20240115_140000.tar.gz -C /opt/supabase/docker/

# Перезагрузка всех сервисов
docker-compose up -d
```

#### Восстановление n8n

```bash
# Остановка n8n
cd /opt/n8n
docker-compose down

# Восстановление БД
docker-compose up -d n8n-postgres
sleep 10

docker-compose exec -T n8n-postgres pg_restore -U n8n -d n8n -Fc \
  < /backups/n8n/n8n_db_20240115_150000.dump

# Восстановление данных
tar -xzf /backups/n8n/n8n_data_20240115_150000.tar.gz -C /opt/n8n/

# Перезагрузка
docker-compose up -d
```

## Мониторинг

### 1. Проверка здоровья сервисов

```bash
#!/bin/bash
# /opt/monitor.sh

echo "=== Supabase Health Check ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health
echo ""
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health
echo ""

echo "=== n8n Health Check ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/health
echo ""

echo "=== Docker Containers ==="
docker-compose -f /opt/supabase/docker/docker-compose.yml ps
docker-compose -f /opt/n8n/docker-compose.yml ps

echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo "=== Disk Usage ==="
df -h | grep -E '^/|^Filesystem'

echo "=== Database Connections ==="
docker-compose -f /opt/supabase/docker/docker-compose.yml exec -T postgres \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'postgres';"
```

### 2. Алерты и уведомления

```bash
#!/bin/bash
# /opt/check-health.sh - скрипт для проверки с уведомлениями

ALERT_EMAIL="admin@example.com"
ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Функция отправки Slack уведомления
send_slack_alert() {
    local message=$1
    curl -X POST $ALERT_SLACK_WEBHOOK \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"$message\"}"
}

# Функция отправки email уведомления
send_email_alert() {
    local subject=$1
    local message=$2
    echo "$message" | mail -s "$subject" $ALERT_EMAIL
}

# Проверка Supabase API
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ "$API_STATUS" != "200" ]; then
    send_slack_alert "🚨 Supabase API is down! Status: $API_STATUS"
    send_email_alert "Alert: Supabase API down" "Status code: $API_STATUS"
fi

# Проверка n8n
N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/health)
if [ "$N8N_STATUS" != "200" ]; then
    send_slack_alert "🚨 n8n is down! Status: $N8N_STATUS"
    send_email_alert "Alert: n8n down" "Status code: $N8N_STATUS"
fi

# Проверка свободного места на диске
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [ "$DISK_USAGE" -gt 85 ]; then
    send_slack_alert "⚠️  Disk usage is high: $DISK_USAGE%"
fi
```

Добавьте в crontab:

```bash
# Проверка каждые 5 минут
*/5 * * * * /opt/check-health.sh
```

### 3. Логирование

```bash
# Проверка логов Supabase
docker-compose -f /opt/supabase/docker/docker-compose.yml logs --tail=100

# Проверка логов n8n
docker-compose -f /opt/n8n/docker-compose.yml logs --tail=100

# Логи конкретного сервиса
docker-compose -f /opt/supabase/docker/docker-compose.yml logs -f api

# Сохранение логов в файл
docker-compose -f /opt/n8n/docker-compose.yml logs > /var/log/n8n-full.log

# Просмотр логов sistem
journalctl -u docker -n 100
```

## Производительность и оптимизация

### 1. Оптимизация PostgreSQL

```sql
-- Анализ скорости запросов
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- Создание индексов
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_products_category ON products(category_id, price);

-- Вакуумирование и анализ
VACUUM ANALYZE;

-- Проверка нарушенных индексов
REINDEX INDEX idx_users_email;

-- Статистика таблицы
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### 2. Оптимизация Docker контейнеров

```yaml
# В docker-compose.yml добавьте ограничения ресурсов

services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
  
  api:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### 3. Оптимизация n8n workflow

```javascript
// Плохо: обработка по одной
for (let i = 0; i < 10000; i++) {
  await api.post('/item', data[i]);  // 10000 запросов
}

// Хорошо: batch обработка
const batchSize = 100;
for (let i = 0; i < 10000; i += batchSize) {
  await api.post('/items/batch', data.slice(i, i + batchSize));
}
// ~100 запросов вместо 10000
```

## Безопасность

### 1. Обновление безопасности

```bash
# Регулярно обновляйте систему
sudo apt-get update
sudo apt-get upgrade

# Проверьте CVE для используемых версий
docker inspect n8n | grep VERSION
docker inspect postgres | grep VERSION

# Сканирование уязвимостей
trivy image n8nio/n8n:latest
trivy image postgres:latest
```

### 2. Управление ключами и паролями

```bash
# Используйте .env для хранения секретов
# НИКОГДА не commit .env в Git

# Пример .env
DB_PASSWORD=your_secure_password_here
JWT_SECRET=your_jwt_secret_here
SERVICE_ROLE_KEY=your_service_role_key_here

# .gitignore
.env
.env.local
*.log
backups/
```

### 3. SSL/TLS сертификаты

```bash
# Регулярно проверяйте срок действия сертификатов
sudo certbot certificates

# Автоматическое обновление Let's Encrypt
sudo systemctl status certbot.timer
sudo systemctl enable certbot.timer

# Тестирование обновления
sudo certbot renew --dry-run
```

## Отладка и решение проблем

### 1. Контейнер не запускается

```bash
# Проверка логов
docker-compose logs n8n

# Проверка процесса
docker ps -a | grep n8n

# Попытка перезагрузки
docker-compose restart n8n

# Полная пересборка
docker-compose down
docker-compose up -d

# Проверка ошибок конфигурации
docker-compose config
```

### 2. Медленная производительность

```bash
# Проверка использования ресурсов
docker stats

# Проверка дисковых операций
iostat -x 1

# Проверка сетевого трафика
nethogs

# Анализ медленных SQL запросов
docker-compose exec postgres psql -U postgres -d postgres -c \
  "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### 3. Проблемы с соединением

```bash
# Проверка портов
sudo netstat -tlnp | grep LISTEN

# Проверка firewall правил
sudo ufw status

# Тестирование подключения
telnet localhost 5432
telnet localhost 5678

# Проверка DNS
nslookup supabase.yourdomain.com
```

## Документирование

### Ведение журнала изменений

```
/opt/CHANGELOG.md

## 2024-01-15
- Updated Supabase to v1.50.0
- Updated n8n to v1.23.0
- Fixed workflow execution timeout issue
- Added new Slack integration workflow

## 2024-01-10
- Implemented daily backup strategy
- Set up monitoring alerts
- Optimized database indexes
```

### Документирование конфигурации

```
/opt/CONFIGURATION.md

# System Configuration

## Server Specs
- OS: Ubuntu 22.04 LTS
- CPU: 4 cores
- RAM: 16 GB
- Disk: 100 GB SSD

## Services
- Supabase: v1.50.0
- n8n: v1.23.0
- PostgreSQL: v15
- Docker: v24.0

## Domains
- Supabase Studio: https://supabase.yourdomain.com
- Supabase API: https://api.supabase.yourdomain.com
- n8n: https://n8n.yourdomain.com

## Credentials Storage
Location: /opt/supabase/.env, /opt/n8n/.env
Backup: encrypted on backup server
```

## Автоматизация задач

### Crontab schedule

```bash
# Просмотр всех задач
sudo crontab -l

# Основные задачи:

# Ежедневное резервное копирование (2:00 AM)
0 2 * * * /opt/supabase/backup.sh

# Ежедневное резервное копирование n8n (3:00 AM)
0 3 * * * /opt/n8n/backup.sh

# Проверка здоровья сервиса (каждые 5 минут)
*/5 * * * * /opt/check-health.sh

# Еженедельное очищение логов (воскресенье, 5:00 AM)
0 5 * * 0 find /var/log -name "*.log" -mtime +7 -delete

# Ежемесячный отчет производительности (1-го числа, 6:00 AM)
0 6 1 * * /opt/generate-report.sh
```

## Следующие шаги

- Регулярно проверяйте логи
- Мониторьте использование ресурсов
- Тестируйте восстановление из резервных копий
- Планируйте обновления в off-peak часы
- Документируйте все изменения
