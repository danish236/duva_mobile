import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { createClient } from '@supabase/supabase-js';

type Bindings = {
  duva_images: R2Bucket;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
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

    const body = await c.req.parseBody();
    const file = body['image'];
    if (!file || !(file instanceof File)) return c.json({ error: 'Invalid file' }, 400);

    const fileName = `profile_${user.id}_${Date.now()}`;
    await c.env.duva_images.put(fileName, await file.arrayBuffer(), {
      httpMetadata: { contentType: file.type },
    });

    // Replace with your R2 Public Dev URL ID
    const publicUrl = `https://pub-<YOUR_R2_DEV_ID>.r2.dev/${fileName}`; 
    return c.json({ url: publicUrl, success: true });
  } catch (e) {
    return c.json({ error: 'Upload failed' }, 500);
  }
});

// --- 2. THE SMART POOL ROUTE (BASIC MATCHING) ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // 1. Get IDs of people I've already swiped on so I don't see them again
    const { data: swipes } = await supabase.from('swipes').select('swiped_id').eq('swiper_id', user.id);
    const swipedIds = (swipes || []).map(s => s.swiped_id);
    swipedIds.push(user.id); // Add my own ID so I don't swipe on myself

    // 2. Get MY specific interests
    const { data: myInterestsData } = await supabase.from('profile_interests').select('interest_id').eq('profile_id', user.id);
    const myInterests = (myInterestsData || []).map(i => i.interest_id);

    // 3. Fetch the unswiped pool WITH their joined interests
    let poolQuery = supabase.from('profiles').select(`
      *,
      profile_interests ( interest_id, master_interests ( name ) )
    `);
    
    // Safely exclude people we've swiped on
    if (swipedIds.length > 0) {
      poolQuery = poolQuery.not('id', 'in', `(${swipedIds.join(',')})`);
    }

    const { data: rawPool, error } = await poolQuery.limit(20);
    if (error) throw error;

    // 4. ALGORITHM: Calculate Shared Interests & Format Data
    const scoredPool = (rawPool || []).map(profile => {
      const theirInterests = profile.profile_interests || [];
      const theirInterestIds = theirInterests.map((pi: any) => pi.interest_id);
      const theirInterestNames = theirInterests.map((pi: any) => pi.master_interests?.name).filter(Boolean);
      
      // Count how many overlapping IDs exist
      const sharedCount = theirInterestIds.filter((id: number) => myInterests.includes(id)).length;
      
      // Calculate Age from DOB
      const age = profile.dob ? Math.floor((Date.now() - new Date(profile.dob).getTime()) / 31557600000) : 18;

      return {
        id: profile.id,
        firstName: profile.first_name, // Map to camelCase for Flutter
        age: age,
        location: profile.location,
        bio: profile.bio,
        work: profile.work,
        education: profile.education,
        expectations: profile.expectations,
        images: profile.images || [],
        interests: theirInterestNames,
        sharedInterestsCount: sharedCount // Send the score to the frontend!
      };
    });

    // 5. Sort the pool so people with the MOST shared interests appear first
    scoredPool.sort((a, b) => b.sharedInterestsCount - a.sharedInterestsCount);

    return c.json(scoredPool);
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to fetch pool' }, 500);
  }
});

// --- 3. THE SWIPE ROUTE ---
app.post('/swipe', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { swiped_id, action } = await c.req.json(); // action is 'like' or 'pass'

    // Insert the swipe
    await supabase.from('swipes').insert({
      swiper_id: user.id,
      swiped_id: swiped_id,
      action: action
    });

    // If it's a 'like', check for a mutual match
    let isMatch = false;
    if (action === 'like') {
      const { data: mutualSwipe } = await supabase
        .from('swipes')
        .select('id')
        .eq('swiper_id', swiped_id)
        .eq('swiped_id', user.id)
        .eq('action', 'like')
        .single();
        
      if (mutualSwipe) isMatch = true;
    }

    return c.json({ success: true, isMatch });
  } catch (e) {
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

export default app;