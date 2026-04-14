const qs = (s, el = document) => el.querySelector(s);
const qsa = (s, el = document) => Array.from(el.querySelectorAll(s));

const API_BASE = 'https://3fhqqpu0di.execute-api.ap-south-1.amazonaws.com';

function youtubeEmbedUrl(url) {
  const u = String(url || '').trim();
  if (!u) return '';
  try {
    const parsed = new URL(u);
    if (parsed.hostname.includes('youtu.be')) {
      const id = parsed.pathname.replace('/', '').trim();
      return id ? `https://www.youtube-nocookie.com/embed/${id}` : '';
    }
    if (parsed.hostname.includes('youtube.com')) {
      const id = parsed.searchParams.get('v');
      return id ? `https://www.youtube-nocookie.com/embed/${id}` : '';
    }
    return '';
  } catch {
    const m = u.match(/(?:youtu\.be\/|v=)([\w-]{6,})/i);
    return m ? `https://www.youtube-nocookie.com/embed/${m[1]}` : '';
  }
}

function youtubeVideoId(url) {
  const u = String(url || '').trim();
  if (!u) return '';
  try {
    const parsed = new URL(u);
    if (parsed.hostname.includes('youtu.be')) {
      return parsed.pathname.replace('/', '').trim();
    }
    if (parsed.hostname.includes('youtube.com')) {
      return parsed.searchParams.get('v') || '';
    }
    return '';
  } catch {
    const m = u.match(/(?:youtu\.be\/|v=)([\w-]{6,})/i);
    return m ? m[1] : '';
  }
}

function youtubeThumbnailUrl(url) {
  const id = youtubeVideoId(url);
  if (!id) return '';
  return `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
}

function setupLecturePlayer() {
  if (qs('#lecturePlayer')) return;

  const dlg = document.createElement('dialog');
  dlg.id = 'lecturePlayer';
  dlg.setAttribute('aria-label', 'Lecture player');
  dlg.innerHTML = `
    <form method="dialog" class="form" style="margin:0; max-width:900px">
      <div style="display:flex; justify-content:space-between; align-items:center; gap:10px">
        <h3 id="lecturePlayerTitle" style="margin:0">Lecture</h3>
        <button class="btn btn-ghost" value="close" type="submit">Close</button>
      </div>
      <div style="margin-top:12px; aspect-ratio:16/9; width:min(860px, 84vw)">
        <iframe
          id="lecturePlayerFrame"
          title="Lecture video"
          width="100%"
          height="100%"
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          allowfullscreen
        ></iframe>
      </div>
    </form>
  `;

  dlg.addEventListener('close', () => {
    const frame = qs('#lecturePlayerFrame', dlg);
    if (frame) frame.removeAttribute('src');
  });

  document.body.appendChild(dlg);
}

function openLecturePlayer({ title, youtubeUrl } = {}) {
  setupLecturePlayer();
  const dlg = qs('#lecturePlayer');
  if (!dlg) return;

  const src = youtubeEmbedUrl(youtubeUrl);
  if (!src) return;

  const h = qs('#lecturePlayerTitle', dlg);
  const frame = qs('#lecturePlayerFrame', dlg);
  if (h) h.textContent = title || 'Lecture';
  if (frame) frame.setAttribute('src', src + '?autoplay=1');

  if (typeof dlg.showModal === 'function') dlg.showModal();
}

function setYear() {
  const y = qs('#year');
  if (y) y.textContent = String(new Date().getFullYear());
}

function setupMobileNav() {
  const toggle = qs('#navToggle') || qs('.nav-toggle');
  const nav = qs('#primaryNav') || qs('nav.nav');
  if (!toggle || !nav) return;

  let lastToggleAt = 0;

  const close = () => {
    nav.classList.remove('open');
    toggle.setAttribute('aria-expanded', 'false');
  };

  const onToggle = (e) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    lastToggleAt = Date.now();
    const isOpen = nav.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(isOpen));
  };

  try {
    window.__optimumNav = { toggle, nav, onToggle };
  } catch {
    // ignore
  }

  const isToggleHit = (ev) => {
    if (!ev || typeof toggle.getBoundingClientRect !== 'function') return false;
    const x = 'clientX' in ev ? Number(ev.clientX) : NaN;
    const y = 'clientY' in ev ? Number(ev.clientY) : NaN;
    if (!Number.isFinite(x) || !Number.isFinite(y)) return false;

    const r = toggle.getBoundingClientRect();
    const insideRect = x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
    if (!insideRect) return false;

    const el = document.elementFromPoint(x, y);
    if (el && (el === toggle || toggle.contains(el))) return true;

    return true;
  };

  const onDocPointerUp = (e) => {
    const t = e?.target;
    if (t instanceof Element && toggle.contains(t)) return;
    if (isToggleHit(e)) {
      onToggle(e);
    }
  };

  const onToggleDirect = (e) => {
    if (Date.now() - lastToggleAt < 250) return;
    onToggle(e);
  };

  const onDocClick = (e) => {
    if (Date.now() - lastToggleAt < 450) return;
    if (isToggleHit(e)) return;
    if (!nav.classList.contains('open')) return;

    const t = e.target;
    if (t instanceof Element && (toggle.contains(t) || nav.contains(t))) return;
    close();
  };

  document.addEventListener('pointerup', onDocPointerUp, { capture: true });
  document.addEventListener('click', onDocClick, { capture: true });

  toggle.addEventListener('pointerup', onToggleDirect, { capture: true });
  toggle.addEventListener('click', onToggleDirect, { capture: true });

  qsa('a', nav).forEach((a) => a.addEventListener('click', close));

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') close();
  });
}

function setupDashboardGate() {
  const btn = qs('#dashboardLink');
  const dlg = qs('#adminDialog');
  const form = qs('#adminDialogForm');
  const note = qs('#adminDialogNote');
  if (!btn || !dlg || !form) return;

  const storageKey = 'optimum_admin_cfg_v1';
  const getCfg = () => {
    try {
      return JSON.parse(localStorage.getItem(storageKey) || '{}');
    } catch {
      return {};
    }
  };

  btn.addEventListener('click', () => {
    const cfg = getCfg();
    if (form.user) form.user.value = cfg.user || '';
    if (form.pass) form.pass.value = cfg.pass || '';
    if (note) note.textContent = '';
    if (typeof dlg.showModal === 'function') dlg.showModal();
    else window.location.href = 'admin.html';
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const user = (form.user?.value || '').trim();
    const pass = form.pass?.value || '';
    if (!user || !pass) {
      if (note) note.textContent = 'Enter username and password.';
      return;
    }

    const cfg = getCfg();
    const apiBase = cfg.apiBase || API_BASE;
    localStorage.setItem(storageKey, JSON.stringify({ apiBase, user, pass }));
    window.location.href = 'admin.html';
  });
}

function setupCounters() {
  const els = qsa('[data-counter]');
  if (!els.length) return;

  const run = (el) => {
    const target = Number(el.getAttribute('data-counter') || '0');
    const duration = 900;
    const start = performance.now();

    const step = (t) => {
      const p = Math.min(1, (t - start) / duration);
      const v = Math.floor(target * (0.18 + 0.82 * p));
      el.textContent = String(v);
      if (p < 1) requestAnimationFrame(step);
      else el.textContent = String(target);
    };

    requestAnimationFrame(step);
  };

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          run(e.target);
          io.unobserve(e.target);
        }
      });
    },
    { threshold: 0.4 }
  );

  els.forEach((el) => io.observe(el));
}

function setupForms() {
  const lead = qs('#leadForm');
  const leadNote = qs('#formNote');
  const contact = qs('#contactForm');
  const contactNote = qs('#contactNote');

  const handleDemo = (form, noteEl) => {
    if (!form || !noteEl) return;
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      noteEl.textContent = 'Thanks! We received your message. (Demo frontend — no backend connected)';
      form.reset();
    });
  };

  handleDemo(lead, leadNote);

  if (contact && contactNote) {
    contact.addEventListener('submit', async (e) => {
      e.preventDefault();
      contactNote.textContent = 'Sending…';

      const fd = new FormData(contact);
      const payload = {
        name: String(fd.get('name') || '').trim(),
        phone: String(fd.get('phone') || '').trim(),
        message: String(fd.get('message') || '').trim(),
      };

      try {
        const res = await fetch(API_BASE + '/contact', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
          },
          body: JSON.stringify(payload),
        });

        if (!res.ok) {
          let msg = `Failed: ${res.status}`;
          try {
            const j = await res.json();
            if (j?.message) msg = j.message;
          } catch {
            // ignore
          }
          contactNote.textContent = msg;
          return;
        }

        contactNote.textContent = 'Sent! We will get back to you soon.';
        contact.reset();
      } catch {
        contactNote.textContent = 'Failed to send. Please try again.';
      }
    });
  }
}

function setupEnquireModal() {
  const dlg = qs('#enquireDialog');
  if (!dlg) return;

  const fillSelect = (selectEl, values, { placeholder = 'Select' } = {}) => {
    if (!selectEl) return;
    const keep = selectEl.value;
    selectEl.innerHTML = `<option value="">${placeholder}</option>`;
    (Array.isArray(values) ? values : []).forEach((v) => {
      const opt = document.createElement('option');
      opt.value = String(v);
      opt.textContent = String(v);
      selectEl.appendChild(opt);
    });
    if (keep && values && values.includes(keep)) selectEl.value = keep;
  };

  const admissionClassEl = qs('[data-admission-class]', dlg);
  const admissionStreamEl = qs('[data-admission-stream]', dlg);
  let optionsCache = null;

  const loadAdmissionOptions = async () => {
    try {
      const res = await fetch(API_BASE + '/admission/options');
      if (!res.ok) return null;
      const data = await res.json();
      return data && typeof data === 'object' ? data : null;
    } catch {
      return null;
    }
  };

  const syncAdmissionStreams = () => {
    if (!optionsCache || !admissionStreamEl || !admissionClassEl) return;
    const klass = String(admissionClassEl.value || '').trim();
    const m = optionsCache.streamsByClass && typeof optionsCache.streamsByClass === 'object' ? optionsCache.streamsByClass : {};
    const streams = Array.isArray(m[klass]) ? m[klass] : [];
    fillSelect(admissionStreamEl, streams, { placeholder: 'Select' });
  };

  if (admissionClassEl) {
    admissionClassEl.addEventListener('change', () => {
      syncAdmissionStreams();
    });
  }

  const ensureAdmissionOptions = async () => {
    if (!admissionClassEl || !admissionStreamEl) return;
    if (!optionsCache) optionsCache = await loadAdmissionOptions();
    const classes = Array.isArray(optionsCache?.classes) ? optionsCache.classes : [];
    fillSelect(admissionClassEl, classes, { placeholder: 'Select' });
    syncAdmissionStreams();
  };

  const resetPreview = () => {
    const box = qs('.admission-photo', dlg);
    const img = qs('.admission-photo-preview', dlg);
    const input = qs('input[type="file"][name="photo"]', dlg);
    if (img) img.removeAttribute('src');
    if (box) box.classList.remove('has-preview');
    if (input) input.value = '';
  };

  const open = (e) => {
    e.preventDefault();
    const note = qs('#admissionNote');
    if (note) note.textContent = '';
    resetPreview();
    ensureAdmissionOptions();
    if (typeof dlg.showModal === 'function') dlg.showModal();
  };

  qsa('[data-enquire-trigger]', document).forEach((el) => {
    el.addEventListener('click', open);
  });

  const submitBtn = qs('#admissionSubmit', dlg);
  const note = qs('#admissionNote', dlg);
  const form = qs('form', dlg);

  const fileInput = qs('input[type="file"][name="photo"]', dlg);
  const previewImg = qs('.admission-photo-preview', dlg);
  const photoBox = qs('.admission-photo', dlg);

  if (fileInput) {
    fileInput.addEventListener('change', () => {
      const f = fileInput.files && fileInput.files[0];
      if (!f || !previewImg) {
        resetPreview();
        return;
      }
      if (!f.type || !f.type.startsWith('image/')) {
        resetPreview();
        return;
      }
      const url = URL.createObjectURL(f);
      previewImg.src = url;
      previewImg.onload = () => URL.revokeObjectURL(url);
      if (photoBox) photoBox.classList.add('has-preview');
    });
  }

  qsa('button[value="close"]', dlg).forEach((b) => {
    b.addEventListener('click', () => {
      try {
        dlg.close();
      } catch {
        // ignore
      }
    });
  });

  dlg.addEventListener('close', () => {
    resetPreview();
  });

  const onSubmit = () => {
    if (!form) return;
    const submit = async () => {
      try {
        if (note) note.textContent = 'Submitting...';

        const fd = new FormData(form);
        const data = Object.fromEntries(fd.entries());

        const f = fileInput?.files && fileInput.files[0];
        let photoBase64 = '';
        if (f && f.type && f.type.startsWith('image/')) {
          photoBase64 = await new Promise((resolve) => {
            const r = new FileReader();
            r.onload = () => resolve(String(r.result || ''));
            r.onerror = () => resolve('');
            r.readAsDataURL(f);
          });
        }

        const resp = await fetch(API_BASE + '/admission', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ data, photoBase64 }),
        });

        if (!resp.ok) {
          let msg = `Failed to submit (HTTP ${resp.status}).`;
          try {
            const j = await resp.json();
            if (j?.message) msg = j.message;
          } catch {
            // ignore
          }
          throw new Error(msg);
        }

        if (note) note.textContent = 'Submitted! The PDF has been emailed.';
        window.setTimeout(() => {
          try {
            form.reset();
            resetPreview();
            dlg.close();
          } catch {
            // ignore
          }
        }, 900);
      } catch (err) {
        if (note) note.textContent = err?.message || 'Submission failed. Please try again.';
      }
    };

    submit();
  };

  if (submitBtn) submitBtn.addEventListener('click', onSubmit);
}

function setupProgramsCarousel() {
  const root = qs('#programsCarousel');
  if (!root) return;

  const bg = qs('.programs-banner-bg', root);
  const dots = qs('.programs-dots', root);
  if (!bg || !dots) return;

  const images = ['assets/carousel/c1.png', 'assets/carousel/c2.png'];
  let i = 0;
  let timer = null;

  const setSlide = (idx) => {
    i = (idx + images.length) % images.length;
    bg.style.backgroundImage = `url('${images[i]}')`;
    qsa('button', dots).forEach((b, bi) => b.setAttribute('aria-selected', String(bi === i)));
  };

  const start = () => {
    stop();
    timer = window.setInterval(() => setSlide(i + 1), 4500);
  };

  const stop = () => {
    if (timer) window.clearInterval(timer);
    timer = null;
  };

  dots.innerHTML = '';
  images.forEach((_, idx) => {
    const b = document.createElement('button');
    b.className = 'dot';
    b.type = 'button';
    b.setAttribute('role', 'tab');
    b.setAttribute('aria-label', `Slide ${idx + 1}`);
    b.setAttribute('aria-selected', 'false');
    b.addEventListener('click', () => {
      setSlide(idx);
      start();
    });
    dots.appendChild(b);
  });

  setSlide(0);
  start();

  root.addEventListener('mouseenter', stop);
  root.addEventListener('mouseleave', start);
}

function setupNotesCarousel() {
  const root = qs('#notesCarousel');
  if (!root) return;

  const viewport = qs('.notes-viewport', root);
  const prev = qs('.notes-nav.prev', root);
  const next = qs('.notes-nav.next', root);
  if (!viewport || !prev || !next) return;

  const getStep = () => {
    const card = qs('.note-card', root);
    if (!card) return Math.max(220, Math.floor(viewport.clientWidth * 0.8));
    const styles = getComputedStyle(qs('.notes-track', root));
    const gap = Number.parseFloat(styles.columnGap || styles.gap || '0') || 0;
    return card.getBoundingClientRect().width + gap;
  };

  const clampButtons = () => {
    const max = viewport.scrollWidth - viewport.clientWidth;
    prev.disabled = viewport.scrollLeft <= 2;
    next.disabled = viewport.scrollLeft >= max - 2;
  };

  const scrollByStep = (dir) => {
    viewport.scrollBy({ left: dir * getStep(), behavior: 'smooth' });
  };

  prev.addEventListener('click', () => scrollByStep(-1));
  next.addEventListener('click', () => scrollByStep(1));
  viewport.addEventListener('scroll', clampButtons, { passive: true });

  viewport.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowLeft') {
      e.preventDefault();
      scrollByStep(-1);
    }
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      scrollByStep(1);
    }
  });

  let isDown = false;
  let startX = 0;
  let startLeft = 0;

  const onDown = (e) => {
    isDown = true;
    viewport.classList.add('dragging');
    startX = e.clientX;
    startLeft = viewport.scrollLeft;
  };

  const onMove = (e) => {
    if (!isDown) return;
    const dx = e.clientX - startX;
    viewport.scrollLeft = startLeft - dx;
  };

  const onUp = () => {
    isDown = false;
    viewport.classList.remove('dragging');
  };

  viewport.addEventListener('pointerdown', (e) => {
    viewport.setPointerCapture(e.pointerId);
    onDown(e);
  });
  viewport.addEventListener('pointermove', onMove);
  viewport.addEventListener('pointerup', onUp);
  viewport.addEventListener('pointercancel', onUp);

  clampButtons();
}

function setupHorizontalCarousel(rootSelector, viewportSelector, prevSelector, nextSelector, cardSelector, trackSelector) {
  const root = qs(rootSelector);
  if (!root) return;

  const viewport = qs(viewportSelector, root);
  const prev = qs(prevSelector, root);
  const next = qs(nextSelector, root);
  if (!viewport || !prev || !next) return;

  const getStep = () => {
    const card = qs(cardSelector, root);
    if (!card) return Math.max(220, Math.floor(viewport.clientWidth * 0.8));
    const track = qs(trackSelector, root);
    if (!track) return card.getBoundingClientRect().width;
    const styles = getComputedStyle(track);
    const gap = Number.parseFloat(styles.columnGap || styles.gap || '0') || 0;
    return card.getBoundingClientRect().width + gap;
  };

  const clampButtons = () => {
    const max = viewport.scrollWidth - viewport.clientWidth;
    prev.disabled = viewport.scrollLeft <= 2;
    next.disabled = viewport.scrollLeft >= max - 2;
  };

  const scrollByStep = (dir) => {
    viewport.scrollBy({ left: dir * getStep(), behavior: 'smooth' });
  };

  prev.addEventListener('click', () => scrollByStep(-1));
  next.addEventListener('click', () => scrollByStep(1));
  viewport.addEventListener('scroll', clampButtons, { passive: true });

  viewport.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowLeft') {
      e.preventDefault();
      scrollByStep(-1);
    }
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      scrollByStep(1);
    }
  });

  let isDown = false;
  let startX = 0;
  let startLeft = 0;

  const onDown = (e) => {
    isDown = true;
    viewport.classList.add('dragging');
    startX = e.clientX;
    startLeft = viewport.scrollLeft;
  };

  const onMove = (e) => {
    if (!isDown) return;
    const dx = e.clientX - startX;
    viewport.scrollLeft = startLeft - dx;
  };

  const onUp = () => {
    isDown = false;
    viewport.classList.remove('dragging');
  };

  viewport.addEventListener('pointerdown', (e) => {
    viewport.setPointerCapture(e.pointerId);
    onDown(e);
  });
  viewport.addEventListener('pointermove', onMove);
  viewport.addEventListener('pointerup', onUp);
  viewport.addEventListener('pointercancel', onUp);

  clampButtons();
}

function setupStudentsCarousel() {
  setupHorizontalCarousel(
    '#studentsCarousel',
    '.hscroll-viewport',
    '.hscroll-nav.prev',
    '.hscroll-nav.next',
    '.scard',
    '.hscroll-track'
  );

  const root = qs('#studentsCarousel');
  if (!root) return;
  const viewport = qs('.hscroll-viewport', root);
  const track = qs('.hscroll-track', root);
  if (!viewport) return;

  if (track && !track.dataset.cloned) {
    const items = Array.from(track.children);
    items.forEach((el) => {
      const clone = el.cloneNode(true);
      clone.setAttribute('aria-hidden', 'true');
      track.appendChild(clone);
    });
    track.dataset.cloned = 'true';
  }
}

function initSite() {
  setYear();
  setupMobileNav();
  setupDashboardGate();
  setupCounters();
  setupForms();
  setupEnquireModal();
  setupLeadPopup();
  setupAnnouncementsAndTimetable();
  setupProgramsCarousel();
  setupNotesCarousel();
  setupOfferingsTabs();
  setupStudentsCarousel();
  setupStudentDashboard();
  setupStudentRedirects();
}

function setupLeadPopup() {
  const dlg = qs('#leadDialog');
  const form = qs('#leadDialogForm');
  const note = qs('#leadDialogNote');
  if (!dlg || !form) return;

  const postBotclapLead = async ({ name, phone }) => {
    try {
      const params = new URLSearchParams();
      params.set('Name', String(name || ''));
      params.set('PhoneNumber', String(phone || ''));

      await fetch('https://botclap.com/webhook/contact/764610403118927', {
        method: 'POST',
        mode: 'no-cors',
        headers: {
          'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body: params.toString(),
      });
    } catch {
      // ignore
    }
  };

  const key = 'optimum_lead_popup_v1';
  const state = localStorage.getItem(key) || '';
  if (state === 'dismissed' || state === 'submitted') return;

  const show = () => {
    if (typeof dlg.showModal === 'function') {
      try {
        dlg.showModal();
        return;
      } catch {
        // ignore
      }
    }

    try {
      dlg.setAttribute('open', '');
    } catch {
      // ignore
    }
  };

  const closeDialog = (val = 'cancel') => {
    if (typeof dlg.close === 'function') {
      try {
        dlg.close(val);
        return;
      } catch {
        // ignore
      }
    }
    try {
      dlg.removeAttribute('open');
    } catch {
      // ignore
    }
  };

  qsa('[data-lead-trigger]').forEach((el) => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      if (note) note.textContent = '';
      show();
    });
  });

  const timer = setTimeout(show, 4500);

  dlg.addEventListener('close', () => {
    clearTimeout(timer);
    if (dlg.returnValue === 'cancel' || dlg.returnValue === 'notnow') {
      localStorage.setItem(key, 'dismissed');
    }
  });

  const notNowBtn = qs('#leadNotNow');
  if (notNowBtn) {
    notNowBtn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      localStorage.setItem(key, 'dismissed');
      if (note) note.textContent = '';
      try {
        closeDialog('cancel');
      } catch {
        // ignore
      }
    });
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const submitterValue = String(e?.submitter?.value || '').toLowerCase();
    if (submitterValue === 'cancel' || submitterValue === 'notnow') {
      localStorage.setItem(key, 'dismissed');
      if (note) note.textContent = '';
      try {
        closeDialog('cancel');
      } catch {
        // ignore
      }
      return;
    }

    if (note) note.textContent = 'Submitting…';

    const fd = new FormData(form);
    const payload = {
      name: String(fd.get('name') || '').trim(),
      phone: String(fd.get('phone') || '').trim(),
    };

    try {
      const res = await fetch(API_BASE + '/leads', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const txt = await res.text();
        if (note) note.textContent = `Failed: ${res.status} ${txt}`;
        return;
      }

      postBotclapLead(payload);

      localStorage.setItem(key, 'submitted');
      if (note) note.textContent = 'Submitted. We will call you soon.';
      setTimeout(() => {
        try {
          closeDialog('ok');
        } catch {
          // ignore
        }
      }, 800);
    } catch {
      if (note) note.textContent = 'Failed to submit. Please try again.';
    }
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSite);
} else {
  initSite();
}

function setupOfferingsTabs() {
  const roots = qsa('.offerings-tabs');
  if (!roots.length) return;

  roots.forEach((root) => {
    const tabs = qsa('.tab', root);
    if (!tabs.length) return;

    if (!tabs.some((x) => x.classList.contains('active') || x.getAttribute('aria-selected') === 'true')) {
      tabs[0].classList.add('active');
      tabs[0].setAttribute('aria-selected', 'true');
    }

    const sectionLabel = root.closest('section')?.getAttribute('aria-label') || '';
    const isLecturesTabs = !!qs('#lecturesCarousel') && sectionLabel === 'Recorded lectures offerings';
    const isMaterialsSection = !!qs('#notesCarousel') && sectionLabel === 'Study materials offerings';
    const isMaterialTypeTabs = root.hasAttribute('data-material-tabs');

    const hasMaterialTypeTabs = !!qs('[data-material-tabs]');
    const isMaterialsClassTabs = isMaterialsSection && !isMaterialTypeTabs && hasMaterialTypeTabs;

    const labelToClass = (label) => {
      const s = String(label || '').toLowerCase();
      if (s.includes('12 pass')) return '12pass';
      const m = s.match(/class\s*(\d+)/);
      return m ? m[1] : '';
    };

    tabs.forEach((t) => {
      t.addEventListener('click', () => {
        tabs.forEach((x) => {
          x.classList.remove('active');
          x.setAttribute('aria-selected', 'false');
        });
        t.classList.add('active');
        t.setAttribute('aria-selected', 'true');

        if (isLecturesTabs) {
          const klass = labelToClass(t.textContent);
          loadRecordedLectures({ class: klass });
        }

        if (isMaterialsClassTabs) {
          const klass = labelToClass(t.textContent);
          loadStudyMaterials({ class: klass });
        }

        if (isMaterialTypeTabs) {
          const classTabsRoot = qsa('.offerings-tabs').find((r) => {
            const lab = r.closest('section')?.getAttribute('aria-label') || '';
            return lab === 'Study materials offerings' && !r.hasAttribute('data-material-tabs');
          });
          const activeClassTab = classTabsRoot ? qs('.tab.active', classTabsRoot) : null;
          const klass = labelToClass(activeClassTab?.textContent);
          loadStudyMaterials({ class: klass });
        }
      });
    });

    if (isLecturesTabs) {
      const active = tabs.find((x) => x.classList.contains('active')) || tabs[0];
      const klass = labelToClass(active?.textContent);
      loadRecordedLectures({ class: klass });
    }

    if (isMaterialsClassTabs) {
      const active = tabs.find((x) => x.classList.contains('active')) || tabs[0];
      const klass = labelToClass(active?.textContent);
      loadStudyMaterials({ class: klass });
    }

    if (isMaterialTypeTabs) return;
  });
}

function loadStudyMaterials({ class: klass } = {}) {
  const root = qs('#notesCarousel');
  if (!root) return;
  const track = qs('.notes-track', root);
  if (!track) return;

  const shouldRedirectToStudent = !qs('#studentShell');

  const activeTypeBtn = qs('[data-material-tabs] .tab.active');
  const category = (activeTypeBtn?.dataset?.materialType || 'materials').toLowerCase();

  const url = new URL(API_BASE + '/materials');
  url.searchParams.set('category', category);
  if (klass) url.searchParams.set('class', klass);

  fetch(url.toString())
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      const items = Array.isArray(data?.items) ? data.items : [];
      track.innerHTML = '';

      if (!items.length) {
        const empty = document.createElement('article');
        empty.className = 'note-card';
        empty.style.cssText = '--card:#f1f5f9; --ring:#94a3b8';
        empty.innerHTML = '<div class="note-top"><div class="note-title"><strong>No</strong><br />notes yet</div></div>';
        track.appendChild(empty);
        return;
      }

      const palette = [
        { card: '#ffd9d9', ring: '#ff8a5b' },
        { card: '#dedbff', ring: '#5b34ff' },
        { card: '#e2dcff', ring: '#7a52cf' },
        { card: '#cfe2ff', ring: '#6aa7ff' },
        { card: '#dcfce7', ring: '#22c55e' },
        { card: '#ede9fe', ring: '#8b5cf6' },
      ];

      items.slice(0, 12).forEach((it, idx) => {
        const c = palette[idx % palette.length];
        const subjectLabel = String(it.subject || '').trim();
        const chapterLabel = String(it.chapter || '').trim();
        const isChapterSolutions = category === 'chaptersolutions' || String(it.category || '').toLowerCase() === 'chaptersolutions';
        const title = (isChapterSolutions ? subjectLabel : it.title || it.fileName || 'Revision Notes').toString().trim();
        const link = it.webViewLink || it.webContentLink || '';
        const isYears = category === 'yearspapers' || String(it.category || '').toLowerCase() === 'yearspapers';
        const yearLabel = (it.year || '').toString().trim();
        const fileId = String(it.fileId || '').trim();
        const thumb = fileId ? `https://drive.google.com/thumbnail?id=${encodeURIComponent(fileId)}&sz=w320` : 'assets/notes/note1.png';

        const card = document.createElement('article');
        card.className = 'note-card';
        card.style.cssText = `--card:${c.card}; --ring:${c.ring}`;
        card.tabIndex = 0;
        card.setAttribute('role', 'button');
        card.setAttribute('aria-label', `Open ${title}`);
        card.style.cursor = 'pointer';
        if (isYears && yearLabel) card.dataset.year = yearLabel;
        card.dataset.category = isYears ? 'yearspapers' : 'materials';
        card.innerHTML = `
          <div class="note-top">
            <div class="note-title"><strong>${escapeHtml(title || 'Chapter Solution')}</strong><br />${
              isYears ? "year's papers" : isChapterSolutions ? escapeHtml(chapterLabel || 'chapter solution') : 'revision notes'
            }</div>
          </div>
          <div class="note-circle"><img src="${thumb}" alt="${escapeHtml(title)}" onerror="this.onerror=null;this.src='assets/notes/note1.png';" /></div>
        `;

        const open = () => {
          if (shouldRedirectToStudent) {
            const u = new URL('student.html', window.location.href);
            u.searchParams.set('view', isYears ? 'yearspapers' : category === 'chaptersolutions' ? 'chaptersolutions' : 'materials');
            if (klass) u.searchParams.set('class', klass);
            u.searchParams.set('category', isYears ? 'yearspapers' : 'materials');
            if (isYears && yearLabel) u.searchParams.set('year', yearLabel);
            window.location.href = u.toString();
            return;
          }
          if (link) window.open(link, '_blank', 'noopener');
        };

        card.addEventListener('click', open);
        card.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            open();
          }
        });

        track.appendChild(card);
      });
    })
    .catch(() => {
      track.innerHTML = '';
      const fail = document.createElement('article');
      fail.className = 'note-card';
      fail.style.cssText = '--card:#ffe4e6; --ring:#fb7185';
      fail.innerHTML = '<div class="note-top"><div class="note-title"><strong>Failed</strong><br />to load</div></div>';
      track.appendChild(fail);
    });
}

function loadRecordedLectures({ class: klass } = {}) {
  const root = qs('#lecturesCarousel');
  if (!root) return;
  const track = qs('.notes-track', root);
  if (!track) return;

  const shouldRedirectToStudent = !qs('#studentShell');

  const url = new URL(API_BASE + '/lectures');
  if (klass) url.searchParams.set('class', klass);

  fetch(url.toString())
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      const items = Array.isArray(data?.items) ? data.items : [];
      track.innerHTML = '';

      if (!items.length) {
        const empty = document.createElement('article');
        empty.className = 'note-card';
        empty.style.cssText = '--card:#f1f5f9; --ring:#94a3b8';
        empty.innerHTML = '<div class="note-top"><div class="note-title"><strong>No</strong><br />lectures yet</div></div>';
        track.appendChild(empty);
        return;
      }

      items.slice(0, 12).forEach((it) => {
        const card = document.createElement('article');
        card.className = 'note-card';
        card.style.cssText = '--card:#dbeafe; --ring:#3b82f6';
        card.tabIndex = 0;
        card.setAttribute('role', 'button');
        card.setAttribute('aria-label', `Play ${it.subject} lecture`);
        card.style.cursor = 'pointer';
        const thumb = youtubeThumbnailUrl(it.youtubeUrl) || 'assets/lectures/lec2.jpg';
        card.innerHTML = `
          <div class="note-top">
            <div class="note-title"><strong>${escapeHtml(it.subject || 'Lecture')}</strong><br />recorded lecture</div>
          </div>
          <div class="note-circle"><img src="${thumb}" alt="${escapeHtml(it.subject || 'Lecture')} recorded lecture" /></div>
        `;

        const play = () => {
          if (shouldRedirectToStudent) {
            const u = new URL('student.html', window.location.href);
            u.searchParams.set('view', 'lectures');
            if (klass) u.searchParams.set('class', klass);
            window.location.href = u.toString();
            return;
          }
          openLecturePlayer({
            title: `${it.subject || 'Lecture'} (Class ${it.class || ''}${it.section ? ' ' + it.section : ''})`,
            youtubeUrl: it.youtubeUrl,
          });
        };

        card.addEventListener('click', play);
        card.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            play();
          }
        });

        track.appendChild(card);
      });
    })
    .catch(() => {
      track.innerHTML = '';
      const fail = document.createElement('article');
      fail.className = 'note-card';
      fail.style.cssText = '--card:#ffe4e6; --ring:#fb7185';
      fail.innerHTML = '<div class="note-top"><div class="note-title"><strong>Failed</strong><br />to load</div></div>';
      track.appendChild(fail);
    });
}

function escapeHtml(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function setupAnnouncementsAndTimetable() {
  const annTrack = qs('#annTrack');
  const annScroll = qs('#annScroll');
  const annClass = qs('#annClass');
  const annSection = qs('#annSection');
  const annNote = qs('#annNote');

  const ttList = qs('#ttList');
  const ttClass = qs('#ttClass');
  const ttSection = qs('#ttSection');
  const ttRefresh = qs('#ttRefresh');
  const ttNote = qs('#ttNote');

  if (!annTrack && !ttList) return;

  const uniqSorted = (arr) => {
    const s = new Set(
      arr
        .filter((x) => x !== null && x !== undefined && String(x).trim() !== '')
        .map((x) => String(x).trim())
    );
    return Array.from(s).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));
  };

  const setOptions = (sel, values, { includeAll = true, allLabel = 'All', keep = true } = {}) => {
    if (!sel) return;
    const prev = keep ? sel.value : '';
    sel.innerHTML = includeAll ? `<option value="">${allLabel}</option>` : '<option value="">Select</option>';
    values.forEach((v) => {
      const opt = document.createElement('option');
      opt.value = v;
      opt.textContent = v;
      sel.appendChild(opt);
    });
    if (keep && values.includes(prev)) sel.value = prev;
  };

  async function loadAnnouncements() {
    if (!annTrack) return;
    const url = new URL(API_BASE + '/announcements');
    if (annClass?.value) url.searchParams.set('class', annClass.value);
    if (annSection?.value) url.searchParams.set('section', annSection.value);

    if (annNote) annNote.textContent = 'Loading…';
    annTrack.innerHTML = '';

    try {
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const items = Array.isArray(data?.items) ? data.items : [];

      const allClasses = uniqSorted(items.map((x) => x.class));
      const allSections = uniqSorted(items.map((x) => x.section));
      if (annClass && annClass.options.length <= 1) setOptions(annClass, allClasses, { includeAll: true, allLabel: 'All', keep: true });
      if (annSection && annSection.options.length <= 1) setOptions(annSection, allSections, { includeAll: true, allLabel: 'All', keep: true });

      if (!items.length) {
        annTrack.innerHTML = '<div class="notice-item">No announcements yet.</div>';
        if (annNote) annNote.textContent = '';
        if (annScroll) annScroll.dataset.animate = 'false';
        return;
      }

      const renderItems = (arr) => {
        annTrack.innerHTML = '';
        arr.forEach((it) => {
          const div = document.createElement('div');
          div.className = 'notice-item';
          div.innerHTML = `<strong>Class ${escapeHtml(it.class || '')}${it.section ? ' • ' + escapeHtml(it.section) : ''}</strong><div style="margin-top:6px">${escapeHtml(it.text || '')}</div>`;
          annTrack.appendChild(div);
        });
      };

      renderItems(items);

      if (annScroll) {
        const needsScroll = annTrack.scrollHeight > annScroll.clientHeight + 8;
        if (needsScroll) {
          const clone = items.map((x) => ({ ...x }));
          renderItems(items.concat(clone));
          annScroll.dataset.animate = 'true';
        } else {
          annScroll.dataset.animate = 'false';
        }
      }

      if (annNote) annNote.textContent = '';
    } catch {
      annTrack.innerHTML = '<div class="notice-item">Failed to load announcements.</div>';
      if (annNote) annNote.textContent = '';
      if (annScroll) annScroll.dataset.animate = 'false';
    }
  }

  async function loadTimetables() {
    if (!ttList) return;
    const url = new URL(API_BASE + '/timetables');
    if (ttClass?.value) url.searchParams.set('class', ttClass.value);
    if (ttSection?.value) url.searchParams.set('section', ttSection.value);

    if (ttNote) ttNote.textContent = 'Loading…';
    ttList.innerHTML = '';

    try {
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const items = Array.isArray(data?.items) ? data.items : [];

      const classes = uniqSorted(items.map((x) => x.class));
      const sections = uniqSorted(items.map((x) => x.section));
      if (ttClass && ttClass.options.length <= 1) setOptions(ttClass, classes, { includeAll: false, keep: true });
      if (ttSection && ttSection.options.length <= 1) setOptions(ttSection, sections, { includeAll: false, keep: true });

      if (!items.length) {
        ttList.innerHTML = '<div class="notice-item">No time-table uploaded yet.</div>';
        if (ttNote) ttNote.textContent = '';
        return;
      }

      items.forEach((it) => {
        const row = document.createElement('div');
        row.className = 'notice-link';
        const title = (it.title || it.fileName || 'Time-table').trim();
        const link = it.webViewLink || it.webContentLink || '';
        row.innerHTML = `
          <div style="min-width:0">
            <strong>${escapeHtml(title)}</strong>
            <div class="muted" style="font-size:12px; margin-top:4px">Class ${escapeHtml(it.class || '')}${it.section ? ' • ' + escapeHtml(it.section) : ''}</div>
          </div>
          ${link ? `<a href="${link}" target="_blank" rel="noopener">Download PDF</a>` : '<span class="muted" style="font-size:12px">No link</span>'}
        `;
        ttList.appendChild(row);
      });

      if (ttNote) ttNote.textContent = '';
    } catch {
      ttList.innerHTML = '<div class="notice-item">Failed to load time-table.</div>';
      if (ttNote) ttNote.textContent = '';
    }
  }

  if (annClass) annClass.addEventListener('change', loadAnnouncements);
  if (annSection) annSection.addEventListener('change', loadAnnouncements);

  if (ttRefresh) ttRefresh.addEventListener('click', loadTimetables);
  if (ttClass) ttClass.addEventListener('change', loadTimetables);
  if (ttSection) ttSection.addEventListener('change', loadTimetables);

  loadAnnouncements();
  loadTimetables();
}

function setupStudentDashboard() {
  const shell = qs('#studentShell');
  if (!shell) return;

  const tabs = qsa('.student-tab', shell);
  const classSel = qs('#studentClass', shell);
  const sectionSel = qs('#studentSection', shell);
  const subjectSel = qs('#studentSubject', shell);
  const refreshBtn = qs('#studentRefresh', shell);
  const statusEl = qs('#studentStatus', shell);
  const listEl = qs('#studentList', shell);
  const backBtn = qs('#studentBackBtn');

  let yearSel = qs('#studentYear', shell);
  if (!yearSel) {
    const filters = qs('.student-filters', shell);
    const subjectLabel = subjectSel?.closest?.('label');
    const yearLabel = document.createElement('label');
    yearLabel.id = 'studentYearWrap';
    yearLabel.style.display = 'none';
    yearLabel.innerHTML = '<span>Year</span>';

    yearSel = document.createElement('select');
    yearSel.id = 'studentYear';
    yearSel.setAttribute('aria-label', 'Year');

    yearLabel.appendChild(yearSel);

    if (filters && subjectLabel && subjectLabel.parentElement === filters) {
      subjectLabel.insertAdjacentElement('afterend', yearLabel);
    } else if (filters) {
      filters.appendChild(yearLabel);
    } else {
      shell.appendChild(yearLabel);
    }
  }

  let chapterSel = qs('#studentChapter', shell);
  if (!chapterSel) {
    const filters = qs('.student-filters', shell);
    const yearLabel = qs('#studentYearWrap', shell);
    const chapterLabel = document.createElement('label');
    chapterLabel.id = 'studentChapterWrap';
    chapterLabel.style.display = 'none';
    chapterLabel.innerHTML = '<span>Chapter</span>';

    chapterSel = document.createElement('select');
    chapterSel.id = 'studentChapter';
    chapterSel.setAttribute('aria-label', 'Chapter');
    chapterLabel.appendChild(chapterSel);

    if (filters && yearLabel && yearLabel.parentElement === filters) {
      yearLabel.insertAdjacentElement('afterend', chapterLabel);
    } else if (filters) {
      filters.appendChild(chapterLabel);
    } else {
      shell.appendChild(chapterLabel);
    }
  }

  const params = new URLSearchParams(window.location.search);
  const initialView = (params.get('view') || 'lectures').toLowerCase();
  const initialClass = (params.get('class') || '').trim();
  const initialSection = (params.get('section') || '').trim();
  const initialSubject = (params.get('subject') || '').trim();
  const initialCategory = (params.get('category') || 'materials').toLowerCase();
  const initialYear = (params.get('year') || '').trim();
  const initialChapter = (params.get('chapter') || '').trim();

  const state = {
    view:
      initialView === 'materials' || initialView === 'yearspapers' || initialView === 'chaptersolutions' ? initialView : 'lectures',
    klass: initialClass,
    section: initialSection,
    subject: initialSubject,
    category:
      initialView === 'chaptersolutions'
        ? 'chaptersolutions'
        : initialView === 'yearspapers'
          ? 'yearspapers'
          : initialCategory === 'yearspapers'
            ? 'yearspapers'
            : initialCategory === 'chaptersolutions'
              ? 'chaptersolutions'
              : 'materials',
    year: initialYear,
    chapter: initialChapter,
  };

  const setStatus = (msg) => {
    if (statusEl) statusEl.textContent = msg || '';
  };

  const setSelectOptions = (sel, values, { placeholder } = {}) => {
    if (!sel) return;
    const current = (sel.value || '').trim();
    sel.innerHTML = '';

    const ph = document.createElement('option');
    ph.value = '';
    ph.textContent = placeholder || 'All';
    sel.appendChild(ph);

    values.forEach((v) => {
      const opt = document.createElement('option');
      opt.value = v;
      opt.textContent = v;
      sel.appendChild(opt);
    });

    if (values.includes(current)) sel.value = current;
  };

  const applyYearVisibility = () => {
    const show = state.view === 'yearspapers' || (state.view === 'materials' && state.category === 'yearspapers');
    if (!yearSel) return;
    const wrap = yearSel.closest('label') || qs('#studentYearWrap', shell);
    if (wrap) wrap.style.display = show ? '' : 'none';
  };

  const applyChapterVisibility = () => {
    const show = state.view === 'chaptersolutions';
    if (!chapterSel) return;
    const wrap = chapterSel.closest('label') || qs('#studentChapterWrap', shell);
    if (wrap) wrap.style.display = show ? '' : 'none';
  };

  const normalizeKlass = (k) => {
    const s = String(k || '').trim();
    if (!s) return '';
    return s;
  };

  const uniqueSorted = (arr) => {
    return Array.from(new Set((arr || []).map((x) => String(x || '').trim()).filter(Boolean))).sort((a, b) =>
      a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' })
    );
  };

  const getFiltersFromUI = () => {
    state.klass = normalizeKlass(classSel?.value);
    state.section = (sectionSel?.value || '').trim();
    state.subject = (subjectSel?.value || '').trim();
    state.year = (yearSel?.value || '').trim();
    state.chapter = (chapterSel?.value || '').trim();
  };

  const applyFiltersToUI = () => {
    if (classSel) classSel.value = state.klass || '';
    if (sectionSel) sectionSel.value = state.section || '';
    if (subjectSel) subjectSel.value = state.subject || '';
    if (yearSel) yearSel.value = state.year || '';
    if (chapterSel) chapterSel.value = state.chapter || '';
  };

  const setActiveTab = (view) => {
    state.view = view === 'materials' || view === 'yearspapers' || view === 'chaptersolutions' ? view : 'lectures';
    tabs.forEach((t) => {
      const isActive = (t.dataset.view || '') === state.view;
      t.classList.toggle('active', isActive);
      t.setAttribute('aria-selected', String(isActive));
    });
    if (state.view === 'materials') {
      state.category = 'materials';
      state.year = '';
      state.chapter = '';
    } else if (state.view === 'yearspapers') {
      state.category = 'yearspapers';
      state.chapter = '';
    } else if (state.view === 'chaptersolutions') {
      state.category = 'chaptersolutions';
      state.year = '';
    } else {
      state.category = 'materials';
      state.year = '';
      state.chapter = '';
    }
    applyYearVisibility();
    applyChapterVisibility();
  };

  const renderEmpty = (label) => {
    if (!listEl) return;
    listEl.innerHTML = '';
    const row = document.createElement('div');
    row.className = 'student-item';
    row.innerHTML = `
      <div class="student-item-left">
        <div class="student-item-title">No ${escapeHtml(label)}</div>
        <div class="student-item-meta">Try changing filters.</div>
      </div>
    `;
    listEl.appendChild(row);
  };

  const renderError = () => {
    if (!listEl) return;
    listEl.innerHTML = '';
    const row = document.createElement('div');
    row.className = 'student-item';
    row.innerHTML = `
      <div class="student-item-left">
        <div class="student-item-title">Failed to load</div>
        <div class="student-item-meta">Please try again.</div>
      </div>
    `;
    listEl.appendChild(row);
  };

  const renderMaterials = (items) => {
    if (!listEl) return;
    listEl.innerHTML = '';

    if (!items.length) {
      renderEmpty('study materials');
      return;
    }

    items.forEach((it) => {
      const title = (it.title || it.fileName || 'Study Material').trim();
      const meta = `Class ${it.class || ''}${it.section ? ' • ' + it.section : ''}${it.subject ? ' • ' + it.subject : ''}`.trim();
      const link = it.webViewLink || it.webContentLink || '';
      const row = document.createElement('div');
      row.className = 'student-item';
      row.innerHTML = `
        <div class="student-item-left">
          <div class="student-item-title">${escapeHtml(title)}</div>
          <div class="student-item-meta">${escapeHtml(meta)}</div>
        </div>
        <div class="student-item-right">
          <a class="student-item-link" href="${escapeHtml(link)}" target="_blank" rel="noopener">Open</a>
        </div>
      `;
      listEl.appendChild(row);
    });
  };

  const renderLectures = (items) => {
    if (!listEl) return;
    listEl.innerHTML = '';

    if (!items.length) {
      renderEmpty('lectures');
      return;
    }

    items.forEach((it) => {
      const title = `${it.subject || 'Lecture'}${it.title ? ' • ' + it.title : ''}`.trim();
      const meta = `Class ${it.class || ''}${it.section ? ' • ' + it.section : ''}${it.youtubeUrl ? ' • YouTube' : ''}`.trim();
      const row = document.createElement('div');
      row.className = 'student-item';
      row.innerHTML = `
        <div class="student-item-left">
          <div class="student-item-title">${escapeHtml(title)}</div>
          <div class="student-item-meta">${escapeHtml(meta)}</div>
        </div>
        <div class="student-item-right">
          <button class="btn btn-primary" type="button">Play</button>
        </div>
      `;
      const btn = qs('button', row);
      if (btn) {
        btn.addEventListener('click', () => {
          openLecturePlayer({
            title: `${it.subject || 'Lecture'} (Class ${it.class || ''}${it.section ? ' ' + it.section : ''})`,
            youtubeUrl: it.youtubeUrl,
          });
        });
      }
      listEl.appendChild(row);
    });
  };

  const fetchItems = async () => {
    if (!listEl) return;
    getFiltersFromUI();

    setStatus('Loading...');
    listEl.innerHTML = '';

    const isMaterials = state.view === 'materials' || state.view === 'yearspapers' || state.view === 'chaptersolutions';
    const url = new URL(API_BASE + (isMaterials ? '/materials' : '/lectures'));
    if (isMaterials) {
      url.searchParams.set(
        'category',
        state.view === 'yearspapers' ? 'yearspapers' : state.view === 'chaptersolutions' ? 'chaptersolutions' : 'materials'
      );
    }
    if (state.klass) url.searchParams.set('class', state.klass);
    if (state.section) url.searchParams.set('section', state.section);
    if (state.subject) url.searchParams.set('subject', state.subject);
    if (isMaterials && state.view === 'yearspapers' && state.year) url.searchParams.set('year', state.year);
    if (isMaterials && state.view === 'chaptersolutions' && state.chapter) url.searchParams.set('chapter', state.chapter);

    try {
      const r = await fetch(url.toString());
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const data = await r.json();
      const items = Array.isArray(data?.items) ? data.items : [];

      const classes = uniqueSorted(items.map((x) => x.class));
      const sections = uniqueSorted(items.map((x) => x.section));
      const subjects = uniqueSorted(items.map((x) => x.subject));
      const years = uniqueSorted(items.map((x) => x.year));
      const chapters = uniqueSorted(items.map((x) => x.chapter));

      setSelectOptions(classSel, classes, { placeholder: 'All classes' });
      setSelectOptions(sectionSel, sections, { placeholder: 'All sections' });
      setSelectOptions(subjectSel, subjects, { placeholder: 'All subjects' });
      setSelectOptions(yearSel, years, { placeholder: 'All years' });
      setSelectOptions(chapterSel, chapters, { placeholder: 'All chapters' });

      applyFiltersToUI();

      if (isMaterials) {
        const inferred = (params.get('category') || state.category || 'materials').toLowerCase();
        state.category = inferred === 'yearspapers' ? 'yearspapers' : 'materials';
      }
      applyYearVisibility();

      setStatus(items.length ? `Showing ${items.length} item(s).` : 'No items found.');

      if (isMaterials) renderMaterials(items);
      else renderLectures(items);
    } catch {
      setStatus('');
      renderError();
    }
  };

  tabs.forEach((t) => {
    t.addEventListener('click', () => {
      setActiveTab(t.dataset.view);
      fetchItems();
    });
  });

  [classSel, sectionSel, subjectSel].forEach((sel) => {
    if (!sel) return;
    sel.addEventListener('change', fetchItems);
  });

  if (yearSel) yearSel.addEventListener('change', fetchItems);
  if (chapterSel) chapterSel.addEventListener('change', fetchItems);

  if (refreshBtn) refreshBtn.addEventListener('click', fetchItems);

  if (backBtn) {
    backBtn.addEventListener('click', (e) => {
      e.preventDefault();
      if (window.history.length > 1) window.history.back();
      else window.location.href = 'index.html';
    });
  }

  setActiveTab(state.view);

  const seedSelects = () => {
    setSelectOptions(classSel, [], { placeholder: 'All classes' });
    setSelectOptions(sectionSel, [], { placeholder: 'All sections' });
    setSelectOptions(subjectSel, [], { placeholder: 'All subjects' });
    setSelectOptions(yearSel, [], { placeholder: 'All years' });
    setSelectOptions(chapterSel, [], { placeholder: 'All chapters' });
    applyFiltersToUI();
  };

  seedSelects();
  applyYearVisibility();
  applyChapterVisibility();
  fetchItems();
}

function setupStudentRedirects() {
  if (qs('#studentShell')) return;

  const labelToClass = (label) => {
    const s = String(label || '').toLowerCase();
    if (s.includes('12 pass')) return '12pass';
    const m = s.match(/class\s*(\d+)/);
    return m ? m[1] : '';
  };

  const getActiveClassFromSection = (ariaLabel) => {
    const section = qsa('section.offerings').find((x) => (x.getAttribute('aria-label') || '') === ariaLabel);
    const active = section ? qs('.offerings-tabs .tab.active', section) : null;
    return labelToClass(active?.textContent);
  };

  const go = ({ view, klass } = {}) => {
    const url = new URL('student.html', window.location.href);
    url.searchParams.set('view', view === 'materials' ? 'materials' : 'lectures');
    if (klass) url.searchParams.set('class', klass);
    window.location.href = url.toString();
  };

  const bind = ({ rootId, view, sectionLabel }) => {
    const root = qs(rootId);
    if (!root) return;

    let down = null;

    root.addEventListener(
      'pointerdown',
      (e) => {
        const card = e.target?.closest?.('.note-card');
        if (!card) return;
        down = { x: e.clientX, y: e.clientY, card };
      },
      true
    );

    root.addEventListener(
      'pointerup',
      (e) => {
        if (!down) return;

        const dx = Math.abs(e.clientX - down.x);
        const dy = Math.abs(e.clientY - down.y);
        const card = down.card;
        down = null;

        if (dx > 6 || dy > 6) return;

        e.preventDefault();
        e.stopPropagation();

        const klass = getActiveClassFromSection(sectionLabel);
        go({ view, klass });
      },
      true
    );

    root.addEventListener(
      'pointercancel',
      () => {
        down = null;
      },
      true
    );

    root.addEventListener(
      'keydown',
      (e) => {
        if (e.key !== 'Enter' && e.key !== ' ') return;
        const card = e.target?.closest?.('.note-card');
        if (!card) return;
        e.preventDefault();
        e.stopPropagation();
        const klass = getActiveClassFromSection(sectionLabel);
        go({ view, klass });
      },
      true
    );
  };

  bind({ rootId: '#notesCarousel', view: 'materials', sectionLabel: 'Study materials offerings' });
  bind({ rootId: '#lecturesCarousel', view: 'lectures', sectionLabel: 'Recorded lectures offerings' });
}
