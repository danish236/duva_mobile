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

// --- 2. THE SMART POOL ROUTE (With Strict Preferences) ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // 1. Get My Profile (for my preferences)
    const { data: myProfile } = await supabase.from('profiles').select('min_age, max_age, filter_expectation').eq('id', user.id).single();
    const minAge = myProfile?.min_age || 18;
    const maxAge = myProfile?.max_age || 65;
    const filterExpectation = myProfile?.filter_expectation;

    // 2. Get IDs of people I've already swiped on
    const { data: swipes } = await supabase.from('swipes').select('swiped_id').eq('swiper_id', user.id);
    const swipedIds = (swipes || []).map(s => s.swiped_id);
    swipedIds.push(user.id);

    // 3. Get MY specific interests
    const { data: myInterestsData } = await supabase.from('profile_interests').select('interest_id').eq('profile_id', user.id);
    const myInterests = (myInterestsData || []).map(i => i.interest_id);

    // 4. Fetch the unswiped pool
    let poolQuery = supabase.from('profiles').select(`*, profile_interests ( interest_id, master_interests ( name ) )`);
    if (swipedIds.length > 0) poolQuery = poolQuery.not('id', 'in', `(${swipedIds.join(',')})`);
    
    // APPLY EXPECTATION FILTER AT DATABASE LEVEL
    if (filterExpectation) poolQuery = poolQuery.eq('expectations', filterExpectation);

    const { data: rawPool, error } = await poolQuery.limit(50);
    if (error) throw error;

    // 5. ALGORITHM: Filter Age & Calculate Shared Interests
    const scoredPool = (rawPool || [])
      .map(profile => {
        const theirInterests = profile.profile_interests || [];
        const theirInterestIds = theirInterests.map((pi: any) => pi.interest_id);
        const theirInterestNames = theirInterests.map((pi: any) => pi.master_interests?.name).filter(Boolean);
        const sharedCount = theirInterestIds.filter((id: number) => myInterests.includes(id)).length;
        const age = profile.dob ? Math.floor((Date.now() - new Date(profile.dob).getTime()) / 31557600000) : 18;

        return {
          id: profile.id,
          firstName: profile.first_name,
          age: age,
          location: profile.location,
          bio: profile.bio,
          expectations: profile.expectations,
          images: profile.images || [],
          interests: theirInterestNames,
          sharedInterestsCount: sharedCount 
        };
      })
      // APPLY AGE FILTER IN MEMORY (Since age is dynamic based on DOB)
      .filter(profile => profile.age >= minAge && profile.age <= maxAge);

    scoredPool.sort((a, b) => b.sharedInterestsCount - a.sharedInterestsCount);
    return c.json(scoredPool.slice(0, 20)); // Return top 20 matches
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to fetch pool' }, 500);
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

// --- 6. FETCH NOTIFICATIONS ---
app.get('/notifications', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { data: notifications, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) throw error;
    return c.json(notifications || []);
  } catch (e) {
    return c.json({ error: 'Failed to fetch notifications' }, 500);
  }
});

// --- 7. SAVE PREFERENCES ---
app.post('/preferences', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { min_age, max_age, filter_expectation } = await c.req.json();

    const { error } = await supabase
      .from('profiles')
      .update({ 
        min_age: min_age, 
        max_age: max_age, 
        filter_expectation: filter_expectation === 'Any' ? null : filter_expectation 
      })
      .eq('id', user.id);

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

export default app;