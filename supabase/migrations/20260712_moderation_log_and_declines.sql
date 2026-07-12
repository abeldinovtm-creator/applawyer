-- Отказ от юриста (клиент) / от заявки (юрист) после принятия отклика,
-- но до завершения дела. Оба действия обязаны указать причину и логируются
-- в moderation_log — для ручного разбора злоупотреблений (частые немотивированные
-- отказы одной стороны), без автоматической блокировки.
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- ПЕРЕД ПРИМЕНЕНИЕМ, ПРОВЕРИТЬ ВРУЧНУЮ:
-- 1. Эта миграция впервые заставляет cases.status реально переходить в
--    'closed' при принятии отклика (сейчас status всегда остаётся 'open' до
--    completed — лента заявок для юристов ленты сегодня НЕ фильтрует по
--    status вообще, см. _refreshCases в lawyer_screen.dart, который эта
--    миграция дополняет фильтром .eq('status','open') на клиенте). Без этого
--    фильтра "заявка снова видна другим юристам" после отказа не имело бы
--    смысла — сегодня она и так всегда видна.
-- 2. cases_status_check уже разрешает 'closed' (см. 20260704_fix_cases_status_check.sql) —
--    ALTER CONSTRAINT не нужен.

-- =====================================================================
-- 1. moderation_log — только для ручного разбора через SQL Editor.
--    Никаких SELECT/INSERT policy для authenticated намеренно не создаём:
--    запись идёт исключительно из SECURITY DEFINER функций ниже (роль
--    выполнения обходит RLS так же, как это уже сделано для escrow_accounts).
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.moderation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
  actor_id UUID NOT NULL REFERENCES public.profiles(id),
  actor_role TEXT NOT NULL CHECK (actor_role IN ('client', 'lawyer')),
  action TEXT NOT NULL CHECK (action IN ('client_declined_lawyer', 'lawyer_declined_case')),
  reason_code TEXT NOT NULL,
  reason_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS moderation_log_actor_idx ON public.moderation_log(actor_id);
CREATE INDEX IF NOT EXISTS moderation_log_case_idx ON public.moderation_log(case_id);

ALTER TABLE public.moderation_log ENABLE ROW LEVEL SECURITY;

-- Агрегат для ручного разбора («частые отказы одного юриста/клиента») —
-- смотреть через SQL Editor (обходит RLS как владелец), в приложении не используется.
CREATE OR REPLACE VIEW public.moderation_decline_stats AS
SELECT
  actor_id,
  actor_role,
  action,
  count(*) AS decline_count,
  count(*) FILTER (WHERE reason_code = 'other') AS other_reason_count,
  max(created_at) AS last_decline_at
FROM public.moderation_log
GROUP BY actor_id, actor_role, action;

-- =====================================================================
-- 2. При принятии отклика заявка перестаёт быть видна другим юристам
--    (status: open -> closed). Дополняет уже существующий триггер создания
--    эскроу-счёта (conversations_create_escrow_on_accept), не заменяет его.
-- =====================================================================
CREATE OR REPLACE FUNCTION conversations_close_case_on_accept()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE cases SET status = 'closed' WHERE id = NEW.case_id AND status = 'open';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_conversation_accepted_close_case ON conversations;
CREATE TRIGGER on_conversation_accepted_close_case
  AFTER UPDATE OF status ON conversations
  FOR EACH ROW
  WHEN (NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM 'accepted')
  EXECUTE FUNCTION conversations_close_case_on_accept();

-- =====================================================================
-- 3. Guard на cases (cases_guard_completion_columns, см. 20260703_...)
--    не даёт откатить client/lawyer_confirmed_completion_at обратно в NULL —
--    это верно для обычных пользователей, но отказ обязан сбросить оба
--    подтверждения (дело "начинается заново" с чистого листа для следующего
--    юриста). Даём функциям отказа легитимный обход через transaction-local
--    GUC, не трогая обычный путь пользовательских UPDATE.
-- =====================================================================
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

-- =====================================================================
-- 4. Клиент отказывается от принятого юриста.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.client_decline_lawyer(
  p_case_id UUID,
  p_reason_code TEXT,
  p_reason_text TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case cases%ROWTYPE;
  v_conv conversations%ROWTYPE;
BEGIN
  IF p_reason_code NOT IN ('not_responding', 'price_disagreement', 'changed_mind', 'other') THEN
    RAISE EXCEPTION 'Некорректная причина отказа: %', p_reason_code;
  END IF;

  SELECT * INTO v_case FROM cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Заявка не найдена';
  END IF;
  IF v_case.client_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Только клиент этой заявки может отказаться от юриста';
  END IF;
  IF v_case.status = 'completed' THEN
    RAISE EXCEPTION 'Дело уже завершено — отказ невозможен';
  END IF;
  IF v_case.client_confirmed_completion_at IS NOT NULL THEN
    RAISE EXCEPTION 'Вы уже подтвердили завершение дела — отказ невозможен';
  END IF;

  SELECT * INTO v_conv FROM conversations
    WHERE case_id = p_case_id AND status = 'accepted'
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'По этой заявке нет принятого юриста';
  END IF;

  UPDATE conversations SET status = 'rejected' WHERE id = v_conv.id;

  PERFORM set_config('app.bypass_completion_guard', 'true', true);
  UPDATE cases SET
    status = 'open',
    client_confirmed_completion_at = NULL,
    lawyer_confirmed_completion_at = NULL
  WHERE id = p_case_id;

  -- Реальных денег в эскроу пока нет (Kaspi не подключён, статус всегда
  -- 'pending' до релиза) — просто убираем счёт, чтобы освободить
  -- case_id UNIQUE для эскроу-счёта следующего принятого юриста.
  DELETE FROM escrow_accounts WHERE case_id = p_case_id AND status = 'pending';

  INSERT INTO moderation_log (case_id, conversation_id, actor_id, actor_role, action, reason_code, reason_text)
  VALUES (p_case_id, v_conv.id, auth.uid(), 'client', 'client_declined_lawyer', p_reason_code, p_reason_text);
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_decline_lawyer(UUID, TEXT, TEXT) TO authenticated;

-- =====================================================================
-- 5. Юрист отказывается от принятой заявки.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.lawyer_decline_case(
  p_case_id UUID,
  p_reason_code TEXT,
  p_reason_text TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case cases%ROWTYPE;
  v_conv conversations%ROWTYPE;
BEGIN
  IF p_reason_code NOT IN ('not_my_specialization', 'conflict_of_interest', 'client_unresponsive', 'other') THEN
    RAISE EXCEPTION 'Некорректная причина отказа: %', p_reason_code;
  END IF;

  SELECT * INTO v_conv FROM conversations
    WHERE case_id = p_case_id AND lawyer_id = auth.uid() AND status = 'accepted'
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Вы не являетесь принятым юристом по этой заявке';
  END IF;

  SELECT * INTO v_case FROM cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Заявка не найдена';
  END IF;
  IF v_case.status = 'completed' THEN
    RAISE EXCEPTION 'Дело уже завершено — отказ невозможен';
  END IF;
  IF v_case.lawyer_confirmed_completion_at IS NOT NULL THEN
    RAISE EXCEPTION 'Вы уже подтвердили завершение дела — отказ невозможен';
  END IF;

  UPDATE conversations SET status = 'rejected' WHERE id = v_conv.id;

  PERFORM set_config('app.bypass_completion_guard', 'true', true);
  UPDATE cases SET
    status = 'open',
    client_confirmed_completion_at = NULL,
    lawyer_confirmed_completion_at = NULL
  WHERE id = p_case_id;

  DELETE FROM escrow_accounts WHERE case_id = p_case_id AND status = 'pending';

  INSERT INTO moderation_log (case_id, conversation_id, actor_id, actor_role, action, reason_code, reason_text)
  VALUES (p_case_id, v_conv.id, auth.uid(), 'lawyer', 'lawyer_declined_case', p_reason_code, p_reason_text);
END;
$$;

GRANT EXECUTE ON FUNCTION public.lawyer_decline_case(UUID, TEXT, TEXT) TO authenticated;
