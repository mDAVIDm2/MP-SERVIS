-- Права сотрудника: чаты и настройки организации
ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS can_see_chats boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_write_chats boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_manage_org_settings boolean NOT NULL DEFAULT false;

UPDATE staff_members SET
  can_see_chats = false,
  can_write_chats = false,
  can_manage_org_settings = false
WHERE role = 'master';

UPDATE staff_members SET
  can_see_chats = true,
  can_write_chats = true,
  can_manage_org_settings = true
WHERE role = 'admin';
