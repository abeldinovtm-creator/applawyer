-- moderation_decline_stats — плоское представление поверх moderation_log,
-- которое (в отличие от таблицы) выполняется с правами владельца и поэтому
-- обходит RLS: без этой миграции его видел любой authenticated/anon
-- благодаря дефолтным grant'ам схемы public. Доступ должен быть только
-- через SQL Editor (роль postgres/service_role), как и задумывалось.
-- Применено 12.07.2026 через Supabase MCP сразу после обнаружения при
-- накатке 20260712_moderation_log_and_declines.sql.
REVOKE ALL ON public.moderation_decline_stats FROM anon, authenticated;
REVOKE ALL ON public.moderation_log FROM anon, authenticated;
