import { json } from '../lib/response.js';
import { requireBasicAuth } from '../lib/auth.js';
import { getDriveAccessToken } from '../lib/drive.js';

function getHeader(event, name) {
  const h = event?.headers || {};
  return h[name] || h[name.toLowerCase()] || '';
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const authResp = requireBasicAuth(event);
  if (authResp) return authResp;

  const method = event?.requestContext?.http?.method || 'PUT';
  if (method !== 'PUT' && method !== 'POST') return json(405, { message: 'Method not allowed' });

  try {
    const uploadUrl = getHeader(event, 'x-upload-url');
    const contentRange = getHeader(event, 'content-range');
    const contentLength = getHeader(event, 'content-length');

    if (!uploadUrl) return json(400, { message: 'Missing x-upload-url header' });
    if (!contentRange) return json(400, { message: 'Missing Content-Range header' });

    const rawBody = event?.body || '';
    const isB64 = !!event?.isBase64Encoded;
    const buf = isB64 ? Buffer.from(rawBody, 'base64') : Buffer.from(rawBody);
    if (!buf.length) return json(400, { message: 'Missing chunk body' });

    const { accessToken } = await getDriveAccessToken();

    const res = await fetch(uploadUrl, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Range': contentRange,
        ...(contentLength ? { 'Content-Length': String(contentLength) } : {}),
      },
      body: buf,
    });

    const txt = await res.text();
    let data = null;
    try {
      data = txt ? JSON.parse(txt) : null;
    } catch {
      data = null;
    }

    return json(200, {
      status: res.status,
      headers: {
        range: res.headers.get('range') || '',
      },
      data,
      text: txt,
    });
  } catch (e) {
    console.error('materialsResumableChunk error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
