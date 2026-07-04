-- Клиент мог принять (status='accepted') сразу несколько откликов юристов
-- по одной заявке — ничего не запрещало. Эскроу-счёт при этом привязан
-- к заявке (case_id UNIQUE), а не к конкретному отклику, и создаётся
-- только для ПЕРВОГО принятого — второй принятый отклик оставался бы
-- без эскроу и ломался бы на этапе двойного подтверждения завершения
-- (см. feedback-bugs-fixed про "Эскроу-счёт для дела % не найден").
--
-- Фикс: при принятии одного отклика — остальные ожидающие (pending) по
-- этой же заявке автоматически становятся rejected. Плюс защита от гонки
-- (два "Принять" почти одновременно) — если по заявке уже есть другой
-- принятый отклик, повторное принятие блокируется исключением.
CREATE OR REPLACE FUNCTION conversations_auto_reject_others_on_accept()
RETURNS TRIGGER AS $$
DECLARE
  v_other_accepted_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM conversations
    WHERE case_id = NEW.case_id AND id <> NEW.id AND status = 'accepted'
  ) INTO v_other_accepted_exists;

  IF v_other_accepted_exists THEN
    RAISE EXCEPTION 'По этой заявке уже принят другой отклик';
  END IF;

  UPDATE conversations
    SET status = 'rejected'
    WHERE case_id = NEW.case_id AND id <> NEW.id AND status = 'pending';

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_conversation_accepted_reject_others ON conversations;
CREATE TRIGGER on_conversation_accepted_reject_others
  AFTER UPDATE OF status ON conversations
  FOR EACH ROW
  WHEN (NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM 'accepted')
  EXECUTE FUNCTION conversations_auto_reject_others_on_accept();
