# Справочник нод n8n

## Основные категории нод

### 1. Trigger Ноды (Запуск рабочего процесса)

Ноды, с которых начинается выполнение workflow.

#### 1.1 Manual

```
Описание: Ручной запуск workflow
Использование: Тестирование, разовые операции, отладка

Параметры:
- Примечания: описание для пользователя

Выходные данные:
{
  "note": "Manual trigger started at..."
}

Пример использования:
- Тестирование workflow перед активацией
- Разовые операции, требующие человеческого участия
```

#### 1.2 Webhook

```
Описание: Запуск по HTTP запросу
Использование: Интеграции, вебхуки из других систем

Параметры:
- HTTP Method: GET, POST, PUT, DELETE, PATCH
- Path: /my-webhook
- Response: текст ответа
- Authentication: None, Header, Key/Value

Выходные данные: распарсенные параметры и тело запроса

Пример (Supabase вебхук):
POST https://n8n.yourdomain.com/webhook/supabase-trigger
Headers:
  Authorization: Bearer token
Body:
  {
    "type": "INSERT",
    "table": "users",
    "record": { "id": 1, "email": "user@example.com" }
  }
```

#### 1.3 Schedule / Cron

```
Описание: Запуск по расписанию
Использование: Регулярные задачи, синхронизация данных

Параметры:
- Rule: CRON выражение
  * * * * * (minute hour day month weekday)
  
Примеры CRON:
- 0 9 * * * - Каждый день в 9:00
- 0 * * * * - Каждый час
- 0 0 * * 0 - Каждый понедельник в 00:00
- */15 * * * * - Каждые 15 минут
- 0 9 1 * * - 1-го числа каждого месяца в 9:00

Выходные данные:
{
  "timestamp": "2024-01-15T09:00:00Z",
  "cronExpression": "0 9 * * *"
}

Пример использования:
- Ежедневная синхронизация данных
- Отправка сводных отчетов
- Очистка старых данных
```

#### 1.4 Interval

```
Описание: Запуск через определенные интервалы
Использование: Повторяющиеся задачи

Параметры:
- Interval: количество
- Unit: Seconds, Minutes, Hours, Days

Пример:
- Interval: 15, Unit: Minutes
  → запуск каждые 15 минут

Выходные данные:
{
  "executionCount": 42
}
```

### 2. Data Input Ноды (Получение данных)

#### 2.1 HTTP Request

```
Описание: HTTP запрос к любому API
Использование: Универсальная интеграция

Параметры:
- URL: https://api.example.com/data
- Method: GET, POST, PUT, DELETE, PATCH
- Headers: Authorization, Content-Type
- Query Parameters: параметры URL
- Body: JSON, Form, X-www-form-urlencoded
- Authentication: Basic, Bearer Token, OAuth2

Переменные для использования в URL/Body:
{{ $json.userId }}
{{ $node["Previous Node"].json.data }}

Выходные данные:
{
  "statusCode": 200,
  "headers": { ... },
  "data": { ... }
}

Примеры:

# GET запрос с параметрами
URL: https://api.supabase.yourdomain.com/rest/v1/users
Query: { "id": "gt.100", "limit": "10" }
Headers: Authorization: Bearer YOUR_ANON_KEY

# POST запрос с телом
URL: https://api.example.com/create
Method: POST
Headers: Content-Type: application/json
Body: {
  "name": "{{ $json.user.name }}",
  "email": "{{ $json.user.email }}"
}

# Обработка ошибок
Error handling: Retry (3 retries, exponential backoff)
```

#### 2.2 Supabase / PostgreSQL

```
Описание: Работа с PostgreSQL/Supabase БД
Использование: Получение/сохранение данных в БД

Параметры основные:
- Credential: сохраненное подключение к БД
- Query: SQL запрос
- Substitutions: параметры запроса

Параметры для PostgreSQL ноды:
- Operation: Execute Query, Select
- Query Type: SQL, Builder

Выходные данные:
[
  { "id": 1, "name": "John", "email": "john@example.com" },
  { "id": 2, "name": "Jane", "email": "jane@example.com" }
]

Примеры SQL запросов:

# SELECT
SELECT * FROM users WHERE created_at > NOW() - INTERVAL '1 day'

# SELECT с параметрами (защита от SQL injection)
SELECT * FROM users WHERE id = $1 AND status = $2
Substitutions: [ 123, 'active' ]

# INSERT
INSERT INTO users (name, email) VALUES ($1, $2)
Substitutions: [ '{{ $json.name }}', '{{ $json.email }}' ]

# UPDATE
UPDATE users SET status = 'processed', updated_at = NOW() 
WHERE id = $1
Substitutions: [ 123 ]

# DELETE
DELETE FROM users WHERE id > $1
Substitutions: [ 100 ]

# INSERT многих записей (RETURNING)
INSERT INTO users (name, email) VALUES 
($1, $2), ($3, $4), ($5, $6)
RETURNING *

# Транзакция (если поддерживается)
BEGIN;
INSERT INTO orders ...
UPDATE inventory ...
COMMIT;
```

#### 2.3 Google Sheets

```
Описание: Чтение данных из Google Sheets
Использование: Импорт данных из таблиц

Параметры:
- Credential: Google Sheets OAuth
- Spreadsheet ID: из URL
- Sheet Name: "Sheet1", "Users", и т.д.
- Range: A1:D100 (опционально)

Выходные данные:
[
  { "Name": "John", "Email": "john@example.com", "Status": "Active" },
  { "Name": "Jane", "Email": "jane@example.com", "Status": "Active" }
]

Операции:
- Append: добавить строки
- Clear: удалить содержимое
- Create: создать новую таблицу
- Read: прочитать данные
- Update: обновить ячейки
```

#### 2.4 JSON Parse / XML Parse

```
Описание: Парсинг JSON/XML данных
Использование: Преобразование формата данных

Параметры:
- JSON (если JSON):
  - Property Name: поле для парсинга
  - JSON: {{ $json.data }}

Выходные данные:
Распарсенные объекты из JSON строки

Пример:
Входная ноды: '{"users": [{"id": 1, "name": "John"}]}'
После парсинга: { users: [...] }
```

### 3. Processing Ноды (Обработка данных)

#### 3.1 Code

```
Описание: Выполнение JavaScript кода
Использование: Сложная логика, трансформация данных

Язык: JavaScript (Node.js environment)

Входные данные:
- item - текущий элемент
- items - все элементы
- $input - объект для доступа к данным
- $json - текущие данные
- $params - параметры

Примеры:

# Простая трансформация
return items.map(item => ({
  id: item.json.user_id,
  email: item.json.user_email.toLowerCase(),
  created: new Date(item.json.created_at).toISOString()
}));

# Фильтрация
return items.filter(item => item.json.status === 'active');

# Группировка
const grouped = {};
items.forEach(item => {
  const key = item.json.category;
  if (!grouped[key]) grouped[key] = [];
  grouped[key].push(item.json);
});
return [grouped];

# Использование внешних библиотек
const crypto = require('crypto');
return items.map(item => ({
  ...item.json,
  hash: crypto.createHash('sha256').update(item.json.email).digest('hex')
}));

# Условная логика
return items.map(item => ({
  ...item.json,
  level: item.json.score > 80 ? 'HIGH' : 
         item.json.score > 50 ? 'MEDIUM' : 'LOW'
}));

# Использование контекста ноды
return {
  nodeName: item.node_name,
  executionTime: item.execution_time,
  timestamp: new Date().toISOString()
};

# Возвращение ошибки
if (!item.json.email) {
  throw new Error('Email is required');
}
```

#### 3.2 Set

```
Описание: Установка значений переменных
Использование: Установка полей выходных данных

Параметры:
- Name: имя переменной
- Value: значение

Примеры:
Name: userId
Value: {{ $json.user.id }}

Name: processedAt
Value: {{ $now.toISOString() }}

Name: status
Value: completed

Выходные данные:
{
  "userId": 123,
  "processedAt": "2024-01-15T10:30:00Z",
  "status": "completed",
  ... (остальные поля из предыдущей ноды)
}
```

#### 3.3 Filter

```
Описание: Фильтрация элементов по условию
Использование: Выборка нужных данных

Параметры:
- Property: поле для проверки
- Condition: условие (equals, contains, gt, lt, regex, и т.д.)
- Value: значение для сравнения

Примеры условий:
- equals: точное совпадение
- contains: содержит
- regex: регулярное выражение
- starts with: начинается с
- ends with: заканчивается на
- is empty / is not empty
- > (gt) / < (lt) / >= (gte) / <= (lte)

Пример:
Property: status
Condition: equals
Value: active

# Результат: только элементы где status == 'active'

Несколько условий (AND/OR):
Condition 1: status equals 'active'
AND Condition 2: score > 100
```

#### 3.4 Sort

```
Описание: Сортировка элементов
Использование: Упорядочение данных

Параметры:
- Field Name: поле для сортировки
- Direction: ASC (возрастание), DESC (убывание)

Пример:
Field Name: created_at
Direction: DESC (новые сверху)
```

#### 3.5 Merge

```
Описание: Объединение данных из нескольких веток
Использование: Комбинирование результатов

Параметры:
- How to combine: Merge, Concatenate

Merge: объединение по общему ключу
Concatenate: просто складывание массивов

Пример:
Branch 1: Пользователи из Supabase
Branch 2: Профили из Google Sheets
Merge Result: объединенные данные
```

### 4. Control Flow Ноды (Управление потоком)

#### 4.1 IF

```
Описание: Условное разветвление
Использование: Логика выбора пути

Параметры:
- Condition: условие (Property, Condition, Value)
- True Branch: действия если true
- False Branch: действия если false

Примеры условий:
1. String: {{ $json.status }} equals active
2. Number: {{ $json.amount }} > 1000
3. Exists: Property exists: email
4. Empty: Property is empty: notes
5. Complex: multiple conditions (AND/OR)

Пример workflow:
Webhook (получить заказ)
  ↓
IF amount > 5000
  ├─ True: Send approval email
  └─ False: Auto confirm order
```

#### 4.2 Loop

```
Описание: Итерация по элементам
Использование: Обработка массивов

Параметры:
- Input: какие данные обрабатывать
- Batch Size: сколько элементов обрабатывать за раз
- Concurrency: параллельные процессы

Выходные данные: результаты обработки всех элементов

Пример:
Items: [user1, user2, user3, ...]
Loop итерирует каждого пользователя:
  - Get user profile
  - Calculate statistics
  - Save to database
```

#### 4.3 Switch

```
Описание: Множественное ветвление (like switch/case)
Использование: Много возможных путей

Параметры:
- Expression: выражение для проверки
- Cases: варианты значений и соответствующие действия

Пример:
Expression: {{ $json.event_type }}
Cases:
  - "ORDER_CREATED": Send to inventory
  - "ORDER_CANCELLED": Update inventory
  - "ORDER_SHIPPED": Send notification
  - default: Log unknown event
```

#### 4.4 Wait

```
Описание: Задержка выполнения
Использование: Пауза перед следующим шагом

Параметры:
- Pause Until: указанное время
- Wait Time: продолжительность (hours, minutes, seconds)

Примеры:
1. Wait Until: 2024-01-20 09:00:00
   (продолжить в определенное время)

2. Wait Time: 5 minutes
   (ждать 5 минут)

Использование:
- Rate limiting при работе с API
- Ожидание обработки
- Задержка отправки сообщения
```

#### 4.5 Try-Catch-Error Handler

```
Описание: Обработка ошибок
Использование: Перехват и обработка исключений

Структура:
Try:
  - Ноды которые могут вызвать ошибку
  - HTTP запрос, работа с БД
Catch:
  - Ноды для обработки ошибки
  - Логирование, отправка алерта
Error Handler:
  - Как обработать ошибку ловушки
  - Retry, skip, или stop

Пример:
Try:
  - API запрос
Catch:
  - Log error
  - Send alert email
  - Retry with backoff
```

### 5. Output Ноды (Отправка данных)

#### 5.1 HTTP Request (POST/PUT/PATCH)

```
(Уже описана в Input ноды, здесь примеры для отправки)

Примеры отправки данных:

# POST - создание
URL: https://api.example.com/users
Method: POST
Body:
{
  "name": "{{ $json.name }}",
  "email": "{{ $json.email }}"
}

# PUT - полное обновление
URL: https://api.example.com/users/{{ $json.id }}
Method: PUT
Body:
{
  "name": "{{ $json.name }}",
  "status": "updated"
}

# PATCH - частичное обновление
URL: https://api.example.com/users/{{ $json.id }}
Method: PATCH
Body:
{
  "status": "processed"
}

# DELETE - удаление
URL: https://api.example.com/users/{{ $json.id }}
Method: DELETE
```

#### 5.2 Slack

```
Описание: Отправка сообщений в Slack
Использование: Уведомления

Параметры:
- Webhook URL: Incoming Webhook из Slack
- Message: текст сообщения
- Channel: канал Slack
- Username: имя бота

Примеры:

# Простое сообщение
Message: "New user registered: {{ $json.email }}"

# С блоками/форматированием
Blocks:
[
  {
    "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "*Order Confirmation*\nUser: {{ $json.user }}\nAmount: ${{ $json.amount }}"
    }
  },
  {
    "type": "divider"
  },
  {
    "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "Status: _{{ $json.status }}_"
    }
  }
]

# С вложениями
Attachments:
[
  {
    "color": "good",
    "title": "Order Confirmed",
    "text": "Order #{{ $json.order_id }} has been confirmed"
  }
]
```

#### 5.3 Email

```
Описание: Отправка email
Использование: Рассылка уведомлений

Параметры:
- Credential: настройка SMTP или Gmail
- To: адрес получателя
- Subject: тема письма
- Body: содержание (Text или HTML)
- Attachments: вложения

Пример:

To: {{ $json.email }}
Subject: Order Confirmation - #{{ $json.order_id }}
Body (HTML):
<html>
  <h1>Order Confirmed</h1>
  <p>Hello {{ $json.customer_name }},</p>
  <p>Your order #{{ $json.order_id }} has been confirmed.</p>
  <p>Amount: <strong>${{ $json.total }}</strong></p>
  <p>Status: <em>{{ $json.status }}</em></p>
</html>
```

#### 5.4 Discord

```
Описание: Отправка сообщений в Discord
Использование: Уведомления в Discord

Параметры:
- Webhook URL: Discord Webhook
- Content: текст сообщения
- Embed: расширенное форматирование

Пример:
Content: New alert!
Embed:
{
  "title": "System Alert",
  "description": "{{ $json.alert_text }}",
  "color": 16711680,  // Red
  "fields": [
    {
      "name": "Severity",
      "value": "{{ $json.severity }}"
    },
    {
      "name": "Time",
      "value": "{{ $now.toISOString() }}"
    }
  ]
}
```

#### 5.5 Webhook

```
Описание: Отправка данных на вебхук
Использование: Интеграция с другими системами

Параметры:
- URL: адрес вебхука
- Method: POST, PUT, PATCH
- Headers: заголовки запроса
- Body: данные для отправки

Пример:
URL: https://your-app.com/api/webhook
Method: POST
Headers:
  X-API-Key: {{ $env.API_KEY }}
  Content-Type: application/json
Body:
{
  "event": "user_registered",
  "user_id": "{{ $json.user_id }}",
  "email": "{{ $json.email }}",
  "timestamp": "{{ $now.toISOString() }}"
}
```

#### 5.6 Supabase / PostgreSQL (INSERT/UPDATE/DELETE)

```
Если используется как output нода:

Operation: Insert or Insert Multiple
Table: users
Values:
{
  "email": "{{ $json.email }}",
  "name": "{{ $json.name }}",
  "created_at": "{{ $now.toISOString() }}"
}

Результат: вставленная запись с ID
```

### 6. Вспомогательные ноды

#### 6.1 Split Out

```
Описание: Разделение массива на отдельные элементы
Использование: Перед Loop для распаковки массивов

Пример:
Входные данные: [{ id: 1 }, { id: 2 }, { id: 3 }]
После Split Out:
  Output 1: { id: 1 }
  Output 2: { id: 2 }
  Output 3: { id: 3 }
```

#### 6.2 Item Lists

```
Описание: Работа со списками
Использование: Агрегация данных

Операции:
- Create list: создать массив из элементов
- Flatten: распрямить вложенные массивы
- Limit output: ограничить количество элементов
```

#### 6.3 Rename

```
Описание: Переименование полей
Использование: Изменение структуры данных

Параметры:
- Old name: текущее имя поля
- New name: новое имя поля

Пример:
Old: userId
New: user_id

Результат: { "user_id": 123 } вместо { "userId": 123 }
```

#### 6.4 Date & Time

```
Описание: Работа с датами и временем
Использование: Трансформация дат

Операции:
- Format: форматировать дату
- Get current date: текущее время
- Add/Subtract: добавить/вычесть время
- Diff: разница между датами

Пример:
Operation: Format
Format: YYYY-MM-DD HH:mm:ss
Timezone: Europe/Moscow
Input: {{ $json.created_at }}
Output: "2024-01-15 10:30:00"
```

## Комбинирование нод

### Типичные паттерны

#### Паттерн 1: Получение и обновление

```
HTTP Request (GET)
    ↓
Code (transform)
    ↓
HTTP Request (POST/PUT)
```

#### Паттерн 2: Условная логика с ошибками

```
Try-Catch
├─ Try:
│   ├─ Webhook
│   ├─ Validation (IF)
│   └─ Database INSERT
└─ Catch:
    ├─ Log error
    └─ Send alert email
```

#### Паттерн 3: Обработка много элементов

```
HTTP GET (get array)
    ↓
Loop (для каждого)
├─ Code (transform)
├─ IF (condition)
└─ Database or API call
    ↓
Merge (собрать результаты)
    ↓
Email (отправить отчет)
```

## Документация и ресурсы

- [Официальная документация n8n](https://docs.n8n.io/)
- [Ноды на GitHub](https://github.com/n8n-io/n8n/tree/master/packages/nodes-base)
- [Community форум](https://community.n8n.io/)

## Следующие шаги

- [Интеграция Supabase и n8n](./supabase-n8n-integration.md)
- [Настройка n8n](./n8n-configuration.md)
