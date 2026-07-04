-- Центр уведомлений внутри приложения + счётчики непрочитанного
-- (уведомления и сообщения в чатах) для бейджей в меню.
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)

-- =====================================================================
-- 1. notifications — лог уведомлений. recipient_id = NULL означает
--    объявление для всех пользователей (админ вставляет вручную через
--    SQL Editor: INSERT INTO notifications (recipient_id, title, body)
--    VALUES (NULL, '...', '...');).
-- =====================================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select ON notifications;
CREATE POLICY notifications_select ON notifications
  FOR SELECT USING (recipient_id = auth.uid() OR recipient_id IS NULL);

-- =====================================================================
-- 2. notification_reads — какие уведомления пользователь уже видел
--    (нужно и для личных, и для общих объявлений — у объявления один
--    ряд в notifications, но прочитанность своя у каждого пользователя).
-- =====================================================================
CREATE TABLE IF NOT EXISTS notification_reads (
  notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, user_id)
);

ALTER TABLE notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notification_reads_own ON notification_reads;
CREATE POLICY notification_reads_own ON notification_reads
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- 3. conversation_reads — когда пользователь последний раз открывал
--    конкретный чат. Непрочитанные сообщения = созданы позже этой
--    отметки и написаны не им самим.
-- =====================================================================
CREATE TABLE IF NOT EXISTS conversation_reads (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

ALTER TABLE conversation_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversation_reads_own ON conversation_reads;
CREATE POLICY conversation_reads_own ON conversation_reads
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- 4. call_send_push теперь также пишет запись в notifications —
--    те же 3 события (юрист откликнулся / клиент принял-отклонил /
--    новое сообщение в чате), что уже шлют push, попадают и в
--    внутриприложенческий список уведомлений.
-- =====================================================================
CREATE OR REPLACE FUNCTION call_send_push(
  p_recipient_id UUID,
  p_title        TEXT,
  p_body         TEXT
) RETURNS VOID AS $$
DECLARE
  v_key TEXT;
BEGIN
  INSERT INTO notifications (recipient_id, title, body)
  VALUES (p_recipient_id, p_title, p_body);

  SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets
    WHERE name = 'supabase_service_role_key'
    LIMIT 1;

  PERFORM net.http_post(
    url     := 'https://xkxontehimricgmmkjbw.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'recipient_id', p_recipient_id::text,
      'title',        p_title,
      'body',         p_body
    )::text
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================
-- 5. get_unread_counts() — RPC для бейджей в меню. SECURITY DEFINER,
--    чтобы не упереться в RLS-рекурсию между cases/conversations
--    (см. feedback-bugs-fixed про 42P17) — фильтруем сами по auth.uid().
--
--    Сообщения считаются раздельно как "как клиент" и "как юрист" —
--    один и тот же пользователь может одновременно иметь свои заявки
--    (client_id) и отклики на чужие (conversations.lawyer_id) при
--    переключении active_role, единая сумма вешала непрочитанные
--    сообщения из чатов-юриста на пункт меню "Мои заявки", которые
--    оттуда физически не открыть — бейдж никогда не гас (найдено
--    04.07.2026 на тестовом аккаунте role=lawyer/active_role=client).
-- =====================================================================
DROP FUNCTION IF EXISTS get_unread_counts();
CREATE OR REPLACE FUNCTION get_unread_counts()
RETURNS TABLE(unread_notifications BIGINT, unread_messages_client BIGINT, unread_messages_lawyer BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    (
      SELECT count(*) FROM notifications n
      WHERE (n.recipient_id = v_uid OR n.recipient_id IS NULL)
        AND NOT EXISTS (
          SELECT 1 FROM notification_reads r
          WHERE r.notification_id = n.id AND r.user_id = v_uid
        )
    ),
    (
      SELECT count(*) FROM messages m
      JOIN conversations c ON c.id = m.conversation_id
      JOIN cases cs ON cs.id = c.case_id
      LEFT JOIN conversation_reads cr ON cr.conversation_id = c.id AND cr.user_id = v_uid
      WHERE m.sender_id != v_uid
        AND cs.client_id = v_uid
        AND m.created_at > COALESCE(cr.last_read_at, '-infinity'::timestamptz)
    ),
    (
      SELECT count(*) FROM messages m
      JOIN conversations c ON c.id = m.conversation_id
      LEFT JOIN conversation_reads cr ON cr.conversation_id = c.id AND cr.user_id = v_uid
      WHERE m.sender_id != v_uid
        AND c.lawyer_id = v_uid
        AND m.created_at > COALESCE(cr.last_read_at, '-infinity'::timestamptz)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_unread_counts() TO authenticated;
