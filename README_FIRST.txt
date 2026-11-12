AUREM WORLD — CHAT AND INBOX UPDATE PACK
================================================

WHAT THIS PACK DOES
-------------------
1. Fixes the Inbox experience so it can show other registered profiles, not only
   people who already have a conversation.
2. Keeps the existing get_or_create_conversation(uuid) RPC.
3. Adds participant-only read/send policies for conversations and text messages.
4. Does not delete existing users, posts, profiles, conversations, or messages.

IMPORTANT
---------
Your current app.js already contains:
- loadInbox()
- openChat()
- refreshChat()
- the chat-form submit handler

The SQL migration is additive. It does not replace your existing policies.
Do not run a full database reset. Do not delete tables or policies.

PART 1 — RUN THE SUPABASE SQL
-----------------------------
1. Open:
   https://supabase.com/dashboard/project/wfreidisslthhitupzie/sql/new
2. Start a new query.
3. Open the file: aurem_chat_repair.sql
4. Copy all its contents into the SQL editor.
5. Tap Run.
6. If Supabase shows an error, stop and send the exact error. Do not run it repeatedly.

The SQL includes two verification queries at the bottom.

PART 2 — UPDATE app.js
---------------------
Open:
https://github.com/auremempire/Aurem-World-001/edit/main/app.js

Find the existing function that starts:
   async function loadInbox(){

Replace ONLY that complete loadInbox() function (from its opening line through
its closing brace immediately before async function openChat) with this:

async function loadInbox(){
  const box = $("inbox-list");
  if (!currentUser) {
    box.innerHTML = '<div class="inbox-empty">Sign in to view messages.</div>';
    return;
  }

  box.innerHTML = '<div class="inbox-empty">Loading inbox…</div>';

  const { data: convs, error: convError } = await db
    .from("conversations")
    .select("id,user_one,user_two,user_a,user_b,created_at")
    .or(`user_one.eq.${currentUser.id},user_two.eq.${currentUser.id},user_a.eq.${currentUser.id},user_b.eq.${currentUser.id}`)
    .order("created_at", { ascending: false });

  if (convError) {
    box.innerHTML = `<div class="inbox-empty">${esc(convError.message)}</div>`;
    return;
  }

  const otherIds = [...new Set((convs || []).map(c =>
    c.user_one === currentUser.id ? c.user_two :
    c.user_two === currentUser.id ? c.user_one :
    c.user_a === currentUser.id ? c.user_b : c.user_a
  ).filter(Boolean))];

  // Fetch every other profile so a user can start a conversation
  // even when no conversation row exists yet.
  const { data: people, error: peopleError } = await db
    .from("profiles")
    .select("id,username,display_name,avatar_url,is_verified")
    .neq("id", currentUser.id)
    .order("username")
    .limit(100);

  if (peopleError) {
    box.innerHTML = `<div class="inbox-empty">Could not load people: ${esc(peopleError.message)}</div>`;
    return;
  }

  const byId = new Map((people || []).map(p => [p.id, p]));
  const recentPeople = otherIds.map(id => byId.get(id)).filter(Boolean);
  const recentSet = new Set(otherIds);
  const discoverPeople = (people || []).filter(p => !recentSet.has(p.id));

  const personButton = (u) => `
    <button class="inbox-person" data-id="${u.id}"
      data-name="${esc(u.username || u.display_name || "Creator")}">
      <span class="inbox-avatar">
        ${u.avatar_url ? `<img src="${esc(u.avatar_url)}" alt="">`
          : esc((u.username || "?")[0].toUpperCase())}
      </span>
      <span class="inbox-person-text">
        <b>${esc(u.display_name || u.username || "Creator")}
          ${u.is_verified ? "✓" : ""}</b>
        <small>@${esc(u.username || "user")}</small>
      </span>
      <span class="inbox-arrow">›</span>
    </button>`;

  box.innerHTML = `
    <div class="inbox-section-title">Recent conversations</div>
    ${recentPeople.map(personButton).join("") ||
      '<div class="inbox-empty">No conversations yet. Start one below.</div>'}
    <div class="inbox-section-title">People on Aurem World</div>
    ${discoverPeople.map(personButton).join("") ||
      '<div class="inbox-empty">No other profiles found.</div>'}`;

  box.querySelectorAll(".inbox-person").forEach(button => {
    button.addEventListener("click", () =>
      openChat(button.dataset.id, button.dataset.name));
  });
}

Then tap Commit changes.

PART 3 — CHECK THE MESSAGE BUTTON
---------------------------------
The existing profile Message button already calls:
   openChat(id, p.username)

Keep that line. The existing openChat() function calls:
   db.rpc("get_or_create_conversation", { other_user_id: otherId })

Your Supabase function exists and returns a UUID, based on the result you shared.
Do not recreate it unless the app displays a specific RPC error.

PART 4 — TEST
-------------
1. Refresh the live site:
   https://auremempire.github.io/Aurem-World-001/
2. Sign in.
3. Open Inbox. You should now see registered profiles under "People on Aurem World".
4. Tap a profile. The chat should open.
5. Send a short test message.
6. Sign in with the other test account to check whether the message appears.

IF IT STILL FAILS
-----------------
Send the exact error shown in the Aurem World notice, or a screenshot.
Do not run extra SQL or delete existing policies.

CURRENT LIMITATION
------------------
This pack repairs the inbox directory and text-chat database permissions.
It does NOT yet add working voice notes, image/video attachments, or sticker
uploads. Those require a separate frontend implementation and testing.
