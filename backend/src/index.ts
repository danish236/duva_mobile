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

// --- 2. THE SMART POOL ROUTE ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // Call Supabase: Get profiles where ID is not me, and not in my swipes table
    const { data, error } = await supabase.rpc('get_unswiped_profiles', { 
      my_id: user.id 
    });

    if (error) throw error;
    return c.json(data);
  } catch (e) {
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

export default app;