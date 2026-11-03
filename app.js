// Aurem World MVP. Configure SUPABASE_URL and SUPABASE_ANON_KEY below.
const SUPABASE_URL = "https://wfreidisslthhitupzie.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_gxv0C4OePj4S6FrqSuTxVw_NuNcHqoO";
const OWNER_USERNAME = "anonymous_001";
const configured = SUPABASE_URL.startsWith("https://") && !SUPABASE_ANON_KEY.includes("YOUR_");
const db = configured ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;
let currentUser = null, currentProfile = null, authMode = "login", activeView = "for-you", activeChat = null, commentsPost = null;
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function notice(msg){$("notice").textContent=msg;$("notice").classList.remove("hidden");setTimeout(()=>$("notice").classList.add("hidden"),6500)}
function requireDb(){if(!db){notice("Setup required: add your Supabase URL and anon key in app.js, then run supabase.sql in your Supabase project.");return false}return true}
function showDialog(id){$(id).showModal()} function closeDialogs(){document.querySelectorAll("dialog").forEach(d=>d.close())}
document.querySelectorAll("[data-close]").forEach(b=>b.addEventListener("click",closeDialogs));
$("auth-open").onclick=()=>{if(currentUser){if(confirm("Sign out of Aurem World?"))db.auth.signOut();}else showDialog("auth-dialog")};
$("upload-open").onclick=$("mobile-create").onclick=()=>{if(!currentUser){notice("Sign in before creating a post.");showDialog("auth-dialog");return}showDialog("upload-dialog")};
$("search-toggle").onclick=()=>$("search-panel").classList.toggle("hidden");
$("auth-switch").onclick=()=>{authMode=authMode==="login"?"signup":"login";$("auth-title").textContent=authMode==="login"?"Welcome to Aurem World":"Create your account";$("auth-subtitle").textContent=authMode==="login"?"Sign in to continue your journey.":"Join the Aurem World community."; $("username-wrap").classList.toggle("hidden",authMode==="login");$("auth-submit").textContent=authMode==="login"?"Sign in":"Create account";$("auth-switch-text").textContent=authMode==="login"?"New here?":"Already have an account?";$("auth-switch").textContent=authMode==="login"?"Create account":"Sign in";$("auth-username").required=authMode==="signup"};
$("auth-form").addEventListener("submit",async e=>{
  e.preventDefault();
  if(!requireDb()) return;
  const submit=$("auth-submit"), mode=authMode;
  const email=$("auth-email").value.trim(), password=$("auth-password").value;
  submit.disabled=true; submit.textContent=mode==="login"?"Signing in…":"Creating account…";
  try {
    let result;
    if(mode==="login") {
      result=await db.auth.signInWithPassword({email,password});
    } else {
      const username=$("auth-username").value.trim().toLowerCase().replace(/[^a-z0-9_.]/g,"");
      if(username.length<3){notice("Username must be at least 3 characters.");return;}
      result=await db.auth.signUp({email,password,options:{data:{username,display_name:username}}});
    }
    if(result.error){notice(mode==="login"?"Sign-in failed: "+result.error.message:result.error.message);return;}
    if(mode==="login" && !result.data?.session){notice("Your account was found, but no session was created. Check your email confirmation in Supabase, then try again.");return;}
    closeDialogs();
    notice(mode==="signup"?"Account created. Check your email if confirmation is enabled.":"Welcome back!");
    await loadSession();
  } catch(err) {
    console.error("Aurem World authentication error",err);
    notice("Sign-in could not complete: "+(err?.message||"Network error. Check your connection and try again."));
  } finally {
    submit.disabled=false; submit.textContent=authMode==="login"?"Sign in":"Create account";
  }
});
async function loadSession(){if(!requireDb())return;const {data:{session}}=await db.auth.getSession();currentUser=session?.user||null;currentProfile=null;if(currentUser){let {data}=await db.from("profiles").select("*").eq("id",currentUser.id).maybeSingle();currentProfile=data;if(!data){const username=(currentUser.user_metadata?.username||"user_"+currentUser.id.slice(0,6)).toLowerCase();let ins=await db.from("profiles").insert({id:currentUser.id,username,display_name:username}).select().single();currentProfile=ins.data} $("auth-open").textContent="Sign out";}else $("auth-open").textContent="Sign in";await loadFeed()};
db?.auth.onAuthStateChange(()=>setTimeout(loadSession,0));
function setView(view){activeView=view;document.querySelectorAll(".nav").forEach(b=>b.classList.toggle("active",b.dataset.view===view));$("feed-view").classList.toggle("hidden",view==="profile"||view==="inbox");$("profile-view").classList.toggle("hidden",view!=="profile");$("inbox-view").classList.toggle("hidden",view!=="inbox");if(view==="profile")loadProfile(currentProfile?.id);else if(view==="inbox")loadInbox();else{ $("feed-title").textContent=view==="following"?"Following":view==="discover"?"Discover":"For You";loadFeed()}}
document.querySelectorAll("[data-view]").forEach(b=>b.addEventListener("click",()=>setView(b.dataset.view)));
async function loadFeed(){if(!requireDb())return;let q=db.from("posts").select("*,profiles!posts_user_id_fkey(id,username,display_name,is_verified,avatar_url)").eq("visibility","public").order("created_at",{ascending:false}).limit(40);if(activeView==="following"&&currentUser){let {data:f}=await db.from("follows").select("following_id").eq("follower_id",currentUser.id);q=q.in("user_id",(f||[]).map(x=>x.following_id));}let {data,error}=await q;if(error){$("feed").innerHTML=`<div class="empty">${esc(error.message)}</div>`;return}if(!data?.length){$("feed").innerHTML='<div class="empty">No posts yet. Be the first to share something.</div>';return}let ids=data.map(p=>p.id),liked=new Set();if(currentUser){let {data:l}=await db.from("likes").select("post_id").eq("user_id",currentUser.id).in("post_id",ids);(l||[]).forEach(x=>liked.add(x.post_id))}let {data:counts}=await db.from("post_counts").select("*").in("post_id",ids);let cm=new Map((counts||[]).map(x=>[x.post_id,x]));$("feed").innerHTML=data.map(p=>renderPost(p,liked.has(p.id),cm.get(p.id))).join("");bindPostActions()}
function renderPost(p,liked,c){
 const prof=p.profiles||{},isVideo=p.media_type==="video";
 const media=isVideo?`<video src="${esc(p.media_url)}" controls playsinline preload="metadata"></video>`:`<img src="${esc(p.media_url)}" alt="Post by ${esc(prof.username)}">`;
 const isOwner=currentUser?.id===p.user_id, isAdmin=currentProfile?.username===OWNER_USERNAME;
 const deleteButton=(isOwner||isAdmin)?'<button class="action danger" data-action="delete">🗑<small>Delete</small></button>':"";
 return `<article class="post" data-post="${p.id}" data-media-url="${esc(p.media_url)}" data-media-path="${esc(p.media_path||"")}" data-media-type="${p.media_type}" data-creator="${esc(prof.username||"creator")}" data-user-id="${p.user_id}"><div><div class="media-wrap">${media}</div><div class="post-info"><div class="creator"><span class="profile-avatar" style="width:30px;height:30px;font-size:14px">${prof.avatar_url?`<img src="${esc(prof.avatar_url)}" alt="">`:esc((prof.display_name||prof.username||"?")[0].toUpperCase())}</span><span>${esc(prof.display_name||prof.username||"Creator")} ${prof.is_verified?'<span class="verified">✓</span>':""}<br><small>@${esc(prof.username||"user")}</small></span></div><p class="caption">${esc(p.caption||"")}</p></div></div><div class="post-actions"><button class="action like ${liked?"liked":""}" data-action="like">♥<small>${c?.like_count||0}</small></button><button class="action" data-action="comments">▢<small>${c?.comment_count||0}</small></button><button class="action" data-action="share">↗<small>Share</small></button><button class="action" data-action="download">⬇<small>Download</small></button><button class="action" data-action="follow" data-user="${p.user_id}">＋<small>Follow</small></button>${deleteButton}</div></article>`
}
function bindPostActions(){document.querySelectorAll(".post").forEach(el=>el.querySelectorAll("[data-action]").forEach(b=>b.onclick=()=>{let id=el.dataset.post,action=b.dataset.action;if(action==="like")toggleLike(id,b);if(action==="comments")openComments(id);if(action==="share")sharePost(id);if(action==="download")downloadWatermarked(el);if(action==="delete")deletePost(el);if(action==="follow")toggleFollow(b.dataset.user,b)}))}
async function downloadWatermarked(post){
 const url=post.dataset.mediaUrl,type=post.dataset.mediaType,creator=post.dataset.creator||"creator";
 const btn=post.querySelector('[data-action="download"]');
 if(btn){btn.disabled=true;btn.innerHTML='…<small>Preparing</small>'}
 try {
  // Videos are downloaded as the original complete file. Re-recording a video in
  // the browser can truncate its ending or omit audio on some Android devices.
  if(type==="video"){
   const response=await fetch(url);
   if(!response.ok)throw new Error(`Video download failed (${response.status}).`);
   const blob=await response.blob();
   if(!blob.size)throw new Error("The downloaded video file was empty.");
   const ext=(url.split("?")[0].match(/\.([a-z0-9]{2,5})$/i)||[])[1]||"mp4";
   saveBlob(blob,`aurem-world-${creator}.${ext}`);
   notice("Original video downloaded. It is saved without re-encoding so the full video and audio are preserved.");
  } else {
   const response=await fetch(url); if(!response.ok)throw new Error("Image could not be fetched");
   const blob=await response.blob(),objectUrl=URL.createObjectURL(blob),img=new Image();
   await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(new Error("Image could not be opened"));img.src=objectUrl});
   const canvas=document.createElement("canvas");canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;
   const ctx=canvas.getContext("2d");ctx.drawImage(img,0,0);drawWatermark(ctx,canvas.width,canvas.height,creator);
   const out=await new Promise(resolve=>canvas.toBlob(resolve,"image/png"));URL.revokeObjectURL(objectUrl);
   if(!out)throw new Error("Could not watermark this image");
   saveBlob(out,`aurem-world-${creator}-watermarked.png`);notice("Image downloaded with the Aurem World watermark.");
  }
 }catch(err){notice("Download issue: "+(err.message||"Could not prepare media"));}
 finally{if(btn){btn.disabled=false;btn.innerHTML='⬇<small>Download</small>'}}
}
async function deletePost(post){
 const isOwner=currentUser?.id===post.dataset.userId,isAdmin=currentProfile?.username===OWNER_USERNAME;
 if(!currentUser||(!isOwner&&!isAdmin)){notice("You are not allowed to delete this post.");return}
 if(!confirm(isAdmin&&!isOwner?"As admin, delete this post for everyone?":"Delete your post? This cannot be undone."))return;
 const postId=post.dataset.post,mediaPath=post.dataset.mediaPath;
 const btn=post.querySelector('[data-action="delete"]');if(btn){btn.disabled=true;btn.innerHTML='…<small>Deleting</small>'}
 try{
  if(mediaPath){const {error:storageError}=await db.storage.from("media").remove([mediaPath]);if(storageError)throw storageError;}
  const {error}=await db.from("posts").delete().eq("id",postId);
  if(error)throw error;
  post.remove();notice("Post deleted.");
 }catch(err){if(btn){btn.disabled=false;btn.innerHTML='🗑<small>Delete</small>'}notice("Could not delete post: "+(err.message||"Permission denied"));}
}
function drawWatermark(ctx,w,h,creator){const size=Math.max(16,Math.round(w*.027)),pad=Math.round(size*.8);ctx.save();ctx.font=`700 ${size}px Arial`;const label=`AUREM WORLD  •  @${creator}`,width=ctx.measureText(label).width;const x=pad,y=h-pad;ctx.fillStyle="rgba(12,5,24,.58)";ctx.fillRect(x-pad*.45,y-size-pad*.45,width+pad*.9,size+pad*.9);ctx.fillStyle="rgba(225,204,255,.92)";ctx.shadowColor="#9d62ff";ctx.shadowBlur=size*.35;ctx.fillText(label,x,y);ctx.restore()}
function saveBlob(blob,name){const a=document.createElement("a"),u=URL.createObjectURL(blob);a.href=u;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),3000)}
async function toggleLike(id,b){if(!currentUser){notice("Sign in to like posts.");return}let {data:old}=await db.from("likes").select("post_id").eq("post_id",id).eq("user_id",currentUser.id).maybeSingle();let r=old?await db.from("likes").delete().eq("post_id",id).eq("user_id",currentUser.id):await db.from("likes").insert({post_id:id,user_id:currentUser.id});if(r.error){notice(r.error.message);return}loadFeed()}
async function toggleFollow(id,b){if(!currentUser){notice("Sign in to follow creators.");return}if(id===currentUser.id){notice("You cannot follow yourself.");return}let {data:old}=await db.from("follows").select("following_id").eq("follower_id",currentUser.id).eq("following_id",id).maybeSingle();let r=old?await db.from("follows").delete().eq("follower_id",currentUser.id).eq("following_id",id):await db.from("follows").insert({follower_id:currentUser.id,following_id:id});if(r.error)notice(r.error.message);else{b.innerHTML=old?'＋<small>Follow</small>':'✓<small>Following</small>'}}
async function sharePost(id){let url=`${location.origin}${location.pathname}?post=${encodeURIComponent(id)}`;if(navigator.share){try{await navigator.share({title:"Aurem World",text:"Check out this post on Aurem World",url})}catch(e){}}else{await navigator.clipboard.writeText(url);notice("Post link copied.")}}
async function openComments(id){commentsPost=id;$("comments-list").innerHTML="Loading…";showDialog("comments-dialog");let {data,error}=await db.from("comments").select("*,profiles(username,display_name)").eq("post_id",id).order("created_at");$("comments-list").innerHTML=error?esc(error.message):(data||[]).map(c=>`<div class="comment-item"><b>@${esc(c.profiles?.username||"user")}</b><p>${esc(c.body)}</p></div>`).join("")||"No comments yet."}
$("comment-form").onsubmit=async e=>{e.preventDefault();if(!currentUser){notice("Sign in to comment.");return}let body=$("comment-input").value.trim();if(!body)return;let {error}=await db.from("comments").insert({post_id:commentsPost,user_id:currentUser.id,body});if(error)notice(error.message);else{$("comment-input").value="";openComments(commentsPost);loadFeed()}};
$("upload-form").onsubmit=async e=>{e.preventDefault();if(!currentUser)return;let file=$("post-file").files[0];if(!file)return;if(file.size>200*1024*1024){notice("Please choose a file smaller than 200 MB.");return}let type=file.type.startsWith("video/")?"video":"image";if(!["video","image"].includes(type)){notice("Choose an image or video.");return}let ext=file.name.split(".").pop().toLowerCase(),path=`${currentUser.id}/${crypto.randomUUID()}.${ext}`;$("upload-progress").textContent="Uploading…";let {error:upErr}=await db.storage.from("media").upload(path,file,{upsert:false,contentType:file.type});if(upErr){$("upload-progress").textContent=upErr.message;return}let {data:{publicUrl}}=db.storage.from("media").getPublicUrl(path);let {error}=await db.from("posts").insert({user_id:currentUser.id,caption:$("post-caption").value.trim(),media_url:publicUrl,media_path:path,media_type:type,visibility:"public"});if(error){$("upload-progress").textContent=error.message;return}$("upload-form").reset();$("upload-progress").textContent="";closeDialogs();setView("for-you");notice("Your post is live on Aurem World!")};
async function loadProfile(id){if(!id){$("profile-view").innerHTML='<div class="empty">Sign in to view your profile.</div>';return}let {data:p}=await db.from("profiles").select("*").eq("id",id).single();let [{count:followers},{count:following},{data:posts}]=await Promise.all([db.from("follows").select("*",{count:"exact",head:true}).eq("following_id",id),db.from("follows").select("*",{count:"exact",head:true}).eq("follower_id",id),db.from("posts").select("*").eq("user_id",id).order("created_at",{ascending:false})]);$("profile-view").innerHTML=`<div class="profile-head"><div class="profile-avatar">${p?.avatar_url?`<img src="${esc(p.avatar_url)}" alt="Profile picture">`:esc((p?.display_name||p?.username||"U")[0].toUpperCase())}</div><div><h2>${esc(p?.display_name||p?.username)} ${p?.is_verified?'<span class="verified">✓</span>':""}</h2><div>@${esc(p?.username||"")}</div><div class="profile-stats"><span>${posts?.length||0} posts</span><span>${followers||0} followers</span><span>${following||0} following</span></div><div class="profile-actions">${id===currentUser?.id?'<button class="primary-btn" id="edit-profile">Edit profile</button><label class="profile-upload">Change photo<input id="avatar-file" type="file" accept="image/*"></label><button class="avatar" id="privacy-toggle">'+(p.is_private?'Make public':'Make private')+'</button>':`<button class="primary-btn" id="profile-follow">Follow</button><button class="avatar" id="profile-message">Message</button>`}</div></div></div><div class="profile-grid">${(posts||[]).map(x=>x.media_type==="video"?`<video src="${esc(x.media_url)}" controls></video>`:`<img src="${esc(x.media_url)}">`).join("")}</div>`;$("edit-profile")?.addEventListener("click",async()=>{let name=prompt("Display name",p.display_name||"");if(name!==null){let {error}=await db.from("profiles").update({display_name:name}).eq("id",currentUser.id);if(error)notice(error.message);else loadProfile(id)}});$("avatar-file")?.addEventListener("change",async e=>{const file=e.target.files[0];if(!file)return;if(!file.type.startsWith("image/")){notice("Choose an image file.");return}const path=`${currentUser.id}/avatar-${Date.now()}.${file.name.split(".").pop()}`;const {error:upErr}=await db.storage.from("avatars").upload(path,file,{upsert:true,contentType:file.type});if(upErr){notice(upErr.message);return}const {data}=db.storage.from("avatars").getPublicUrl(path);const {error}=await db.from("profiles").update({avatar_url:data.publicUrl}).eq("id",currentUser.id);if(error)notice(error.message);else{notice("Profile picture updated.");loadProfile(id)}});$("privacy-toggle")?.addEventListener("click",async()=>{const {error}=await db.from("profiles").update({is_private:!p.is_private}).eq("id",currentUser.id);if(error)notice(error.message);else{notice(p.is_private?"Your account is now public.":"Your account is now private.");loadProfile(id)}});if(id===currentUser?.id){db.from("follow_requests").select("id,requester_id,profiles!follow_requests_requester_id_fkey(username,display_name)").eq("target_id",id).eq("status","pending").then(({data,error})=>{if(error){notice("Follow requests: "+error.message);return}if(data?.length){const box=document.createElement("div");box.className="panel follow-requests";box.innerHTML="<h3>Follow requests</h3>"+data.map(r=>`<div class="request-row"><span>@${esc(r.profiles?.username||"user")}</span><button class="primary-btn" data-approve="${r.id}">Approve</button><button class="avatar" data-decline="${r.id}">Decline</button></div>`).join("");$("profile-view").insertBefore(box,$("profile-view").querySelector(".profile-grid"));box.querySelectorAll("[data-approve]").forEach(btn=>btn.onclick=async()=>{const {error}=await db.rpc("approve_follow_request",{request_id:btn.dataset.approve});if(error){notice(error.message);return}notice("Follow request approved.");loadProfile(id)});box.querySelectorAll("[data-decline]").forEach(btn=>btn.onclick=async()=>{const {error}=await db.from("follow_requests").update({status:"declined"}).eq("id",btn.dataset.decline);if(error)notice(error.message);else loadProfile(id)});}})}$("profile-follow")?.addEventListener("click",()=>toggleFollow(id,$("profile-follow")));$("profile-message")?.addEventListener("click",()=>openChat(id,p.username))}
async function searchUsers(q){if(!q.trim())return;$("search-results").innerHTML="Searching…";let {data,error}=await db.from("profiles").select("id,username,display_name,is_verified").ilike("username",`%${q}%`).limit(10);$("search-results").innerHTML=error?esc(error.message):(data||[]).map(u=>`<div class="search-result" data-id="${u.id}"><b>${esc(u.display_name||u.username)}</b> @${esc(u.username)} ${u.is_verified?"✓":""}</div>`).join("")||"No users found.";document.querySelectorAll(".search-result").forEach(x=>x.onclick=()=>{loadProfile(x.dataset.id);setView("profile");$("search-panel").classList.add("hidden")})}
$("search-input").oninput=e=>{if(requireDb())searchUsers(e.target.value)};
async function loadInbox(){if(!currentUser){$("inbox-list").innerHTML="Sign in to view messages.";return}let {data,error}=await db.from("conversations").select("id, user_a, user_b").or(`user_a.eq.${currentUser.id},user_b.eq.${currentUser.id}`);if(error){$("inbox-list").textContent=error.message;return}let otherIds=(data||[]).map(c=>c.user_a===currentUser.id?c.user_b:c.user_a);if(!otherIds.length){$("inbox-list").textContent="No conversations yet. Find a creator in Discover to message.";return}let {data:users}=await db.from("profiles").select("id,username").in("id",otherIds);$("inbox-list").innerHTML=(users||[]).map(u=>`<div class="search-result" data-id="${u.id}" data-name="${esc(u.username)}">@${esc(u.username)} — Open chat</div>`).join("");document.querySelectorAll("#inbox-list [data-id]").forEach(x=>x.onclick=()=>openChat(x.dataset.id,x.dataset.name))}
async function openChat(otherId,name){if(!currentUser){notice("Sign in to message.");return}let {data:conv,error}=await db.rpc("get_or_create_conversation",{other_user_id:otherId});if(error){notice("Messaging setup: "+error.message);return}activeChat=conv;$("chat-title").textContent="@"+name;$("chat-messages").innerHTML="Loading…";showDialog("chat-dialog");await refreshChat();db.channel("chat-"+conv).on("postgres_changes",{event:"INSERT",schema:"public",table:"messages",filter:`conversation_id=eq.${conv}`},refreshChat).subscribe()}
async function refreshChat(){if(!activeChat)return;let {data,error}=await db.from("messages").select("id,sender_id,body,created_at").eq("conversation_id",activeChat).order("created_at").limit(100);$("chat-messages").innerHTML=error?esc(error.message):(data||[]).map(m=>`<div class="message ${m.sender_id===currentUser.id?"mine":""}">${esc(m.body)}</div>`).join("");$("chat-messages").scrollTop=$("chat-messages").scrollHeight}
$("chat-form").onsubmit=async e=>{e.preventDefault();if(!activeChat||!currentUser)return;let body=$("chat-input").value.trim();if(!body)return;let {error}=await db.from("messages").insert({conversation_id:activeChat,sender_id:currentUser.id,body});if(error)notice(error.message);else{$("chat-input").value="";refreshChat()}};
(async()=>{if(!configured){$("feed").innerHTML='<div class="empty"><b>Welcome to Aurem World.</b><br>To activate accounts, uploads, likes, comments and messaging, configure Supabase using the included SETUP.md and supabase.sql files.</div>'}else await loadSession()})();

// Private-account follow requests: requests are approved by the account owner.
const _toggleFollowOriginal = toggleFollow;
toggleFollow = async function(id,b){
 if(!currentUser){notice("Sign in to follow creators.");return}
 if(id===currentUser.id){notice("You cannot follow yourself.");return}
 const {data:target}=await db.from("profiles").select("is_private").eq("id",id).maybeSingle();
 if(target?.is_private){
  const {data:existing}=await db.from("follow_requests").select("id,status").eq("requester_id",currentUser.id).eq("target_id",id).maybeSingle();
  if(existing?.status==="pending"){notice("Follow request already sent.");return}
  const {error}=await db.from("follow_requests").upsert({requester_id:currentUser.id,target_id:id,status:"pending"},{onConflict:"requester_id,target_id"});
  if(error)notice(error.message);else{notice("Follow request sent.");if(b)b.innerHTML='◷<small>Requested</small>'}
  return;
 }
 return _toggleFollowOriginal(id,b);
};
