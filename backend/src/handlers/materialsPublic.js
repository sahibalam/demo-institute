import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const q = event?.queryStringParameters || {};
  const filter = {};

  if (q.category) filter.category = String(q.category);
  if (q.class) filter.class = String(q.class);
  if (q.section) filter.section = String(q.section);
  if (q.subject) filter.subject = String(q.subject);
  if (q.year) filter.year = String(q.year);

  try {
    const db = await getDb();
    const items = await db
      .collection('materials')
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(200)
      .toArray();

    return json(200, {
      items: items.map((x) => ({
        id: String(x._id),
        category: x.category || 'materials',
        class: x.class,
        section: x.section,
        subject: x.subject,
        year: x.year || '',
        chapter: x.chapter || '',
        title: x.title,
        fileName: x.fileName,
        fileId: x.fileId,
        webViewLink: x.webViewLink,
        webContentLink: x.webContentLink,
        createdAt: x.createdAt,
      })),
    });
  } catch (e) {
    console.error('materialsPublic error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
