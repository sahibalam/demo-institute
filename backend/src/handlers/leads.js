import nodemailer from 'nodemailer';
import { json } from '../lib/response.js';

function sanitize(s) {
  return String(s || '').trim();
}

function isValidPhone(s) {
  const v = sanitize(s);
  if (!v) return false;
  const digits = v.replace(/\D/g, '');
  return digits.length >= 10 && digits.length <= 15;
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

  const method = event?.requestContext?.http?.method || 'POST';
  if (method !== 'POST') return json(405, { message: 'Method not allowed' });

  try {
    const body = parseJsonBody(event) || {};
    const name = sanitize(body.name);
    const phone = sanitize(body.phone);

    if (!name) return json(400, { message: 'Missing name' });
    if (!isValidPhone(phone)) return json(400, { message: 'Invalid phone number' });

    // const toEmail = process.env.ADMISSION_EMAIL || 'optimumeducationcentre786@gmail.com';
    // const fromEmail = 'optimumeducationcentre786@gmail.com';
    // const appPassword = process.env.APP_PASSWORD;
    //
    // if (!appPassword) {
    //   return json(500, { message: 'Missing APP_PASSWORD in environment' });
    // }
    //
    // const transporter = nodemailer.createTransport({
    //   service: 'gmail',
    //   auth: {
    //     user: fromEmail,
    //     pass: appPassword,
    //   },
    // });
    //
    // await transporter.sendMail({
    //   from: fromEmail,
    //   to: toEmail,
    //   subject: `New Lead - ${name}`,
    //   text: `New lead received:\n\nName: ${name}\nPhone: ${phone}\n\nSent from OPTIMUM website lead form.`,
    // });

    return json(200, { ok: true });
  } catch (e) {
    console.error('leads error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
