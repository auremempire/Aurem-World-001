AUREM WORLD — COMPLETE FEATURE UPDATE

This package preserves the latest Aurem World app source and adds the mobile layout/feed ordering and clickable creator profiles.

FILES
- index.html, app.js, styles.css, aurem-world-icon.png: replace the matching files in the root of your existing GitHub repository.
- AUREM_WORLD_FEATURE_MIGRATION.sql: additive setup for reshares, suggestions, presence, chat activity and voice-note storage.
- PROFILE_PRIVACY_MIGRATION.sql, POST_DELETE_PERMISSIONS.sql, FIX_DATABASE.sql: supporting migrations from the existing setup. Run only migrations you have not already run; do not rerun older migrations blindly.

IMPORTANT
- The app uses the existing Supabase project configured in app.js. Never put a service-role/secret key in browser code.
- The feature migration assumes the existing profiles, posts, conversations and messages tables are already present.
- Admin dashboard access is currently keyed to the owner username in the client; this is not a secure production admin boundary. Use server-side role/RPC authorization before handling sensitive admin actions.
- Chat streak recording stores daily chat activity; a full two-person consecutive-day streak display still needs a dedicated UI and verified database logic.
- Notifications are not fully implemented in this package. Do not treat the app as production-complete until backend policies, realtime behavior, and each feature are tested with two separate accounts.
- Likes and follows remain voluntary and reversible.
