-- ЧЕРНОВИК СХЕМЫ — НЕ ПРИМЕНЯТЬ АВТОМАТИЧЕСКИ
--
-- Предложение схемы для новой бизнес-модели: оплата через эскроу-счёт
-- с удержанием комиссии платформы за завершённые дела.
-- Требует ревью (расчёт комиссии, кто и как переводит деньги в эскроу,
-- интеграция с платёжным провайдером в Казахстане) перед применением.
-- Ничего из этого не применялось к базе данных — файл только для обсуждения.

-- 1. Эскроу-счёт по заявке (case). Клиент вносит деньги, они "замораживаются"
--    до подтверждения завершения работы, затем переводятся юристу за вычетом комиссии.
CREATE TABLE IF NOT EXISTS escrow_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id),
  lawyer_id UUID NOT NULL REFERENCES profiles(id),
  amount NUMERIC(12, 2) NOT NULL,
  commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  commission_amount NUMERIC(12, 2) GENERATED ALWAYS AS (amount * commission_percent / 100) STORED,
  payout_amount NUMERIC(12, 2) GENERATED ALWAYS AS (amount - amount * commission_percent / 100) STORED,
  -- pending: клиент ещё не оплатил
  -- held: деньги внесены и заморожены на эскроу
  -- released: дело завершено, деньги (за вычетом комиссии) переведены юристу
  -- refunded: возврат клиенту (например, при отмене заявки)
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'held', 'released', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_escrow_accounts_case ON escrow_accounts(case_id);
CREATE INDEX IF NOT EXISTS idx_escrow_accounts_lawyer ON escrow_accounts(lawyer_id);
CREATE INDEX IF NOT EXISTS idx_escrow_accounts_client ON escrow_accounts(client_id);

ALTER TABLE escrow_accounts ENABLE ROW LEVEL SECURITY;

-- Клиент и юрист видят только свои эскроу-счета
CREATE POLICY "escrow_select_own"
  ON escrow_accounts FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = lawyer_id);

-- Изменять статус эскроу (held/released/refunded) должен только бэкенд
-- (Edge Function с service_role — например, после вебхука от платёжного провайдера),
-- НЕ напрямую клиент/юрист через RLS.
-- Явных INSERT/UPDATE policy для anon/authenticated намеренно не создаём.

-- 2. История операций по эскроу-счёту (для истории/статистики)
CREATE TABLE IF NOT EXISTS escrow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  escrow_account_id UUID NOT NULL REFERENCES escrow_accounts(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'release', 'refund', 'commission')),
  amount NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE escrow_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "escrow_transactions_select_own"
  ON escrow_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM escrow_accounts ea
      WHERE ea.id = escrow_account_id
        AND (auth.uid() = ea.client_id OR auth.uid() = ea.lawyer_id)
    )
  );

-- ОТКРЫТЫЕ ВОПРОСЫ ДЛЯ ОБСУЖДЕНИЯ:
-- - какой платёжный провайдер держит реальные деньги в РК (Kaspi, банк-эквайер)?
-- - процент комиссии — фиксированный или зависит от категории/подтипа юриста?
-- - что считать "завершённым делом" для списания комиссии: cases.status = 'completed'
--   (client_orders_screen.dart._closeOrder) или отдельное подтверждение обеих сторон?
-- - нужен ли отдельный экран истории выплат для юриста и клиента?
