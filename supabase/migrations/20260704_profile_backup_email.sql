-- Резервная почта в профиле (обычный текстовый столбец, без подтверждения —
-- основной email пользователя живёт в auth.users и меняется через
-- supabase.auth.updateUser(), не через эту таблицу).
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS backup_email TEXT;
