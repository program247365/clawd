// Page chrome: the Clawd menu, the Acts window, copy buttons, the clock.
(() => {
  const root = document.documentElement;

  // The menubar item is the app's real menu, and it works on the page's Clawd.
  const button = document.getElementById('clawd-menu-button');
  const panel = document.getElementById('clawd-menu');
  const toggle = document.getElementById('toggle-clawd');
  const sizeButtons = [...panel.querySelectorAll('[data-size]')];

  function setOpen(open) {
    panel.hidden = !open;
    button.setAttribute('aria-expanded', String(open));
  }
  button.addEventListener('click', () => setOpen(panel.hidden));
  document.addEventListener('click', event => {
    if (!panel.hidden && !event.target.closest('.menu')) setOpen(false);
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !panel.hidden) { setOpen(false); button.focus(); }
  });
  panel.querySelector('a').addEventListener('click', () => setOpen(false));

  // The menu names whoever is on the page.
  let characterName = 'Clawd';
  const labelToggle = () => {
    toggle.textContent = `${root.hasAttribute('data-hidden') ? 'Show' : 'Hide'} ${characterName}`;
  };
  toggle.addEventListener('click', () => {
    root.toggleAttribute('data-hidden');
    labelToggle();
    setOpen(false);
  });

  for (const sizeButton of sizeButtons) {
    sizeButton.addEventListener('click', () => {
      root.dataset.size = sizeButton.dataset.size;
      for (const other of sizeButtons) other.setAttribute('aria-pressed', String(other === sizeButton));
      setOpen(false);
    });
  }

  // Acts window: click one and he does it.
  const acts = [...document.querySelectorAll('.act')];
  const hint = document.getElementById('acts-hint');
  const clawd = window.Clawd;
  if (clawd && clawd.live) {
    for (const act of acts) {
      act.setAttribute('aria-pressed', 'false');
      act.addEventListener('click', () => {
        if (root.hasAttribute('data-hidden')) toggle.click();
        clawd.perform(act.dataset.act);
      });
    }
    clawd.onAct(name => {
      for (const act of acts) act.setAttribute('aria-pressed', String(act.dataset.act === name));
    });
    // These are Clawd's acts; with someone else on the page, a click brings him back to do one.
    clawd.onCharacter(character => {
      characterName = character.name;
      labelToggle();
      hint.textContent = character.id === 'clawd'
        ? "Click one and he'll do it."
        : `These are Clawd's. Click one and he'll swap back in to do it.`;
    });
  }
  // No animation library, or the walk never arrived: the thumbnails still show what he does.
  function showActsAsStills() {
    hint.textContent = "The animations didn't load, but here is everything he does.";
    for (const act of acts) act.disabled = true;
  }
  if (!clawd || !clawd.live) showActsAsStills();
  document.addEventListener('clawd:static', showActsAsStills);

  // Copy buttons.
  for (const copy of document.querySelectorAll('.copy')) {
    copy.addEventListener('click', async () => {
      const text = document.getElementById(copy.dataset.copy).textContent;
      try {
        await navigator.clipboard.writeText(text);
        copy.textContent = 'Copied';
        copy.dataset.copied = '';
      } catch {
        copy.textContent = 'Select and copy';
      }
      setTimeout(() => { copy.textContent = 'Copy'; delete copy.dataset.copied; }, 2000);
    });
  }

  // Say so plainly when the visitor isn't on a Mac.
  const platform = navigator.userAgentData?.platform || navigator.platform || '';
  const isTouchApple = /iPhone|iPad|iPod/.test(navigator.userAgent) || (/Mac/.test(platform) && navigator.maxTouchPoints > 1);
  if (!/Mac/i.test(platform) || isTouchApple) {
    document.getElementById('platform-note').textContent =
      "You're not on a Mac right now. Clawd is a Mac app and needs macOS 14 or later.";
  }

  // The lock screen clip plays while it's on screen. With reduced motion it waits to be asked.
  const lockVideo = document.getElementById('lock-video');
  if (matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
    lockVideo.controls = true;
  } else {
    new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) lockVideo.play().catch(() => { lockVideo.controls = true; });
      else lockVideo.pause();
    }, { threshold: 0.4 }).observe(lockVideo);
  }

  const clock = document.getElementById('clock');
  function tick() {
    clock.textContent = new Date().toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' });
  }
  tick();
  setInterval(tick, 30000);
})();
