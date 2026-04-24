const YT_RE = /^(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[\w-]{6,}/i;

export function isValidYoutubeUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return YT_RE.test(url.trim());
}

export function normalizeLecture(input) {
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
