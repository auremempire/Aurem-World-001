# Aurem World update

## Deploy
Upload the contents of this folder (or this ZIP) to Netlify Drop. Keep your existing Netlify site; this creates a new deploy for that site when uploaded through its deploy page.

## Required Supabase migration
Before testing the new profile features, open Supabase → SQL Editor → New query, paste the complete contents of `PROFILE_PRIVACY_MIGRATION.sql`, and run it. This adds the private-profile setting, follow requests/approval function, and avatar storage bucket/policies. It also updates post visibility rules.

Your existing Supabase URL and publishable key are already configured in `app.js`. Never put a Supabase secret/service-role key in browser code.

## Features in this update
- Download button on posts. Downloaded images receive an AUREM WORLD + creator watermark. Videos are exported as watermarked WebM where the browser supports canvas capture and MediaRecorder.
- Change profile picture using the profile page (image limit 5 MB).
- Switch your account between public and private.
- Private account follow requests; the account owner can approve or decline requests. Private posts are protected by Supabase row-level security after the migration is run.

## Browser note
For watermarked video export, use an up-to-date Chrome browser. Some mobile browsers do not support video canvas recording; in that case the app will show a clear message instead of silently downloading an unwatermarked video.
