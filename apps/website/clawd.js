// The page's character and their routine: the same rules as the Mac app.
// Walk to a stop, perform an act, repeat; about one time in four, teleport instead of walking.
// Clawd walks the page to start; the Characters window can swap in anyone from the cast.
//
// Animations are fetched one at a time. Only the walk is needed to start; each act is
// requested while they walk toward the spot where they'll perform it.
(() => {
  const root = document.documentElement;
  const el = document.getElementById('clawd');
  const body = el.querySelector('.clawd-body');
  const status = document.getElementById('clawd-status');

  const WALK_SPEED_FACTOR = 140 / 360; // Clawd-widths per second
  const WALK_FACES_RIGHT = true;       // native facing of the walking animation
  const SHORT_ACT_FRAMES = 40;         // acts shorter than this play twice
  const TELEPORT_CHANCE = 0.25;
  const GRAVITY = 2400;                // px per second squared, the same fall as the app's entrance
  // These three live beside the acts folder rather than in it.
  const TOP_LEVEL = new Set(['walking', 'waving', 'looking']);

  const listeners = new Set();
  const characterListeners = new Set();
  const api = {
    live: Boolean(window.lottie),
    setCharacter() {},
    character: 'clawd',
    onAct(fn) { listeners.add(fn); },
    onCharacter(fn) { characterListeners.add(fn); },
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
  // Clawd's acts come from assets/characters/index.json, like everyone else's; until it arrives
  // (or if it never does) he has the two that live beside the walk.
  // clawd-walking.json: frames 0–4 stand + lean in, 5–24 step cycle, 25–27 stand.
  // Looping only the step cycle keeps him from sliding while posed still.
  const CLAWD = {
    id: 'clawd',
    name: 'Clawd',
    walkCycle: [5, 25],
    standingFrame: 26,
    acts: ['waving', 'looking'],
    url: name => `assets/${TOP_LEVEL.has(name) ? '' : 'acts/'}clawd-${name}.json`,
  };
  // Anyone else comes from assets/characters/index.json, as the Characters window reads it.
  const castMember = entry => entry.builtin ? CLAWD : {
    id: entry.id,
    name: entry.name,
    walkCycle: entry.walkCycle,
    standingFrame: entry.standingFrame,
    acts: entry.acts,
    url: name => `assets/characters/${entry.id}/${name}.json`,
  };
  let character = CLAWD;

  const players = new Map(); // name -> promise of { name, el, anim, frames }

  function ready(name) {
    if (!players.has(name)) {
      const url = character.url(name);
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
    show(walking, { loop: true, segment: character.walkCycle });
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
    const acts = character.acts;
    if (!queue.length) queue = [...acts].sort(() => Math.random() - 0.5);
    const name = queue.pop();
    // The act on screen is released when the next one takes over, so never queue it twice in a row.
    return current && current.name === name && acts.length > 1 ? nextAct() : name;
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

  // The app's launch entrance, on page load: he drops in under a spotlight, lands, waves once,
  // the light fades, and only then does he start walking.
  async function entrance(walking, mine) {
    const spotlight = document.getElementById('spotlight');
    const waving = fetchAct('waving');
    x = Math.round(maxX() / 2);
    dir = 1;
    lift = innerHeight;
    place();
    show(walking, { still: character.standingFrame });
    if (spotlight) {
      spotlight.style.left = `${x + width() / 2}px`;
      spotlight.dataset.on = '';
    }
    await new Promise(resolve => {
      const top = lift;
      let falling = 0;
      let last = performance.now();
      function step(now) {
        // A newer character's entrance has taken over the floor.
        if (mine !== session) { resolve(); return; }
        falling += Math.min(now - last, 50) / 1000;
        last = now;
        lift = Math.max(0, top - 0.5 * GRAVITY * falling * falling);
        place();
        if (lift <= 0) resolve(); else requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
      // Frames pause in a background tab; he still lands.
      setTimeout(() => { if (mine === session) { lift = 0; place(); } resolve(); }, 1500);
    });
    const wave = await waving;
    if (mine !== session) return;
    if (wave) {
      announce('waving');
      show(wave);
      await Promise.race([
        new Promise(resolve => wave.anim.addEventListener('complete', resolve, { once: true })),
        new Promise(resolve => setTimeout(resolve, 3000)),
      ]);
    }
    if (mine !== session) return;
    show(walking, { still: character.standingFrame });
    if (spotlight) delete spotlight.dataset.on;
    await new Promise(resolve => setTimeout(resolve, 700));
  }

  let walksFirst = true; // after the entrance their first move is a walk from where they landed
  // Each character gets a session; switching starts a new one and the old routine stops.
  let session = 0;
  async function run(walking, mySession) {
    await entrance(walking, mySession);
    for (;;) {
      if (mySession !== session) return;
      const mine = generation;
      backToFloor();
      if (root.hasAttribute('data-hidden')) { await interrupted(); continue; }

      const name = nextAct();
      const loading = fetchAct(name); // downloads while he walks
      const teleports = !walksFirst && Math.random() < TELEPORT_CHANCE;
      walksFirst = false;
      if (teleports) {
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
        show(walking, { still: character.standingFrame });
        await pop(true);
      } else {
        await walkTo(walking, randomStop());
        if (generation !== mine) continue;
        // If the act is still downloading he stands and waits, rather than walking on the spot.
        show(walking, { still: character.standingFrame });
        const act = await unlessInterrupted(loading);
        if (generation !== mine) continue;
        if (act) await perform(act);
      }
    }
  }

  // With reduced motion they stand still.
  function stand(walking) {
    backToFloor();
    announce('standing');
    show(walking, { still: character.standingFrame });
  }

  // Resizing clears each canvas. A playing animation repaints on its next frame; a still one never would.
  function resizeCurrent() {
    if (!current) return;
    current.anim.resize();
    if (current.anim.isPaused) current.anim.goToAndStop(current.anim.currentFrame, true);
  }

  let walkingNow = null;

  // Loads `next`'s walk and starts their routine with an entrance. Resolves false if it failed.
  function begin(next) {
    const mySession = ++session;
    interrupt();
    for (const loading of players.values()) {
      loading.then(player => { player.anim.destroy(); player.el.remove(); }, () => {});
    }
    players.clear();
    current = null;
    queue = [];
    walksFirst = true;
    character = next;
    api.character = next.id;
    return ready('walking').then(walking => {
      if (mySession !== session) return true;
      walkingNow = walking;
      for (const fn of characterListeners) fn(next);
      if (reducedMotion) stand(walking); else run(walking, mySession);
      return true;
    }, () => false);
  }

  api.setCharacter = async entry => {
    const next = castMember(entry);
    if (next.id === character.id) return true;
    const previous = character;
    const ok = await begin(next);
    // Their files never arrived: put the previous character back rather than leave the floor empty.
    if (!ok) await begin(previous);
    return ok;
  };

  new MutationObserver(() => {
    // Size or visibility changed: start the routine over from the floor at the new size.
    if (reducedMotion) requestAnimationFrame(() => walkingNow && stand(walkingNow)); else interrupt();
  }).observe(root, { attributes: true, attributeFilter: ['data-size', 'data-hidden'] });

  addEventListener('resize', () => {
    resizeCurrent();
    x = Math.min(x, maxX());
    place();
    // The walk target was chosen for the old width.
    if (!reducedMotion) interrupt();
  });

  fetch('assets/characters/index.json')
    .then(response => response.json())
    .then(manifest => {
      const clawd = manifest.characters.find(entry => entry.builtin);
      if (clawd && clawd.acts && clawd.acts.length) CLAWD.acts = clawd.acts;
    })
    .catch(() => {})
    .finally(() => begin(CLAWD).then(ok => { if (!ok) goStatic(); }));
})();
