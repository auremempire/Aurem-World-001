AUREM WORLD UPDATE

Included:
- Users can delete their own posts.
- The account with username @anonymous_001 sees an admin delete button on all posts.
- Video downloads now save the original complete video file instead of recording it again in the browser. This avoids truncated playback/audio caused by browser re-encoding. Video downloads are not watermarked; image downloads retain the Aurem World watermark.

IMPORTANT SETUP:
1. In Supabase SQL Editor, run POST_DELETE_PERMISSIONS.sql before testing delete.
2. Upload the ZIP contents to the EXISTING GitHub repository (replace app.js and add POST_DELETE_PERMISSIONS.sql / README_UPDATE.txt), then commit to main.
3. Netlify should automatically deploy from GitHub.

The admin username must be exactly anonymous_001 in public.profiles. The database permission policy also checks that username. Do not allow ordinary users to change another user's profile row.
