AUREM WORLD — FEATURE UPGRADE

Files:
- app.js: updated application logic
- index.html: existing page structure, preserved
- styles.css: existing purple styling plus new feature styles
- FEATURE_UPGRADE.sql: Supabase database migration

INSTALLATION
1. Make a backup/commit of the current GitHub repository first.
2. In Supabase SQL Editor, run FEATURE_UPGRADE.sql once.
3. Confirm the SQL finishes successfully.
4. In your existing GitHub repository, replace app.js and styles.css with these versions.
5. Keep your current index.html and aurem-world-icon.png. The supplied index.html is included unchanged as a reference.
6. Commit the changes to the main branch. Netlify should deploy from its existing GitHub connection.

IMPORTANT NOTES
- Messaging requires the SQL migration and authenticated user accounts.
- Voice notes require microphone permission and browser MediaRecorder support.
- Voice-note audio uses a private Storage bucket and signed URLs.
- Chat streaks count consecutive UTC calendar days when both participants have sent at least one message.
- Active users are those with a presence heartbeat in the last five minutes. Inactive is total registered users minus active.
- Admin metrics and suggestion review are restricted by the database function to the profile username anonymous_001.
- Reshares reference the original post, preserving the original creator and post ID.
- Video watermark export re-encodes video to WebM in the browser; browser/device codec support and media CORS rules can affect export. The original source post is not modified.
- Test with two separate accounts before announcing the upgrade.

SECURITY
Never place a Supabase service-role/secret key in app.js. Keep only the public publishable/anon key in browser code.
