-- Общая оценка 1-5 заменяется структурированными критериями, безопасными
-- с точки зрения адвокатской тайны (только про сервис/общение, не про
-- содержание дела): коммуникация, соблюдение сроков, вежливость и
-- профессионализм, прозрачность оплаты. Итоговый рейтинг = среднее по ним.
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)

ALTER TABLE public.reviews
  ADD COLUMN communication_rating INTEGER CHECK (communication_rating BETWEEN 1 AND 5),
  ADD COLUMN timeliness_rating INTEGER CHECK (timeliness_rating BETWEEN 1 AND 5),
  ADD COLUMN professionalism_rating INTEGER CHECK (professionalism_rating BETWEEN 1 AND 5),
  ADD COLUMN payment_transparency_rating INTEGER CHECK (payment_transparency_rating BETWEEN 1 AND 5);

-- Бэкфилл уже существующих отзывов (на момент миграции их 2) — переносим
-- старую общую оценку во все 4 критерия, чтобы не потерять данные перед
-- тем как сделать колонки NOT NULL.
UPDATE public.reviews SET
  communication_rating = rating,
  timeliness_rating = rating,
  professionalism_rating = rating,
  payment_transparency_rating = rating
WHERE communication_rating IS NULL;

ALTER TABLE public.reviews
  ALTER COLUMN communication_rating SET NOT NULL,
  ALTER COLUMN timeliness_rating SET NOT NULL,
  ALTER COLUMN professionalism_rating SET NOT NULL,
  ALTER COLUMN payment_transparency_rating SET NOT NULL;

-- rating теперь вычисляется как среднее по 4 критериям — больше не пишется
-- напрямую при INSERT (GENERATED-колонка), UI переходит на запись критериев.
ALTER TABLE public.reviews DROP COLUMN rating;
ALTER TABLE public.reviews ADD COLUMN rating NUMERIC(3, 2) GENERATED ALWAYS AS (
  (communication_rating + timeliness_rating + professionalism_rating + payment_transparency_rating)::numeric / 4
) STORED;

-- RLS-политики на reviews не завязаны на конкретные колонки
-- (client_id/can_review_case), поэтому изменений не требуют.
