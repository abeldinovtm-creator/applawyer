-- Отзывы клиента на юриста после завершения дела.
-- Один отзыв на одно завершённое дело (case_id UNIQUE), необязателен,
-- виден публично всем авторизованным пользователям (в профиле юриста).

CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL UNIQUE REFERENCES public.cases(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.profiles(id),
  lawyer_id UUID NOT NULL REFERENCES public.profiles(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reviews_lawyer_id_idx ON public.reviews(lawyer_id);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- SECURITY DEFINER, т.к. проверка идёт через cases + escrow_accounts —
-- та же схема, что уже используется в get_unread_counts(), чтобы обойти
-- потенциальную рекурсию RLS между cases/conversations
-- (см. 20260704_fix_cases_rls_recursion.sql).
CREATE OR REPLACE FUNCTION public.can_review_case(p_case_id UUID, p_lawyer_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.cases c
    JOIN public.escrow_accounts e ON e.case_id = c.id
    WHERE c.id = p_case_id
      AND c.status = 'completed'
      AND e.client_id = auth.uid()
      AND e.lawyer_id = p_lawyer_id
  );
$$;

-- Отзывы публичны внутри приложения (профиль юриста виден всем клиентам).
CREATE POLICY "Отзывы видны всем авторизованным"
  ON public.reviews FOR SELECT
  TO authenticated
  USING (true);

-- Оставить отзыв может только клиент завершённого дела, один раз (UNIQUE case_id).
-- Изменять/удалять отзыв нельзя — сознательное ограничение MVP.
CREATE POLICY "Клиент оставляет отзыв на завершённое дело"
  ON public.reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid()
    AND public.can_review_case(case_id, lawyer_id)
  );
