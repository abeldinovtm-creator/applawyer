-- Счётчик отмен принятых дел для раздела "Статистика" юриста.
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- "Отменено" = дело было принято (conversations.status = accepted), но потом
-- кто-то из сторон отказался через client_decline_lawyer/lawyer_decline_case
-- (20260712_moderation_log_and_declines.sql) — считаем оба направления отказа
-- одинаково, т.к. для юриста важен сам факт срыва уже начатой работы,
-- а не кто именно инициировал отказ.
--
-- moderation_log не содержит lawyer_id напрямую — определяем юриста через
-- JOIN на conversations по conversation_id (та самая беседа, которую отказ
-- перевёл в status='rejected'). Без параметра, всегда auth.uid() — как и
-- get_lawyer_earnings_stats (20260726_lawyer_earnings_stats.sql), чтобы один
-- юрист не мог узнать число отмен другого через API.
CREATE OR REPLACE FUNCTION public.get_lawyer_cancellation_count()
RETURNS BIGINT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT count(*)
  FROM public.moderation_log m
  JOIN public.conversations c ON c.id = m.conversation_id
  WHERE c.lawyer_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_lawyer_cancellation_count() TO authenticated;
