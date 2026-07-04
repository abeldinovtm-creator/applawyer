-- call_send_push вызывал net.http_post с body::text, но в установленной
-- версии pg_net (0.20.3) параметр body имеет тип jsonb — вызов падал на
-- 42883 (no function matches) на КАЖДОМ срабатывании, но
-- "EXCEPTION WHEN OTHERS THEN NULL" внутри функции глушил это молча.
-- Из-за этого вся система уведомлений (и push, и внутриприложенческий
-- список notifications) не работала вообще ни разу с момента создания —
-- таблица notifications была полностью пустой.
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
    )
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
