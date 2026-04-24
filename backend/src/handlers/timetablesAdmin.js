import { ObjectId } from 'mongodb';
import parser from 'lambda-multipart-parser';
import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDb } from '../lib/db.js';
import { uploadPdfToDrive } from '../lib/drive.js';

function sanitize(s) {
  return String(s || '').trim();
}

function normalizeClass(s) {
  const v = sanitize(s);
  if (!v) return '';
  return v.toLowerCase().includes('12') && v.toLowerCase().includes('pass') ? '12pass' : v;
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const authResp = requireBasicAuth(event);
  if (authResp) return authResp;

  const method = event?.requestContext?.http?.method || 'GET';
  const id = event?.pathParameters?.id;

  try {
    const db = await getDb();
    const col = db.collection('timetables');

    if (method === 'GET') {
      const items = await col.find({}).sort({ createdAt: -1 }).limit(500).toArray();
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
    }

    if (method === 'POST') {
      const parsed = await parser.parse(event);
      const fields = parsed?.fields && typeof parsed.fields === 'object' ? parsed.fields : parsed;
      const file = Array.isArray(parsed?.files) ? parsed.files[0] : null;

      if (!file?.content) return json(400, { message: 'Missing PDF file' });
      if (!String(file.contentType || '').toLowerCase().includes('pdf')) {
        return json(400, { message: 'Only PDF is allowed' });
      }

      const klass = normalizeClass(fields?.class);
      const section = sanitize(fields?.section);
      const title = sanitize(fields?.title) || '';

      if (!klass || !section) {
        return json(400, { message: 'Missing class/section' });
      }

      const safeFileName = sanitize(file.filename) || `${klass}-${section}-timetable.pdf`;

      const up = await uploadPdfToDrive({
        fileName: safeFileName,
        mimeType: file.contentType || 'application/pdf',
        buffer: Buffer.from(file.content),
      });

      const doc = {
        class: klass,
        section,
        title,
        fileName: safeFileName,
        fileId: up.id,
        webViewLink: up.webViewLink || '',
        webContentLink: up.webContentLink || '',
        createdAt: new Date().toISOString(),
      };

      const res = await col.insertOne(doc);
      return json(201, {
        id: String(res.insertedId),
        fileId: up.id,
        webViewLink: up.webViewLink,
        webContentLink: up.webContentLink,
      });
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
    console.error('timetablesAdmin error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
