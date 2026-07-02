-- 1. Переключение роли (lawyer ↔ client) без изменения основной role
-- Применить в: Supabase Dashboard → SQL Editor
-- (миграция не применяется автоматически, применить вручную и проверить перед прод-раскаткой)

-- Колонка активной роли — если заполнена, AuthRouter показывает интерфейс
-- по её значению, а не по основной profiles.role. Основная role не меняется никогда.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS active_role TEXT;

-- 2. Защита от самооткликов (юрист не может откликнуться на свою же заявку,
-- если он же выступает клиентом — актуально при переключении роли)
--
-- Таблица откликов в этом проекте называется "conversations", не "responses"
-- (case_id, lawyer_id — см. lib/lawyer_screen.dart _sendResponse()).
--
-- ВАЖНО: политика создана как RESTRICTIVE, а не обычная (permissive).
-- В Postgres RLS несколько permissive-политик для одной команды объединяются через OR —
-- значит обычная политика тут ничего бы не гарантировала, если существует любая другая
-- permissive INSERT-политика на conversations. RESTRICTIVE-политики всегда объединяются
-- через AND с остальными, поэтому это ограничение нельзя обойти другой политикой.
DROP POLICY IF EXISTS "lawyer_cannot_respond_own_case" ON conversations;
CREATE POLICY "lawyer_cannot_respond_own_case"
  ON conversations
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    lawyer_id != (SELECT client_id FROM cases WHERE id = case_id)
  );
