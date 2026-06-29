-- Push-уведомления: FCM токены + триггеры
-- Применить в: Supabase Dashboard → SQL Editor

-- 1. Колонка для FCM токена в профилях
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. TODO: Установить service_role_key для триггеров
-- Выполни это один раз (замени значение на свой ключ из Supabase → Settings → API):
-- ALTER DATABASE postgres SET app.service_role_key = 'eyJ...твой_service_role_key...';

-- 3. Вспомогательная функция — вызывает Edge Function send-push
CREATE OR REPLACE FUNCTION call_send_push(
  p_recipient_id UUID,
  p_title TEXT,
  p_body TEXT
) RETURNS VOID AS $$
BEGIN
  PERFORM net.http_post(
    url      := 'https://xkxontehimricgmmkjbw.supabase.co/functions/v1/send-push',
    headers  := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body     := jsonb_build_object(
      'recipient_id', p_recipient_id::text,
      'title',        p_title,
      'body',         p_body
    )::text
  );
EXCEPTION WHEN OTHERS THEN
  NULL; -- Не блокируем основную операцию если пуш не отправился
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
      'Новый отклик юриста',
      'Юрист откликнулся на вашу заявку. Откройте приложение.'
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
        'Клиент принял ваш отклик!',
        'Откройте чат и начните работу'
      );
    ELSIF NEW.status = 'rejected' THEN
      PERFORM call_send_push(
        NEW.lawyer_id,
        'Клиент отклонил ваш отклик',
        'Попробуйте откликнуться на другие заявки'
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
  v_lawyer_id  UUID;
  v_client_id  UUID;
  v_recipient  UUID;
BEGIN
  SELECT lawyer_id INTO v_lawyer_id
    FROM conversations WHERE id = NEW.conversation_id;

  SELECT client_id INTO v_client_id
    FROM cases
    WHERE id = (SELECT case_id FROM conversations WHERE id = NEW.conversation_id);

  -- Получатель — тот, кто НЕ отправил сообщение
  IF NEW.sender_id = v_lawyer_id THEN
    v_recipient := v_client_id;
  ELSE
    v_recipient := v_lawyer_id;
  END IF;

  IF v_recipient IS NOT NULL THEN
    PERFORM call_send_push(
      v_recipient,
      'Новое сообщение',
      'У вас новое сообщение в чате'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_message_created ON messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION trigger_notify_on_message();
