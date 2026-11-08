AUREM WORLD UPDATE — NOVEMBER 8

Replace these files in the ROOT of your existing GitHub repository (main branch):
index.html
app.js
styles.css
aurem-world-icon.png

Keep your existing Netlify settings and Supabase project. Do not replace database keys or secret keys.

Changes:
- Creator names/avatars in feed posts open that creator's profile.
- Inbox redesigned with story-style profile circles and conversation rows.
- Chat creation accepts either a UUID or an object returned by the RPC.
- Mobile feed uses a vertical, full-screen TikTok-inspired layout.
- Image downloads receive an Aurem World watermark.
- Video download attempts a moving watermark overlay, retaining the audio track and full playback timeline. Browser MediaRecorder re-encodes to WebM, so output encoding/container and quality may differ from the source. Test with a short video first. If the browser cannot export it, it reports an error and does not silently download the unwatermarked original.

Important: JavaScript syntax validation passed. This package has not been end-to-end tested against the live Supabase project or on multiple Android devices. Back up current files before replacing them.
