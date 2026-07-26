-- Заработок юриста по категориям для раздела "Статистика".
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- В отличие от get_lawyer_category_stats (20260706_reviews_anonymous_and_lawyer_stats.sql),
-- которая публичная (принимает p_lawyer_id, её может вызвать любой авторизованный
-- пользователь для чужого профиля — там отдаются только категория+число, ничего
-- денежного), эта функция параметра НЕ принимает и всегда использует auth.uid() —
-- заработок каждого юриста виден только ему самому.
--
-- SECURITY DEFINER нужен только чтобы обойти отсутствие SELECT-политики на cases
-- для JOIN (сам escrow_accounts уже читаем по своей RLS-политике escrow_select_own,
-- но она не помогает достать cases.category).
CREATE OR REPLACE FUNCTION public.get_lawyer_earnings_stats()
RETURNS TABLE(category TEXT, cases_count BIGINT, gross_amount NUMERIC, payout_amount NUMERIC)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT c.category, count(*) AS cases_count, sum(e.amount) AS gross_amount, sum(e.payout_amount) AS payout_amount
  FROM public.escrow_accounts e
  JOIN public.cases c ON c.id = e.case_id
  WHERE e.lawyer_id = auth.uid()
    AND e.status = 'released'
  GROUP BY c.category
  ORDER BY payout_amount DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_lawyer_earnings_stats() TO authenticated;
