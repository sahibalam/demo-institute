import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDb } from '../lib/db.js';
import { getDriveClient } from '../lib/drive.js';

function sanitize(s) {
  return String(s || '').trim();
}

function normalizeClass(s) {
  const v = sanitize(s);
  if (!v) return '';
  return v.toLowerCase().includes('12') && v.toLowerCase().includes('pass') ? '12pass' : v;
}

function normalizeCategory(s) {
  const v = sanitize(s).toLowerCase();
  if (v === 'yearspapers' || v === 'years' || v === 'year_papers' || v === 'year-papers') return 'yearspapers';
  if (v === 'chaptersolutions' || v === 'chapter_solutions' || v === 'chapter-solutions' || v === 'chapters' || v === 'solutions') {
    return 'chaptersolutions';
  }
  return 'materials';
}

function normalizeYear(s) {
  const v = sanitize(s);
  if (!v) return '';
  const y = v.replace(/[^0-9]/g, '');
  if (!y) return '';
  return y.slice(0, 4);
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

  const method = event?.requestContext?.http?.method || 'POST';
  if (method !== 'POST') return json(405, { message: 'Method not allowed' });

  try {
    const body = parseJsonBody(event) || {};

    const fileId = sanitize(body.fileId);
    if (!fileId) return json(400, { message: 'Missing fileId' });

    const klass = normalizeClass(body.class);
    const section = sanitize(body.section);
    const subject = sanitize(body.subject);
    const title = sanitize(body.title) || '';
    const category = normalizeCategory(body.category);
    const year = category === 'yearspapers' ? normalizeYear(body.year) : '';
    const chapter = category === 'chaptersolutions' ? sanitize(body.chapter) : '';

    if (!klass || !section || !subject) {
      return json(400, { message: 'Missing class/section/subject' });
    }
    if (category === 'yearspapers' && !year) {
      return json(400, { message: 'Missing year' });
    }

    const drive = getDriveClient();

    try {
      await drive.permissions.create({
        fileId,
        supportsAllDrives: true,
        requestBody: {
          role: 'reader',
          type: 'anyone',
        },
      });
    } catch (e) {
      console.error('materialsResumableFinalize permissions error', e);
    }

    const meta = await drive.files.get({
      fileId,
      supportsAllDrives: true,
      fields: 'id, name, webViewLink, webContentLink',
    });

    const fileName = sanitize(body.fileName) || sanitize(meta?.data?.name) || `${klass}-${section}-${subject}.pdf`;

    const doc = {
      category,
      class: klass,
      section,
      subject,
      year,
      chapter,
      title,
      fileName,
      fileId,
      webViewLink: meta?.data?.webViewLink || '',
      webContentLink: meta?.data?.webContentLink || '',
      createdAt: new Date().toISOString(),
    };

    const db = await getDb();
    const col = db.collection('materials');
    const res = await col.insertOne(doc);

    return json(201, {
      id: String(res.insertedId),
      category,
      year,
      chapter,
      fileId,
      webViewLink: doc.webViewLink,
      webContentLink: doc.webContentLink,
    });
  } catch (e) {
    console.error('materialsResumableFinalize error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
