import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { createClient } from '@supabase/supabase-js';

type Bindings = {
  duva_images: R2Bucket;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  R2_PUBLIC_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  AI: any;
};

const POOL_BATCH_SIZE = 15;
const MAX_MESSAGES_FETCH = 100;
const MAX_MESSAGE_LENGTH = 1000;

const app = new Hono<{ Bindings: Bindings }>();
app.use('/*', cors());

// --- SECURITY MIDDLEWARE ---
// This grabs the Supabase Auth token sent by the Flutter app
const getSupabaseClient = (c: any) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader) throw new Error('Missing Auth Header');
  
  return createClient(c.env.SUPABASE_URL, c.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  });
};

// --- 1. SECURE UPLOAD ROUTE WITH AI MODERATION ---
app.post('/upload', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return c.json({ error: 'Unauthorized' }, 401);

    const formData = await c.req.formData();
    const file = formData.get('image');
    
    if (!file || !(file instanceof File)) {
      return c.json({ error: 'Invalid file or no file uploaded' }, 400);
    }

    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    if (!allowedTypes.includes(file.type)) {
      return c.json({ error: 'Only image uploads are allowed.' }, 400);
    }

    // 🧠 THE AI MODERATION CHECK
    const arrayBuffer = await file.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);
    
    // We convert the image to an array of numbers so the AI can read it
    const ai = c.env.AI;
    const aiResponse = await ai.run('@cf/meta/llama-3.2-11b-vision-instruct', {
      prompt: "You are a Trust and Safety moderator. Look at this image. Is it NSFW (Not Safe For Work), sexually explicit, or containing nudity? Answer STRICTLY with 'YES' or 'NO'. Nothing else.",
      image: [...uint8Array] 
    });

    // Read the AI's answer
    const isNSFW = aiResponse.response.toUpperCase().includes('YES');

    if (isNSFW) {
        return c.json({ error: 'NSFW Content Detected. Image rejected by Safety Engine.' }, 403);
    }

    // ✅ If the AI says 'NO' (Safe), proceed to save to Cloudflare R2
    const fileName = `profile_${user.id}_${Date.now()}`;
    await c.env.duva_images.put(fileName, arrayBuffer, {
      httpMetadata: { contentType: file.type },
    });

    const publicUrl = `${c.env.R2_PUBLIC_URL}/${fileName}`;
    return c.json({ url: publicUrl, success: true });
  } catch (e) {
    console.error("UPLOAD CRASH:", e);
    return c.json({ error: 'Upload failed: ' + String(e) }, 500);
  }
});

// --- 2. THE SMART POOL ROUTE (With Strict Preferences) ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const page = parseInt(c.req.query('page') || '0');
    const limit = POOL_BATCH_SIZE; // Using your constant of 15
    const offset = page * limit;

    const { data: myProfile } = await supabase.from('profiles').select('*').eq('id', user.id).single();

    // Call the database-level filtering function we just made
    const { data: rawPool, error } = await supabase.rpc('get_smart_pool', {
      my_id: user.id,
      my_lat: myProfile.lat,
      my_lng: myProfile.lng,
      min_age: myProfile.min_age || 18,
      max_age: myProfile.max_age || 65,
      max_dist_km: myProfile.max_distance || 50,
      filter_exp: myProfile.filter_expectation,
      page_limit: limit,
      page_offset: offset
    });

    if (error) throw error;

    // Get My Interests
    const { data: myInterestsData } = await supabase.from('profile_interests').select('interest_id').eq('profile_id', user.id);
    const myInterests = (myInterestsData || []).map(i => i.interest_id);

    const scoredPool = [];
    
    // Iterate over 15 users
    for (const profile of (rawPool || [])) {
      const { data: theirInterests } = await supabase.from('profile_interests').select('interest_id, master_interests(name)').eq('profile_id', profile.id);
      
      const theirInterestIds = (theirInterests || []).map((pi: any) => pi.interest_id);
      const theirInterestNames = (theirInterests || []).map((pi: any) => pi.master_interests?.name);
      const sharedCount = theirInterestIds.filter((id: number) => myInterests.includes(id)).length;

      scoredPool.push({
        id: profile.id,
        firstName: profile.first_name,
        age: profile.dob ? Math.floor((Date.now() - new Date(profile.dob).getTime()) / 31557600000) : 18,
        location: profile.location,
        distance: Math.round(profile.distance), 
        bio: profile.bio,
        expectations: profile.expectations,
        currentDateBid: profile.current_date_bid,
        images: profile.images || [],
        interests: theirInterestNames,
        sharedInterestsCount: sharedCount,
        lastSeen: profile.last_seen
      });
    }

    // Sort users by shared interests
    scoredPool.sort((a, b) => b.sharedInterestsCount - a.sharedInterestsCount);
    
    return c.json({
        data: scoredPool,
        nextPage: (rawPool && rawPool.length === limit) ? page + 1 : null
    });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to fetch pool' }, 500);
  }
});

// --- ADD THIS TO YOUR index.ts ---
app.get('/matches', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // 🔒 VAPT FIX: Add pagination and limits to Admirers
    const page = parseInt(c.req.query('page') || '0');
    const limit = 20;
    const offset = page * limit;

    const { data, error } = await supabase
      .from('swipes')
      .select('profiles!swipes_swiper_id_fkey(*)') 
      .eq('swiped_id', user.id)
      .eq('action', 'like')
      .range(offset, offset + limit - 1); // Only fetch 20 at a time!

    if (error) throw error;
    
    // ✅ Map snake_case to camelCase so Flutter doesn't crash
    const admirers = (data || []).map((d: any) => d.profiles).filter(Boolean).map((p: any) => ({
        id: p.id,
        firstName: p.first_name,
        // Calculate age on the fly
        age: p.dob ? Math.floor((Date.now() - new Date(p.dob).getTime()) / 31557600000) : 18,
        location: p.location,
        bio: p.bio,
        expectations: p.expectations,
        currentDateBid: p.current_date_bid, 
        images: p.images || [],
        distance: 0, 
        interests: [] 
    }));

    // Return with pagination token
    return c.json({
        data: admirers,
        nextPage: (data && data.length === limit) ? page + 1 : null
    });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to fetch admirers' }, 500);
  }
});

// --- 3. THE SWIPE ROUTE (Updated with Notifications) ---
app.post('/swipe', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { swiped_id, action } = await c.req.json();

    if (user.id === swiped_id) return c.json({ error: 'Cannot swipe yourself.' }, 400);

    // ⚡ THE SUPERLIKE LOGIC
    if (action === 'superlike') {
      const { data: myProfile } = await supabase.from('profiles').select('superlikes_balance').eq('id', user.id).single();
      
      // If balance is 0, trigger the frontend to show the Purchase Screen
      if (!myProfile || myProfile.superlikes_balance <= 0) {
        return c.json({ error: 'Out of Superlikes', outOfBalance: true }, 402); // 402 Payment Required
      }

      // Deduct 1 Superlike
      await supabase.from('profiles').update({ superlikes_balance: myProfile.superlikes_balance - 1 }).eq('id', user.id);
      
      // Notify the receiver INSTANTLY
      await supabase.from('notifications').insert({
         user_id: swiped_id, 
         type: 'superlike', 
         title: '⚡ You received a Super Alignment!', 
         message: 'Someone really stands out. Check your pool now.' 
      });
    }

    // Insert the swipe
    await supabase.from('swipes').insert({
      swiper_id: user.id,
      swiped_id: swiped_id,
      action: action // 'like', 'pass', or 'superlike'
    });

    let isMatch = false;
    if (action === 'like') {
      const { data: mutualSwipe } = await supabase
        .from('swipes')
        .select('id')
        .eq('swiper_id', swiped_id)
        .eq('swiped_id', user.id)
        .eq('action', 'like')
        .single();
        
      if (mutualSwipe) {
        isMatch = true;
        // Generate Match Notifications for BOTH users
        await supabase.from('notifications').insert([
          { user_id: swiped_id, type: 'match', title: '✨ Zenith Alignment!', message: 'Someone you liked liked you back.' },
          { user_id: user.id, type: 'match', title: '✨ Zenith Alignment!', message: 'You matched with a new profile.' }
        ]);
      } else {
        // Generate a "Blind Like" Notification for the receiver
        await supabase.from('notifications').insert({
           user_id: swiped_id, 
           type: 'like', 
           title: 'Someone likes you!', 
           message: 'Keep swiping in the pool to find out who.' 
        });
      }
    }

    return c.json({ success: true, isMatch });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Swipe failed' }, 500);
  }
});

// GET: Generate AI Icebreakers for an empty chat
app.get('/matches/:match_id/icebreakers', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');

    // 1. Fetch Interests for both users
    const { data: myInterests } = await supabase.from('profile_interests').select('master_interests(name)').eq('profile_id', user.id);
    const { data: theirInterests } = await supabase.from('profile_interests').select('master_interests(name)').eq('profile_id', matchId);

    const myTags = myInterests?.map((i: any) => i.master_interests?.name).join(', ') || 'nothing specific';
    const theirTags = theirInterests?.map((i: any) => i.master_interests?.name).join(', ') || 'nothing specific';

    // 2. Call Cloudflare Text AI
    const ai = c.env.AI;
    const aiResponse = await ai.run('@cf/meta/llama-3.1-8b-instruct', {
      messages: [
        { 
          role: "system", 
          content: "You are a witty dating assistant. Your job is to write 3 short, clever, and engaging opening messages for a dating app. Base them on the shared or unique interests of the users. Return EXACTLY a JSON array of 3 strings. Do not include markdown, greetings, or explanations. Example: [\"text 1\", \"text 2\", \"text 3\"]" 
        },
        { 
          role: "user", 
          content: `My interests: ${myTags}. Their interests: ${theirTags}. Generate 3 icebreakers.` 
        }
      ]
    });

    // 3. Clean and parse the LLM's response
    let rawText = (aiResponse.response as string).trim();
    // Sometimes LLMs wrap JSON in markdown blocks, we must strip it safely
    if (rawText.startsWith('```json')) rawText = rawText.replace(/```json/g, '');
    if (rawText.startsWith('```')) rawText = rawText.replace(/```/g, '');
    rawText = rawText.trim();

    try {
      const icebreakers = JSON.parse(rawText);
      return c.json(icebreakers);
    } catch (parseError) {
      // Fallback if the AI hallucinates bad JSON
      return c.json([
        "I saw your profile and had to say hi!",
        "What's the best thing that happened to you this week?",
        "If you had to eat one meal for the rest of your life, what would it be?"
      ]);
    }

  } catch (e) {
    console.error("Icebreaker Error:", e);
    return c.json({ error: 'Failed to generate icebreakers' }, 500);
  }
});

// --- 5. STATELESS CHAT POLLING (Saves WebSocket Limits) ---

// GET: Fetch conversation history
app.get('/messages/:match_id', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');

    // Fetch messages where I am sender & they are receiver, OR they are sender & I am receiver
    const { data: messages, error } = await supabase
      .from('messages')
      .select('id, sender_id, content, created_at, is_read')
      .or(`and(sender_id.eq.${user.id},receiver_id.eq.${matchId}),and(sender_id.eq.${matchId},receiver_id.eq.${user.id})`)
      .order('created_at', { ascending: false })
      .limit(100); 

    if (error) throw error;
    return c.json(messages || []);
  } catch (e) {
    return c.json({ error: 'Failed to fetch messages' }, 500);
  }
});

// POST: Send a new message
app.post('/messages/:match_id', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');
    const { content } = await c.req.json();

    if (!content || content.trim() === '') return c.json({ error: 'Empty message' }, 400);

    if (content.length > 1000) {
        return c.json({ error: 'Message exceeds maximum length of 1000 characters.' }, 413);
    }

    const { error } = await supabase.from('messages').insert({
      sender_id: user.id,
      receiver_id: matchId,
      content: content.trim()
    });

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to send message' }, 500);
  }
});

// GET: Fetch real notifications from Supabase
app.get('/notifications', async (c) => {
  const supabase = getSupabaseClient(c);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return c.json({ error: 'Unauthorized' }, 401);

  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  if (error) return c.json({ error: error.message }, 500);
  return c.json(data);
});

// PATCH: Mark all as read
app.patch('/notifications/read', async (c) => {
  const supabase = getSupabaseClient(c);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return c.json({ error: 'Unauthorized' }, 401);

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', user.id)
    .eq('is_read', false);

  if (error) return c.json({ error: error.message }, 500);
  return c.json({ success: true });
});

// --- 7. SAVE PREFERENCES ---
// --- 7. SAVE PREFERENCES ---
app.post('/preferences', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { min_age, max_age, filter_expectation, max_distance } = await c.req.json();

    // 🔒 SECURITY FIX: Server-Side Data Validation
    // 1. Enforce POCSO / DPDP Age Compliance
    if (min_age !== undefined && typeof min_age === 'number' && min_age < 18) {
      return c.json({ error: 'Critical Security: Minimum age must be 18+.' }, 403);
    }
    
    // 2. Prevent Logic Manipulation
    if (min_age !== undefined && max_age !== undefined && max_age < min_age) {
      return c.json({ error: 'Maximum age cannot be lower than minimum age.' }, 400);
    }

    // 3. Prevent Server Load Attacks (e.g., sending distance: 9999999 to crash the haversine query)
    if (max_distance !== undefined && (max_distance < 1 || max_distance > 500)) {
       return c.json({ error: 'Distance must be between 1km and 500km.' }, 400);
    }

    const { error } = await supabase.from('profiles').update({ 
        min_age: min_age, 
        max_age: max_age, 
        max_distance: max_distance, 
        filter_expectation: filter_expectation === 'Any' ? null : filter_expectation 
    }).eq('id', user.id);

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    console.error('Preferences API Error:', e);
    return c.json({ error: 'Failed to update preferences' }, 500);
  }
});

// --- 8. ACCOUNT MANAGEMENT (Settings) ---
app.delete('/account', async (c) => {
  try {
    const supabase = getSupabaseClient(c); // Standard client for checking who requested it
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // ✅ FIX: Create an Admin Client to delete the actual Auth User
    const adminSupabase = createClient(c.env.SUPABASE_URL, c.env.SUPABASE_SERVICE_ROLE_KEY);
    
    // Deleting the auth user automatically cascades and deletes their 'profiles' row if your DB foreign keys are set up correctly.
    const { error } = await adminSupabase.auth.admin.deleteUser(user.id);
    
    if (error) throw error;
    return c.json({ success: true, message: 'Account wiped successfully' });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to delete account' }, 500);
  }
});

// --- 9. TRUST & SAFETY ---

// GET: Fetch master reasons
app.get('/reasons', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const type = c.req.query('type'); // 'block' or 'report'
    
    let query = supabase.from('master_report_reasons').select('*');
    if (type) query = query.eq('category', type);

    const { data, error } = await query;
    if (error) throw error;
    return c.json(data);
  } catch (e) {
    return c.json({ error: 'Failed to fetch reasons' }, 500);
  }
});

// POST: Block a user
app.post('/block', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { blocked_id, reason_id } = await c.req.json();

    await supabase.from('blocks').insert({
      blocker_id: user.id,
      blocked_id: blocked_id,
      reason_id: reason_id
    });

    // We also insert a "Pass" swipe so they never appear in the pool query logic again
    await supabase.from('swipes').insert({ swiper_id: user.id, swiped_id: blocked_id, action: 'pass' });

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to block' }, 500);
  }
});

// POST: Report a user
app.post('/report', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { reported_id, reason_id } = await c.req.json();

    // 1. Log the report for the Admin Panel
    await supabase.from('reports').insert({
      reporter_id: user.id,
      reported_id: reported_id,
      reason_id: reason_id
    });

    // 2. Automatically block them so the user is safe immediately
    await supabase.from('blocks').insert({ blocker_id: user.id, blocked_id: reported_id, reason_id: reason_id });
    await supabase.from('swipes').insert({ swiper_id: user.id, swiped_id: reported_id, action: 'pass' });

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to report' }, 500);
  }
});

// --- 10. UPDATE LOCATION ---
app.post('/location', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { lat, lng, city } = await c.req.json();

    // 🔒 SECURITY FIX: Geographic boundary validation
    if (typeof lat !== 'number' || typeof lng !== 'number' || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
       return c.json({ error: 'Invalid geographic coordinates provided.' }, 400);
    }

    await supabase.from('profiles').update({ 
      lat: lat, 
      lng: lng, 
      location: city ? String(city).substring(0, 50) : 'Unknown',
      last_seen: new Date().toISOString() // 🟢 Heartbeat refreshed!
    }).eq('id', user.id);

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to update location' }, 500);
  }
});

// --- REWIND ROUTE (Premium) ---
app.post('/rewind', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // Get the absolute last swipe they made
    const { data: lastSwipe, error } = await supabase
      .from('swipes')
      .select('id, action, swiped_id')
      .eq('swiper_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (error || !lastSwipe) return c.json({ error: 'No swipes to rewind' }, 400);

    // ✅ FIX: Check if it was a mutual match before allowing deletion
    if (lastSwipe.action === 'like') {
        const { data: mutual } = await supabase
            .from('swipes')
            .select('id')
            .eq('swiper_id', lastSwipe.swiped_id)
            .eq('swiped_id', user.id)
            .eq('action', 'like')
            .single();
        
        if (mutual) return c.json({ error: 'Cannot rewind an alignment.' }, 403);
    }

    // Delete it so the profile returns to the pool
    await supabase.from('swipes').delete().eq('id', lastSwipe.id);

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Rewind failed' }, 500);
  }
});

// --- 11. THE PROFILE GATEKEEPER ---
app.post('/profile', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { firstName, lastName, bio, dob, gender, lookingFor, images, expectations } = await c.req.json();

    // 1. 🛡️ PROFANITY & SPAM SANITIZER
    // Blocks slurs, solicitation, and external handles (Insta, Telegram, OnlyFans, Snap)
    const spamRegex = /(fuck|shit|bitch|cunt|nigger|onlyfans|only fans|t\.me|telegram|insta|ig:|snapchat|sc:|\@)/i;
    if (spamRegex.test(bio || '') || spamRegex.test(firstName || '')) {
      return c.json({ error: 'Profile text contains prohibited language or social handles.' }, 400);
    }

    // 2. 🛡️ THE IMAGE DOMAIN LOCK (The ultimate hack-killer)
    // Forces 100% of image URLs to belong to YOUR Cloudflare R2 bucket. 
    const validImages = (images || []).filter((url: string) => {
      return typeof url === 'string' && url.startsWith(c.env.R2_PUBLIC_URL);
    });

    if (validImages.length === 0) {
      return c.json({ error: 'You must provide at least 1 valid Duva photograph.' }, 400);
    }

    // 3. 🛡️ SERVER-SIDE AGE ENFORCEMENT (Prevents dob tampering)
    const birthDate = new Date(dob);
    const age = Math.floor((Date.now() - birthDate.getTime()) / 31557600000);
    if (age < 18 || age > 99) {
      return c.json({ error: 'You must be 18+ to use Duva.' }, 403);
    }

    // 4. Safe to commit to DB
    const { error } = await supabase.from('profiles').upsert({
      id: user.id,
      first_name: String(firstName).trim().substring(0, 30),
      last_name: lastName ? String(lastName).trim().substring(0, 30) : null,
      bio: bio ? String(bio).trim().substring(0, 300) : '',
      dob: dob,
      gender: gender,
      looking_for_gender: lookingFor,
      images: validImages, // Only accepts the locked-down R2 urls
      expectations: expectations
    });

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    console.error("Profile Gatekeeper Failed:", e);
    return c.json({ error: 'Failed to commit profile' }, 500);
  }
});

// --- TRUST & SAFETY: TEXT MODERATION ---
app.post('/moderate-text', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { text } = await c.req.json();
    
    // If empty, nothing to moderate
    if (!text || typeof text !== 'string' || text.trim() === '') {
      return c.json({ isClean: true });
    }

    const ai = c.env.AI;
    const aiResponse = await ai.run('@cf/meta/llama-3.1-8b-instruct', {
      messages: [
        { 
          role: "system", 
          content: "You are a highly strict Trust & Safety automated filter for a premium dating app. Read the user input. If it contains profanity, slurs, explicit sexual requests, severe toxicity, or insults, reply STRICTLY with 'DIRTY'. If it is completely clean and safe, reply STRICTLY with 'CLEAN'. Do not explain your answer." 
        },
        { 
          role: "user", 
          content: text 
        }
      ]
    });

    const responseText = (aiResponse.response as string).toUpperCase();
    
    // If the AI flags it as dirty, return false
    const isClean = !responseText.includes('DIRTY');

    return c.json({ isClean });
  } catch (e) {
    console.error("Moderation Error:", e);
    // Fail open if the AI is down, so users aren't permanently locked out of saving
    return c.json({ isClean: true }); 
  }
});

// --- 12. AI BIO GENERATION (Once per week) ---
app.post('/generate-bio', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { interests, work, education, expectations, current_bio } = await c.req.json();

    // 1. Check 7-day cooldown
    const { data: profile } = await supabase
      .from('profiles')
      .select('last_bio_generation_at')
      .eq('id', user.id)
      .single();

    if (profile?.last_bio_generation_at) {
      const lastGen = new Date(profile.last_bio_generation_at);
      const now = new Date();
      const diffDays = Math.floor((now.getTime() - lastGen.getTime()) / (1000 * 60 * 60 * 24));
      if (diffDays < 7) {
        return c.json({ cooldown_days: 7 - diffDays });
      }
    }

    // 2. Generate 3 bios via Cloudflare AI
    const ai = c.env.AI;
    const aiResponse = await ai.run('@cf/meta/llama-3.1-8b-instruct', {
      messages: [
        {
          role: "system",
          content: "You are a creative dating profile bio writer. Generate 3 short, engaging, and unique bio options for a dating app profile. Base them on the user's interests, work, education, and relationship expectations. Each bio must be under 200 characters. Return EXACTLY a JSON array of 3 strings. Do not include markdown, greetings, or explanations. Example: [\"bio 1\", \"bio 2\", \"bio 3\"]"
        },
        {
          role: "user",
          content: `Interests: ${interests?.join(', ') || 'None specified'}. Work: ${work || 'Not specified'}. Education: ${education || 'Not specified'}. Looking for: ${expectations || 'Not specified'}. Current bio: ${current_bio || 'None'}. Generate 3 unique bio options.`
        }
      ]
    });

    let rawText = (aiResponse.response as string).trim();
    if (rawText.startsWith('```json')) rawText = rawText.replace(/```json/g, '');
    if (rawText.startsWith('```')) rawText = rawText.replace(/```/g, '');
    rawText = rawText.trim();

    let bios: string[];
    try {
      bios = JSON.parse(rawText);
      if (!Array.isArray(bios) || bios.length === 0) throw new Error('Invalid format');
    } catch {
      bios = [
        "I'm all about good vibes and great conversations. Let's see where this goes!",
        "Exploring life one adventure at a time. Coffee and deep talks are my love language.",
        "Just a regular person looking for something real. If you love dogs and sunsets, we'll get along!"
      ];
    }

    // 3. Update cooldown timestamp
    await supabase
      .from('profiles')
      .update({ last_bio_generation_at: new Date().toISOString() })
      .eq('id', user.id);

    return c.json({ bios, cooldown_days: 7 });
  } catch (e) {
    console.error("Bio Generation Error:", e);
    return c.json({ error: 'Failed to generate bio' }, 500);
  }
});

export default app;