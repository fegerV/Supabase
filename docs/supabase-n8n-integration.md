# Интеграция Supabase и n8n

## Введение

Интеграция между Supabase и n8n позволяет:
- Автоматически обрабатывать изменения в БД
- Синхронизировать данные между системами
- Создавать сложные бизнес-процессы
- Отправлять уведомления на основе событий БД

## Архитектура интеграции

```
Supabase (PostgreSQL)
    │
    ├─ REST API → n8n (HTTP запросы)
    ├─ Webhook → n8n (события изменений)
    └─ PostgreSQL → n8n (прямое подключение)

n8n
    │
    ├─ Обработка данных → Supabase
    ├─ Уведомления → Email, Slack, Discord
    └─ Синхронизация → Другие системы
```

## Способ 1: REST API Supabase

Простой способ работы с данными через HTTP запросы.

### 1. Получение API ключей

```
1. Откройте Supabase Studio
2. Settings → API
3. Скопируйте:
   - Project URL: https://api.supabase.yourdomain.com
   - Anon Key: для фронтенда
   - Service Role Key: для backend/n8n
```

### 2. Создание Credential в n8n

```
1. Перейдите в Credentials
2. Нажмите "+ New"
3. Выберите "HTTP Authorization"
4. Настройте:
   - Name: "Supabase API"
   - Type: "Bearer Token"
   - Token: YOUR_SERVICE_ROLE_KEY
5. Сохраните
```

### 3. HTTP Request нода

```
HTTP Request (GET пример)
├─ URL: https://api.supabase.yourdomain.com/rest/v1/users
├─ Method: GET
├─ Authentication: "Supabase API" (credential созданный выше)
├─ Query Parameters:
│  └─ select: "*"
│     limit: "10"
│     order: created_at.desc
└─ Output: Массив пользователей
```

### 4. Примеры REST запросов

#### GET - получение данных

```javascript
// Все пользователи
URL: /rest/v1/users
Method: GET
Headers: Authorization: Bearer SERVICE_ROLE_KEY

// С фильтром
URL: /rest/v1/users?status=eq.active&limit=10
Method: GET

// С сортировкой
URL: /rest/v1/users?order=created_at.desc&limit=100
Method: GET

// С выборкой определенных столбцов
URL: /rest/v1/users?select=id,email,name
Method: GET

// С JOIN
URL: /rest/v1/users?select=id,email,profiles(name,bio)
Method: GET
```

#### POST - создание данных

```javascript
URL: /rest/v1/users
Method: POST
Headers: 
  Authorization: Bearer SERVICE_ROLE_KEY
  Content-Type: application/json
Body:
{
  "email": "{{ $json.email }}",
  "name": "{{ $json.name }}",
  "created_at": "{{ $now.toISOString() }}"
}
```

#### PATCH - обновление данных

```javascript
URL: /rest/v1/users?id=eq.{{ $json.user_id }}
Method: PATCH
Headers: Authorization: Bearer SERVICE_ROLE_KEY
Body:
{
  "status": "updated",
  "updated_at": "{{ $now.toISOString() }}"
}
```

#### DELETE - удаление данных

```javascript
URL: /rest/v1/users?id=eq.{{ $json.user_id }}
Method: DELETE
Headers: Authorization: Bearer SERVICE_ROLE_KEY
```

## Способ 2: Direct PostgreSQL Connection

Прямое подключение к PostgreSQL для высокопроизводительной работы.

### 1. Создание Credential

```
1. Credentials → "+ New"
2. Выберите "PostgreSQL"
3. Заполните параметры:
   - Host: supabase_postgres (если на одном сервере)
            или hostname.yourdomain.com (если отдельно)
   - Port: 5432
   - Database: postgres
   - User: postgres
   - Password: ваш пароль
   - SSL: Enabled
4. Сохраните
```

### 2. PostgreSQL нода

```
PostgreSQL Node
├─ Credential: выбранное подключение
├─ Query: SELECT * FROM users WHERE status = 'active'
└─ Output: Массив записей
```

### 3. Примеры SQL запросов

#### SELECT

```sql
-- Получить активных пользователей
SELECT * FROM users WHERE status = 'active'

-- С параметрами (защита от SQL injection)
SELECT * FROM users WHERE id = $1 AND email = $2
Substitutions: [123, 'user@example.com']

-- GROUP BY и агрегация
SELECT 
  category,
  COUNT(*) as count,
  SUM(amount) as total
FROM products
GROUP BY category
ORDER BY total DESC

-- JOIN между таблицами
SELECT 
  u.id, u.email,
  COUNT(o.id) as order_count,
  SUM(o.total) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id
HAVING SUM(o.total) > 1000
```

#### INSERT / UPDATE / DELETE

```sql
-- INSERT одной записи
INSERT INTO users (email, name, created_at)
VALUES ($1, $2, NOW())
RETURNING *

Substitutions: ['user@example.com', 'John Doe']

-- INSERT многих записей
INSERT INTO users (email, name) VALUES
($1, $2), ($3, $4), ($5, $6)
RETURNING id, email

-- UPDATE
UPDATE users 
SET status = $1, updated_at = NOW()
WHERE id = $2
RETURNING *

Substitutions: ['active', 123]

-- DELETE
DELETE FROM users WHERE created_at < NOW() - INTERVAL '1 year'
```

#### Вызов функций

```sql
-- Вызов PostgreSQL функции
SELECT get_current_user();

-- С параметрами
SELECT count_products_in_category($1);

Substitutions: [5]

-- С транзакциями
BEGIN;
INSERT INTO orders (user_id, total) VALUES ($1, $2);
UPDATE inventory SET quantity = quantity - 1 WHERE id = $3;
COMMIT;
```

## Способ 3: Webhooks из Supabase

Автоматическое реагирование на изменения в БД через вебхуки.

### 1. Создание Webhook в Supabase

```
1. Supabase Studio → Database → Webhooks
2. Нажмите "+ Create a new webhook"
3. Настройте:
   - Table: выберите таблицу (например, orders)
   - Events: INSERT, UPDATE, DELETE (или несколько)
   - HTTP method: POST
   - Webhook URL: https://n8n.yourdomain.com/webhook/supabase-trigger
   - Active: включено
4. Сохраните
```

### 2. n8n Webhook нода

```
Webhook Node
├─ HTTP Method: POST
├─ Path: /supabase-trigger
├─ Authentication: None (или API Key если нужно)
└─ Output: события из Supabase
```

### 3. Структура Payload вебхука

```json
{
  "type": "INSERT",
  "table": "orders",
  "schema": "public",
  "record": {
    "id": 123,
    "user_id": 45,
    "total": 99.99,
    "status": "pending",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "old_record": null
}
```

### 4. Пример workflow с вебхуком

```
Webhook (триггер из Supabase)
    ↓
IF: event type is INSERT
    ├─ true: Send welcome email
    └─ false: Check if UPDATE
           ├─ true: Send update notification
           └─ false: DELETE - archive record
```

## Способ 4: Webhooks из n8n в Supabase

Вызов n8n webhook из Supabase для сложной обработки.

### 1. Создание Webhook в n8n

```
Workflow: "Supabase Order Processor"

Webhook Node
├─ HTTP Method: POST
├─ Path: /process-order
├─ Response: Success message
```

### 2. Настройка вебхука в Supabase

```
Database → Webhooks → Create new webhook

Table: orders
Events: INSERT
HTTP Method: POST
Webhook URL: https://n8n.yourdomain.com/webhook/process-order

Payload при INSERT в orders будет отправлен в n8n
```

### 3. Полный workflow пример

```
Webhook (триггер: new order)
    ↓
Code (валидация)
    ↓
IF: order_amount > 5000
    ├─ true:
    │   ├─ Send to admin email for approval
    │   └─ Save approval_required = true
    └─ false:
        ├─ Auto-process payment
        ├─ Update order status
        └─ Send confirmation email
    ↓
Slack notification
```

## Практические примеры

### Пример 1: Real-time уведомления о новых пользователях

```
Workflow: "New User Alert"

1. Webhook (триггер: событие INSERT из Supabase)

2. Code (extraction):
   return {
     email: item.json.record.email,
     name: item.json.record.name,
     createdAt: item.json.record.created_at
   };

3. Email (отправка):
   To: admin@example.com
   Subject: New user registered: {{ $json.email }}
   Body: 
   <html>
     <h2>New User Sign Up</h2>
     <p>Email: {{ $json.email }}</p>
     <p>Name: {{ $json.name }}</p>
     <p>Time: {{ $json.createdAt }}</p>
   </html>

4. PostgreSQL (логирование):
   INSERT INTO audit_log (action, email, timestamp)
   VALUES ('user_signup', $1, NOW())
   Substitutions: ['{{ $json.email }}']
```

### Пример 2: Синхронизация данных между системами

```
Workflow: "Daily Data Sync"

1. Cron (триггер: ежедневно в 2:00 AM):
   0 2 * * *

2. PostgreSQL (получить измененные данные):
   SELECT * FROM users 
   WHERE updated_at > NOW() - INTERVAL '1 day'

3. Loop (для каждого пользователя):

4. Code (transform):
   return {
     id: item.json.id,
     email: item.json.email,
     status: item.json.status,
     lastSynced: new Date().toISOString()
   };

5. HTTP Request (отправить в другую систему):
   URL: https://external-system.com/api/users
   Method: POST
   Body: {{ $json }}

6. PostgreSQL (update sync status):
   UPDATE users 
   SET synced = true, synced_at = NOW()
   WHERE id = $1
   Substitutions: ['{{ $json.id }}']

7. Email (отправить отчет):
   Subject: Daily sync completed
   Body: Synced {{ items.length }} users
```

### Пример 3: Обработка заказов с уведомлениями

```
Workflow: "Order Processing Pipeline"

1. Webhook (триггер: новый заказ):
   Path: /new-order

2. PostgreSQL (получить детали пользователя):
   SELECT * FROM users WHERE id = $1
   Substitutions: ['{{ $json.record.user_id }}']

3. Code (merge user data):
   return [{
     ...item[0].json,
     order: $node["Webhook"].json.record
   }];

4. IF: order.total > 10000
   ├─ true: Premium order
   │   ├─ PostgreSQL: INSERT into premium_queue
   │   ├─ Slack: Alert premium support team
   │   └─ Email: VIP notification
   └─ false: Standard order
       ├─ PostgreSQL: UPDATE order status = 'processing'
       ├─ Email: Confirmation to customer
       └─ Webhook: Call inventory system

5. Wait: 24 hours (для проверки процесса)

6. PostgreSQL: SELECT order status

7. Email (отправить статус):
   Subject: Order {{ $json.order.id }} Status Update
   Body: Your order is {{ $json.status }}
```

### Пример 4: Trigger функции PostgreSQL из n8n

```
Workflow: "Generate Report"

1. Schedule (триггер: ежемесячно 1-го числа):

2. PostgreSQL (call function):
   SELECT generate_monthly_report($1)
   Substitutions: ['{{ $now.getMonth() }}']

3. Code (parse результат):
   const report = item.json;
   return {
     recordCount: report.total_records,
     errors: report.error_count,
     summary: report.summary
   };

4. Email (отправить отчет):
   To: reports@company.com
   Subject: Monthly Report - {{ $now.toLocaleDateString() }}
   Body: 
   Records: {{ $json.recordCount }}
   Errors: {{ $json.errors }}
   Summary: {{ $json.summary }}
```

## Best Practices

### 1. Безопасность

```
✅ Используйте Service Role Key только в n8n backend
❌ Никогда не используйте Service Role Key в фронтенде

✅ Используйте RLS (Row Level Security) в Supabase
❌ Не полагайтесь только на фильтрацию в n8n

✅ Валидируйте данные перед сохранением
❌ Не доверяйте входящим данным без проверки

✅ Используйте environment переменные для ключей
❌ Не commit ключи в Git
```

### 2. Производительность

```
✅ Используйте batch операции для множества записей
❌ Не вызывайте API по одной записи в цикле

✅ Добавляйте индексы на часто используемые столбцы
❌ Не выполняйте сложные JOIN без оптимизации

✅ Используйте Webhook для real-time обновлений
❌ Не опрашивайте БД каждую минуту через Schedule

✅ Ограничивайте размер результатов (LIMIT)
❌ Не выбирайте все миллионы записей сразу
```

### 3. Обработка ошибок

```
✅ Используйте Try-Catch блоки
❌ Не игнорируйте ошибки

✅ Логируйте все ошибки в БД или файл
❌ Не теряйте информацию об ошибках

✅ Настройте retry механизм с exponential backoff
❌ Не повторяйте запросы сразу же

✅ Отправляйте алерты при критических ошибках
❌ Не оставляйте ошибки без внимания
```

### 4. Мониторинг

```
✅ Проверяйте execution logs в n8n
❌ Не предполагайте что все работает

✅ Настройте email уведомления при ошибках
❌ Не ждите когда пользователь сообщит о проблеме

✅ Отслеживайте метрики производительности
❌ Не игнорируйте медленные workflow

✅ Периодически тестируйте workflow
❌ Не обновляйте workflow без предварительного тестирования
```

## Решение проблем

### Проблема: Ошибка аутентификации при доступе к API

```
Решение:
1. Проверьте что используется SERVICE_ROLE_KEY, а не ANON_KEY
2. Проверьте что ключ скопирован полностью без пробелов
3. Убедитесь что header правильно: Authorization: Bearer KEY
4. Проверьте срок действия ключа в Supabase Settings
```

### Проблема: Медленное выполнение workflow

```
Решение:
1. Используйте EXPLAIN ANALYZE для медленных SQL запросов
2. Добавьте индексы на часто фильтруемые столбцы
3. Ограничьте количество обрабатываемых записей (LIMIT)
4. Используйте batch operations вместо циклов
5. Распределите обработку на несколько n8n workers
```

### Проблема: Webhook не срабатывает

```
Решение:
1. Проверьте что webhook включен в Supabase: Database → Webhooks
2. Проверьте что n8n webhook активен (зеленая точка)
3. Смотрите логи в Supabase: Database → Webhooks → Events
4. Проверьте что URL правильно построен
5. Используйте ngrok или Webhook.site для тестирования
```

### Проблема: RLS не работает как ожидается

```
Решение:
1. Проверьте что RLS включена: ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
2. Проверьте что политика написана правильно
3. Убедитесь что используется SERVICE_ROLE_KEY для обхода RLS (если нужно)
4. Смотрите документацию Supabase по RLS
5. Тестируйте политику с разными пользователями
```

## Следующие шаги

- Перейдите к [Обновлению и поддержке](./maintenance.md)
- Изучите документацию [n8n](https://docs.n8n.io/)
- Изучите документацию [Supabase](https://supabase.com/docs)
