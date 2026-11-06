AUREM WORLD — FEED, RESHARE, PRIVATE SUGGESTIONS & MESSAGING UPDATE

Files to replace in the ROOT of your existing GitHub repository:
- index.html
- app.js
- styles.css
- aurem-world-icon.png

Supabase:
1. Open the SQL Editor.
2. Run MESSAGING_AND_FEATURES_FIX.sql.
3. Do not run the older feature migration again; the reshare and private suggestion tables/admin setup were already run in this chat.

What this update includes:
- TikTok-inspired full-height mobile post layout and action rail.
- Reshare action and original creator credit.
- Private suggestion submission; only users in app_admins can read suggestions.
- Admin suggestion inbox/dashboard for the registered owner account.
- Profile navigation from creator name/avatar.
- Messaging fixes: normalizes the conversation RPC result, displays errors, loads existing conversations, sends and refreshes messages, and subscribes to new messages.

Important:
- This is a best-effort update based on the existing source files and known schema. Test with two accounts after deployment.
- The messaging SQL assumes conversations has id,user_a,user_b and messages has id,conversation_id,sender_id,body,created_at, matching the existing app code. If SQL reports a missing column, stop and share the exact error; do not delete tables.
- Existing database records are not deleted.
