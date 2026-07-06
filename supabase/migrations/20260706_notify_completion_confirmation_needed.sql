-- Раньше при подтверждении завершения дела одной стороной вторая сторона
-- не получала вообще никакого сигнала — оставалось только случайно
-- наткнуться на кнопку подтверждения в "В работе" (юрист) / "Мои заявки"
-- (клиент). Теперь противоположная сторона сразу получает push-напоминание.

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
        v_conversation_id
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
        v_conversation_id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_completion_confirmation_needed ON cases;
CREATE TRIGGER on_completion_confirmation_needed
  AFTER UPDATE OF client_confirmed_completion_at, lawyer_confirmed_completion_at ON cases
  FOR EACH ROW EXECUTE FUNCTION trigger_notify_completion_confirmation_needed();
