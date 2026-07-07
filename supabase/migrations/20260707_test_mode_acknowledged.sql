-- Согласие пользователя на тестовый режим — показывается один раз диалогом
-- при первой регистрации (чекбокс "Понятно, не буду загружать реальные документы").
-- Отдельной RLS-политики не нужно: существующая users_update_own_profile
-- (auth.uid() = id) уже покрывает все колонки профиля, включая эту.
ALTER TABLE public.profiles
  ADD COLUMN test_mode_acknowledged BOOLEAN NOT NULL DEFAULT false;
