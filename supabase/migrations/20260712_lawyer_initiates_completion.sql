-- До сих пор обе стороны могли независимо подтвердить завершение дела в
-- любом порядке (двойное подтверждение без очерёдности, см.
-- 20260703_escrow_commission_dual_confirmation.sql). Меняем бизнес-правило:
-- инициатива должна исходить от юриста/адвоката — он отмечает дело
-- завершённым первым, и только после этого клиент может подтвердить.
--
-- CREATE OR REPLACE полностью переопределяет тело функции — берём АКТУАЛЬНОЕ
-- тело (уже с bypass-GUC из 20260712_moderation_log_and_declines.sql, нужным
-- для сброса дат подтверждения при отказе одной из сторон — см.
-- client_decline_lawyer/lawyer_decline_case), а не исходное из
-- 20260703_escrow_commission_dual_confirmation.sql, и добавляем только
-- одну новую проверку в client-ветке.

CREATE OR REPLACE FUNCTION cases_guard_completion_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF current_setting('app.bypass_completion_guard', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF NEW.client_confirmed_completion_at IS DISTINCT FROM OLD.client_confirmed_completion_at THEN
    IF OLD.client_confirmed_completion_at IS NOT NULL THEN
      RAISE EXCEPTION 'client_confirmed_completion_at уже установлен и не может быть изменён';
    END IF;
    IF auth.uid() IS DISTINCT FROM NEW.client_id THEN
      RAISE EXCEPTION 'Только клиент этого дела может подтвердить его завершение';
    END IF;
    IF OLD.lawyer_confirmed_completion_at IS NULL THEN
      RAISE EXCEPTION 'Юрист ещё не отметил дело завершённым — клиент подтверждает только после него';
    END IF;
    -- Не доверяем значению от клиента (может прислать любую дату) — фиксируем сами.
    NEW.client_confirmed_completion_at := now();
  END IF;

  IF NEW.lawyer_confirmed_completion_at IS DISTINCT FROM OLD.lawyer_confirmed_completion_at THEN
    IF OLD.lawyer_confirmed_completion_at IS NOT NULL THEN
      RAISE EXCEPTION 'lawyer_confirmed_completion_at уже установлен и не может быть изменён';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM conversations
      WHERE case_id = NEW.id AND lawyer_id = auth.uid() AND status = 'accepted'
    ) THEN
      RAISE EXCEPTION 'Только принятый юрист по этому делу может подтвердить его завершение';
    END IF;
    NEW.lawyer_confirmed_completion_at := now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
