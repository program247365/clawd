// Clawd's routine on the page: the same rules as the Mac app.
// Walk to a stop, perform an act, repeat; about one time in four, teleport instead of walking.
//
// Animations are fetched one at a time. Only the walk is needed to start; each act is
// requested while he walks toward the spot where he'll perform it.
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
  // These three live beside the acts folder rather than in it.
  const TOP_LEVEL = new Set(['walking', 'waving', 'looking']);

  const listeners = new Set();
  const api = {
    live: Boolean(window.lottie),
    perform() {},
    onAct(fn) { listeners.add(fn); },
  };
  window.Clawd = api;

  // Without the animation library, or without the walk, the static Clawd in the markup stays.
  function goStatic() {
    api.live = false;
    root.dataset.clawd = 'static';
    document.dispatchEvent(new Event('clawd:static'));
  }
  if (!window.lottie) { goStatic(); return; }

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  // The Acts window lists every act, so the page needs no separate manifest.
  const actNames = [...document.querySelectorAll('.act')].map(button => button.dataset.act);

  const players = new Map(); // name -> promise of { name, el, anim, frames }

  function ready(name) {
    if (!players.has(name)) {
      const url = `assets/${TOP_LEVEL.has(name) ? '' : 'acts/'}clawd-${name}.json`;
      const loading = fetch(url)
        .then(response => {
          if (!response.ok) throw new Error(`${url}: ${response.status}`);
          return response.json();
        })
        .then(data => {
          const container = document.createElement('div');
          container.className = 'anim';
          body.appendChild(container);
          const anim = lottie.loadAnimation({
            container, renderer: 'canvas', loop: false, autoplay: false, animationData: data,
          });
          return { name, el: container, anim, frames: data.op - data.ip };
        });
      // A failed download is forgotten so a later request can try again.
      loading.catch(() => players.delete(name));
      players.set(name, loading);
    }
    return players.get(name);
  }

  // Keep the walk and whatever is on screen; let finished acts go.
  function release(player) {
    if (!player || player.name === 'walking') return;
    players.delete(player.name);
    player.anim.destroy();
    player.el.remove();
  }

  let current = null;
  function show(p, { loop = false, segment = null, still = null } = {}) {
    const previous = current;
    if (previous && previous !== p) { previous.el.classList.remove('on'); previous.anim.stop(); }
    current = p;
    p.anim.loop = loop;
    // A player made at another size, or before a window resize, still has its old canvas.
    p.anim.resize();
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
    if (previous !== p) release(previous);
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
  let wake = null; // one promise shared by everything waiting on the current generation
  function interrupt() {
    generation++;
    if (wake) { const { resolve } = wake; wake = null; resolve(); }
  }
  function interrupted() {
    if (!wake) { let resolve; const promise = new Promise(r => { resolve = r; }); wake = { promise, resolve }; }
    return wake.promise;
  }
  const pause = ms => Promise.race([new Promise(r => setTimeout(r, ms)), interrupted()]);

  function walkTo(walking, target) {
    const mine = generation;
    dir = target >= x ? 1 : -1;
    announce('walking');
    show(walking, { loop: true, segment: WALK_CYCLE });
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

  function perform(act) {
    announce(act.name);
    show(act);
    let plays = act.frames < SHORT_ACT_FRAMES ? 2 : 1;
    const finished = new Promise(resolve => {
      const done = () => {
        if (--plays > 0) { act.anim.goToAndPlay(0, true); return; }
        act.anim.removeEventListener('complete', done);
        resolve();
      };
      act.anim.addEventListener('complete', done);
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
    const name = queue.pop();
    // The act on screen is released when the next one takes over, so never queue it twice in a row.
    return current && current.name === name && actNames.length > 1 ? nextAct() : name;
  }

  function backToFloor() {
    lift = 0;
    x = Math.min(Math.max(x, 0), maxX());
    delete body.dataset.popped;
    place();
  }

  // An act that fails to download is skipped rather than stalling him.
  const fetchAct = name => ready(name).catch(() => null);
  // A slow download must not hold up a click or a size change: resolves null if interrupted first.
  const unlessInterrupted = loading => Promise.race([loading, interrupted().then(() => null)]);

  let requested = null;
  async function run(walking) {
    place();
    for (;;) {
      const mine = generation;
      backToFloor();
      if (root.hasAttribute('data-hidden')) { await interrupted(); continue; }

      if (requested) {
        const name = requested;
        requested = null;
        const act = await unlessInterrupted(fetchAct(name));
        // Interrupted while it downloaded: if a newer click replaced it, that one wins; otherwise ask again.
        if (generation !== mine) { requested = requested || name; continue; }
        if (act) await perform(act);
        continue;
      }

      const name = nextAct();
      const loading = fetchAct(name); // downloads while he walks
      if (Math.random() < TELEPORT_CHANCE) {
        const act = await unlessInterrupted(loading);
        if (generation !== mine) continue;
        if (!act) { await pause(1000); continue; }
        await pop(false);
        if (generation !== mine) continue;
        const menubar = document.querySelector('.menubar').offsetHeight;
        x = Math.random() * maxX();
        lift = Math.random() * Math.max(0, innerHeight - menubar - el.offsetHeight);
        place();
        show(act, { still: 0 });
        await pop(true);
        if (generation !== mine) continue;
        await perform(act);
        if (generation !== mine) continue;
        await pop(false);
        if (generation !== mine) continue;
        x = Math.random() * maxX();
        lift = 0;
        place();
        show(walking, { still: STANDING_FRAME });
        await pop(true);
      } else {
        await walkTo(walking, randomStop());
        if (generation !== mine) continue;
        // If the act is still downloading he stands and waits, rather than walking on the spot.
        show(walking, { still: STANDING_FRAME });
        const act = await unlessInterrupted(loading);
        if (generation !== mine) continue;
        if (act) await perform(act);
      }
    }
  }

  // With reduced motion he stands still; asking for an act shows a still of it.
  let stillTimer = null;
  function stand(walking) {
    backToFloor();
    announce('standing');
    show(walking, { still: STANDING_FRAME });
  }
  async function showStill(walking, name) {
    clearTimeout(stillTimer);
    const act = await fetchAct(name);
    if (!act) return;
    announce(name);
    show(act, { still: Math.round((act.frames - 1) / 2) });
    stillTimer = setTimeout(() => stand(walking), 4000);
  }

  // Resizing clears each canvas. A playing animation repaints on its next frame; a still one never would.
  function resizeCurrent() {
    if (!current) return;
    current.anim.resize();
    if (current.anim.isPaused) current.anim.goToAndStop(current.anim.currentFrame, true);
  }

  ready('walking').then(walking => {
    api.perform = name => {
      if (!actNames.includes(name)) return;
      if (reducedMotion) { showStill(walking, name); return; }
      requested = name;
      interrupt();
    };

    new MutationObserver(() => {
      // Size or visibility changed: start the routine over from the floor at the new size.
      // Interrupting right away, not a frame later, keeps an act requested in the same click.
      if (reducedMotion) requestAnimationFrame(() => stand(walking)); else interrupt();
    }).observe(root, { attributes: true, attributeFilter: ['data-size', 'data-hidden'] });

    addEventListener('resize', () => {
      resizeCurrent();
      x = Math.min(x, maxX());
      place();
      // His walk target was chosen for the old width.
      if (!reducedMotion) interrupt();
    });

    if (reducedMotion) stand(walking); else run(walking);
  }, goStatic);
})();
