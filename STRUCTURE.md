# Структура проекта

```
project/
│
├── README.md                           # Главный файл документации
├── QUICKSTART.md                       # Быстрый старт за 30 минут
├── STRUCTURE.md                        # Этот файл - структура проекта
│
├── .env.example                        # Пример переменных окружения
├── .gitignore                          # Исключения для Git
│
├── docker-compose.example.yml          # Пример Docker Compose конфигурации
│
├── docs/                               # Полная документация
│   ├── requirements.md                 # Системные требования
│   ├── supabase-deployment.md          # Развертывание Supabase
│   ├── supabase-configuration.md       # Настройка админки Supabase
│   ├── n8n-deployment.md               # Развертывание n8n
│   ├── n8n-configuration.md            # Настройка интерфейса n8n
│   ├── n8n-nodes-guide.md              # Справочник нод n8n
│   ├── supabase-n8n-integration.md     # Интеграция Supabase и n8n
│   └── maintenance.md                  # Обновление и поддержка
│
├── scripts/                            # Вспомогательные скрипты
│   ├── install.sh                      # Автоматическая установка
│   ├── backup-supabase.sh              # Резервная копия Supabase
│   ├── backup-n8n.sh                   # Резервная копия n8n
│   └── monitor.sh                      # Мониторинг сервисов
│
└── examples/                           # Примеры (если будут добавлены)
    ├── workflows/                      # Примеры n8n workflows
    ├── sql/                            # Примеры SQL запросов
    └── integrations/                   # Примеры интеграций
```

## Описание файлов и директорий

### Корневые файлы

| Файл | Описание |
|------|---------|
| `README.md` | Основной файл документации, содержит обзор проекта и быстрые ссылки |
| `QUICKSTART.md` | Инструкции для быстрого развертывания за 30 минут |
| `STRUCTURE.md` | Описание структуры проекта (этот файл) |
| `.env.example` | Шаблон переменных окружения (используйте как основу для `.env`) |
| `.gitignore` | Файлы и директории, исключаемые из Git |
| `docker-compose.example.yml` | Шаблон конфигурации Docker Compose |

### Папка `docs/`

Полная справочная документация по всем аспектам системы:

| Документ | Содержит |
|----------|----------|
| `requirements.md` | Системные требования, порты, firewall, SSL сертификаты |
| `supabase-deployment.md` | Пошаговое развертывание Supabase, конфигурация Nginx, SSL |
| `supabase-configuration.md` | Полное описание админски Supabase (RLS, функции, webhooks, и т.д.) |
| `n8n-deployment.md` | Развертывание n8n с Docker Compose, оптимизация, обновления |
| `n8n-configuration.md` | Интерфейс n8n, настройки, обработка ошибок, производительность |
| `n8n-nodes-guide.md` | Справочник всех типов нод n8n с примерами использования |
| `supabase-n8n-integration.md` | Все способы интеграции (API, webhooks, PostgreSQL), примеры, best practices |
| `maintenance.md` | Обновления, резервное копирование, мониторинг, безопасность |

### Папка `scripts/`

Автоматизированные скрипты для управления системой:

| Скрипт | Назначение |
|--------|-----------|
| `install.sh` | Автоматическая установка всех компонентов (запускается один раз) |
| `backup-supabase.sh` | Ежедневное резервное копирование Supabase (добавьте в crontab) |
| `backup-n8n.sh` | Ежедневное резервное копирование n8n (добавьте в crontab) |
| `monitor.sh` | Проверка здоровья всех сервисов (рекомендуется запускать каждые 5 минут) |

## Как использовать документацию

### Для новичков

1. Начните с [QUICKSTART.md](./QUICKSTART.md) - развертывание за 30 минут
2. Затем прочитайте [requirements.md](./docs/requirements.md) - понимание требований
3. Изучите [n8n-configuration.md](./docs/n8n-configuration.md) - основы интерфейса n8n

### Для администраторов

1. [supabase-deployment.md](./docs/supabase-deployment.md) - развертывание Supabase
2. [n8n-deployment.md](./docs/n8n-deployment.md) - развертывание n8n
3. [maintenance.md](./docs/maintenance.md) - резервные копии и мониторинг

### Для разработчиков

1. [supabase-configuration.md](./docs/supabase-configuration.md) - работа с БД
2. [n8n-nodes-guide.md](./docs/n8n-nodes-guide.md) - справочник нод
3. [supabase-n8n-integration.md](./docs/supabase-n8n-integration.md) - интеграция

## Рекомендуемая последовательность действий

### Шаг 1: Подготовка (5 минут)

```bash
# Проверьте требования
less docs/requirements.md

# Завршите установку
sudo bash scripts/install.sh
```

### Шаг 2: Конфигурация (10 минут)

```bash
# Отредактируйте переменные окружения
sudo nano /opt/supabase/docker/.env
sudo nano /opt/n8n/.env

# Копируйте docker-compose.example.yml в правильное место
cp docker-compose.example.yml /opt/supabase/docker/docker-compose.yml
```

### Шаг 3: Запуск (5 минут)

```bash
# Запустите сервисы
cd /opt/supabase/docker && docker-compose up -d
cd /opt/n8n && docker-compose up -d

# Проверьте статус
bash /opt/monitor.sh
```

### Шаг 4: Первоначальная настройка (20 минут)

1. Откройте Supabase Studio (http://localhost:3000)
   - Создайте администраторский аккаунт
   - Создайте первую таблицу

2. Откройте n8n (http://localhost:5678)
   - Создайте администраторский аккаунт
   - Создайте первый workflow

3. Настройте интеграцию (см. [supabase-n8n-integration.md](./docs/supabase-n8n-integration.md))

### Шаг 5: Производство (текущий день)

1. Настройте SSL сертификаты (Let's Encrypt)
2. Настройте Nginx reverse proxy
3. Добавьте скрипты резервного копирования в crontab
4. Настройте мониторинг и алерты

## Структура файловой системы сервера

После установки на сервере будет создана следующая структура:

```
/
├── opt/
│   ├── supabase/
│   │   ├── docker/
│   │   │   ├── .env                    # Конфигурация Supabase
│   │   │   ├── docker-compose.yml      # Docker Compose конфиг
│   │   │   ├── volumes/                # Данные контейнеров
│   │   │   ├── supabase_postgres_data/ # PostgreSQL данные
│   │   │   └── backup.sh               # Резервная копия
│   │   └── supabase_backup.tar.gz      # Последняя резервная копия
│   │
│   ├── n8n/
│   │   ├── .env                        # Конфигурация n8n
│   │   ├── docker-compose.yml          # Docker Compose конфиг
│   │   ├── data/                       # n8n данные (workflows, etc)
│   │   ├── n8n_postgres_data/          # PostgreSQL данные
│   │   ├── postgres_data/              # Данные БД
│   │   └── backup.sh                   # Резервная копия
│   │
│   ├── monitor.sh                      # Скрипт мониторинга
│   ├── check-health.sh                 # Проверка здоровья
│   └── generate-report.sh              # Генерация отчетов
│
├── backups/
│   ├── supabase/
│   │   ├── supabase_db_20240115_020000.dump
│   │   ├── supabase_config_20240115_020000.tar.gz
│   │   └── ...
│   └── n8n/
│       ├── n8n_db_20240115_030000.dump
│       ├── n8n_data_20240115_030000.tar.gz
│       └── ...
│
├── var/
│   └── log/
│       ├── supabase-backup.log
│       ├── n8n-backup.log
│       ├── monitor.log
│       └── nginx/
│
├── etc/
│   └── nginx/
│       └── sites-available/
│           ├── supabase
│           └── n8n
│
└── letsencrypt/
    └── live/
        └── yourdomain.com/
            ├── fullchain.pem
            └── privkey.pem
```

## Переменные окружения

Все переменные окружения хранятся в `.env` файлах:

```
/opt/supabase/docker/.env     # Суpabase configuration
/opt/n8n/.env                 # n8n configuration
```

**Важно**: Эти файлы содержат чувствительные данные и не должны коммититься в Git.

## Правила для Git

Проект содержит `.gitignore` который исключает:
- `.env` файлы
- Логи (`*.log`)
- Резервные копии (`*.dump`, `*.tar.gz`)
- Docker volumes (данные)
- Временные файлы

## Как добавить собственные документы

Если вы добавляете новые документы:

1. Сохраняйте их в папку `docs/`
2. Используйте Markdown формат (`.md`)
3. Обновите ссылку в `README.md`
4. Используйте относительные ссылки между документами

## Контрольный список для нового сервера

- [ ] Система соответствует требованиям (docs/requirements.md)
- [ ] Установлены Docker и Docker Compose
- [ ] Запущен scripts/install.sh
- [ ] Отредактированы .env файлы
- [ ] Запущены docker-compose up -d
- [ ] Проверен статус /opt/monitor.sh
- [ ] Создана учетная запись администратора Supabase
- [ ] Создана учетная запись администратора n8n
- [ ] Настроены SSL сертификаты
- [ ] Настроен Nginx reverse proxy
- [ ] Добавлены скрипты в crontab
- [ ] Протестированы резервные копии

## Контакты и поддержка

Для вопросов и проблем:
1. Проверьте документацию в папке `docs/`
2. Посмотрите логи: `/opt/monitor.sh`
3. Проверьте примеры и интеграции
4. Создайте issue в репозитории (если используется Git)
