import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDriveAccessToken } from '../lib/drive.js';

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

  const method = event?.requestContext?.http?.method || 'POST';
  if (method !== 'POST') return json(405, { message: 'Method not allowed' });

  try {
    const body = parseJsonBody(event) || {};
    const fileName = sanitize(body.fileName) || 'study-material.pdf';
    const mimeType = sanitize(body.mimeType) || 'application/pdf';
    const size = Number(body.size || 0);

    if (!mimeType.toLowerCase().includes('pdf')) {
      return json(400, { message: 'Only PDF is allowed' });
    }

    const { accessToken } = await getDriveAccessToken();

    const folderId = sanitize(process.env.GOOGLE_DRIVE_FOLDER_ID);
    const requestBody = {
      name: fileName,
      mimeType,
      ...(folderId ? { parents: [folderId] } : {}),
    };

    const url = 'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true';

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': mimeType,
        ...(size > 0 ? { 'X-Upload-Content-Length': String(size) } : {}),
      },
      body: JSON.stringify(requestBody),
    });

    if (!res.ok) {
      const txt = await res.text();
      return json(500, { message: `Drive resumable start failed: ${res.status} ${txt}` });
    }

    const uploadUrl = res.headers.get('location') || '';
    if (!uploadUrl) return json(500, { message: 'Drive resumable start failed: missing upload URL' });

    return json(200, {
      uploadUrl,
      accessToken,
    });
  } catch (e) {
    console.error('materialsResumableStart error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
