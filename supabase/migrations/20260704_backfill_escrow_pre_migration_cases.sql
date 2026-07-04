-- Бэкфилл эскроу-счетов для дел, отклик по которым был принят ДО
-- 20260703_escrow_commission_dual_confirmation.sql (эскроу-триггер на
-- conversations ещё не существовал в момент принятия) — иначе
-- cases_release_on_dual_confirmation блокирует двойное подтверждение
-- этих дел с ошибкой "Эскроу-счёт для дела % не найден".
-- Разово затрагивает только 3 тестовых дела, принятые 02.07.2026.
INSERT INTO escrow_accounts (case_id, client_id, lawyer_id, amount, commission_percent)
SELECT
  c.id,
  c.client_id,
  cv.lawyer_id,
  COALESCE(cv.price_amount, 0),
  COALESCE((SELECT percent FROM commission_rates WHERE category = c.category), 10.00)
FROM cases c
JOIN conversations cv ON cv.case_id = c.id AND cv.status = 'accepted'
LEFT JOIN escrow_accounts ea ON ea.case_id = c.id
WHERE ea.id IS NULL
ON CONFLICT (case_id) DO NOTHING;
