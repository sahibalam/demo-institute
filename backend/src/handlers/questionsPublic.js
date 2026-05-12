import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';

const cache = {};

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const q = event?.queryStringParameters || {};
  const filter = {};
  const includeAnswers = q.includeAnswers === 'true';

  if (q.class) filter.class = String(q.class);
  if (q.stream) filter.stream = String(q.stream);
  if (q.section) filter.section = String(q.section);
  if (q.subject) filter.subject = String(q.subject);
  if (q.chapter) filter.chapter = String(q.chapter);

  try {
    // Create cache key
    const cacheKey = JSON.stringify(filter);
    
    // Check cache first
    if (cache[cacheKey]) {
      return json(200, cache[cacheKey]);
    }

    const db = await getDb();
    const questions = await db
      .collection('questions')
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(100)
      .toArray();

    // Cache the result for 5 minutes
    cache[cacheKey] = questions;
    setTimeout(() => delete cache[cacheKey], 5 * 60 * 1000);

    return json(200, {
      items: questions.map((x) => ({
        id: String(x._id),
        questionHtml: x.questionHtml || x.question || '',
        optionsHtml: x.optionsHtml || x.options || [],
        correctOption: includeAnswers ? x.correctOption : undefined,
        marks: x.marks,
        class: x.class,
        stream: x.stream,
        section: x.section,
        subject: x.subject,
        chapter: x.chapter,
        createdAt: x.createdAt,
      })),
    });
  } catch (e) {
    console.error('questionsPublic error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
