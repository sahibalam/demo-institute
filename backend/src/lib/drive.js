import { google } from 'googleapis';
import { Readable } from 'node:stream';

function requiredEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function optionalEnv(name) {
  const v = process.env[name];
  return v ? String(v) : '';
}

function getOAuthClient() {
  const clientId = requiredEnv('CLIENT_ID');
  const clientSecret = requiredEnv('CLIENT_SECRET');
  const redirectUri = requiredEnv('REDIRECT_URI');
  const refreshToken = requiredEnv('REFRESH_TOKEN');

  const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  return oauth2Client;
}

export function getDriveClient() {
  const oauth2Client = getOAuthClient();
  return google.drive({ version: 'v3', auth: oauth2Client });
}

export async function getDriveAccessToken() {
  const oauth2Client = getOAuthClient();
  const tok = await oauth2Client.getAccessToken();
  const accessToken = typeof tok === 'string' ? tok : tok?.token;
  if (!accessToken) throw new Error('Failed to get Drive access token');
  return { accessToken };
}

export async function uploadPdfToDrive({ fileName, mimeType, buffer }) {
  if (!buffer || !Buffer.isBuffer(buffer) || !buffer.length) {
    throw new Error('Missing PDF data');
  }

  const drive = getDriveClient();
  const folderId = optionalEnv('GOOGLE_DRIVE_FOLDER_ID');

  const res = await drive.files.create({
    supportsAllDrives: true,
    requestBody: {
      name: fileName || 'study-material.pdf',
      ...(folderId ? { parents: [folderId] } : {}),
      mimeType: mimeType || 'application/pdf',
    },
    media: {
      mimeType: mimeType || 'application/pdf',
      body: Readable.from(buffer),
    },
    fields: 'id, webViewLink, webContentLink',
  });

  const fileId = res.data.id;
  if (!fileId) throw new Error('Drive upload failed: missing file id');

  await drive.permissions.create({
    fileId,
    supportsAllDrives: true,
    requestBody: {
      role: 'reader',
      type: 'anyone',
    },
  });

  const meta = await drive.files.get({
    fileId,
    supportsAllDrives: true,
    fields: 'id, webViewLink, webContentLink',
  });

  return {
    id: meta.data.id,
    webViewLink: meta.data.webViewLink,
    webContentLink: meta.data.webContentLink,
  };
}
