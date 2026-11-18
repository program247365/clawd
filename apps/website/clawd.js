// Clawd's routine on the page: the same rules as the Mac app.
// Walk to a stop, perform an act, repeat; about one time in four, teleport instead of walking.
(() => {
  const root = document.documentElement;
  const el = document.getElementById('clawd');
  const body = el.querySelector('.clawd-body');
  const status = document.getElementById('clawd-status');

  const WALK_SPEED_FACTOR = 140 / 360; // Clawd-widths per second
  const WALK_FACES_RIGHT = true;       // native facing of the walking animation
  const SHORT_ACT_FRAMES = 40;         // acts shorter than this play twice
  const TELEPORT_CHANCE = 0.25;
  // clawd-walking.json: frames 0–4 stand + lean in, 5–24 step cycle, 25–27 stand.
  // Looping only the step cycle keeps him from sliding while posed still.
  const WALK_CYCLE = [5, 25];
  const STANDING_FRAME = 26;

  const listeners = new Set();
  const api = {
    live: false,
    perform() {},
    onAct(fn) { listeners.add(fn); },
  };
  window.Clawd = api;

  // Without the animation library or data, the static Clawd in the markup stays.
  if (!window.lottie || !window.CLAWD) {
    root.dataset.clawd = 'static';
    return;
  }

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const actNames = Object.keys(window.CLAWD).filter(n => n !== 'walking');
  const players = {};

  function player(name) {
    if (!players[name]) {
      const data = window.CLAWD[name];
      const container = document.createElement('div');
      container.className = 'anim';
      body.appendChild(container);
      const anim = lottie.loadAnimation({
        container, renderer: 'canvas', loop: false, autoplay: false, animationData: data,
      });
      players[name] = { el: container, anim, frames: data.op - data.ip };
    }
    return players[name];
  }

  let current = null;
  function show(name, { loop = false, segment = null, still = null } = {}) {
    if (current) { current.el.classList.remove('on'); current.anim.stop(); }
    const p = current = player(name);
    p.anim.loop = loop;
    const start = () => {
      if (current !== p) return;
      if (still !== null) p.anim.goToAndStop(still, true);
      else if (segment) p.anim.playSegments(segment, true);
      else p.anim.goToAndPlay(0, true);
      // Only now is he drawn, so only now does the static Clawd in the markup step aside.
      root.dataset.clawd = 'live';
    };
    // Lottie ignores playback calls made before it has finished setting up.
    if (p.anim.isLoaded) start(); else p.anim.addEventListener('DOMLoaded', start);
    p.el.classList.add('on');
    return p;
  }

  function announce(name) {
    status.textContent = name.replace(/-/g, ' ');
    for (const fn of listeners) fn(name);
  }

  // Position. x is the left edge; lift is how far above the floor he is (teleports only).
  let x = Math.round(innerWidth * 0.08);
  let lift = 0;
  let dir = 1;
  const width = () => el.offsetWidth;
  const maxX = () => Math.max(0, document.documentElement.clientWidth - width());
  function place() {
    el.style.transform = `translate3d(${x}px, ${-lift}px, 0)`;
    body.dataset.facing = (dir === 1) === WALK_FACES_RIGHT ? 'right' : 'left';
  }

  // Anything that should cut the routine short bumps the generation.
  let generation = 0;
  let wake = [];
  function interrupt() {
    generation++;
    for (const resolve of wake.splice(0)) resolve();
  }
  const interrupted = () => new Promise(resolve => wake.push(resolve));
  const pause = ms => Promise.race([new Promise(r => setTimeout(r, ms)), interrupted()]);

  function walkTo(target) {
    const mine = generation;
    dir = target >= x ? 1 : -1;
    announce('walking');
    show('walking', { loop: true, segment: WALK_CYCLE });
    const arrived = new Promise(resolve => {
      let last = performance.now();
      function step(now) {
        if (generation !== mine) { resolve(); return; }
        const dt = Math.min(now - last, 50) / 1000;
        last = now;
        x += dir * width() * WALK_SPEED_FACTOR * dt;
        if ((dir === 1 && x >= target) || (dir === -1 && x <= target)) {
          x = target; place(); resolve(); return;
        }
        place();
        requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    });
    // Don't wait for the next frame to notice an interruption: frames pause in a background tab.
    return Promise.race([arrived, interrupted()]);
  }

  function perform(name) {
    announce(name);
    const p = show(name);
    let plays = p.frames < SHORT_ACT_FRAMES ? 2 : 1;
    const finished = new Promise(resolve => {
      const done = () => {
        if (--plays > 0) { p.anim.goToAndPlay(0, true); return; }
        p.anim.removeEventListener('complete', done);
        resolve();
      };
      p.anim.addEventListener('complete', done);
    });
    return Promise.race([finished, interrupted()]);
  }

  async function pop(visible) {
    if (visible) delete body.dataset.popped; else body.dataset.popped = '';
    await pause(160);
  }

  function randomStop() {
    const max = maxX();
    // Walk at least a third of the way, alternating direction when there's room.
    const minHop = max / 3;
    const goRight = dir === -1 ? x + minHop <= max : x - minHop < 0;
    const stop = goRight
      ? x + minHop + Math.random() * Math.max(0, max - x - minHop)
      : Math.random() * Math.max(0, x - minHop);
    return Math.min(Math.max(stop, 0), max);
  }

  let queue = [];
  function nextAct() {
    if (!queue.length) queue = [...actNames].sort(() => Math.random() - 0.5);
    return queue.pop();
  }

  function backToFloor() {
    lift = 0;
    x = Math.min(Math.max(x, 0), maxX());
    delete body.dataset.popped;
    place();
  }

  let requested = null;
  async function run() {
    place();
    for (;;) {
      const mine = generation;
      backToFloor();
      if (root.hasAttribute('data-hidden')) { await interrupted(); continue; }

      if (requested) {
        const name = requested;
        requested = null;
        await perform(name);
        continue;
      }

      const name = nextAct();
      if (Math.random() < TELEPORT_CHANCE) {
        await pop(false);
        if (generation !== mine) continue;
        const menubar = document.querySelector('.menubar').offsetHeight;
        x = Math.random() * maxX();
        lift = Math.random() * Math.max(0, innerHeight - menubar - el.offsetHeight);
        place();
        show(name, { still: 0 });
        await pop(true);
        if (generation !== mine) continue;
        await perform(name);
        if (generation !== mine) continue;
        await pop(false);
        if (generation !== mine) continue;
        x = Math.random() * maxX();
        lift = 0;
        place();
        show('walking', { still: STANDING_FRAME });
        await pop(true);
      } else {
        await walkTo(randomStop());
        if (generation !== mine) continue;
        await perform(name);
      }
    }
  }

  // With reduced motion he stands still; asking for an act shows a still of it.
  let stillTimer = null;
  function stand() {
    backToFloor();
    announce('standing');
    show('walking', { still: STANDING_FRAME });
  }
  function showStill(name) {
    clearTimeout(stillTimer);
    announce(name);
    show(name, { still: Math.round((player(name).frames - 1) / 2) });
    stillTimer = setTimeout(stand, 4000);
  }

  api.live = true;
  api.perform = name => {
    if (!actNames.includes(name)) return;
    if (reducedMotion) { showStill(name); return; }
    requested = name;
    interrupt();
  };

  new MutationObserver(() => {
    // Size or visibility changed: start the routine over from the floor at the new size.
    requestAnimationFrame(() => {
      for (const p of Object.values(players)) p.anim.resize();
      if (reducedMotion) stand(); else interrupt();
    });
  }).observe(root, { attributes: true, attributeFilter: ['data-size', 'data-hidden'] });

  addEventListener('resize', () => {
    for (const p of Object.values(players)) p.anim.resize();
    x = Math.min(x, maxX());
    place();
  });

  if (reducedMotion) stand(); else run();
})();
