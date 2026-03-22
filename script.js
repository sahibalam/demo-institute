const qs = (s, el = document) => el.querySelector(s);
const qsa = (s, el = document) => Array.from(el.querySelectorAll(s));

function setYear() {
  const y = qs('#year');
  if (y) y.textContent = String(new Date().getFullYear());
}

function setupMobileNav() {
  const toggle = qs('#navToggle');
  const nav = qs('#primaryNav');
  if (!toggle || !nav) return;

  const close = () => {
    nav.classList.remove('open');
    toggle.setAttribute('aria-expanded', 'false');
  };

  toggle.addEventListener('click', () => {
    const isOpen = nav.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(isOpen));
  });

  qsa('a', nav).forEach((a) => a.addEventListener('click', close));

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') close();
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

  const handle = (form, noteEl) => {
    if (!form || !noteEl) return;
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      noteEl.textContent = 'Thanks! We received your message. (Demo frontend — no backend connected)';
      form.reset();
    });
  };

  handle(lead, leadNote);
  handle(contact, contactNote);
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

  const getLoopPoint = () => {
    if (!track) return 0;
    return Math.floor(track.scrollWidth / 2);
  };

  const wrap = () => {
    const loopPoint = getLoopPoint();
    if (!loopPoint) return;
    if (viewport.scrollLeft >= loopPoint) viewport.scrollLeft -= loopPoint;
    if (viewport.scrollLeft < 0) viewport.scrollLeft += loopPoint;
  };

  const reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduceMotion) return;

  let raf = 0;
  let paused = false;

  const tick = () => {
    if (!paused) {
      viewport.scrollLeft += 0.35;
      wrap();
    }
    raf = window.requestAnimationFrame(tick);
  };

  const start = () => {
    if (raf) return;
    raf = window.requestAnimationFrame(tick);
  };

  const stop = () => {
    if (!raf) return;
    window.cancelAnimationFrame(raf);
    raf = 0;
  };

  const pause = () => {
    paused = true;
  };

  const resume = () => {
    paused = false;
  };

  root.addEventListener('mouseenter', pause);
  root.addEventListener('mouseleave', resume);
  viewport.addEventListener('focusin', pause);
  viewport.addEventListener('focusout', resume);
  viewport.addEventListener('pointerdown', pause);
  viewport.addEventListener('pointerup', resume);
  viewport.addEventListener('pointercancel', resume);
  window.addEventListener('blur', pause);

  viewport.addEventListener('scroll', wrap, { passive: true });

  start();
}

function setupOfferingsTabs() {
  const roots = qsa('.offerings-tabs');
  if (!roots.length) return;

  roots.forEach((root) => {
    const tabs = qsa('.tab', root);
    if (!tabs.length) return;

    tabs.forEach((t) => {
      t.addEventListener('click', () => {
        tabs.forEach((x) => {
          x.classList.remove('active');
          x.setAttribute('aria-selected', 'false');
        });
        t.classList.add('active');
        t.setAttribute('aria-selected', 'true');
      });
    });
  });
}

setYear();
setupMobileNav();
setupCounters();
setupForms();
setupProgramsCarousel();
setupNotesCarousel();
setupOfferingsTabs();
setupStudentsCarousel();
