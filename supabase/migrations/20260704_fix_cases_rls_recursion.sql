-- Фикс: PostgrestException "infinite recursion detected in policy for
-- relation cases" (42P17) при попытке юриста подтвердить завершение дела.
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- ПРИЧИНА: политика "lawyer_confirm_completion" на cases (из
-- 20260703_escrow_commission_dual_confirmation.sql) делает EXISTS-подзапрос
-- к conversations прямо в USING/WITH CHECK. RLS-политики самой conversations
-- (существующие, не отслеживаются в репозитории) в свою очередь ссылаются
-- обратно на cases (например, чтобы клиент видел отклики по своим делам).
-- Получается циклическая зависимость между политиками cases <-> conversations,
-- которую Postgres не может развернуть при планировании запроса — отсюда 42P17.
--
-- ФИКС: выносим проверку "юрист принят по этому делу" в SECURITY DEFINER
-- функцию. Она выполняется с правами владельца функции (обычно postgres,
-- который является владельцем cases/conversations), поэтому не применяет RLS
-- повторно к conversations при этой проверке — цикл разрывается. Это тот же
-- приём, что уже используется в триггерных функциях миграции 20260703
-- (conversations_create_escrow_on_accept, cases_guard_completion_columns и т.д.) —
-- они не пострадали от этого бага именно потому, что уже были SECURITY DEFINER,
-- а вот RLS-политика (в отличие от триггера) SECURITY DEFINER не наследует.

CREATE OR REPLACE FUNCTION is_accepted_lawyer_for_case(p_case_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM conversations
    WHERE case_id = p_case_id AND lawyer_id = auth.uid() AND status = 'accepted'
  );
$$;

DROP POLICY IF EXISTS "lawyer_confirm_completion" ON cases;
CREATE POLICY "lawyer_confirm_completion"
  ON cases FOR UPDATE
  USING (is_accepted_lawyer_for_case(id))
  WITH CHECK (is_accepted_lawyer_for_case(id));
