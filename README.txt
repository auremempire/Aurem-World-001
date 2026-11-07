AUREM WORLD - NOVEMBER 7 FIX

This update includes code-side fixes for:
- Messaging: reads both user_one/user_two and user_a/user_b conversation fields; handles RPC response formats; replaces old realtime chat subscription.
- Reshare: adds a Reshare button and inserts the required original_post_id field.
- Follow: checks the saved relationship after insert/delete and updates the button from the database result.

INSTALL:
1. Back up the current index.html, app.js, and styles.css in your GitHub aurem-world repository.
2. Upload/replace index.html, app.js, styles.css, and aurem-world-icon.png at the repository root (same level as before).
3. Commit the changes to the main branch.
4. Wait for Netlify to finish deploying, then refresh the Aurem World website.

IMPORTANT:
- This is a best-effort code patch based on the table columns and successful SQL changes reported in the conversation. It has passed JavaScript syntax validation, but has not been end-to-end tested against your live Supabase project.
- The chat code expects the existing get_or_create_conversation RPC to return a conversation UUID. If chat still errors, send the exact error.
- Reshare records are saved in the reshares table. This patch does not yet add reshared posts into the main feed as separate feed cards.
- Follow counts are read from the follows table; database RLS must allow a user to read their own follow rows and insert/delete their own rows.
- Do not upload any Supabase service-role key. The publishable key in app.js is intended for browser use.
