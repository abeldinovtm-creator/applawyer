-- Ограничение cases_status_check никогда не обновлялось под фичу
-- двойного подтверждения завершения дела (20260703_escrow_commission_
-- dual_confirmation.sql) — триггер cases_release_on_dual_confirmation
-- пытается выставить status='completed', но constraint разрешал только
-- 'open'/'closed'. Из-за этого весь релиз эскроу по двойному
-- подтверждению был сломан с момента деплоя (23514 при первой попытке
-- обеими сторонами подтвердить одно и то же дело).
ALTER TABLE cases DROP CONSTRAINT IF EXISTS cases_status_check;
ALTER TABLE cases ADD CONSTRAINT cases_status_check
  CHECK (status = ANY (ARRAY['open'::text, 'closed'::text, 'completed'::text]));
