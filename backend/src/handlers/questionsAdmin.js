import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';
import { requireBasicAuth } from '../lib/auth.js';

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  const authError = requireBasicAuth(event);
  if (authError) return authError;

  const method = event?.requestContext?.http?.method;

  try {
    const db = await getDb();
    const collection = db.collection('questions');

    if (method === 'GET') {
      const items = await collection
        .find({})
        .sort({ createdAt: -1 })
        .limit(100)
        .toArray();

      return json(200, {
        items: items.map((x) => ({
          id: String(x._id),
          questionHtml: x.questionHtml || x.question || '',
          optionsHtml: x.optionsHtml || x.options || [],
          correctOption: x.correctOption,
          marks: x.marks,
          class: x.class,
          stream: x.stream,
          section: x.section,
          subject: x.subject,
          chapter: x.chapter,
          createdAt: x.createdAt,
          updatedAt: x.updatedAt,
        })),
      });
    }

    if (method === 'POST') {
      const body = JSON.parse(event.body);
      
      // Basic validation
      if (!body.question || typeof body.question !== 'string') {
        return json(400, { message: 'Question text is required' });
      }
      
      if (!Array.isArray(body.options) || body.options.length < 2) {
        return json(400, { message: 'At least 2 options are required' });
      }
      
      if (typeof body.correctOption !== 'number' || body.correctOption < 0 || body.correctOption >= body.options.length) {
        return json(400, { message: 'Valid correct option index is required' });
      }
      
      if (!body.class || typeof body.class !== 'string') {
        return json(400, { message: 'Class is required' });
      }
      
      if (!body.stream || typeof body.stream !== 'string') {
        return json(400, { message: 'Stream is required' });
      }
      
      if (!body.subject || typeof body.subject !== 'string') {
        return json(400, { message: 'Subject is required' });
      }

      const question = {
        questionHtml: body.questionHtml || body.question || '',
        optionsHtml: body.optionsHtml || body.options || [],
        correctOption: body.correctOption,
        marks: body.marks || 1,
        class: body.class,
        stream: body.stream,
        section: body.section,
        subject: body.subject,
        chapter: body.chapter || '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      const result = await collection.insertOne(question);
      
      return json(201, { 
        message: 'Question created successfully',
        questionId: String(result.insertedId)
      });
    }

    if (method === 'DELETE') {
      const { id } = event.pathParameters || {};
      
      if (!id) {
        return json(400, { message: 'Question ID is required' });
      }

      const result = await collection.deleteOne({ _id: id });

      if (result.deletedCount === 0) {
        return json(404, { message: 'Question not found' });
      }

      return json(200, { message: 'Question deleted successfully' });
    }

    return json(405, { message: 'Method not allowed' });

  } catch (e) {
    console.error('questionsAdmin error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
