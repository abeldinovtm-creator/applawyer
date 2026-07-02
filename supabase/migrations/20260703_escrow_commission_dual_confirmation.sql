-- Комиссия платформы по категориям + двустороннее подтверждение завершения дела
-- Применить в: Supabase Dashboard → SQL Editor (миграция не применяется автоматически)
--
-- ПЕРЕД ПРИМЕНЕНИЕМ, ПРОВЕРИТЬ ВРУЧНУЮ:
-- 1. Существует ли уже permissive UPDATE-политика на cases для client_id = auth.uid()
--    (её существование объясняет, почему сегодня работают _closeOrder/_cancelOrder
--    в client_orders_screen.dart). Она не отслеживается в репозитории. Если она
--    отсутствует — client_confirmed_completion_at не получится записать, и это
--    надо решать отдельно, ДО применения этого файла.
-- 2. Полный список колонок cases (Table Editor → cases). Триггер
--    cases_guard_lawyer_column_scope ниже сравнивает NEW/OLD через to_jsonb() и
--    работает независимо от точного списка колонок, но стоит убедиться, что
--    в cases нет колонки, которая на каждый UPDATE трогается автоматически
--    (кроме предполагаемой updated_at, которую мы уже исключаем) — иначе
--    триггер будет ошибочно блокировать законные обновления юриста.
-- 3. Эта миграция заменяет собой 20260701_escrow_commission_DRAFT.sql
--    (черновик ни разу не применялся к базе — см. его заголовок). Рекомендуется
--    пометить черновик как superseded / удалить его из репозитория отдельным PR.

-- =====================================================================
-- 1. Комиссия по категориям
-- =====================================================================
CREATE TABLE IF NOT EXISTS commission_rates (
  category   TEXT PRIMARY KEY,
  percent    NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE commission_rates ENABLE ROW LEVEL SECURITY;

-- Читать могут все авторизованные (например, чтобы в будущем показать
-- юристу "комиссия платформы: X%" перед принятием заявки). Редактирование —
-- только вручную через SQL Editor (admin UI нет в этом раунде), поэтому
-- никаких INSERT/UPDATE policy для authenticated намеренно не создаём.
DROP POLICY IF EXISTS "commission_rates_select_all" ON commission_rates;
CREATE POLICY "commission_rates_select_all"
  ON commission_rates FOR SELECT
  TO authenticated
  USING (true);

-- Плейсхолдер 10% для всех категорий — ЗНАЧЕНИЯ НАДО ПОДКРУТИТЬ ВРУЧНУЮ
-- под реальную бизнес-модель. Список категорий взят из фактического кода
-- (main.dart CategorySelectionScreen, client_orders_screen.dart, lawyer_screen.dart
-- _trCategory) — НЕ из списка в CLAUDE.md, который устарел и не совпадает
-- со значениями, реально записываемыми в cases.category.
INSERT INTO commission_rates (category, percent) VALUES
  ('Составить или проверить договор', 10.00),
  ('Споры, суды и долги',              10.00),
  ('Трудовые споры',                   10.00),
  ('Семья, брак и развод',             10.00),
  ('Штрафы, налоги и госорганы',       10.00),
  ('Бизнес, ИП и ТОО',                 10.00),
  ('Земельные вопросы',                10.00),
  ('Долги и коллекторы',               10.00),
  ('Уголовные дела',                   10.00),
  ('Исполнение решения суда / ЧСИ',    10.00),
  ('Нотариальные услуги',              10.00),
  ('Другой вопрос',                    10.00)
ON CONFLICT (category) DO NOTHING;

-- =====================================================================
-- 2. Эскроу-счета (финализированная версия черновика 20260701)
-- =====================================================================
CREATE TABLE IF NOT EXISTS escrow_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL UNIQUE REFERENCES cases(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id),
  lawyer_id UUID NOT NULL REFERENCES profiles(id),
  amount NUMERIC(12, 2) NOT NULL,
  -- Процент комиссии подставляется триггером ниже из commission_rates
  -- по категории дела на момент принятия отклика (снимок, не "живая" ссылка —
  -- если потом изменить commission_rates, старые эскроу-счета не пересчитаются).
  commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  commission_amount NUMERIC(12, 2) GENERATED ALWAYS AS (amount * commission_percent / 100) STORED,
  payout_amount NUMERIC(12, 2) GENERATED ALWAYS AS (amount - amount * commission_percent / 100) STORED,
  -- pending: создан, реальной оплаты через Kaspi Pay ещё нет (Kaspi не подключён)
  -- held: TODO(kaspi) — деньги реально захолдированы через Kaspi Pay (пока не используется)
  -- released: обе стороны подтвердили завершение, выплата (бухгалтерски) проведена
  -- refunded: возврат клиенту (не реализовано в этом раунде)
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'held', 'released', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_escrow_accounts_case ON escrow_accounts(case_id);
CREATE INDEX IF NOT EXISTS idx_escrow_accounts_lawyer ON escrow_accounts(lawyer_id);
CREATE INDEX IF NOT EXISTS idx_escrow_accounts_client ON escrow_accounts(client_id);

ALTER TABLE escrow_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "escrow_select_own" ON escrow_accounts;
CREATE POLICY "escrow_select_own"
  ON escrow_accounts FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = lawyer_id);

-- Как и в черновике: явных INSERT/UPDATE policy для authenticated нет.
-- Запись идёт только из SECURITY DEFINER триггерных функций ниже.

CREATE TABLE IF NOT EXISTS escrow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  escrow_account_id UUID NOT NULL REFERENCES escrow_accounts(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'release', 'refund', 'commission')),
  amount NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE escrow_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "escrow_transactions_select_own" ON escrow_transactions;
CREATE POLICY "escrow_transactions_select_own"
  ON escrow_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM escrow_accounts ea
      WHERE ea.id = escrow_account_id
        AND (auth.uid() = ea.client_id OR auth.uid() = ea.lawyer_id)
    )
  );

-- =====================================================================
-- 3. Триггер: юрист принят клиентом → создаём эскроу-счёт
-- =====================================================================
CREATE OR REPLACE FUNCTION conversations_create_escrow_on_accept()
RETURNS TRIGGER AS $$
DECLARE
  v_case cases%ROWTYPE;
  v_amount NUMERIC(12, 2);
  v_percent NUMERIC(5, 2);
BEGIN
  SELECT * INTO v_case FROM cases WHERE id = NEW.case_id;
  IF NOT FOUND THEN
    RETURN NEW; -- дело не найдено — не должно происходить, но не блокируем принятие
  END IF;

  -- Сумма берётся из цены самого отклика (conversations), а НЕ из cases.budget —
  -- юрист мог предложить свою цену вместо бюджета клиента (см. _sendResponse
  -- в lawyer_screen.dart, чекбокс "Принять цену клиента").
  v_amount := COALESCE(NEW.price_prepayment, 0)
            + COALESCE(NEW.price_on_completion, 0)
            + COALESCE(NEW.price_on_result, 0);

  SELECT percent INTO v_percent FROM commission_rates WHERE category = v_case.category;
  IF NOT FOUND THEN
    v_percent := 10.00; -- запасной процент, если категория не найдена в справочнике
  END IF;

  INSERT INTO escrow_accounts (case_id, client_id, lawyer_id, amount, commission_percent)
  VALUES (NEW.case_id, v_case.client_id, NEW.lawyer_id, v_amount, v_percent)
  ON CONFLICT (case_id) DO NOTHING; -- защита от повторного срабатывания / гонки

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- SECURITY DEFINER обязателен: на escrow_accounts нет INSERT-политики для
-- authenticated (по замыслу), иначе принятие отклика клиентом будет падать
-- с ошибкой RLS.

DROP TRIGGER IF EXISTS on_conversation_accepted_create_escrow ON conversations;
CREATE TRIGGER on_conversation_accepted_create_escrow
  AFTER UPDATE OF status ON conversations
  FOR EACH ROW
  WHEN (NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION conversations_create_escrow_on_accept();

-- =====================================================================
-- 4. Колонки подтверждения завершения на cases
-- =====================================================================
ALTER TABLE cases ADD COLUMN IF NOT EXISTS client_confirmed_completion_at TIMESTAMPTZ;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS lawyer_confirmed_completion_at TIMESTAMPTZ;

-- =====================================================================
-- 5. Guard A: подтверждение может выставить только своя сторона,
--    и только один раз (NULL -> now(), назад не откатывается)
-- =====================================================================
CREATE OR REPLACE FUNCTION cases_guard_completion_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.client_confirmed_completion_at IS DISTINCT FROM OLD.client_confirmed_completion_at THEN
    IF OLD.client_confirmed_completion_at IS NOT NULL THEN
      RAISE EXCEPTION 'client_confirmed_completion_at уже установлен и не может быть изменён';
    END IF;
    IF auth.uid() IS DISTINCT FROM NEW.client_id THEN
      RAISE EXCEPTION 'Только клиент этого дела может подтвердить его завершение';
    END IF;
    -- Не доверяем значению от клиента (может прислать любую дату) — фиксируем сами.
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

DROP TRIGGER IF EXISTS cases_guard_completion_columns_trg ON cases;
CREATE TRIGGER cases_guard_completion_columns_trg
  BEFORE UPDATE OF client_confirmed_completion_at, lawyer_confirmed_completion_at ON cases
  FOR EACH ROW EXECUTE FUNCTION cases_guard_completion_columns();

-- =====================================================================
-- 6. Guard B: status = 'completed' можно выставить только изнутри
--    релиз-триггера (п.8), не напрямую клиентом/юристом
-- =====================================================================
CREATE OR REPLACE FUNCTION cases_guard_status_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed'
     AND OLD.status IS DISTINCT FROM NEW.status
     AND pg_trigger_depth() <= 1 THEN
    -- depth = 1 означает, что UPDATE вызван напрямую (top-level), а не
    -- каскадно из другого триггера (release-триггер ниже вызывает вложенный
    -- UPDATE, который увидит depth = 2 и пройдёт).
    RAISE EXCEPTION 'cases.status нельзя перевести в completed напрямую — только через двойное подтверждение';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cases_guard_status_completed_trg ON cases;
CREATE TRIGGER cases_guard_status_completed_trg
  BEFORE UPDATE OF status ON cases
  FOR EACH ROW EXECUTE FUNCTION cases_guard_status_completed();

-- =====================================================================
-- 7. Guard C: у принятого юриста нет RLS-политики на cases сегодня.
--    Добавляем permissive UPDATE-политику, дающую юристу доступ к строке,
--    и универсальный триггер, ограничивающий его ТОЛЬКО колонкой
--    lawyer_confirmed_completion_at (RLS не умеет ограничивать по колонкам).
-- =====================================================================
DROP POLICY IF EXISTS "lawyer_confirm_completion" ON cases;
CREATE POLICY "lawyer_confirm_completion"
  ON cases FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE case_id = cases.id AND lawyer_id = auth.uid() AND status = 'accepted'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE case_id = cases.id AND lawyer_id = auth.uid() AND status = 'accepted'
    )
  );
-- Это permissive-политика — она OR-комбинируется с уже существующей (не
-- отслеживаемой в репозитории) UPDATE-политикой клиента на cases. Именно
-- поэтому колонки НАДО дополнительно ограничить триггером ниже: сама по себе
-- RLS не различает "юрист меняет lawyer_confirmed_completion_at" от
-- "юрист меняет title/budget/client_id/...".

CREATE OR REPLACE FUNCTION cases_guard_lawyer_column_scope()
RETURNS TRIGGER AS $$
DECLARE
  v_is_accepted_lawyer BOOLEAN;
BEGIN
  -- Вложенный вызов (например, из release-триггера, депth > 1) уже прошёл
  -- свои проверки — не вмешиваемся.
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  -- Владелец заявки (клиент) может редактировать её как раньше —
  -- ограничений на набор колонок для него не вводим.
  IF auth.uid() = OLD.client_id THEN
    RETURN NEW;
  END IF;

  v_is_accepted_lawyer := EXISTS (
    SELECT 1 FROM conversations
    WHERE case_id = OLD.id AND lawyer_id = auth.uid() AND status = 'accepted'
  );

  IF v_is_accepted_lawyer THEN
    -- Сравниваем весь остальной набор колонок через to_jsonb(), исключая
    -- lawyer_confirmed_completion_at (разрешённая колонка) и updated_at
    -- (если она есть и трогается автоматически). Это устойчиво к тому, что
    -- полная схема cases не задокументирована в репозитории.
    IF (to_jsonb(NEW) - 'lawyer_confirmed_completion_at' - 'updated_at')
       IS DISTINCT FROM
       (to_jsonb(OLD) - 'lawyer_confirmed_completion_at' - 'updated_at') THEN
      RAISE EXCEPTION 'Юрист может изменять только lawyer_confirmed_completion_at в этом деле';
    END IF;
    RETURN NEW;
  END IF;

  -- Ни владелец, ни принятый юрист — RLS должна была отсечь это раньше,
  -- но дублируем проверку на уровне триггера для надёжности.
  RAISE EXCEPTION 'Недостаточно прав для изменения этой заявки';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS cases_guard_lawyer_column_scope_trg ON cases;
CREATE TRIGGER cases_guard_lawyer_column_scope_trg
  BEFORE UPDATE ON cases
  FOR EACH ROW EXECUTE FUNCTION cases_guard_lawyer_column_scope();

-- =====================================================================
-- 8. Релиз: обе стороны подтвердили → completed + эскроу released + проводки
-- =====================================================================
CREATE OR REPLACE FUNCTION cases_release_on_dual_confirmation()
RETURNS TRIGGER AS $$
DECLARE
  v_escrow escrow_accounts%ROWTYPE;
BEGIN
  IF NEW.client_confirmed_completion_at IS NULL OR NEW.lawyer_confirmed_completion_at IS NULL THEN
    RETURN NEW; -- защитная проверка, WHEN-условие триггера уже это гарантирует
  END IF;

  -- Вложенный UPDATE (depth > 1) — пройдёт guard B (cases_guard_status_completed).
  UPDATE cases SET status = 'completed' WHERE id = NEW.id AND status <> 'completed';

  SELECT * INTO v_escrow FROM escrow_accounts WHERE case_id = NEW.id;
  IF NOT FOUND THEN
    -- Намеренно НЕ глушим ошибку (в отличие от push-триггеров) — если
    -- эскроу-счёта нет, значит где-то раньше сломалась бухгалтерия, и лучше
    -- откатить это подтверждение и показать пользователю ошибку, чем молча
    -- закрыть дело без учёта денег.
    RAISE EXCEPTION 'Эскроу-счёт для дела % не найден — подтверждение отменено', NEW.id;
  END IF;

  IF v_escrow.status = 'released' THEN
    RETURN NEW; -- уже проведено (защита от повторного срабатывания)
  END IF;

  -- TODO(kaspi): когда появится реальная оплата через Kaspi Pay, здесь нужно
  -- проверять v_escrow.status = 'held' (деньги реально захолдированы Kaspi'ом
  -- по вебхуку) и НЕ переводить в released, если оплата не подтверждена.
  -- Сейчас статус идёт pending -> released напрямую, т.к. реального
  -- списания денег в этом раунде ещё нет (Kaspi не подключён).
  UPDATE escrow_accounts
    SET status = 'released', updated_at = now()
    WHERE id = v_escrow.id;

  INSERT INTO escrow_transactions (escrow_account_id, type, amount) VALUES
    (v_escrow.id, 'release', v_escrow.payout_amount),
    (v_escrow.id, 'commission', v_escrow.commission_amount);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS cases_release_on_dual_confirmation_trg ON cases;
CREATE TRIGGER cases_release_on_dual_confirmation_trg
  AFTER UPDATE OF client_confirmed_completion_at, lawyer_confirmed_completion_at ON cases
  FOR EACH ROW
  WHEN (
    NEW.client_confirmed_completion_at IS NOT NULL
    AND NEW.lawyer_confirmed_completion_at IS NOT NULL
    AND (OLD.client_confirmed_completion_at IS NULL OR OLD.lawyer_confirmed_completion_at IS NULL)
  )
  EXECUTE FUNCTION cases_release_on_dual_confirmation();
