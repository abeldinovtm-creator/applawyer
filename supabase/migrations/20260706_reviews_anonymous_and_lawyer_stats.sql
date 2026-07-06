-- Отзыв можно оставить анонимно — колонка is_anonymous, по умолчанию
-- false (автор виден). RLS не меняется: существующие политики на
-- reviews не завязаны на конкретный список колонок.
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT false;

-- Статистика юриста по категориям (сколько завершённых дел в каждой) —
-- считается через escrow_accounts (там точно известен lawyer_id для
-- каждого завершённого дела), а не через conversations напрямую, т.к.
-- клиент, листающий чужой публичный профиль юриста, не имеет RLS-доступа
-- к чужим conversations/escrow_accounts — оборачиваем в SECURITY DEFINER,
-- отдаёт только агрегат (категория + число), без чувствительных данных.
CREATE OR REPLACE FUNCTION public.get_lawyer_category_stats(p_lawyer_id UUID)
RETURNS TABLE(category TEXT, completed_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT c.category, count(*) AS completed_count
  FROM public.cases c
  JOIN public.escrow_accounts e ON e.case_id = c.id
  WHERE e.lawyer_id = p_lawyer_id
    AND c.status = 'completed'
  GROUP BY c.category
  ORDER BY completed_count DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_lawyer_category_stats(UUID) TO authenticated;
