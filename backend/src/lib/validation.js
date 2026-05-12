const YT_RE = /^(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[\w-]{6,}/i;

function isValidYoutubeUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return YT_RE.test(url.trim());
}

function normalizeLecture(input) {
  const klass = String(input?.class ?? '').trim();
  const section = String(input?.section ?? '').trim();
  const subject = String(input?.subject ?? '').trim();
  const youtubeUrl = String(input?.youtubeUrl ?? '').trim();

  if (!klass) return { ok: false, message: 'class is required' };
  if (!section) return { ok: false, message: 'section is required' };
  if (!subject) return { ok: false, message: 'subject is required' };
  if (!youtubeUrl) return { ok: false, message: 'youtubeUrl is required' };
  if (!isValidYoutubeUrl(youtubeUrl)) return { ok: false, message: 'youtubeUrl must be a valid YouTube URL' };

  return {
    ok: true,
    value: {
      class: klass,
      section,
      subject,
      youtubeUrl,
    },
  };
}

function validateQuestionsQuery(params) {
  const { class: className, stream, subject, chapter } = params;
  
  // All parameters are optional, but if provided, they should be strings
  if (className && typeof className !== 'string') {
    return { isValid: false, error: 'class must be a string' };
  }
  if (stream && typeof stream !== 'string') {
    return { isValid: false, error: 'stream must be a string' };
  }
  if (subject && typeof subject !== 'string') {
    return { isValid: false, error: 'subject must be a string' };
  }
  if (chapter && typeof chapter !== 'string') {
    return { isValid: false, error: 'chapter must be a string' };
  }

  return { isValid: true };
}

function validateQuestionData(data) {
  const { question, options, correctOption, marks, class: className, stream, subject, chapter } = data;

  if (!question || typeof question !== 'string' || question.trim().length === 0) {
    return { isValid: false, error: 'Question text is required' };
  }

  if (!Array.isArray(options) || options.length < 2) {
    return { isValid: false, error: 'At least 2 options are required' };
  }

  if (typeof correctOption !== 'number' || correctOption < 0 || correctOption >= options.length) {
    return { isValid: false, error: 'Correct option must be a valid option index' };
  }

  if (typeof marks !== 'number' || marks <= 0) {
    return { isValid: false, error: 'Marks must be a positive number' };
  }

  if (!className || typeof className !== 'string') {
    return { isValid: false, error: 'Class is required' };
  }

  if (!stream || typeof stream !== 'string') {
    return { isValid: false, error: 'Stream is required' };
  }

  if (!subject || typeof subject !== 'string') {
    return { isValid: false, error: 'Subject is required' };
  }

  return { isValid: true };
}

export { 
  isValidYoutubeUrl,
  normalizeLecture,
  validateQuestionsQuery,
  validateQuestionData
};
