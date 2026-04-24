import { ObjectId } from 'mongodb';
import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDb } from '../lib/db.js';

function sanitize(s) {
  return String(s || '').trim();
}

function parseJsonBody(event) {
  if (!event?.body) return null;
  try {
    return JSON.parse(event.body);
  } catch {
    return null;
  }
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const authResp = requireBasicAuth(event);
  if (authResp) return authResp;

  const method = event?.requestContext?.http?.method || 'GET';
  const id = event?.pathParameters?.id;

  try {
    const db = await getDb();
    const col = db.collection('sessions');

    if (method === 'GET') {
      const items = await col.find({}).sort({ createdAt: -1 }).limit(200).toArray();
      return json(200, {
        items: items.map((x) => ({
          id: String(x._id),
          name: x.name,
          createdAt: x.createdAt,
        })),
      });
    }

    if (method === 'POST') {
      const body = parseJsonBody(event) || {};
      const name = sanitize(body.name || body.session);

      if (!name) return json(400, { message: 'Missing session name' });

      const existing = await col.findOne({ name });
      if (existing) return json(409, { message: 'Session already exists' });

      const doc = {
        name,
        createdAt: new Date().toISOString(),
      };

      const res = await col.insertOne(doc);
      return json(201, { id: String(res.insertedId) });
    }

    if (method === 'DELETE') {
      if (!id) return json(400, { message: 'Missing id' });
      if (!ObjectId.isValid(id)) return json(400, { message: 'Invalid id' });

      const res = await col.deleteOne({ _id: new ObjectId(id) });
      if (!res.deletedCount) return json(404, { message: 'Not found' });
      return json(200, { ok: true });
    }

    return json(405, { message: 'Method not allowed' });
  } catch (e) {
    console.error('sessionsAdmin error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
