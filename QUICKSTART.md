# Быстрый старт: Развертывание Supabase и n8n

Это руководство поможет вам быстро развернуть Supabase и n8n на собственном сервере за 30 минут.

## Предварительные требования

- Ubuntu 20.04+ или Debian 11+
- Минимум 4GB оперативной памяти
- Минимум 20GB свободного место на диске
- Доступ в интернет
- SSH доступ к серверу с правами sudo

## Быстрая установка (3 шага)

### Шаг 1: Загрузка и запуск установочного скрипта

```bash
# Клонирование репозитория
git clone <repository-url>
cd <project-name>

# Запуск установочного скрипта с правами администратора
sudo bash scripts/install.sh
```

Скрипт автоматически:
- Проверит системные требования
- Установит Docker и Docker Compose
- Создаст необходимые директории
- Установит Nginx, Certbot и другие компоненты
- Настроит firewall

### Шаг 2: Конфигурация

```bash
# Редактирование конфигурации Supabase
sudo nano /opt/supabase/docker/.env

# Редактирование конфигурации n8n
sudo nano /opt/n8n/.env
```

Ключевые переменные для заполнения:
- `SUPABASE_DB_PASSWORD` - пароль PostgreSQL (сгенерируйте надежный пароль)
- `N8N_DB_PASSWORD` - пароль для БД n8n
- `N8N_ENCRYPTION_KEY` - ключ шифрования n8n (используйте `openssl rand -base64 32`)

### Шаг 3: Запуск сервисов

```bash
# Запуск Supabase
cd /opt/supabase/docker
docker-compose up -d

# Запуск n8n
cd /opt/n8n
docker-compose up -d

# Проверка статуса
docker-compose ps
```

## Доступ к интерфейсам

После запуска доступны:

- **Supabase Studio**: http://localhost:3000
- **Supabase API**: http://localhost:8000
- **n8n**: http://localhost:5678

## Настройка SSL сертификатов

Для использования HTTPS:

```bash
# Получение сертификата Let's Encrypt
sudo certbot certonly --standalone \
  -d supabase.yourdomain.com \
  -d n8n.yourdomain.com \
  --email your-email@example.com \
  --agree-tos

# Конфигурация Nginx
sudo nano /etc/nginx/sites-available/supabase
sudo nano /etc/nginx/sites-available/n8n

# Активация конфигураций
sudo ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Проверка работы

```bash
# Проверка всех сервисов
/opt/monitor.sh

# Проверка логов
docker-compose -f /opt/supabase/docker/docker-compose.yml logs -f
docker-compose -f /opt/n8n/docker-compose.yml logs -f
```

## Первые шаги

### 1. Создание первого workflow в n8n

```
1. Откройте n8n (http://localhost:5678)
2. Создайте учетную запись администратора
3. Create New Workflow
4. Add Webhook trigger
5. Test и Deploy
```

### 2. Создание первой таблицы в Supabase

```
1. Откройте Supabase Studio (http://localhost:3000)
2. Введите учетные данные администратора
3. Database → SQL Editor
4. Выполните:
   CREATE TABLE users (
     id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
     email TEXT UNIQUE NOT NULL,
     name TEXT,
     created_at TIMESTAMP DEFAULT NOW()
   );
```

### 3. Интеграция n8n с Supabase

```
1. В n8n создайте новый workflow
2. Добавьте Webhook trigger
3. Добавьте HTTP Request node для вызова Supabase API
4. URL: http://localhost:8000/rest/v1/users
5. Method: GET
6. Headers: Authorization: Bearer YOUR_ANON_KEY
```

## Резервное копирование

Скрипты резервного копирования уже установлены. Добавьте их в crontab:

```bash
sudo crontab -e

# Добавьте:
0 2 * * * /opt/supabase/backup.sh >> /var/log/supabase-backup.log 2>&1
0 3 * * * /opt/n8n/backup.sh >> /var/log/n8n-backup.log 2>&1
*/5 * * * * /opt/monitor.sh >> /var/log/monitor.log 2>&1
```

## Решение проблем

### Контейнер не запускается

```bash
# Проверьте логи
docker-compose logs n8n

# Перезагрузите контейнер
docker-compose restart n8n

# Полная пересборка
docker-compose down
docker-compose up -d
```

### Медленная производительность

```bash
# Проверьте использование ресурсов
docker stats

# Увеличьте лимиты в docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

### Ошибка подключения к БД

```bash
# Проверьте переменные окружения
docker-compose config | grep DB_

# Проверьте соединение с БД
docker-compose exec postgres psql -U postgres -c "SELECT version();"
```

## Дополнительная информация

- [Полная документация Supabase](./docs/supabase-configuration.md)
- [Полная документация n8n](./docs/n8n-configuration.md)
- [Интеграция Supabase и n8n](./docs/supabase-n8n-integration.md)
- [Обновление и поддержка](./docs/maintenance.md)

## Поддержка и помощь

Для получения помощи:
1. Проверьте документацию в папке `docs/`
2. Просмотрите логи сервисов
3. Используйте `/opt/monitor.sh` для диагностики

## Следующие шаги

1. ✅ Развертывание завершено
2. 📚 Изучите [документацию n8n](./docs/n8n-configuration.md)
3. 🔗 Настройте [интеграцию с Supabase](./docs/supabase-n8n-integration.md)
4. 🔐 Настройте SSL и доменные имена
5. 📊 Создайте первые автоматизированные процессы
