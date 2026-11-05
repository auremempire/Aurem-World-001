AUREM WORLD UPDATE PACKAGE

Files:
- index.html
- app.js
- styles.css
- aurem-world-icon.png
- AUREM_WORLD_FEATURE_MIGRATION.sql

IMPORTANT:
1. Back up your current GitHub repository before replacing files.
2. Upload the four website files to the same folder/root in your existing aurem-world repository.
3. Run AUREM_WORLD_FEATURE_MIGRATION.sql in Supabase SQL Editor.
4. Wait for Netlify to finish deploying, then test with two separate test accounts.

Included in this update:
- Reshare action (requires reshares table migration).
- Profile suggestion box (submissions are private to their author under the supplied policies; admin review needs a secure admin RPC/role before production).
- Admin dashboard UI for owner username anonymous_001 (metrics depend on read permissions; secure admin access is not fully enforced by this client-only MVP).
- Creator like totals.
- Voice-note recording and playback (requires microphone permission and voice-notes storage bucket).
- Presence heartbeat and chat activity recording (streak history table/function; a full mutual-streak display is not yet included).
- Video watermark export is attempted where browser capture support permits; unsupported browsers fall back to original download.

Existing authentication, profile privacy, follow requests, and post deletion code is retained.
This is an MVP integration, not a production security audit. Admin analytics and suggestion review must be moved behind a server-side role/RPC before public launch. Test all functions before announcing launch.
