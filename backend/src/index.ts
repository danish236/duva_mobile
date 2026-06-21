import { Hono } from 'hono';
import { cors } from 'hono/cors';

// UPDATED: Match the binding name Wrangler just put in your wrangler.jsonc
type Bindings = {
  duva_images: R2Bucket; 
};

const app = new Hono<{ Bindings: Bindings }>();

app.use('/*', cors());

app.get('/', (c) => c.text('Duva API is running!'));

app.post('/upload', async (c) => {
  try {
    const body = await c.req.parseBody();
    const file = body['image'];

    if (!file || !(file instanceof File)) {
      return c.json({ error: 'No valid image file uploaded' }, 400);
    }

    const uniqueId = crypto.randomUUID();
    const fileName = `profile_${Date.now()}_${uniqueId}`;

    // UPDATED: Use the new binding name here
    await c.env.duva_images.put(fileName, await file.arrayBuffer(), {
      httpMetadata: { contentType: file.type },
    });

    // We will update this URL format once you enable Public Access below
    const publicUrl = `https://pub-14d6730afe75454abee3a5b34ad3e194.r2.dev.r2.dev/${fileName}`; 

    return c.json({ url: publicUrl, success: true });

  } catch (error) {
    console.error('Upload error:', error);
    return c.json({ error: 'Failed to upload image' }, 500);
  }
});

export default app;