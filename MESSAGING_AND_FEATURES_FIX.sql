-- Aurem World messaging repair. Additive: preserves existing conversations and messages.
-- Existing schema expected: conversations(id,user_a,user_b), messages(id,conversation_id,sender_id,body,created_at).

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversation participants read" ON public.conversations;
CREATE POLICY "conversation participants read" ON public.conversations
FOR SELECT TO authenticated
USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "conversation participants create" ON public.conversations;
CREATE POLICY "conversation participants create" ON public.conversations
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "message participants read" ON public.messages;
CREATE POLICY "message participants read" ON public.messages
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND auth.uid() IN (c.user_a,c.user_b)));

DROP POLICY IF EXISTS "message participants send" ON public.messages;
CREATE POLICY "message participants send" ON public.messages
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND auth.uid() IN (c.user_a,c.user_b)));

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE result_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Please sign in first'; END IF;
  IF other_user_id IS NULL OR other_user_id = auth.uid() THEN RAISE EXCEPTION 'Invalid recipient'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = other_user_id) THEN RAISE EXCEPTION 'User not found'; END IF;
  SELECT id INTO result_id FROM public.conversations
  WHERE (user_a = auth.uid() AND user_b = other_user_id)
     OR (user_a = other_user_id AND user_b = auth.uid())
  LIMIT 1;
  IF result_id IS NULL THEN
    INSERT INTO public.conversations(user_a,user_b)
    VALUES(auth.uid(),other_user_id) RETURNING id INTO result_id;
  END IF;
  RETURN result_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
