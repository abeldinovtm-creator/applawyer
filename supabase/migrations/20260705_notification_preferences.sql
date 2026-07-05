-- Настройки уведомлений по типам событий. Общий вкл/выкл push не
-- хранится отдельным флагом — он и так эквивалентен наличию/отсутствию
-- fcm_token (см. lib/services/push_service.dart), поэтому здесь только
-- гранулярные переключатели по типам событий.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notify_new_response BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_status_change BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_new_message BOOLEAN NOT NULL DEFAULT true;

-- Триггеры теперь проверяют предпочтение получателя перед вызовом
-- call_send_push — если тип события отключён, ни push, ни запись в
-- notifications (внутренний список) не создаются вообще.

CREATE OR REPLACE FUNCTION trigger_notify_client_on_response()
RETURNS TRIGGER AS $$
DECLARE v_client_id UUID;
BEGIN
  SELECT client_id INTO v_client_id FROM cases WHERE id = NEW.case_id;
  IF v_client_id IS NOT NULL AND v_client_id != NEW.lawyer_id THEN
    IF COALESCE((SELECT notify_new_response FROM profiles WHERE id = v_client_id), true) THEN
      PERFORM call_send_push(
        v_client_id,
        'Жаңа заңгер жауабы',
        'Заңгер сіздің өтінімге жауап берді'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_notify_lawyer_on_status()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT COALESCE((SELECT notify_status_change FROM profiles WHERE id = NEW.lawyer_id), true) THEN
      RETURN NEW;
    END IF;
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

  IF v_recipient IS NOT NULL AND COALESCE((SELECT notify_new_message FROM profiles WHERE id = v_recipient), true) THEN
    PERFORM call_send_push(
      v_recipient,
      'Жаңа хабарлама',
      'Чатта жаңа хабарлама бар'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
