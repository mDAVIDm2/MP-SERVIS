-- Добавить колонку аватара пользователя (если не используете synchronize: true).
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url varchar(1024) NULL;
