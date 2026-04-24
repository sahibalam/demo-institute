import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const q = event?.queryStringParameters || {};
  const filter = {};

  if (q.class) filter.class = String(q.class);
  if (q.section) filter.section = String(q.section);

  try {
    const db = await getDb();
    const items = await db
      .collection('timetables')
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(200)
      .toArray();

    return json(200, {
      items: items.map((x) => ({
        id: String(x._id),
        class: x.class,
        section: x.section,
        title: x.title || '',
        fileName: x.fileName,
        fileId: x.fileId,
        webViewLink: x.webViewLink,
        webContentLink: x.webContentLink,
        createdAt: x.createdAt,
      })),
    });
  } catch (e) {
    console.error('timetablesPublic error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
