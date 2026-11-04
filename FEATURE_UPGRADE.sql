-- AUREM WORLD FEATURE UPGRADE
-- Run once in Supabase Dashboard > SQL Editor.
-- This migration adds messaging, voice notes, suggestions, reshares,
-- presence and admin metrics. It does not change existing posts or follows.

-- Direct conversations (one row per pair of users).
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conversations_distinct_users CHECK (user_a <> user_b),
  CONSTRAINT conversations_pair_unique UNIQUE (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL DEFAULT '',
  message_type text NOT NULL DEFAULT 'text' CHECK (message_type IN ('text','voice')),
  media_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_path text;
CREATE INDEX IF NOT EXISTS messages_conversation_created_idx ON public.messages(conversation_id, created_at);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "conversation participants read" ON public.conversations;
CREATE POLICY "conversation participants read" ON public.conversations FOR SELECT TO authenticated
USING (auth.uid() = user_a OR auth.uid() = user_b);
DROP POLICY IF EXISTS "conversation participants create" ON public.conversations;
CREATE POLICY "conversation participants create" ON public.conversations FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_a OR auth.uid() = user_b);
DROP POLICY IF EXISTS "message participants read" ON public.messages;
CREATE POLICY "message participants read" ON public.messages FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND auth.uid() IN (c.user_a,c.user_b)));
DROP POLICY IF EXISTS "participants send messages as self" ON public.messages;
CREATE POLICY "participants send messages as self" ON public.messages FOR INSERT TO authenticated
WITH CHECK (sender_id = auth.uid() AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND auth.uid() IN (c.user_a,c.user_b)));

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(other_user_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a uuid; b uuid; conversation_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF other_user_id IS NULL OR other_user_id = auth.uid() THEN RAISE EXCEPTION 'Choose another user'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = other_user_id) THEN RAISE EXCEPTION 'User not found'; END IF;
  a := LEAST(auth.uid(), other_user_id); b := GREATEST(auth.uid(), other_user_id);
  INSERT INTO public.conversations(user_a,user_b) VALUES(a,b)
  ON CONFLICT(user_a,user_b) DO UPDATE SET user_a = EXCLUDED.user_a
  RETURNING id INTO conversation_id;
  RETURN conversation_id;
END $$;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid) TO authenticated;

-- Voice-note storage. Files are private; participants receive signed URLs through the app.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('voice-notes','voice-notes',false,15728640,ARRAY['audio/webm','audio/ogg','audio/mp4','audio/mpeg'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=15728640,allowed_mime_types=EXCLUDED.allowed_mime_types;
DROP POLICY IF EXISTS "users upload own voice notes" ON storage.objects;
CREATE POLICY "users upload own voice notes" ON storage.objects FOR INSERT TO authenticated
WITH CHECK(bucket_id='voice-notes' AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS "conversation members read voice notes" ON storage.objects;
CREATE POLICY "conversation members read voice notes" ON storage.objects FOR SELECT TO authenticated
USING(bucket_id='voice-notes' AND (storage.foldername(name))[1]=auth.uid()::text);
-- Note: private voice-note URLs need signed access for the other participant.
-- This version stores voice files in a private bucket; the next app build should
-- request signed URLs through a trusted server/RPC before sharing across users.

-- User suggestions.
CREATE TABLE IF NOT EXISTS public.suggestions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 suggestion text NOT NULL CHECK (char_length(suggestion) BETWEEN 3 AND 1200),
 status text NOT NULL DEFAULT 'received' CHECK(status IN ('received','reviewing','planned','completed','declined')),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users submit suggestions" ON public.suggestions;
CREATE POLICY "users submit suggestions" ON public.suggestions FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid());
DROP POLICY IF EXISTS "users read own suggestions" ON public.suggestions;
CREATE POLICY "users read own suggestions" ON public.suggestions FOR SELECT TO authenticated USING(user_id=auth.uid());
DROP POLICY IF EXISTS "admin reads suggestions" ON public.suggestions;
CREATE POLICY "admin reads suggestions" ON public.suggestions FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND lower(p.username)='anonymous_001'));

-- Reshares reference the original post; they never duplicate or transfer ownership.
CREATE TABLE IF NOT EXISTS public.reshares(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 original_post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,original_post_id),
 CHECK(user_id <> (SELECT user_id FROM public.posts WHERE id=original_post_id))
);
ALTER TABLE public.reshares ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reshares readable" ON public.reshares;
CREATE POLICY "public reshares readable" ON public.reshares FOR SELECT USING(true);
DROP POLICY IF EXISTS "users create own reshares" ON public.reshares;
CREATE POLICY "users create own reshares" ON public.reshares FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid());
DROP POLICY IF EXISTS "users remove own reshares" ON public.reshares;
CREATE POLICY "users remove own reshares" ON public.reshares FOR DELETE TO authenticated USING(user_id=auth.uid());

-- Presence. Active is defined as last seen within five minutes.
CREATE TABLE IF NOT EXISTS public.user_presence(
 user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
 last_seen_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users update own presence" ON public.user_presence;
CREATE POLICY "users update own presence" ON public.user_presence FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid());
DROP POLICY IF EXISTS "users refresh own presence" ON public.user_presence;
CREATE POLICY "users refresh own presence" ON public.user_presence FOR UPDATE TO authenticated USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());

-- Chat streak counts consecutive calendar days on which BOTH participants sent a message.
CREATE OR REPLACE FUNCTION public.get_chat_streak(conversation_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a uuid; b uuid; streak integer; latest_day date;
BEGIN
 SELECT user_a,user_b INTO a,b FROM public.conversations
 WHERE id=conversation_id AND auth.uid() IN (user_a,user_b);
 IF a IS NULL THEN RAISE EXCEPTION 'Conversation not found'; END IF;
 WITH daily AS (
  SELECT (created_at AT TIME ZONE 'UTC')::date AS day,
         count(DISTINCT sender_id) FILTER(WHERE sender_id IN (a,b)) AS participants
  FROM public.messages WHERE conversation_id=get_chat_streak.conversation_id
  GROUP BY 1 HAVING count(DISTINCT sender_id) FILTER(WHERE sender_id IN (a,b))=2
 ), ordered AS (
  SELECT day, day - (row_number() OVER(ORDER BY day))::int AS grp FROM daily
 ), latest AS (SELECT max(day) AS d FROM daily)
 SELECT d INTO latest_day FROM latest;
 IF latest_day IS NULL OR latest_day < (now() AT TIME ZONE 'UTC')::date - 1 THEN RETURN 0; END IF;
 SELECT count(*) INTO streak FROM ordered WHERE grp=(SELECT grp FROM ordered WHERE day=latest_day);
 RETURN COALESCE(streak,0);
END $$;
GRANT EXECUTE ON FUNCTION public.get_chat_streak(uuid) TO authenticated;

-- Admin-only aggregate metrics. No user emails or private message content are exposed.
CREATE OR REPLACE FUNCTION public.admin_recent_suggestions()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE result json;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND lower(username)='anonymous_001') THEN RAISE EXCEPTION 'Admin access required'; END IF;
 SELECT COALESCE(json_agg(x),'[]'::json) INTO result FROM (SELECT s.id,s.suggestion,s.status,s.created_at,p.username FROM public.suggestions s JOIN public.profiles p ON p.id=s.user_id ORDER BY s.created_at DESC LIMIT 30) x;
 RETURN result;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_recent_suggestions() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_user_metrics()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE result json;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND lower(username)='anonymous_001') THEN
  RAISE EXCEPTION 'Admin access required';
 END IF;
 SELECT json_build_object(
  'total_users',(SELECT count(*) FROM public.profiles),
  'active_users',(SELECT count(*) FROM public.user_presence WHERE last_seen_at > now()-interval '5 minutes'),
  'inactive_users',(SELECT greatest((SELECT count(*) FROM public.profiles)-(SELECT count(*) FROM public.user_presence WHERE last_seen_at > now()-interval '5 minutes'),0)),
  'total_likes',(SELECT count(*) FROM public.likes)
 ) INTO result;
 RETURN result;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_user_metrics() TO authenticated;

NOTIFY pgrst, 'reload schema';

DROP POLICY IF EXISTS "conversation members read voice notes" ON storage.objects;
CREATE POLICY "conversation members read voice notes" ON storage.objects FOR SELECT TO authenticated
USING(bucket_id='voice-notes' AND EXISTS(
 SELECT 1 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 WHERE m.media_path=storage.objects.name AND auth.uid() IN(c.user_a,c.user_b)
));
