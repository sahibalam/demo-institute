const { response } = require('./response.js');

function unauthorized() {
  return response(
    401,
    { message: 'Unauthorized' },
    {
      'www-authenticate': 'Basic realm="OPTIMUM Admin"',
    }
  );
}

function requireBasicAuth(event) {
  const user = process.env.ADMIN_USER || '';
  const pass = process.env.ADMIN_PASS || '';

  if (!user || !pass) {
    return response(500, { message: 'Server misconfigured: missing ADMIN_USER/ADMIN_PASS' });
  }

  const header = event?.headers?.authorization || event?.headers?.Authorization;
  if (!header || !header.startsWith('Basic ')) return unauthorized();

  let decoded = '';
  try {
    decoded = Buffer.from(header.slice('Basic '.length), 'base64').toString('utf8');
  } catch {
    return unauthorized();
  }

  const idx = decoded.indexOf(':');
  if (idx < 0) return unauthorized();

  const u = decoded.slice(0, idx);
  const p = decoded.slice(idx + 1);

  if (u !== user || p !== pass) return unauthorized();

  return null;
}

function validateBasicAuth(event) {
  const user = process.env.ADMIN_USER || '';
  const pass = process.env.ADMIN_PASS || '';

  if (!user || !pass) {
    return { isValid: false, error: 'Server misconfigured: missing ADMIN_USER/ADMIN_PASS' };
  }

  const header = event?.headers?.authorization || event?.headers?.Authorization;
  if (!header || !header.startsWith('Basic ')) {
    return { isValid: false, error: 'Missing or invalid authorization header' };
  }

  let decoded = '';
  try {
    decoded = Buffer.from(header.slice('Basic '.length), 'base64').toString('utf8');
  } catch {
    return { isValid: false, error: 'Invalid authorization header format' };
  }

  const idx = decoded.indexOf(':');
  if (idx < 0) {
    return { isValid: false, error: 'Invalid authorization header format' };
  }

  const u = decoded.slice(0, idx);
  const p = decoded.slice(idx + 1);

  if (u !== user || p !== pass) {
    return { isValid: false, error: 'Invalid credentials' };
  }

  return { isValid: true };
}

export { requireBasicAuth, validateBasicAuth };
