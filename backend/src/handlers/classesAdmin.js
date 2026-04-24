import { ObjectId } from 'mongodb';
import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDb } from '../lib/db.js';

function sanitize(s) {
  return String(s || '').trim();
}

function parseQueryString(qs) {
  const q = String(qs || '').replace(/^\?/, '');
  const out = {};
  if (!q) return out;
  q.split('&').forEach((pair) => {
    if (!pair) return;
    const idx = pair.indexOf('=');
    const k = idx >= 0 ? pair.slice(0, idx) : pair;
    const v = idx >= 0 ? pair.slice(idx + 1) : '';
    try {
      out[decodeURIComponent(k)] = decodeURIComponent(v.replace(/\+/g, ' '));
    } catch {
      out[k] = v;
    }
  });
  return out;
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
    const col = db.collection('classes');

    if (method === 'GET') {
      const q = parseQueryString(event?.rawQueryString);
      const session = sanitize(q.session);
      const filter = session ? { session } : {};
      const items = await col.find(filter).sort({ createdAt: -1 }).limit(500).toArray();
      return json(200, {
        items: items.map((x) => ({
          id: String(x._id),
          session: x.session,
          class: x.class,
          stream: x.stream,
          createdAt: x.createdAt,
        })),
      });
    }

    if (method === 'POST') {
      const body = parseJsonBody(event) || {};
      const session = sanitize(body.session);
      const klass = sanitize(body.class);
      const stream = sanitize(body.stream);

      if (!session || !klass || !stream) {
        return json(400, { message: 'Missing session/class/stream' });
      }

      const existing = await col.findOne({ session, class: klass, stream });
      if (existing) {
        return json(409, { message: 'Class/stream already exists for this session' });
      }

      const doc = {
        session,
        class: klass,
        stream,
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
    console.error('classesAdmin error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
