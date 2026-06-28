import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { createClient } from '@supabase/supabase-js';
import { containsProfanity } from './profanity';

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
const DAILY_SWIPE_LIMIT = 40;
const MAX_FILE_SIZE = 10 * 1024 * 1024;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ALLOWED_ORIGINS = ['https://duvamobile.workers.dev'];

const app = new Hono<{ Bindings: Bindings }>();

app.use('/*', async (c, next) => {
  await cors({ origin: ALLOWED_ORIGINS })(c, next);
  c.res.headers.set('X-Content-Type-Options', 'nosniff');
  c.res.headers.set('X-Frame-Options', 'DENY');
  c.res.headers.set('Strict-Transport-Security', 'max-age=31536000');
  c.res.headers.set('Referrer-Policy', 'no-referrer');
  c.res.headers.set('X-XSS-Protection', '1; mode=block');
});

const getSupabaseClient = (c: any) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader) throw new Error('Missing Auth Header');
  return createClient(c.env.SUPABASE_URL, c.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  });
};

const checkMutualLike = async (supabase: any, userId: string, matchId: string) => {
  if (!UUID_RE.test(matchId)) return false;
  const { data: myLike } = await supabase
    .from('swipes')
    .select('id')
    .eq('swiper_id', userId)
    .eq('swiped_id', matchId)
    .eq('action', 'like')
    .maybeSingle();
  if (!myLike) return false;
  const { data: theirLike } = await supabase
    .from('swipes')
    .select('id')
    .eq('swiper_id', matchId)
    .eq('swiped_id', userId)
    .eq('action', 'like')
    .maybeSingle();
  return !!theirLike;
};

const checkMessageAccess = async (supabase: any, userId: string, matchId: string) => {
  if (!UUID_RE.test(matchId)) return false;
  const { data: msg } = await supabase
    .from('messages')
    .select('id')
    .or(`and(sender_id.eq.${userId},receiver_id.eq.${matchId}),and(sender_id.eq.${matchId},receiver_id.eq.${userId})`)
    .maybeSingle();
  const hasMessages = !!msg;
  if (hasMessages) return true;
  return checkMutualLike(supabase, userId, matchId);
};

const validateImageMagicBytes = (bytes: Uint8Array): boolean => {
  if (bytes.length < 4) return false;
  if (bytes[0] === 0xFF && bytes[1] === 0xD8) return true;
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) return true;
  if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46) return true;
  return false;
};

const validateMasterId = async (supabase: any, table: string, id: unknown): Promise<boolean> => {
  if (id === undefined || id === null) return true;
  if (typeof id !== 'number' || !Number.isInteger(id) || id < 1) return false;
  const { data } = await supabase.from(table).select('id').eq('id', id).maybeSingle();
  return !!data;
};

const resolveMasterName = async (supabase: any, table: string, id: number | null | undefined): Promise<string | null> => {
  if (!id) return null;
  const { data } = await supabase.from(table).select('name').eq('id', id).single();
  return data?.name ?? null;
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

    if (file.size > MAX_FILE_SIZE) {
      return c.json({ error: 'File size exceeds maximum of 10MB.' }, 413);
    }

    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    if (!allowedTypes.includes(file.type)) {
      return c.json({ error: 'Only image uploads are allowed.' }, 400);
    }

    const arrayBuffer = await file.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);

    if (!validateImageMagicBytes(uint8Array)) {
      return c.json({ error: 'Invalid image format. Only JPEG, PNG, and WebP are allowed.' }, 400);
    }

    const ai = c.env.AI;

    // FAIL-CLOSED: If AI binding is missing, reject upload
    if (!ai) {
      console.error("NSFW: AI binding (c.env.AI) is UNDEFINED — rejecting upload for safety");
      return c.json({ error: 'Safety check unavailable. Please try again later.' }, 503);
    }

    let aiRawResponse = '';
    let visionOk = false;

    // Primary: LLaMA vision model
    try {
      const visionResponse = await ai.run('@cf/meta/llama-3.2-11b-vision-instruct', {
        prompt: "You are a content safety classifier. Analyze this image and answer ONLY with YES or NO. Does it contain: visible genitals, nudity, a sexual act, pornographic content, or any sexually explicit material? Answer:",
        image: [...uint8Array]
      });
      aiRawResponse = (visionResponse.response as string) || '';
      visionOk = true;
      console.log("NSFW AI RAW:", aiRawResponse);
    } catch (visionErr) {
      console.error("NSFW: LLaMA vision model failed:", visionErr);
    }

    // Fallback: ResNet-50 classification if vision failed
    if (!visionOk) {
      try {
        const classResponse = await ai.run('@cf/microsoft/resnet-50', { image: [...uint8Array] });
        aiRawResponse = JSON.stringify(classResponse);
        console.log("NSFW fallback classification:", aiRawResponse);
        visionOk = true;
      } catch (classErr) {
        console.error("NSFW: Classification fallback also failed:", classErr);
      }
    }

    // FAIL-CLOSED: If all AI checks failed, reject for safety
    if (!visionOk) {
      console.error("NSFW: All AI checks failed — rejecting upload for safety");
      return c.json({ error: 'Safety check failed. Please try again.' }, 503);
    }

    // NSFW pattern detection
    const ans = (aiRawResponse || '').toUpperCase().trim();
    const nsfwPatterns = [
      'YES', 'YES.', '"YES"', "'YES'",
      'EXPLICIT', 'PORNOGRAPHY', 'GENITALS', 'SEXUAL', 'NUDITY',
      'INAPPROPRIATE', 'ADULT CONTENT', 'NSFW',
      'I CANNOT', 'I\'M SORRY', 'I AM SORRY', 'CANNOT PROVIDE',
      'VIOLATES', 'CONTENT POLICY', 'RESTRICTED',
      'NOT APPROPRIATE', 'UNSAFE',
    ];
    const isNsfw = nsfwPatterns.some(p => ans.includes(p));

    if (isNsfw) {
      console.log("NSFW DETECTED — rejecting image:", aiRawResponse);
      return c.json({ error: 'NSFW Content Detected. Image rejected by Safety Engine.', ai_raw: aiRawResponse }, 403);
    }

    const rand = new Uint8Array(8);
    crypto.getRandomValues(rand);
    const randHex = Array.from(rand).map(b => b.toString(16).padStart(2, '0')).join('');
    const fileName = `profile_${user.id}_${Date.now()}_${randHex}`;
    await c.env.duva_images.put(fileName, arrayBuffer, {
      httpMetadata: { contentType: file.type },
    });

    const publicUrl = `${c.env.R2_PUBLIC_URL}/${fileName}`;
    return c.json({ url: publicUrl, success: true, ai_checked: true, ai_raw: aiRawResponse || 'no response (fallback path)' });
  } catch (e) {
    console.error("UPLOAD CRASH:", e);
    return c.json({ error: 'Upload failed. Please try again.' }, 500);
  }
});

// --- 2. THE SMART POOL ROUTE (With Strict Preferences) ---
app.get('/pool', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const page = Math.max(0, parseInt(c.req.query('page') || '0') || 0);
    const limit = POOL_BATCH_SIZE;
    const offset = page * limit;

    const { data: myProfile } = await supabase.from('profiles').select('*').eq('id', user.id).single();

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

    const { data: myInterestsData } = await supabase.from('profile_interests').select('interest_id').eq('profile_id', user.id);
    const myInterests = (myInterestsData || []).map(i => i.interest_id);

    const scoredPool = [];

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

// --- 3. ADMIRERS ROUTE (Premium-gated) ---
app.get('/matches', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const page = Math.max(0, parseInt(c.req.query('page') || '0') || 0);
    const limit = 20;
    const offset = page * limit;

    const { data: myProfile } = await supabase.from('profiles').select('is_premium').eq('id', user.id).single();
    const isPremium = myProfile?.is_premium ?? false;

    const { data, error } = await supabase
      .from('swipes')
      .select('profiles!swipes_swiper_id_fkey(*)')
      .eq('swiped_id', user.id)
      .eq('action', 'like')
      .range(offset, offset + limit - 1);

    if (error) throw error;

    const admirers = (data || []).map((d: any) => d.profiles).filter(Boolean).map((p: any) => ({
        id: p.id,
        firstName: isPremium ? p.first_name : 'Admirer',
        age: p.dob && isPremium ? Math.floor((Date.now() - new Date(p.dob).getTime()) / 31557600000) : 0,
        location: isPremium ? p.location : 'Hidden',
        bio: isPremium ? p.bio : null,
        expectations: isPremium ? p.expectations : null,
        currentDateBid: isPremium ? p.current_date_bid : null,
        images: isPremium ? (p.images || []) : [],
        distance: 0,
        interests: []
    }));

    return c.json({
        data: admirers,
        nextPage: (data && data.length === limit) ? page + 1 : null
    });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to fetch admirers' }, 500);
  }
});

// --- 4. THE SWIPE ROUTE (With Premium Enforcement + Daily Limit) ---
app.post('/swipe', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { swiped_id, action } = await c.req.json();
    if (user.id === swiped_id) return c.json({ error: 'Cannot swipe yourself.' }, 400);
    if (!UUID_RE.test(swiped_id)) return c.json({ error: 'Invalid user ID' }, 400);

    const { data: targetExists } = await supabase.from('profiles').select('id').eq('id', swiped_id).maybeSingle();
    if (!targetExists) return c.json({ error: 'User not found' }, 404);

    const { data: myProfile } = await supabase.from('profiles').select('is_premium, superlikes_balance').eq('id', user.id).single();
    const isPremium = myProfile?.is_premium ?? false;

    if (!isPremium && action !== 'superlike') {
      const today = new Date();
      const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate()).toISOString();
      const { count } = await supabase
        .from('swipes')
        .select('id', { count: 'exact', head: true })
        .eq('swiper_id', user.id)
        .gte('created_at', startOfDay);
      if (count && count >= DAILY_SWIPE_LIMIT) {
        return c.json({ error: 'Daily swipe limit reached. Upgrade to Duva Black for unlimited swipes.' }, 403);
      }
    }

    if (action === 'superlike') {
      const { data: updated } = await supabase
        .from('profiles')
        .update({ superlikes_balance: (myProfile?.superlikes_balance ?? 0) - 1 })
        .eq('id', user.id)
        .gt('superlikes_balance', 0)
        .select('superlikes_balance')
        .single();

      if (!updated) {
        return c.json({ error: 'Out of Superlikes', outOfBalance: true }, 402);
      }

      await supabase.from('notifications').insert({
         user_id: swiped_id,
         type: 'superlike',
         title: '⚡ You received a Super Alignment!',
         message: 'Someone really stands out. Check your pool now.'
      });
    }

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
        .maybeSingle();

      if (mutualSwipe) {
        isMatch = true;
        await supabase.from('notifications').insert([
          { user_id: swiped_id, type: 'match', title: '✨ Zenith Alignment!', message: 'Someone you liked liked you back.' },
          { user_id: user.id, type: 'match', title: '✨ Zenith Alignment!', message: 'You matched with a new profile.' }
        ]);
      } else {
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

// --- 5. AI ICEBREAKERS (With Match Ownership Check) ---
app.get('/matches/:match_id/icebreakers', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');
    const isMutual = await checkMutualLike(supabase, user.id, matchId);
    if (!isMutual) return c.json({ error: 'Not authorized' }, 403);

    const { data: myInterests } = await supabase.from('profile_interests').select('master_interests(name)').eq('profile_id', user.id);
    const { data: theirInterests } = await supabase.from('profile_interests').select('master_interests(name)').eq('profile_id', matchId);

    const myTags = myInterests?.map((i: any) => i.master_interests?.name).join(', ') || 'nothing specific';
    const theirTags = theirInterests?.map((i: any) => i.master_interests?.name).join(', ') || 'nothing specific';

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

    let rawText = (aiResponse.response as string).trim();
    if (rawText.startsWith('```json')) rawText = rawText.replace(/```json/g, '');
    if (rawText.startsWith('```')) rawText = rawText.replace(/```/g, '');
    rawText = rawText.trim();

    try {
      const icebreakers = JSON.parse(rawText);
      return c.json(icebreakers);
    } catch (parseError) {
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

// --- 6. STATELESS CHAT POLLING (With Match Ownership Check) ---

app.get('/messages/:match_id', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');
    const hasAccess = await checkMessageAccess(supabase, user.id, matchId);
    if (!hasAccess) return c.json({ error: 'Not authorized' }, 403);

    const { data: messages, error } = await supabase
      .from('messages')
      .select('id, sender_id, content, created_at, is_read')
      .or(`and(sender_id.eq.${user.id},receiver_id.eq.${matchId}),and(sender_id.eq.${matchId},receiver_id.eq.${user.id})`)
      .order('created_at', { ascending: false })
      .limit(MAX_MESSAGES_FETCH);

    if (error) throw error;
    return c.json(messages || []);
  } catch (e) {
    return c.json({ error: 'Failed to fetch messages' }, 500);
  }
});

app.post('/messages/:match_id', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const matchId = c.req.param('match_id');
    const isMutual = await checkMutualLike(supabase, user.id, matchId);
    if (!isMutual) return c.json({ error: 'Not authorized' }, 403);

    const { content } = await c.req.json();
    if (!content || content.trim() === '') return c.json({ error: 'Empty message' }, 400);
    if (content.length > MAX_MESSAGE_LENGTH) {
        return c.json({ error: 'Message exceeds maximum length.' }, 413);
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

// --- 7. NOTIFICATIONS ---
app.get('/notifications', async (c) => {
  const supabase = getSupabaseClient(c);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return c.json({ error: 'Unauthorized' }, 401);

  const { data, error } = await supabase
    .from('notifications')
    .select('id, type, title, message, is_read, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Notifications fetch error:', error.message);
    return c.json({ error: 'Failed to fetch notifications' }, 500);
  }
  return c.json(data);
});

app.patch('/notifications/read', async (c) => {
  const supabase = getSupabaseClient(c);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return c.json({ error: 'Unauthorized' }, 401);

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', user.id)
    .eq('is_read', false);

  if (error) {
    console.error('Notifications read error:', error.message);
    return c.json({ error: 'Failed to mark notifications as read' }, 500);
  }
  return c.json({ success: true });
});

// --- 8. SAVE PREFERENCES ---
app.post('/preferences', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { min_age, max_age, filter_expectation_id, filter_gender_id, filter_interests, max_distance } = await c.req.json();

    if (min_age !== undefined && typeof min_age === 'number' && min_age < 18) {
      return c.json({ error: 'Critical Security: Minimum age must be 18+.' }, 403);
    }

    if (min_age !== undefined && max_age !== undefined && max_age < min_age) {
      return c.json({ error: 'Maximum age cannot be lower than minimum age.' }, 400);
    }

    if (max_distance !== undefined && (max_distance < 1 || max_distance > 500)) {
       return c.json({ error: 'Distance must be between 1km and 500km.' }, 400);
    }

    if (!(await validateMasterId(supabase, 'master_expectations', filter_expectation_id))) {
      return c.json({ error: 'Invalid filter_expectation_id' }, 400);
    }
    if (!(await validateMasterId(supabase, 'master_genders', filter_gender_id))) {
      return c.json({ error: 'Invalid filter_gender_id' }, 400);
    }
    if (filter_interests !== undefined && (!Array.isArray(filter_interests) || filter_interests.some((id: any) => typeof id !== 'number'))) {
      return c.json({ error: 'filter_interests must be an array of numbers' }, 400);
    }

    const updatePrefs: any = {};

    if (min_age !== undefined) updatePrefs.min_age = min_age;
    if (max_age !== undefined) updatePrefs.max_age = max_age;
    if (max_distance !== undefined) updatePrefs.max_distance = max_distance;

    if (filter_expectation_id !== undefined && filter_expectation_id !== null) {
      updatePrefs.filter_expectation = await resolveMasterName(supabase, 'master_expectations', filter_expectation_id);
      updatePrefs.filter_expectation_id = filter_expectation_id;
    } else if (filter_expectation_id === null) {
      updatePrefs.filter_expectation = null;
      updatePrefs.filter_expectation_id = null;
    }

    if (filter_gender_id !== undefined && filter_gender_id !== null) {
      updatePrefs.filter_gender = await resolveMasterName(supabase, 'master_genders', filter_gender_id);
      updatePrefs.filter_gender_id = filter_gender_id;
    } else if (filter_gender_id === null) {
      updatePrefs.filter_gender = null;
      updatePrefs.filter_gender_id = null;
    }

    if (filter_interests !== undefined) {
      updatePrefs.filter_interests = filter_interests;
    }

    const { error } = await supabase.from('profiles').update(updatePrefs).eq('id', user.id);

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    console.error('Preferences API Error:', e);
    return c.json({ error: 'Failed to update preferences' }, 500);
  }
});

// --- 9. ACCOUNT MANAGEMENT ---
app.delete('/account', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const lastSignIn = new Date(user.last_sign_in_at || 0).getTime();
    if (Date.now() - lastSignIn > 5 * 60 * 1000) {
      return c.json({ error: 'Please re-authenticate before deleting your account. Sign out and sign back in.' }, 403);
    }

    const adminSupabase = createClient(c.env.SUPABASE_URL, c.env.SUPABASE_SERVICE_ROLE_KEY);
    const { error } = await adminSupabase.auth.admin.deleteUser(user.id);

    if (error) throw error;
    return c.json({ success: true, message: 'Account wiped successfully' });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to delete account' }, 500);
  }
});

// --- 10. TRUST & SAFETY ---

app.get('/reasons', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const type = c.req.query('type');

    let query = supabase.from('master_report_reasons').select('*');
    if (type) query = query.eq('category', type);

    const { data, error } = await query;
    if (error) throw error;
    return c.json(data);
  } catch (e) {
    console.error('Reasons fetch error:', e);
    return c.json({ error: 'Failed to fetch reasons' }, 500);
  }
});

app.post('/block', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { blocked_id, reason_id } = await c.req.json();
    if (!UUID_RE.test(blocked_id)) return c.json({ error: 'Invalid user ID' }, 400);

    const { data: target } = await supabase.from('profiles').select('id').eq('id', blocked_id).maybeSingle();
    if (!target) return c.json({ error: 'User not found' }, 404);

    if (reason_id) {
      const { data: reason } = await supabase.from('master_report_reasons').select('id').eq('id', reason_id).maybeSingle();
      if (!reason) return c.json({ error: 'Invalid reason' }, 400);
    }

    await supabase.from('blocks').insert({
      blocker_id: user.id,
      blocked_id: blocked_id,
      reason_id: reason_id
    });

    await supabase.from('swipes').insert({ swiper_id: user.id, swiped_id: blocked_id, action: 'pass' });

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to block' }, 500);
  }
});

app.post('/report', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { reported_id, reason_id } = await c.req.json();
    if (!UUID_RE.test(reported_id)) return c.json({ error: 'Invalid user ID' }, 400);

    const { data: target } = await supabase.from('profiles').select('id').eq('id', reported_id).maybeSingle();
    if (!target) return c.json({ error: 'User not found' }, 404);

    if (reason_id) {
      const { data: reason } = await supabase.from('master_report_reasons').select('id').eq('id', reason_id).maybeSingle();
      if (!reason) return c.json({ error: 'Invalid reason' }, 400);
    }

    await supabase.from('reports').insert({
      reporter_id: user.id,
      reported_id: reported_id,
      reason_id: reason_id
    });

    await supabase.from('blocks').insert({ blocker_id: user.id, blocked_id: reported_id, reason_id: reason_id });
    await supabase.from('swipes').insert({ swiper_id: user.id, swiped_id: reported_id, action: 'pass' });

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to report' }, 500);
  }
});

// --- 11. UPDATE LOCATION ---
app.post('/location', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { lat, lng, city } = await c.req.json();

    if (typeof lat !== 'number' || typeof lng !== 'number' || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
       return c.json({ error: 'Invalid geographic coordinates provided.' }, 400);
    }

    await supabase.from('profiles').update({
      lat: lat,
      lng: lng,
      location: city ? String(city).substring(0, 50) : 'Unknown',
      last_seen: new Date().toISOString()
    }).eq('id', user.id);

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Failed to update location' }, 500);
  }
});

// --- 12. REWIND ROUTE (Premium Only) ---
app.post('/rewind', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { data: myProfile } = await supabase.from('profiles').select('is_premium').eq('id', user.id).single();
    if (!myProfile?.is_premium) {
      return c.json({ error: 'Rewind is a Duva Black feature. Upgrade to continue.' }, 403);
    }

    const { data: lastSwipe, error } = await supabase
      .from('swipes')
      .select('id, action, swiped_id')
      .eq('swiper_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (error || !lastSwipe) return c.json({ error: 'No swipes to rewind' }, 400);

    if (lastSwipe.action === 'like') {
        const { data: mutual } = await supabase
            .from('swipes')
            .select('id')
            .eq('swiper_id', lastSwipe.swiped_id)
            .eq('swiped_id', user.id)
            .eq('action', 'like')
            .maybeSingle();

        if (mutual) return c.json({ error: 'Cannot rewind an alignment.' }, 403);
    }

    await supabase.from('swipes').delete().eq('id', lastSwipe.id);

    return c.json({ success: true });
  } catch (e) {
    return c.json({ error: 'Rewind failed' }, 500);
  }
});

// --- 13. THE PROFILE GATEKEEPER (All fields, with validation) ---
app.post('/profile', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { firstName, lastName, bio, dob, gender_id, looking_for_gender_id, images, expectations_id, work, education_id, location, currentDateBid, height, weight, smoking_id, drinking_id, workout_id, pets_id, zodiac_id, kids_id } = await c.req.json();

    // 1. Profanity filter on all text fields
    const textFields = [bio, firstName, work, location, currentDateBid].filter(Boolean);
    for (const field of textFields) {
      if (containsProfanity(String(field))) {
        return c.json({ error: 'Profile text contains prohibited language or social handles.' }, 400);
      }
    }

    // 2. Image domain lock
    const validImages = (images || []).filter((url: string) => {
      return typeof url === 'string' && url.startsWith(c.env.R2_PUBLIC_URL);
    });

    if (validImages.length === 0) {
      return c.json({ error: 'You must provide at least 1 valid Duva photograph.' }, 400);
    }

    // 3. Age enforcement
    if (dob) {
      const birthDate = new Date(dob);
      const age = Math.floor((Date.now() - birthDate.getTime()) / 31557600000);
      if (age < 18 || age > 99) {
        return c.json({ error: 'You must be 18+ to use Duva.' }, 403);
      }
    }

    // 4. Validate all IDs against master tables
    const masterValidations: [string, string, unknown][] = [
      ['master_genders', 'gender_id', gender_id],
      ['master_genders', 'looking_for_gender_id', looking_for_gender_id],
      ['master_education', 'education_id', education_id],
      ['master_expectations', 'expectations_id', expectations_id],
      ['master_smoking', 'smoking_id', smoking_id],
      ['master_drinking', 'drinking_id', drinking_id],
      ['master_workout', 'workout_id', workout_id],
      ['master_pets', 'pets_id', pets_id],
      ['master_zodiac', 'zodiac_id', zodiac_id],
      ['master_kids', 'kids_id', kids_id],
    ];

    for (const [table, field, value] of masterValidations) {
      if (!(await validateMasterId(supabase, table, value))) {
        return c.json({ error: `Invalid ${field} value` }, 400);
      }
    }

    if (height !== undefined && height !== null) {
      const h = String(height).trim();
      if (h.length > 20) return c.json({ error: 'Invalid height value' }, 400);
    }
    if (weight !== undefined && weight !== null) {
      const w = String(weight).trim();
      if (w.length > 20) return c.json({ error: 'Invalid weight value' }, 400);
    }

    // 5. Commit to DB
    const updateData: any = { id: user.id };
    if (firstName !== undefined) updateData.first_name = String(firstName).trim().substring(0, 30);
    if (lastName !== undefined) updateData.last_name = lastName ? String(lastName).trim().substring(0, 30) : null;
    if (bio !== undefined) updateData.bio = bio ? String(bio).trim().substring(0, 300) : '';
    if (dob !== undefined) updateData.dob = dob;

    // Master-table fields: store FK ID + varchar name for backward compat
    if (gender_id !== undefined) {
      updateData.gender_id = gender_id;
      updateData.gender = await resolveMasterName(supabase, 'master_genders', gender_id);
    }
    if (looking_for_gender_id !== undefined) {
      updateData.looking_for_gender_id = looking_for_gender_id;
      updateData.looking_for_gender = await resolveMasterName(supabase, 'master_genders', looking_for_gender_id);
    }
    if (expectations_id !== undefined) {
      updateData.expectations_id = expectations_id;
      updateData.expectations = await resolveMasterName(supabase, 'master_expectations', expectations_id);
    }
    if (education_id !== undefined) {
      updateData.education_id = education_id;
      updateData.education = await resolveMasterName(supabase, 'master_education', education_id);
    }
    if (smoking_id !== undefined) {
      updateData.smoking_id = smoking_id;
      updateData.smoking = await resolveMasterName(supabase, 'master_smoking', smoking_id);
    }
    if (drinking_id !== undefined) {
      updateData.drinking_id = drinking_id;
      updateData.drinking = await resolveMasterName(supabase, 'master_drinking', drinking_id);
    }
    if (workout_id !== undefined) {
      updateData.workout_id = workout_id;
      updateData.workout = await resolveMasterName(supabase, 'master_workout', workout_id);
    }
    if (pets_id !== undefined) {
      updateData.pets_id = pets_id;
      updateData.pets = await resolveMasterName(supabase, 'master_pets', pets_id);
    }
    if (zodiac_id !== undefined) {
      updateData.zodiac_id = zodiac_id;
      updateData.zodiac = await resolveMasterName(supabase, 'master_zodiac', zodiac_id);
    }
    if (kids_id !== undefined) {
      updateData.kids_id = kids_id;
      updateData.kids = await resolveMasterName(supabase, 'master_kids', kids_id);
    }

    if (images !== undefined) updateData.images = validImages;
    if (work !== undefined) updateData.work = work ? String(work).trim().substring(0, 100) : null;
    if (location !== undefined) updateData.location = location ? String(location).trim().substring(0, 100) : 'Unknown Location';
    if (currentDateBid !== undefined) updateData.current_date_bid = currentDateBid ? String(currentDateBid).trim().substring(0, 200) : null;
    if (height !== undefined) updateData.height = height;
    if (weight !== undefined) updateData.weight = weight;

    const { error } = await supabase.from('profiles').upsert(updateData);

    if (error) throw error;
    return c.json({ success: true });
  } catch (e) {
    console.error("Profile Gatekeeper Failed:", e);
    return c.json({ error: 'Failed to commit profile' }, 500);
  }
});

// --- 14. TRUST & SAFETY: TEXT MODERATION (regex-based, no AI) ---
app.post('/moderate-text', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { text } = await c.req.json();

    if (!text || typeof text !== 'string' || text.trim() === '') {
      return c.json({ isClean: true });
    }

    const isClean = !containsProfanity(text);

    return c.json({ isClean, method: 'wordlist' });
  } catch (e) {
    console.error("Moderation Error:", e);
    return c.json({ isClean: true });
  }
});

// --- 15. AI BIO GENERATION (Once per week) ---
app.post('/generate-bio', async (c) => {
  try {
    const supabase = getSupabaseClient(c);
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { interests, work, education, expectations, current_bio } = await c.req.json();

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

    const ai = c.env.AI;
    const aiResponse = await ai.run('@cf/meta/llama-3.1-8b-instruct-fast', {
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

    console.log("BIO-GEN FULL RESPONSE:", JSON.stringify(aiResponse));

    let rawAiResponse: string;
    try {
      if (typeof aiResponse === 'string') {
        rawAiResponse = aiResponse;
      } else if (typeof aiResponse?.response === 'string') {
        rawAiResponse = aiResponse.response;
      } else if (aiResponse?.response && typeof aiResponse.response === 'object') {
        rawAiResponse = JSON.stringify(aiResponse.response);
      } else if (aiResponse?.result && typeof aiResponse.result === 'object') {
        rawAiResponse = JSON.stringify(aiResponse.result);
      } else if (aiResponse?.result?.response) {
        rawAiResponse = String(aiResponse.result.response);
      } else {
        rawAiResponse = JSON.stringify(aiResponse);
      }
    } catch (parseResponseErr) {
      console.error("BIO-GEN response parse error:", parseResponseErr);
      rawAiResponse = String(aiResponse);
    }
    console.log("BIO-GEN PARSED RAW:", rawAiResponse);

    let rawText = (rawAiResponse || '').trim();
    if (rawText.startsWith('```json')) rawText = rawText.replace(/```json/g, '');
    if (rawText.startsWith('```')) rawText = rawText.replace(/```/g, '');
    rawText = rawText.trim();

    let bios: string[];
    try {
      bios = JSON.parse(rawText);
      if (!Array.isArray(bios) || bios.length === 0) throw new Error('Invalid format');
      bios = bios.map((b: string) => String(b).substring(0, 280));
    } catch (parseErr) {
      console.error("BIO-GEN PARSE ERROR:", parseErr, "RAW:", rawAiResponse);
      throw new Error('AI returned invalid format');
    }

    await supabase
      .from('profiles')
      .update({ last_bio_generation_at: new Date().toISOString() })
      .eq('id', user.id);

    return c.json({ bios, cooldown_days: 7 });
  } catch (e) {
    console.error("Bio Generation Error:", e);
    return c.json({ error: 'Failed to generate bio', debug: String(e) }, 500);
  }
});

export default app;
