# Настройка Supabase

## Введение в админку Supabase

После развертывания Supabase, вы получаете доступ к web-интерфейсу (Studio), где можно управлять всеми аспектами вашей базы данных.

## Основные разделы администраторского интерфейса

### 1. Projects (Проекты)

**Путь**: Home → Projects

Управление всеми проектами:
- Создание новых проектов
- Удаление проектов
- Переименование проектов
- Просмотр статистики проекта

### 2. Database (База данных)

#### 2.1 Tables (Таблицы)

**Путь**: Project → Database → Tables

Управление структурой БД:

- **Создание таблицы**:
  ```sql
  CREATE TABLE users (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
  );
  ```

- **Параметры таблицы**:
  - Primary Key - уникальный идентификатор
  - Foreign Keys - связи с другими таблицами
  - Constraints - ограничения (UNIQUE, NOT NULL, CHECK)
  - Indexes - индексы для оптимизации запросов
  - RLS (Row Level Security) - уровень безопасности на уровне строк

#### 2.2 SQL Editor (SQL Редактор)

**Путь**: Project → Database → SQL

Выполнение произвольных SQL запросов:

```sql
-- Создание таблицы с комментариями
CREATE TABLE products (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10, 2) NOT NULL,
  stock INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

COMMENT ON TABLE products IS 'Таблица товаров';
COMMENT ON COLUMN products.price IS 'Цена товара в рублях';

-- Создание индекса
CREATE INDEX idx_products_price ON products(price);

-- Создание представления
CREATE VIEW expensive_products AS
SELECT * FROM products WHERE price > 1000;
```

#### 2.3 Functions (Функции)

**Путь**: Project → Database → Functions

PostgreSQL функции для сложной бизнес-логики:

```sql
-- Функция для обновления времени изменения
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Функция для подсчета товаров в категории
CREATE OR REPLACE FUNCTION count_products_in_category(cat_id INT)
RETURNS INT AS $$
BEGIN
  RETURN COUNT(*)::INT FROM products WHERE category_id = cat_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления
CREATE TRIGGER products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();
```

#### 2.4 Extensions (Расширения)

**Путь**: Project → Database → Extensions

Включение дополнительных возможностей PostgreSQL:

| Расширение | Описание | Когда использовать |
|-----------|---------|-------------------|
| pgvector | Поддержка векторных данных | AI/ML, сходство поиска |
| uuid-ossp | UUID генерация | Генерация уникальных ID |
| pgjwt | JWT токены | Для отладки |
| http | HTTP запросы | Вызов внешних API |
| plpgsql | PL/pgSQL язык | Функции и триггеры |

```sql
-- Включение расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- Использование
ALTER TABLE users ADD COLUMN id UUID PRIMARY KEY DEFAULT uuid_generate_v4();
ALTER TABLE embeddings ADD COLUMN embedding vector(1536);
```

### 3. Authentication (Аутентификация)

#### 3.1 Users (Пользователи)

**Путь**: Project → Authentication → Users

- Просмотр всех пользователей
- Ручное создание пользователей
- Удаление пользователей
- Просмотр сессий
- Принудительный выход

#### 3.2 Providers (Провайдеры аутентификации)

**Путь**: Project → Authentication → Providers

Настройка методов входа:

##### Email/Password

```
Settings → Authentication → Email/Password
- Autoconfirm users: Автоподтверждение почты (dev режим)
- Double confirm changes: Подтверждение изменений почты
- Email rate limit: Лимит на количество писем
```

##### Social Providers (Google, GitHub, и т.д.)

```
Providers → Google
- Client ID: из Google Cloud Console
- Client Secret: из Google Cloud Console
- Redirect URL: https://yourdomain.com/auth/v1/callback?provider=google
```

Пример для GitHub:
```
Providers → GitHub
- Client ID: из GitHub Developer Settings
- Client Secret: из GitHub Developer Settings
```

#### 3.3 Policies (Политики безопасности)

**Путь**: Project → Authentication → Policies

```sql
-- Включение RLS для таблицы
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Политика для чтения только собственных данных
CREATE POLICY "Users can read own data"
ON users FOR SELECT
USING (auth.uid() = id);

-- Политика для создания только авторизованными пользователями
CREATE POLICY "Users can insert own data"
ON users FOR INSERT
WITH CHECK (auth.uid() = id);

-- Политика для обновления только собственных данных
CREATE POLICY "Users can update own data"
ON users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Политика для удаления только собственных данных
CREATE POLICY "Users can delete own data"
ON users FOR DELETE
USING (auth.uid() = id);
```

### 4. API (Документация API)

#### 4.1 Overview

**Путь**: Project → API → Overview

- API URL: адрес REST API
- Project URL: база для всех запросов
- API Key (anon): публичный ключ для фронтенда
- Service Role Key: приватный ключ для backend

#### 4.2 API Docs

**Путь**: Project → API → Docs

Автоматическая документация REST API для всех таблиц:

```bash
# Получить все записи
curl "https://api.supabase.yourdomain.com/rest/v1/users" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Получить одну запись
curl "https://api.supabase.yourdomain.com/rest/v1/users?id=eq.1" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Создать запись
curl -X POST "https://api.supabase.yourdomain.com/rest/v1/users" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","name":"John"}'

# Обновить запись
curl -X PATCH "https://api.supabase.yourdomain.com/rest/v1/users?id=eq.1" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane"}'

# Удалить запись
curl -X DELETE "https://api.supabase.yourdomain.com/rest/v1/users?id=eq.1" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### 4.3 Webhooks

**Путь**: Project → Database → Webhooks

Система событий для реакции на изменения в БД:

```
Webhook события:
- INSERT: когда добавляется новая запись
- UPDATE: когда обновляется запись
- DELETE: когда удаляется запись

Пример вебхука:
- Table: users
- Event: INSERT, UPDATE
- URL: https://n8n.yourdomain.com/webhook/supabase-trigger
- Method: POST
```

Payload вебхука:
```json
{
  "type": "INSERT",
  "table": "users",
  "schema": "public",
  "record": {
    "id": 1,
    "email": "user@example.com",
    "name": "John",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "old_record": null
}
```

### 5. Realtime (Реал-тайм обновления)

**Путь**: Project → Database → Realtime

Настройка реал-тайм подписок:

```javascript
// Подписка на изменения таблицы
const subscription = supabase
  .channel('users')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'users'
  }, payload => {
    console.log('Change received!', payload)
  })
  .subscribe()

// Подписка на конкретные события
const subscription2 = supabase
  .channel('users')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'users'
  }, payload => {
    console.log('New user added!', payload.new)
  })
  .subscribe()
```

### 6. Settings (Настройки)

#### 6.1 Project Settings

**Путь**: Project → Settings → General

- Project name: название проекта
- API URL: адрес API
- Database URL: адрес БД
- Region: регион расположения

#### 6.2 API Settings

**Путь**: Project → Settings → API

- JWT secret: секрет для подписи JWT
- CORS settings: настройка CORS для безопасности
- Redirect URLs: допустимые URL для перенаправления после аутентификации

```
CORS Allowed Origins:
- http://localhost:3000
- http://localhost:3001
- https://yourdomain.com
- https://www.yourdomain.com
```

#### 6.3 Database Settings

**Путь**: Project → Settings → Database

- Database user: пользователь БД
- Database password: пароль БД
- PostgreSQL version: версия PostgreSQL
- Max connections: максимальное количество подключений

## Практические примеры

### Пример 1: Создание системы пользователей

```sql
-- 1. Создание основной таблицы пользователей
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. Включение RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 3. Политики безопасности
CREATE POLICY "Public users are viewable by everyone"
ON users FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 4. Триггер для обновления updated_at
CREATE TRIGGER users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

-- 5. Функция для получения профиля текущего пользователя
CREATE OR REPLACE FUNCTION get_current_user()
RETURNS SETOF users AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql;
```

### Пример 2: Система роли и разрешений

```sql
-- Таблица ролей
CREATE TABLE roles (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Таблица разрешений
CREATE TABLE permissions (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Связка роли и разрешений
CREATE TABLE role_permissions (
  role_id INT REFERENCES roles(id) ON DELETE CASCADE,
  permission_id INT REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- Назначение ролей пользователям
CREATE TABLE user_roles (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role_id INT REFERENCES roles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);

-- Функция для проверки разрешения
CREATE OR REPLACE FUNCTION has_permission(permission_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = auth.uid() AND p.name = permission_name
  );
END;
$$ LANGUAGE plpgsql;
```

### Пример 3: Логирование действий

```sql
-- Таблица для логирования
CREATE TABLE audit_logs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Индекс для быстрого поиска
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);

-- Функция логирования
CREATE OR REPLACE FUNCTION log_audit_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    NEW.id::TEXT,
    ROW_TO_JSON(OLD.*),
    ROW_TO_JSON(NEW.*)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применение триггера к таблице
CREATE TRIGGER users_audit_log
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION log_audit_action();
```

## Оптимизация производительности

### Индексы

```sql
-- Индекс для часто используемых столбцов
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Составной индекс
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Индекс для текстового поиска
CREATE INDEX idx_products_name_search ON products 
USING GIN (to_tsvector('russian', name));
```

### Статистика и анализ

```sql
-- Анализ плана запроса
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';

-- Сбор статистики
ANALYZE users;

-- Вакуумирование (удаление мертвых строк)
VACUUM ANALYZE users;
```

## Мониторинг

### Просмотр активных соединений

```sql
SELECT datname, usename, application_name, state
FROM pg_stat_activity
WHERE datname = 'postgres';
```

### Размер таблиц

```sql
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Следующие шаги

- Изучите [Интеграцию с n8n](./supabase-n8n-integration.md)
- Настройте [Развертывание n8n](./n8n-deployment.md)
