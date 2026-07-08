-- Ежемесячный лимит бесплатных откликов юриста: 20 в первый месяц
-- использования, затем по 3 в каждый последующий месяц.
--
-- profiles.contacts_left уже существовал в БД (default 20), но не был нигде
-- подключён к коду (ни в lib/, ни в предыдущих миграциях) — переиспользуем
-- его как "остаток бесплатных откликов в текущем периоде" и добавляем
-- недостающее отслеживание периода.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS contacts_period_reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 month');

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS contacts_period_is_first BOOLEAN NOT NULL DEFAULT true;

-- Списывает один бесплатный отклик у юриста, при необходимости сначала
-- переводя счётчик в новый месячный период (первый период — 20, далее — 3).
-- Возвращает true, если отклик разрешён (и уже списан), false — если лимит
-- на этот период исчерпан.
CREATE OR REPLACE FUNCTION consume_free_contact(p_lawyer_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_profile profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_lawyer_id THEN
    RAISE EXCEPTION 'Можно списывать отклики только со своего профиля';
  END IF;

  SELECT * INTO v_profile FROM profiles WHERE id = p_lawyer_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Профиль % не найден', p_lawyer_id;
  END IF;

  IF now() >= v_profile.contacts_period_reset_at THEN
    UPDATE profiles SET
      contacts_left = 3,
      contacts_period_is_first = false,
      contacts_period_reset_at = now() + interval '1 month'
    WHERE id = p_lawyer_id
    RETURNING * INTO v_profile;
  END IF;

  IF v_profile.contacts_left <= 0 THEN
    RETURN false;
  END IF;

  UPDATE profiles SET contacts_left = contacts_left - 1 WHERE id = p_lawyer_id;
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- SECURITY DEFINER нужен, чтобы функция могла UPDATE-ить profiles без
-- отдельной RLS-политики на эту операцию для authenticated; проверка
-- auth.uid() = p_lawyer_id внутри функции — единственная авторизационная
-- граница вместо RLS.

GRANT EXECUTE ON FUNCTION consume_free_contact(UUID) TO authenticated;
