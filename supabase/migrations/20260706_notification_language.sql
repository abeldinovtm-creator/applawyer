-- Баг: текст push/уведомлений был захардкожен на казахском во всех
-- триггерах — настройка языка в профиле (profiles.preferred_language)
-- влияла только на интерфейс приложения, но не на текст, который сам
-- же сервер отправляет получателю. Теперь каждый триггер читает
-- preferred_language получателя и подставляет нужный текст.

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
        END
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_notify_lawyer_on_status()
RETURNS TRIGGER AS $$
DECLARE
  v_lang TEXT;
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
        END
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
        END
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
  v_client_id UUID;
  v_recipient UUID;
  v_lang TEXT;
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
      END
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
