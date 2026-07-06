-- Уведомления получают тип, чтобы приложение знало, куда вести по тапу:
-- 'new_message' → в чат (там и происходит событие), остальные типы
-- ('new_response', 'status_change', 'confirmation_needed') → в заявку/дело,
-- а не в чат.
--
-- Тела функций ниже взяты из live pg_get_functiondef() на момент письма
-- этой миграции (не из старых файлов миграций) — во избежание повторной
-- регрессии, которая уже случалась дважды в этой сессии при неосторожном
-- переписывании call_send_push/trigger_notify_*.

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS type TEXT;

CREATE OR REPLACE FUNCTION call_send_push(
  p_recipient_id     UUID,
  p_title            TEXT,
  p_body             TEXT,
  p_case_id          UUID DEFAULT NULL,
  p_conversation_id  UUID DEFAULT NULL,
  p_type             TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_key TEXT;
BEGIN
  INSERT INTO notifications (recipient_id, title, body, case_id, conversation_id, type)
  VALUES (p_recipient_id, p_title, p_body, p_case_id, p_conversation_id, p_type);

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

CREATE OR REPLACE FUNCTION trigger_notify_client_on_response()
RETURNS TRIGGER AS $$
DECLARE
  v_client_id UUID;
  v_lang TEXT;
BEGIN
  SELECT client_id INTO v_client_id FROM cases WHERE id = NEW.case_id;
  IF v_client_id IS NOT NULL AND v_client_id != NEW.lawyer_id THEN
    IF COALESCE((SELECT notify_new_response FROM profiles WHERE id = v_client_id), true) THEN
      v_lang := COALESCE((SELECT preferred_language FROM profiles WHERE id = v_client_id), 'kk');
      PERFORM call_send_push(
        v_client_id,
        CASE v_lang
          WHEN 'ru' THEN 'Новый отклик юриста'
          WHEN 'en' THEN 'New lawyer response'
          ELSE 'Жаңа заңгер жауабы'
        END,
        CASE v_lang
          WHEN 'ru' THEN 'Юрист ответил на вашу заявку'
          WHEN 'en' THEN 'A lawyer responded to your request'
          ELSE 'Заңгер сіздің өтінімге жауап берді'
        END,
        NEW.case_id,
        NEW.id,
        'new_response'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_notify_lawyer_on_status()
RETURNS TRIGGER AS $$
DECLARE v_lang TEXT;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT COALESCE((SELECT notify_status_change FROM profiles WHERE id = NEW.lawyer_id), true) THEN
      RETURN NEW;
    END IF;
    v_lang := COALESCE((SELECT preferred_language FROM profiles WHERE id = NEW.lawyer_id), 'kk');
    IF NEW.status = 'accepted' THEN
      PERFORM call_send_push(
        NEW.lawyer_id,
        CASE v_lang
          WHEN 'ru' THEN 'Клиент принял ваш отклик!'
          WHEN 'en' THEN 'Client accepted your response!'
          ELSE 'Клиент сіздің жауабыңызды қабылдады!'
        END,
        CASE v_lang
          WHEN 'ru' THEN 'Откройте чат и начните работу'
          WHEN 'en' THEN 'Open the chat and start working'
          ELSE 'Чатты ашыңыз және жұмысты бастаңыз'
        END,
        NEW.case_id,
        NEW.id,
        'status_change'
      );
    ELSIF NEW.status = 'rejected' THEN
      PERFORM call_send_push(
        NEW.lawyer_id,
        CASE v_lang
          WHEN 'ru' THEN 'Клиент отклонил ваш отклик'
          WHEN 'en' THEN 'Client declined your response'
          ELSE 'Клиент жауабыңызды қабылдамады'
        END,
        CASE v_lang
          WHEN 'ru' THEN 'Попробуйте откликнуться на другие заявки'
          WHEN 'en' THEN 'Try responding to other requests'
          ELSE 'Басқа өтінімдерге жауап беріп көріңіз'
        END,
        NEW.case_id,
        NEW.id,
        'status_change'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_notify_on_message()
RETURNS TRIGGER AS $$
DECLARE
  v_lawyer_id UUID;
  v_case_id   UUID;
  v_client_id UUID;
  v_recipient UUID;
  v_lang TEXT;
BEGIN
  SELECT lawyer_id, case_id INTO v_lawyer_id, v_case_id
    FROM conversations WHERE id = NEW.conversation_id;

  SELECT client_id INTO v_client_id FROM cases WHERE id = v_case_id;

  IF NEW.sender_id = v_lawyer_id THEN
    v_recipient := v_client_id;
  ELSE
    v_recipient := v_lawyer_id;
  END IF;

  IF v_recipient IS NOT NULL AND COALESCE((SELECT notify_new_message FROM profiles WHERE id = v_recipient), true) THEN
    v_lang := COALESCE((SELECT preferred_language FROM profiles WHERE id = v_recipient), 'kk');
    PERFORM call_send_push(
      v_recipient,
      CASE v_lang
        WHEN 'ru' THEN 'Новое сообщение'
        WHEN 'en' THEN 'New message'
        ELSE 'Жаңа хабарлама'
      END,
      CASE v_lang
        WHEN 'ru' THEN 'В чате новое сообщение'
        WHEN 'en' THEN 'You have a new message in chat'
        ELSE 'Чатта жаңа хабарлама бар'
      END,
      v_case_id,
      NEW.conversation_id,
      'new_message'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_notify_completion_confirmation_needed()
RETURNS TRIGGER AS $$
DECLARE
  v_lawyer_id UUID;
  v_conversation_id UUID;
  v_lang TEXT;
BEGIN
  -- Клиент только что подтвердил, юрист — ещё нет.
  IF NEW.client_confirmed_completion_at IS NOT NULL
     AND OLD.client_confirmed_completion_at IS NULL
     AND NEW.lawyer_confirmed_completion_at IS NULL THEN
    SELECT id, lawyer_id INTO v_conversation_id, v_lawyer_id
      FROM conversations WHERE case_id = NEW.id AND status = 'accepted'
      LIMIT 1;
    IF v_lawyer_id IS NOT NULL
       AND COALESCE((SELECT notify_status_change FROM profiles WHERE id = v_lawyer_id), true) THEN
      v_lang := COALESCE((SELECT preferred_language FROM profiles WHERE id = v_lawyer_id), 'kk');
      PERFORM call_send_push(
        v_lawyer_id,
        CASE v_lang
          WHEN 'ru' THEN 'Клиент подтвердил завершение'
          WHEN 'en' THEN 'Client confirmed completion'
          ELSE 'Клиент аяқталуын растады'
        END,
        CASE v_lang
          WHEN 'ru' THEN 'Подтвердите тоже — иначе дело не закроется'
          WHEN 'en' THEN 'Confirm too — otherwise the case won''t close'
          ELSE 'Сіз де растаңыз — әйтпесе іс жабылмайды'
        END,
        NEW.id,
        v_conversation_id,
        'confirmation_needed'
      );
    END IF;
  END IF;

  -- Юрист только что подтвердил, клиент — ещё нет.
  IF NEW.lawyer_confirmed_completion_at IS NOT NULL
     AND OLD.lawyer_confirmed_completion_at IS NULL
     AND NEW.client_confirmed_completion_at IS NULL THEN
    IF COALESCE((SELECT notify_status_change FROM profiles WHERE id = NEW.client_id), true) THEN
      SELECT id INTO v_conversation_id
        FROM conversations WHERE case_id = NEW.id AND status = 'accepted'
        LIMIT 1;
      v_lang := COALESCE((SELECT preferred_language FROM profiles WHERE id = NEW.client_id), 'kk');
      PERFORM call_send_push(
        NEW.client_id,
        CASE v_lang
          WHEN 'ru' THEN 'Юрист подтвердил завершение'
          WHEN 'en' THEN 'Lawyer confirmed completion'
          ELSE 'Заңгер аяқталуын растады'
        END,
        CASE v_lang
          WHEN 'ru' THEN 'Подтвердите тоже — иначе дело не закроется'
          WHEN 'en' THEN 'Confirm too — otherwise the case won''t close'
          ELSE 'Сіз де растаңыз — әйтпесе іс жабылмайды'
        END,
        NEW.id,
        v_conversation_id,
        'confirmation_needed'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
