-- Единое поле суммы (amount) вместо трёх отдельных полей оплаты
-- (предоплата / после услуги / по результату) — и в заявке клиента (cases),
-- и в отклике юриста (conversations).
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- ПЕРЕД ПРИМЕНЕНИЕМ, ПРОВЕРИТЬ ВРУЧНУЮ:
-- 1. Что миграция 20260703_escrow_commission_dual_confirmation.sql уже применена
--    (эта миграция переопределяет функцию conversations_create_escrow_on_accept,
--    определённую там).
-- 2. Эскроу-счета (escrow_accounts), уже созданные для откликов, принятых ДО
--    этой миграции, не пересчитываются — их amount остался равен сумме трёх
--    старых полей на момент принятия. Это касается только уже проведённых
--    сделок и не требует ручного вмешательства.
-- 3. cases.budget уже хранит итоговую сумму (main.dart всегда писал
--    budget = prepay + completion + result), поэтому отдельное поле-бэкфилл
--    для cases не нужно — просто перестаём читать/писать колонки-разбивку.

-- =====================================================================
-- 1. cases: удаляем колонки-разбивку бюджета клиента. budget остаётся
--    единственным полем суммы (уже содержит корректное значение).
-- =====================================================================
ALTER TABLE cases DROP COLUMN IF EXISTS budget_prepayment;
ALTER TABLE cases DROP COLUMN IF EXISTS budget_on_completion;
ALTER TABLE cases DROP COLUMN IF EXISTS budget_on_result;

-- =====================================================================
-- 2. conversations: добавляем единое поле цены юриста (price_amount),
--    переносим данные из старой разбивки, затем удаляем старые колонки.
-- =====================================================================
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS price_amount INTEGER;

UPDATE conversations
SET price_amount = COALESCE(price_prepayment, 0) + COALESCE(price_on_completion, 0) + COALESCE(price_on_result, 0)
WHERE price_amount IS NULL
  AND (price_prepayment IS NOT NULL OR price_on_completion IS NOT NULL OR price_on_result IS NOT NULL);

ALTER TABLE conversations DROP COLUMN IF EXISTS price_prepayment;
ALTER TABLE conversations DROP COLUMN IF EXISTS price_on_completion;
ALTER TABLE conversations DROP COLUMN IF EXISTS price_on_result;

-- =====================================================================
-- 3. Эскроу-триггер: сумма для эскроу-счёта теперь берётся напрямую из
--    price_amount принятого отклика, а не суммируется из трёх полей.
--    Логика эскроу не меняется: вся сумма замораживается при принятии
--    отклика (см. триггер on_conversation_accepted_create_escrow из
--    20260703_escrow_commission_dual_confirmation.sql), освобождается
--    юристу за вычетом комиссии (payout_amount) только после двойного
--    подтверждения завершения дела (cases_release_on_dual_confirmation,
--    там же — не меняется этой миграцией).
-- =====================================================================
CREATE OR REPLACE FUNCTION conversations_create_escrow_on_accept()
RETURNS TRIGGER AS $$
DECLARE
  v_case cases%ROWTYPE;
  v_amount NUMERIC(12, 2);
  v_percent NUMERIC(5, 2);
BEGIN
  SELECT * INTO v_case FROM cases WHERE id = NEW.case_id;
  IF NOT FOUND THEN
    RETURN NEW; -- дело не найдено — не должно происходить, но не блокируем принятие
  END IF;

  v_amount := COALESCE(NEW.price_amount, 0);

  SELECT percent INTO v_percent FROM commission_rates WHERE category = v_case.category;
  IF NOT FOUND THEN
    v_percent := 10.00; -- запасной процент, если категория не найдена в справочнике
  END IF;

  INSERT INTO escrow_accounts (case_id, client_id, lawyer_id, amount, commission_percent)
  VALUES (NEW.case_id, v_case.client_id, NEW.lawyer_id, v_amount, v_percent)
  ON CONFLICT (case_id) DO NOTHING; -- защита от повторного срабатывания / гонки

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
