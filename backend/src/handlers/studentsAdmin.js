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

function pickStatus(s) {
  const v = sanitize(s).toLowerCase();
  if (v === 'active' || v === 'inactive') return v;
  return '';
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const authResp = requireBasicAuth(event);
  if (authResp) return authResp;

  const method = event?.requestContext?.http?.method || 'GET';
  const id = event?.pathParameters?.id;

  try {
    const db = await getDb();
    const col = db.collection('students');

    if (method === 'GET') {
      const items = await col.find({}).sort({ createdAt: -1 }).limit(2000).toArray();
      return json(200, {
        items: items.map((x) => ({
          id: String(x._id),
          studentId: x.studentId || '',
          joiningDate: x.joiningDate || x.createdAt || '',
          name: x.name || '',
          class: x.class || '',
          stream: x.stream || '',
          number: x.number || '',
          address: x.address || '',
          photoBase64: x.photoBase64 || '',
          status: x.status || 'active',
          createdAt: x.createdAt || '',
          updatedAt: x.updatedAt || '',
        })),
      });
    }

    if (method === 'PATCH') {
      if (!id) return json(400, { message: 'Missing id' });
      if (!ObjectId.isValid(id)) return json(400, { message: 'Invalid id' });

      const body = parseJsonBody(event) || {};
      const update = {};

      if ('studentId' in body) update.studentId = sanitize(body.studentId);
      if ('joiningDate' in body) update.joiningDate = sanitize(body.joiningDate);
      if ('name' in body) update.name = sanitize(body.name);
      if ('class' in body) update.class = sanitize(body.class);
      if ('stream' in body) update.stream = sanitize(body.stream);
      if ('number' in body) update.number = sanitize(body.number);
      if ('address' in body) update.address = sanitize(body.address);
      if ('status' in body) {
        const st = pickStatus(body.status);
        if (!st) return json(400, { message: 'Invalid status (use active/inactive)' });
        update.status = st;
      }

      update.updatedAt = new Date().toISOString();

      const res = await col.updateOne({ _id: new ObjectId(id) }, { $set: update });
      if (!res.matchedCount) return json(404, { message: 'Not found' });
      return json(200, { ok: true });
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
    console.error('studentsAdmin error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
