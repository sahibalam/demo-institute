import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';

function sanitize(s) {
  return String(s || '').trim();
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  try {
    const db = await getDb();
    const sessionsCol = db.collection('sessions');
    const classesCol = db.collection('classes');

    const sessions = await sessionsCol
      .find({})
      .sort({ createdAt: -1, _id: -1 })
      .limit(25)
      .toArray();

    let sessionName = '';
    let items = [];

    for (const s of sessions) {
      const name = sanitize(s?.name);
      if (!name) continue;
      const found = await classesCol.find({ session: name }).sort({ createdAt: -1 }).limit(1000).toArray();
      if (found && found.length) {
        sessionName = name;
        items = found;
        break;
      }
    }

    if (!sessionName) {
      const latestClass = await classesCol
        .find({})
        .sort({ createdAt: -1, _id: -1 })
        .limit(1)
        .toArray();

      const derivedSession = sanitize(latestClass?.[0]?.session);
      if (derivedSession) {
        const found = await classesCol.find({ session: derivedSession }).sort({ createdAt: -1 }).limit(1000).toArray();
        if (found && found.length) {
          sessionName = derivedSession;
          items = found;
        }
      }
    }

    if (!sessionName) {
      return json(200, { session: '', classes: [], streamsByClass: {} });
    }

    const streamsByClass = {};
    items.forEach((x) => {
      const klass = sanitize(x.class);
      const stream = sanitize(x.stream);
      if (!klass || !stream) return;
      if (!streamsByClass[klass]) streamsByClass[klass] = [];
      if (!streamsByClass[klass].includes(stream)) streamsByClass[klass].push(stream);
    });

    const classes = Object.keys(streamsByClass).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));
    classes.forEach((c) => {
      streamsByClass[c].sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));
    });

    return json(200, {
      session: sessionName,
      classes,
      streamsByClass,
    });
  } catch (e) {
    console.error('admissionOptionsPublic error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
