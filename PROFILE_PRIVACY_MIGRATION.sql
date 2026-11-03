-- Aurem World profile photos, private accounts and follow approvals.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.follow_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','declined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(requester_id,target_id),
  CHECK(requester_id <> target_id)
);
ALTER TABLE public.follow_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "follow requests read participants" ON public.follow_requests;
CREATE POLICY "follow requests read participants" ON public.follow_requests FOR SELECT
USING(auth.uid()=requester_id OR auth.uid()=target_id);
DROP POLICY IF EXISTS "request own follow" ON public.follow_requests;
CREATE POLICY "request own follow" ON public.follow_requests FOR INSERT
WITH CHECK(auth.uid()=requester_id);
DROP POLICY IF EXISTS "requester update own request" ON public.follow_requests;
CREATE POLICY "requester update own request" ON public.follow_requests FOR UPDATE
USING(auth.uid()=requester_id) WITH CHECK(auth.uid()=requester_id);

CREATE OR REPLACE FUNCTION public.approve_follow_request(request_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE req public.follow_requests%ROWTYPE;
BEGIN
 SELECT * INTO req FROM public.follow_requests WHERE id=request_id FOR UPDATE;
 IF req.id IS NULL OR req.target_id <> auth.uid() OR req.status <> 'pending' THEN
   RAISE EXCEPTION 'Follow request not found or not authorized';
 END IF;
 INSERT INTO public.follows(follower_id,following_id)
 VALUES(req.requester_id,req.target_id) ON CONFLICT DO NOTHING;
 UPDATE public.follow_requests SET status='approved' WHERE id=req.id;
END; $$;
GRANT EXECUTE ON FUNCTION public.approve_follow_request(uuid) TO authenticated;

-- Private profiles' posts are visible only to their owner and approved followers.
DROP POLICY IF EXISTS "public posts readable" ON public.posts;
CREATE POLICY "posts readable by privacy" ON public.posts FOR SELECT USING (
 auth.uid()=user_id OR (
   visibility='public' AND (
     NOT EXISTS(SELECT 1 FROM public.profiles pr WHERE pr.id=posts.user_id AND pr.is_private)
     OR EXISTS(SELECT 1 FROM public.follows f WHERE f.follower_id=auth.uid() AND f.following_id=posts.user_id)
   )
 )
);

-- Avatar image storage.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('avatars','avatars',true,5242880,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=true,file_size_limit=5242880,allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp'];
DROP POLICY IF EXISTS "avatar images public read" ON storage.objects;
CREATE POLICY "avatar images public read" ON storage.objects FOR SELECT USING(bucket_id='avatars');
DROP POLICY IF EXISTS "users upload own avatar" ON storage.objects;
CREATE POLICY "users upload own avatar" ON storage.objects FOR INSERT TO authenticated
WITH CHECK(bucket_id='avatars' AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS "users update own avatar" ON storage.objects;
CREATE POLICY "users update own avatar" ON storage.objects FOR UPDATE TO authenticated
USING(bucket_id='avatars' AND (storage.foldername(name))[1]=auth.uid()::text)
WITH CHECK(bucket_id='avatars' AND (storage.foldername(name))[1]=auth.uid()::text);
