import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { createClient } from '@supabase/supabase-js';

type Bindings = {
  duva_images: R2Bucket;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  R2_PUBLIC_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
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

    const formData = await c.req.formData();
    const file = formData.get('image');
    
    if (!file || !(file instanceof File)) {
      return c.json({ error: 'Invalid file or no file uploaded' }, 400);
    }

    // ✅ FIX: Strict Image Validation
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    if (!allowedTypes.includes(file.type)) {
      return c.json({ error: 'Only image uploads (JPEG, PNG, WEBP, HEIC) are allowed.' }, 400);
    }

    // (Rest of the upload code remains the same...)

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
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // ✅ NEW: Read pagination from URL query params (e.g. /pool?page=0)
    const page = parseInt(c.req.query('page') || '0');
    const limit = 15; // 15 users per swipe batch
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
    
    // We only iterate over 15 users now! Extremely fast.
    for (const profile of (rawPool || [])) {
      // (Optional) Fetch their interests here, or join it in the RPC
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
        sharedInterestsCount: sharedCount 
      });
    }

    // Sort the 15 users by shared interests
    scoredPool.sort((a, b) => b.sharedInterestsCount - a.sharedInterestsCount);
    
    return c.json({ data: scoredPool, nextPage: rawPool.length === limit ? page + 1 : null });
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

    const { data, error } = await supabase
      .from('swipes')
      .select('profiles!swipes_swiper_id_fkey(*)') 
      .eq('swiped_id', user.id)
      .eq('action', 'like');

    if (error) throw error;
    
    // ✅ FIX: Map snake_case to camelCase so Flutter doesn't crash
    const admirers = data.map((d: any) => d.profiles).filter(Boolean).map((p: any) => ({
        id: p.id,
        firstName: p.first_name,
        // Calculate age on the fly
        age: p.dob ? Math.floor((Date.now() - new Date(p.dob).getTime()) / 31557600000) : 18,
        location: p.location,
        bio: p.bio,
        expectations: p.expectations,
        currentDateBid: p.current_date_bid, // Snake to Camel
        images: p.images || [],
        distance: 0, // Placeholder unless you calculate distance to admirers
        interests: [] 
    }));

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
      location: city ? String(city).substring(0, 50) : 'Unknown' // Prevent massive string injection
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

export default app;