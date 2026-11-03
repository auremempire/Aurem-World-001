-- Aurem World database repair
-- Run this in Supabase Dashboard > SQL Editor > New query > Run.

-- The app filters public posts by this column and sets it on upload.
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public';

-- Keep the allowed values consistent with the app.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.posts'::regclass
      AND conname = 'posts_visibility_check'
  ) THEN
    ALTER TABLE public.posts
      ADD CONSTRAINT posts_visibility_check
      CHECK (visibility IN ('public', 'private'));
  END IF;
END $$;

-- Refresh Supabase's API schema cache so the new column is recognised.
NOTIFY pgrst, 'reload schema';
