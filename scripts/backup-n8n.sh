#!/bin/bash

# Скрипт резервного копирования n8n

BACKUP_DIR="/backups/n8n"
COMPOSE_DIR="/opt/n8n"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
LOG_FILE="/var/log/n8n-backup.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Функция обработки ошибок
on_error() {
    log "✗ Backup failed: $1"
    exit 1
}

log "Starting n8n backup..."

# Проверка директории
mkdir -p $BACKUP_DIR

# Проверка Docker Compose
cd $COMPOSE_DIR || on_error "Cannot access $COMPOSE_DIR"

# 1. Дамп базы данных n8n
log "Dumping n8n PostgreSQL database..."
docker-compose exec -T n8n-postgres pg_dump -U n8n -Fc n8n > \
    "$BACKUP_DIR/n8n_db_$DATE.dump" 2>/dev/null
    
if [ $? -ne 0 ]; then
    on_error "Database dump failed"
fi
log "✓ Database backup completed"

# 2. Архивирование данных и конфигурации
log "Archiving n8n data..."
tar -czf "$BACKUP_DIR/n8n_data_$DATE.tar.gz" \
    data/ \
    .env \
    --exclude=data/n8n_sqlite.db \
    2>/dev/null

if [ $? -ne 0 ]; then
    on_error "Data backup failed"
fi
log "✓ Data backup completed"

# 3. Архивирование workflow и credentials
log "Archiving workflows and credentials..."
docker cp n8n:/home/node/.n8n ./n8n_backup_tmp 2>/dev/null

if [ -d "./n8n_backup_tmp" ]; then
    tar -czf "$BACKUP_DIR/n8n_workflows_$DATE.tar.gz" \
        ./n8n_backup_tmp \
        2>/dev/null
    rm -rf ./n8n_backup_tmp
    log "✓ Workflows backup completed"
fi

# 4. Получение размеров резервных копий
DB_SIZE=$(du -h "$BACKUP_DIR/n8n_db_$DATE.dump" | cut -f1)
DATA_SIZE=$(du -h "$BACKUP_DIR/n8n_data_$DATE.tar.gz" | cut -f1)
log "Backup sizes: DB=$DB_SIZE, Data=$DATA_SIZE"

# 5. Удаление старых резервных копий
log "Cleaning old backups (older than $RETENTION_DAYS days)..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

BACKUP_COUNT=$(find $BACKUP_DIR -type f -name "*.dump" | wc -l)
log "Kept $BACKUP_COUNT recent backup sets"

# 6. Список файлов резервных копий
log "Current backups:"
ls -lh $BACKUP_DIR | tail -10

log "✓ n8n backup completed successfully"
log "Backup location: $BACKUP_DIR/n8n_db_$DATE.dump"
