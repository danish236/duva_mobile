import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { createClient } from '@supabase/supabase-js';

type Bindings = {
  duva_images: R2Bucket;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  R2_PUBLIC_URL: string;
};

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

// --- 1. SECURE UPLOAD ROUTE ---
app.post('/upload', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return c.json({ error: 'Unauthorized' }, 401);

    // Using formData() is more robust for file uploads than parseBody()
    const formData = await c.req.formData();
    const file = formData.get('image');
    
    if (!file || !(file instanceof File)) {
      return c.json({ error: 'Invalid file or no file uploaded' }, 400);
    }

    const fileName = `profile_${user.id}_${Date.now()}`;
    // Accessing the bucket correctly using the binding name
    await c.env.duva_images.put(fileName, await file.arrayBuffer(), {
      httpMetadata: { contentType: file.type },
    });

    const publicUrl = `${c.env.R2_PUBLIC_URL}/${fileName}`;
    return c.json({ url: publicUrl, success: true });
  } catch (e) {
    // THIS LINE IS THE KEY: It forces the error to appear in your 'wrangler tail' logs
    console.error("UPLOAD CRASH:", e);
    return c.json({ error: 'Upload failed: ' + String(e) }, 500);
  }
});

// --- 2. THE SMART POOL ROUTE (With Strict Preferences) ---
// --- 2. THE SMART POOL ROUTE (With Geolocation & Haversine) ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // 1. Get My Profile & Preferences
    const { data: myProfile } = await supabase.from('profiles').select('min_age, max_age, filter_expectation, lat, lng, max_distance').eq('id', user.id).single();
    const minAge = myProfile?.min_age || 18;
    const maxAge = myProfile?.max_age || 65;
    const maxDistance = myProfile?.max_distance || 50; // Defaults to 50km
    const myLat = myProfile?.lat;
    const myLng = myProfile?.lng;
    const filterExpectation = myProfile?.filter_expectation;

    // 2. Get Exclusions (Swiped + Blocked)
    const { data: swipes } = await supabase.from('swipes').select('swiped_id').eq('swiper_id', user.id);
    const { data: blocksMade } = await supabase.from('blocks').select('blocked_id').eq('blocker_id', user.id);
    const { data: blocksReceived } = await supabase.from('blocks').select('blocker_id').eq('blocked_id', user.id);
    const excludedSet = new Set([user.id, ...(swipes || []).map(s => s.swiped_id), ...(blocksMade || []).map(b => b.blocked_id), ...(blocksReceived || []).map(b => b.blocker_id)]);
    const swipedIds = Array.from(excludedSet);

    // 3. Get MY Interests
    const { data: myInterestsData } = await supabase.from('profile_interests').select('interest_id').eq('profile_id', user.id);
    const myInterests = (myInterestsData || []).map(i => i.interest_id);

    // 4. Fetch the unswiped pool (we fetch a larger batch to filter in memory)
    let poolQuery = supabase.from('profiles').select(`*, profile_interests ( interest_id, master_interests ( name ) )`);
    if (swipedIds.length > 0) poolQuery = poolQuery.not('id', 'in', `(${swipedIds.join(',')})`);
    if (filterExpectation) poolQuery = poolQuery.eq('expectations', filterExpectation);
    
    const { data: rawPool, error } = await poolQuery.limit(100);
    if (error) throw error;

    // 5. ALGORITHM: Calculate Distance, Age, and Shared Interests
    const scoredPool = [];
    
    for (const profile of (rawPool || [])) {
      // Age Calculation
      const age = profile.dob ? Math.floor((Date.now() - new Date(profile.dob).getTime()) / 31557600000) : 18;
      if (age < minAge || age > maxAge) continue; // Drop if outside age range

      // Distance Calculation (Haversine Formula)
      let distanceKm = 0;
      if (myLat && myLng && profile.lat && profile.lng) {
        const R = 6371; // Earth's radius in km
        const dLat = (profile.lat - myLat) * (Math.PI/180);
        const dLng = (profile.lng - myLng) * (Math.PI/180);
        const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(myLat * (Math.PI/180)) * Math.cos(profile.lat * (Math.PI/180)) * Math.sin(dLng/2) * Math.sin(dLng/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        distanceKm = Math.round(R * c);
      }
      
      // Drop if they are further away than user's preference!
      if (distanceKm > maxDistance) continue; 

      // Interests Math
      const theirInterests = profile.profile_interests || [];
      const theirInterestIds = theirInterests.map((pi: any) => pi.interest_id);
      const theirInterestNames = theirInterests.map((pi: any) => pi.master_interests?.name).filter(Boolean);
      const sharedCount = theirInterestIds.filter((id: number) => myInterests.includes(id)).length;

      scoredPool.push({
        id: profile.id,
        firstName: profile.first_name,
        age: age,
        location: profile.location,
        distance: distanceKm, 
        bio: profile.bio,
        expectations: profile.expectations,
        currentDateBid: profile.current_date_bid, // <--- ADD THIS LINE
        images: profile.images || [],
        interests: theirInterestNames,
        sharedInterestsCount: sharedCount 
      });
    }

    scoredPool.sort((a, b) => b.sharedInterestsCount - a.sharedInterestsCount);
    return c.json(scoredPool.slice(0, 20));
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

    // Fetching people who 'like'd the current user
    const { data, error } = await supabase
      .from('swipes')
      .select('swiper_id, profiles!swipes_swiper_id_fkey(*)') 
      .eq('swiped_id', user.id)
      .eq('action', 'like');

    if (error) throw error;
    
    // Map to just the profile objects
    const admirers = data.map((d: any) => d.profiles).filter(Boolean);
    return c.json(admirers);
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

    await supabase.from('swipes').insert({
      swiper_id: user.id,
      swiped_id: swiped_id,
      action: action
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
      .select('id, sender_id, content, created_at')
      .or(`and(sender_id.eq.${user.id},receiver_id.eq.${matchId}),and(sender_id.eq.${matchId},receiver_id.eq.${user.id})`)
      .order('created_at', { ascending: true }) // Oldest first (for chat UI)
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
app.post('/preferences', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { min_age, max_age, filter_expectation, max_distance } = await c.req.json();
    const { error } = await supabase.from('profiles').update({ 
        min_age: min_age, max_age: max_age, 
        max_distance: max_distance, // <--- Add this line to the update block
        filter_expectation: filter_expectation === 'Any' ? null : filter_expectation 
    }).eq('id', user.id);

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to update preferences' }, 500);
  }
});

// --- 8. ACCOUNT MANAGEMENT (Settings) ---
app.delete('/account', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // Hard delete the profile. (If you have CASCADE set up in Supabase, 
    // this automatically wipes their swipes, interests, and messages too).
    const { error } = await supabase.from('profiles').delete().eq('id', user.id);
    
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

    await supabase.from('profiles').update({ 
      lat: lat, 
      lng: lng, 
      location: city // Automatically updates their text location too!
    }).eq('id', user.id);

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to update location' }, 500);
  }
});

export default app;