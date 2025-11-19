# Настройка n8n

## Интерфейс и основные понятия

### Структура проекта n8n

1. **Workflows** - автоматизированные процессы
2. **Nodes** - отдельные действия/интеграции
3. **Connections** - параметры соединений для нод
4. **Credentials** - сохраненные учетные данные

## Основные разделы интерфейса

### 1. Workflows (Рабочие процессы)

**Путь**: Home → Workflows

#### Создание нового workflow

1. Нажмите **+ New**
2. Выберите имя рабочего процесса
3. Добавляйте ноды с помощью кнопки **+** или поиска
4. Соедините ноды линиями
5. Настройте параметры каждой ноды
6. Сохраните (**Ctrl+S**)
7. Активируйте рабочий процесс (переключатель вверху)

#### Жизненный цикл workflow

```
Создание → Тестирование → Активация → Мониторинг → Отключение/Удаление
```

#### Типы начальных нод

| Тип | Описание | Использование |
|-----|---------|---------------|
| Manual | Запуск вручную | Тестирование, разовые операции |
| Trigger | Событие (вебхук, расписание) | Автоматические процессы |
| Cron | По расписанию | Регулярные задачи |
| Webhook | HTTP запрос | Интеграции, вебхуки |

### 2. Settings (Настройки)

**Путь**: Settings (иконка шестеренки)

#### 2.1 General (Общие)

```
Settings → General
- Timezone: выбор часового пояса
- Language: язык интерфейса
- Theme: тема (Light/Dark)
- Execution mode: режим выполнения
```

#### 2.2 Security (Безопасность)

```
Settings → Security
- Change password: изменение пароля
- Two-factor authentication: включение 2FA
- API keys: создание API ключей
```

#### 2.3 Community Nodes

```
Settings → Community Nodes
- Просмотр доступных community нод
- Установка дополнительных нод
- Удаление нод
```

#### 2.4 Personal

```
Settings → Personal
- Email notifications: уведомления по почте
- Notification settings: настройка типов уведомлений
```

### 3. Credentials (Учетные данные)

**Путь**: Credentials → New

Сохранение и управление учетными данными для различных сервисов:

```
Credentials типы:
- API Key / Token
- OAuth 2.0
- Basic Auth (Username/Password)
- Custom Headers
- SSL Certificates
```

#### Создание credential для Supabase

```
1. Перейдите в Credentials
2. Нажмите "New"
3. Выберите тип: "Supabase" или "PostgreSQL"
4. Заполните:
   - Name: "Supabase Production"
   - Host: api.supabase.yourdomain.com (для Postgres)
   - Database: postgres
   - User: postgres
   - Password: ваш пароль
   - Port: 5432
5. Нажмите "Save"
```

#### Создание credential для HTTP

```
1. Выберите "HTTP Authorization"
2. Тип: "Bearer Token" или "Custom Header"
3. Введите ваши токены/ключи
4. Сохраните
```

### 4. User Management (Управление пользователями)

**Путь**: Settings → Users

#### Роли пользователей

| Роль | Права |
|------|-------|
| Admin | Полный доступ ко всему |
| Editor | Создание/редактирование workflows |
| Viewer | Только просмотр workflows |
| Member | Базовый доступ |

#### Приглашение пользователя

```
1. Settings → Users
2. "Invite User"
3. Введите email
4. Выберите роль
5. Отправьте приглашение
```

## Структура Workflow

### Анатомия workflow

```
START NODE → PROCESSING NODES → OUTPUT NODES → END
    ↓              ↓                   ↓
  Trigger    Data manipulation    Action/Webhook
  Manual     Filtering            Email
  Schedule   Transformation       HTTP
  Webhook    Conditions           Database
             Loop/Merge           n8n
```

### Пример: простой workflow

```
1. Trigger: Schedule (каждый день в 9:00)
   ↓
2. Node: Supabase (получить данные)
   ↓
3. Node: Set (преобразовать данные)
   ↓
4. Node: Email (отправить email)
   ↓
5. Node: Webhook (отправить в другую систему)
```

## Типовые конфигурации

### 1. Обработчик вебхука из Supabase

```
Workflow: "Supabase Change Handler"

Node 1: Webhook
- Method: POST
- Path: /supabase-trigger
- Authentication: None / API Key

Node 2: Code
JavaScript:
return items.map(item => ({
  action: item.json.type,
  table: item.json.table,
  record: item.json.record
}));

Node 3: IF (условие по типу события)
- event.action === "INSERT"

Node 4: Действие (Send email, Save to DB, и т.д.)
```

### 2. Запланированная синхронизация данных

```
Workflow: "Daily Data Sync"

Node 1: Cron
- Trigger: Every day at 08:00

Node 2: Supabase (получить новые записи)
SELECT * FROM products WHERE updated_at > now() - interval '1 day'

Node 3: Loop (для каждой записи)

Node 4: HTTP Request (отправить в другую систему)

Node 5: Update (отметить как синхронизировано)
```

### 3. Условная логика

```
Workflow: "Order Processing"

Node 1: Webhook (получить заказ)

Node 2: Code (валидация)

Node 3: IF
- Условие: amount > 1000
- True: требуется одобрение
- False: автоматическое подтверждение

Node 4a: Send notification (для больших заказов)

Node 4b: Auto-confirm (для малых заказов)

Node 5: Save to Supabase
```

## Обработка ошибок

### 1. Try-Catch-Error

```
Node: Try-Catch

1. Try блок: содержит ноды для выполнения
2. Catch блок: обработка ошибок
3. Error handling: логирование или повтор

Пример:
Try:
  - HTTP запрос к API
  - Update в БД
Catch:
  - Log the error
  - Send alert email
  - Retry mechanism
```

### 2. Error Handling в ноде

```javascript
// В Node с кодом

try {
  // Ваша логика
  const data = JSON.parse(item.json.data);
  return data;
} catch (error) {
  // Обработка ошибки
  return {
    error: error.message,
    timestamp: new Date(),
    data: item.json
  };
}
```

### 3. Повторные попытки

```
Node Settings → Error Handling
- Error Handling: Retry
- Max Retries: 3
- Wait (ms): 1000
- Exponential backoff: true
```

## Переменные и контекст

### Типы данных

```
$execution - информация о выполнении
$now - текущее время
$nodeVersion - версия ноды
$defaultOutput - выход по умолчанию
$input - входные данные
$params - параметры
```

### Использование переменных

```javascript
// В выражениях ({{ }})
{{ $now.toISOString() }}
{{ $json.user.email }}
{{ item.json.products[0].name }}

// В Code ноде
const timestamp = new Date().toISOString();
const userId = item.json.user_id;
const amount = item.json.amount;

return {
  timestamp,
  userId,
  amount,
  processed: true
};
```

### Доступ к данным от предыдущих нод

```javascript
// Получение данных от предыдущей ноды
const previousNodeData = $input.all();  // Все элементы
const firstItem = $input.first();       // Первый элемент
const lastItem = $input.last();         // Последний элемент

// Доступ по индексу ноды
{{ $node["Supabase"].json.records }}
{{ $node["HTTP Request"].data.body }}
```

## Производительность

### 1. Пакетная обработка

```
Node: Loop
- Метод: Item Lists
- Batch size: 50  // Обрабатывать по 50 за раз
- Concurrency: 3  // 3 параллельных процесса

Это уменьшает использование памяти и улучшает производительность.
```

### 2. Фильтрация данных на ранних стадиях

```
Хорошо:
Supabase (SELECT * WHERE status='new') → Process

Плохо:
Supabase (SELECT *) → Filter (status='new') → Process
```

### 3. Кеширование результатов

```javascript
// Используйте встроенное кеширование
const cacheKey = 'user_' + userId;

// В Code ноде
if (workflow.cache && workflow.cache.get(cacheKey)) {
  return workflow.cache.get(cacheKey);
}

// Обработка и сохранение в кеш
const result = processData(data);
if (workflow.cache) {
  workflow.cache.set(cacheKey, result);
}
```

## Отладка

### 1. Debug Mode

```
При разработке workflow:
1. Нажмите кнопку "Test Workflow"
2. Добавьте debug ноды между ключевыми точками
3. Смотрите выходные данные каждой ноды
4. Используйте "Execute Node" для отдельных нод
```

### 2. Проверка выходных данных

```
Каждая нода показывает:
- OUTPUT: результаты выполнения
- LOGS: логи выполнения
- ERRORS: ошибки (если есть)

Кликните на нод→ смотрите пример выходных данных в правой панели
```

### 3. Использование встроенного логирования

```javascript
// В Code ноде
console.log('Debug info:', item.json);
console.warn('Warning:', data);
console.error('Error:', error);

// Будут видны в логах workflow
```

## Оптимизация workflow

### Практический пример: Обработка 10,000 записей

```javascript
// Плохой вариант - будет медленно
1. GET all 10,000 records
2. For each: Process and save
   └─ 10,000 HTTP запросов последовательно

// Хороший вариант
1. GET 10,000 records
2. Split into batches of 100
3. For each batch:
   - Process 100 параллельно (concurrency: 5)
   - Batch insert 100 в БД за 1 запрос
   
Результат: ~20 операций вместо 10,000
```

## Экспорт и импорт

### Экспорт workflow

```
1. Откройте workflow
2. Settings (кнопка ⋯ вверху)
3. Download
4. JSON файл сохранится локально
```

### Импорт workflow

```
1. На главной странице
2. Click + New → Import from file
3. Выберите JSON файл
4. Workflow будет загружен
```

### Version Control

```bash
# Сохраняйте экспортированные workflow в Git
git add workflows/
git commit -m "Update workflows"
git push
```

## Интеграция с внешними системами

### Типовые интеграции

| Система | Тип | Ноды |
|---------|-----|------|
| Supabase | БД | PostgreSQL, HTTP |
| Google Sheets | Data | Google Sheets |
| Slack | Уведомления | Slack |
| Email | Уведомления | Email, Gmail |
| Discord | Уведомления | Discord |
| HTTP | Универсальная | HTTP Request |
| Webhook | Входящие | Webhook |

### Пример: Интеграция с Google Sheets

```
1. Add Credential: Google Sheets
   - Пройдите OAuth авторизацию
   
2. Node: Google Sheets
   - Operation: Add rows
   - Spreadsheet ID: из URL
   - Sheet name: "Sheet1"
   
3. Маппируйте данные из предыдущей ноды
```

## Следующие шаги

- Изучите [Справочник нод n8n](./n8n-nodes-guide.md)
- Настройте [Интеграцию с Supabase](./supabase-n8n-integration.md)
