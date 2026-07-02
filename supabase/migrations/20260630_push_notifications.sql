-- Push-уведомления: FCM токены + триггеры
-- Применить в: Supabase Dashboard → SQL Editor
--
-- ПЕРЕД ЗАПУСКОМ:
-- Замени 'ВАШ_SERVICE_ROLE_KEY' на ключ из Supabase → Settings → API → service_role (secret)

-- 1. Колонка для FCM токена
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Сохраняем service_role_key в Vault (безопасное хранилище)
SELECT vault.create_secret(
  'ВАШ_SERVICE_ROLE_KEY',       -- TODO: замени на реальный ключ
  'supabase_service_role_key'   -- имя секрета (не менять)
);

-- 3. Вспомогательная функция — вызывает Edge Function send-push
CREATE OR REPLACE FUNCTION call_send_push(
  p_recipient_id UUID,
  p_title        TEXT,
  p_body         TEXT
) RETURNS VOID AS $$
DECLARE
  v_key TEXT;
BEGIN
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

-- 4. Триггер: юрист откликнулся → уведомить клиента
CREATE OR REPLACE FUNCTION trigger_notify_client_on_response()
RETURNS TRIGGER AS $$
DECLARE v_client_id UUID;
BEGIN
  SELECT client_id INTO v_client_id FROM cases WHERE id = NEW.case_id;
  IF v_client_id IS NOT NULL AND v_client_id != NEW.lawyer_id THEN
    PERFORM call_send_push(
      v_client_id,
      'Жаңа заңгер жауабы',
      'Заңгер сіздің өтінімге жауап берді'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_conversation_created ON conversations;
CREATE TRIGGER on_conversation_created
  AFTER INSERT ON conversations
  FOR EACH ROW EXECUTE FUNCTION trigger_notify_client_on_response();

-- 5. Триггер: клиент принял/отклонил → уведомить юриста
CREATE OR REPLACE FUNCTION trigger_notify_lawyer_on_status()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'accepted' THEN
      PERFORM call_send_push(
        NEW.lawyer_id,
        'Клиент сіздің жауабыңызды қабылдады!',
        'Чатты ашыңыз және жұмысты бастаңыз'
      );
    ELSIF NEW.status = 'rejected' THEN
      PERFORM call_send_push(
        NEW.lawyer_id,
        'Клиент жауабыңызды қабылдамады',
        'Басқа өтінімдерге жауап беріп көріңіз'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_conversation_status_changed ON conversations;
CREATE TRIGGER on_conversation_status_changed
  AFTER UPDATE OF status ON conversations
  FOR EACH ROW EXECUTE FUNCTION trigger_notify_lawyer_on_status();

-- 6. Триггер: новое сообщение → уведомить собеседника
CREATE OR REPLACE FUNCTION trigger_notify_on_message()
RETURNS TRIGGER AS $$
DECLARE
  v_lawyer_id UUID;
  v_client_id UUID;
  v_recipient UUID;
BEGIN
  SELECT lawyer_id INTO v_lawyer_id
    FROM conversations WHERE id = NEW.conversation_id;

  SELECT client_id INTO v_client_id
    FROM cases
    WHERE id = (SELECT case_id FROM conversations WHERE id = NEW.conversation_id);

  IF NEW.sender_id = v_lawyer_id THEN
    v_recipient := v_client_id;
  ELSE
    v_recipient := v_lawyer_id;
  END IF;

  IF v_recipient IS NOT NULL THEN
    PERFORM call_send_push(
      v_recipient,
      'Жаңа хабарлама',
      'Чатта жаңа хабарлама бар'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_message_created ON messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION trigger_notify_on_message();
