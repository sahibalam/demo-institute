import PDFDocument from 'pdfkit';
import nodemailer from 'nodemailer';
import { json } from '../lib/response.js';
import { getDb } from '../lib/db.js';

function sanitize(s) {
  return String(s || '').trim();
}

function decodeBase64ToBuffer(b64) {
  const s = String(b64 || '').trim();
  if (!s) return null;
  const cleaned = s.includes('base64,') ? s.split('base64,').pop() : s;
  try {
    return Buffer.from(cleaned, 'base64');
  } catch {
    return null;
  }
}

function buildPdf({ data, photoBuffer } = {}) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 36 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const pageW = doc.page.width;
    const margin = doc.page.margins.left;
    const contentW = pageW - doc.page.margins.left - doc.page.margins.right;

    const navy = '#173845';
    const ink = '#1b140d';

    const clampOneLine = (s, max = 80) => {
      const v = sanitize(s);
      if (!v) return '';
      return v.length > max ? v.slice(0, max - 1) + '…' : v;
    };

    const drawHeaderBar = (title, y) => {
      const h = 20;
      doc.save();
      doc.roundedRect(margin, y, contentW, h, 6).fill(navy);
      doc.fillColor('#ffffff').fontSize(10).font('Helvetica-Bold').text(title, margin + 10, y + 6);
      doc.restore();
      return y + h;
    };

    const drawFieldLine = (label, value, x, y, w) => {
      const labelW = 120;
      const safeW = Math.max(10, w);
      const safeLabelW = Math.min(labelW, Math.max(70, Math.floor(safeW * 0.42)));
      const lineX = x + safeLabelW + 8;
      const lineW = Math.max(30, safeW - safeLabelW - 8);

      doc.fillColor(ink).fontSize(9).font('Helvetica-Bold').text(label, x, y + 4, {
        width: safeLabelW,
        lineBreak: false,
        ellipsis: true,
      });

      doc.save();
      doc.roundedRect(lineX, y, lineW, 18, 4).strokeColor('#cfd6dc').lineWidth(1).stroke();
      doc.restore();

      doc.fillColor(ink).fontSize(9).font('Helvetica').text(clampOneLine(value, 90), lineX + 6, y + 5, {
        width: lineW - 12,
        lineBreak: false,
        ellipsis: true,
      });

      return y + 24;
    };

    const drawTwoFields = (a, b, x, y, w, gap = 10) => {
      const colW = (w - gap) / 2;
      const y2 = drawFieldLine(a.label, a.value, x, y, colW);
      const y3 = drawFieldLine(b.label, b.value, x + colW + gap, y, colW);
      return Math.max(y2, y3);
    };

    doc.fillColor(ink).fontSize(18).font('Helvetica-Bold').text('ADMISSION FORM', margin, 38, { width: contentW, align: 'center' });

    let y = 70;

    // STUDENT DETAILS
    y = drawHeaderBar('STUDENT DETAILS:', y) + 10;

    const rightW = 180;
    const gap = 10;
    const leftW = contentW - rightW - gap;
    const leftX = margin;
    const rightX = margin + leftW + gap;

    // Photo box
    const photoY = y;
    doc.save();
    doc.roundedRect(rightX, photoY, rightW, 120, 8).dash(4, { space: 3 }).strokeColor('#7d8a93').lineWidth(1).stroke().undash();
    doc.restore();

    if (photoBuffer) {
      try {
        doc.image(photoBuffer, rightX + 10, photoY + 10, { fit: [rightW - 20, 100], align: 'center', valign: 'center' });
      } catch {
        // ignore image errors
      }
    } else {
      doc.fillColor(ink).fontSize(9).font('Helvetica-Bold').text('Passport Size Photograph', rightX + 10, photoY + 40, { width: rightW - 20, align: 'center' });
      doc.fillColor('#555').fontSize(8).font('Helvetica').text('(Paste Here)', rightX + 10, photoY + 55, { width: rightW - 20, align: 'center' });
      doc.fillColor('#555').fontSize(8).font('Helvetica').text('3.5 cm × 4.5 cm', rightX + 10, photoY + 68, { width: rightW - 20, align: 'center' });
    }

    const d = data || {};

    y = drawFieldLine('Full Name', sanitize(d.studentName), leftX, y, leftW);

    y = drawTwoFields(
      { label: 'Gender', value: d.gender },
      { label: 'Contact Number', value: d.studentPhone },
      leftX,
      y,
      leftW
    );

    y = drawTwoFields(
      { label: 'Class/Grade', value: d.classGrade },
      { label: 'Stream', value: d.stream },
      leftX,
      y,
      leftW
    );

    y = drawFieldLine('Address', sanitize(d.address), leftX, y, leftW);
    y += 8;

    // PARENT / GUARDIAN DETAILS
    y = drawHeaderBar('PARENT / GUARDIAN DETAILS:', y) + 10;
    const halfW = (contentW - 10) / 2;
    y = drawTwoFields(
      { label: 'Name', value: d.guardianName },
      { label: 'Relation', value: d.relation },
      margin,
      y,
      contentW
    );
    y = drawFieldLine('Contact Number', sanitize(d.guardianPhone), margin, y, contentW);

    // COURSE / SUBJECTS
    y += 10;
    y = drawHeaderBar('COURSE / SUBJECTS APPLIED FOR:', y) + 10;
    doc.save();
    doc.roundedRect(margin, y, contentW, 50, 6).strokeColor('#cfd6dc').lineWidth(1).stroke();
    doc.restore();
    doc.fillColor(ink).fontSize(9).font('Helvetica').text(sanitize(d.courses), margin + 8, y + 8, { width: contentW - 16, height: 34 });
    y += 64;

    // SPECIAL NOTES
    y = drawHeaderBar('SPECIAL NOTES / REQUIREMENTS (if any):', y) + 10;
    doc.save();
    doc.roundedRect(margin, y, contentW, 50, 6).strokeColor('#cfd6dc').lineWidth(1).stroke();
    doc.restore();
    doc.fillColor(ink).fontSize(9).font('Helvetica').text(sanitize(d.notes), margin + 8, y + 8, { width: contentW - 16, height: 34 });

    doc.end();
  });
}

export async function handler(event) {
  if (event?.requestContext?.http?.method === 'OPTIONS') return json(204, null);

  try {
    const body = event?.body ? JSON.parse(event.body) : {};
    const data = body?.data || {};
    const photoBase64 = body?.photoBase64 || '';

    try {
      const db = await getDb();
      const col = db.collection('students');

      const photoStr = typeof photoBase64 === 'string' ? photoBase64 : '';
      const safePhoto = photoStr && photoStr.length <= 700000 ? photoStr : '';

      const now = new Date().toISOString();
      const doc = {
        joiningDate: now,
        name: sanitize(data.studentName),
        class: sanitize(data.classGrade),
        stream: sanitize(data.stream),
        number: sanitize(data.studentPhone),
        address: sanitize(data.address),
        photoBase64: safePhoto,
        status: 'active',
        createdAt: now,
      };

      const res = await col.insertOne(doc);
      const studentId = `STU-${String(res.insertedId).slice(-6).toUpperCase()}`;
      await col.updateOne({ _id: res.insertedId }, { $set: { studentId } });
    } catch (e) {
      console.error('admission student save error', e);
    }

    const photoBuffer = decodeBase64ToBuffer(photoBase64);

    const pdfBuffer = await buildPdf({ data, photoBuffer });

    const toEmail = process.env.ADMISSION_EMAIL || 'botclap.crm@gmail.com';
    const fromEmail = 'botclap.crm@gmail.com';
    const appPassword = process.env.APP_PASSWORD;

    if (!appPassword) {
      return json(500, { message: 'Missing APP_PASSWORD in environment' });
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: fromEmail,
        pass: appPassword,
      },
    });

    const studentName = sanitize(data.studentName) || 'Student';

    await transporter.sendMail({
      from: fromEmail,
      to: toEmail,
      subject: `New Admission Form - ${studentName}`,
      text: 'New admission form submission. PDF is attached.',
      attachments: [
        {
          filename: `Admission-Form-${studentName.replace(/\s+/g, '_')}.pdf`,
          content: pdfBuffer,
          contentType: 'application/pdf',
        },
      ],
    });

    return json(200, { ok: true });
  } catch (e) {
    console.error('admission error', e);
    return json(500, { message: e?.message || 'Server error' });
  }
}
