-- Aurem World: allow users to delete their own posts and @anonymous_001 to delete any post.
-- Run this in Supabase SQL Editor for project wfreidisslthhitupzie.

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post owner or Aurem admin can delete" ON public.posts;
CREATE POLICY "post owner or Aurem admin can delete"
ON public.posts
FOR DELETE
TO authenticated
USING (
  user_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.profiles AS admin_profile
    WHERE admin_profile.id = auth.uid()
      AND lower(admin_profile.username) = 'anonymous_001'
  )
);

-- Allow owners to remove their own uploaded media and the admin to remove media
-- belonging to any post. This is needed so deleted posts do not leave media behind.
DROP POLICY IF EXISTS "media owner or Aurem admin can delete" ON storage.objects;
CREATE POLICY "media owner or Aurem admin can delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'media'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR EXISTS (
      SELECT 1
      FROM public.profiles AS admin_profile
      WHERE admin_profile.id = auth.uid()
        AND lower(admin_profile.username) = 'anonymous_001'
    )
  )
);
