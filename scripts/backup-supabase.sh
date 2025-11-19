#!/bin/bash

# Скрипт резервного копирования Supabase

BACKUP_DIR="/backups/supabase"
COMPOSE_DIR="/opt/supabase/docker"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
LOG_FILE="/var/log/supabase-backup.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Функция обработки ошибок
on_error() {
    log "✗ Backup failed: $1"
    # Отправка уведомления (если настроено)
    # mail -s "Supabase Backup Failed" admin@example.com <<< "$1"
    exit 1
}

log "Starting Supabase backup..."

# Проверка директории
mkdir -p $BACKUP_DIR

# Проверка Docker Compose
cd $COMPOSE_DIR || on_error "Cannot access $COMPOSE_DIR"

# 1. Дамп базы данных
log "Dumping PostgreSQL database..."
docker-compose exec -T postgres pg_dump -U postgres -Fc postgres > \
    "$BACKUP_DIR/supabase_db_$DATE.dump" 2>/dev/null
    
if [ $? -ne 0 ]; then
    on_error "Database dump failed"
fi
log "✓ Database backup completed"

# 2. Архивирование конфигурации
log "Archiving configuration..."
tar -czf "$BACKUP_DIR/supabase_config_$DATE.tar.gz" \
    .env \
    volumes/ \
    --exclude=volumes/db \
    --exclude=volumes/db/* \
    2>/dev/null

if [ $? -ne 0 ]; then
    on_error "Configuration backup failed"
fi
log "✓ Configuration backup completed"

# 3. Проверка целостности
log "Verifying backup integrity..."
pg_restore --list "$BACKUP_DIR/supabase_db_$DATE.dump" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    on_error "Backup integrity check failed"
fi
log "✓ Backup integrity verified"

# 4. Получение размера резервной копии
DB_SIZE=$(du -h "$BACKUP_DIR/supabase_db_$DATE.dump" | cut -f1)
CONFIG_SIZE=$(du -h "$BACKUP_DIR/supabase_config_$DATE.tar.gz" | cut -f1)
log "Backup sizes: DB=$DB_SIZE, Config=$CONFIG_SIZE"

# 5. Удаление старых резервных копий
log "Cleaning old backups (older than $RETENTION_DAYS days)..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

OLD_COUNT=$(find $BACKUP_DIR -type f \( -name "*.dump" -o -name "*.tar.gz" \) | wc -l)
log "Kept $OLD_COUNT recent backup sets"

# 6. Список файлов резервных копий
log "Current backups:"
ls -lh $BACKUP_DIR | grep -E "dump|tar.gz"

log "✓ Supabase backup completed successfully"
log "Backup location: $BACKUP_DIR/supabase_db_$DATE.dump"
