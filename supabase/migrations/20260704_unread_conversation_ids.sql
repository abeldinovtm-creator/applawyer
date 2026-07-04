-- RPC для точечного индикатора непрочитанного — какие именно беседы/заявки
-- содержат непрочитанные сообщения, а не только агрегированный счётчик
-- (get_unread_counts). Нужно, чтобы подсветить конкретную карточку в
-- "Мои заявки" / "Отклики" / "Мои отклики", а не заставлять пользователя
-- перебирать все чаты вручную.
CREATE OR REPLACE FUNCTION get_unread_conversation_ids()
RETURNS TABLE(conversation_id UUID, case_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT c.id, c.case_id
  FROM messages m
  JOIN conversations c ON c.id = m.conversation_id
  LEFT JOIN cases cs ON cs.id = c.case_id
  LEFT JOIN conversation_reads cr ON cr.conversation_id = c.id AND cr.user_id = v_uid
  WHERE m.sender_id != v_uid
    AND (c.lawyer_id = v_uid OR cs.client_id = v_uid)
    AND m.created_at > COALESCE(cr.last_read_at, '-infinity'::timestamptz);
END;
$$;

GRANT EXECUTE ON FUNCTION get_unread_conversation_ids() TO authenticated;
