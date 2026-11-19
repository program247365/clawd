// The Characters window: the cast lined up on a stage like a fighting game's character select.
// Each one idles (their own "ready" animation, or their standing pose bounced through a crouch and
// a lean by shifting whole rows of pixels, as the Mac app does), and picking one puts them on the page.
(() => {
  const stage = document.getElementById('characters');
  if (!stage) return;
  const fighters = [...stage.querySelectorAll('.fighter')];
  const nameplate = document.getElementById('fighter-name');
  const blurb = document.getElementById('fighter-blurb');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const page = window.Clawd;

  // Crouch (art rows down) and lean (art columns sideways) for each frame of the generated idle.
  const STEPS = [[0, 0], [1, 0], [1, 1], [1, 1], [1, 0], [0, 0], [0, -1], [0, -1]];
  const FPS = 10;
  // The art canvas is 27.5 of its own pixels wide (2750 Lottie units).
  const ART_COLUMNS = 27.5;

  let entries = new Map(); // id -> manifest entry

  function reflect(id) {
    for (const fighter of fighters) {
      const on = fighter.dataset.character === id;
      fighter.setAttribute('aria-checked', String(on));
      fighter.tabIndex = on ? 0 : -1;
      if (on) {
        nameplate.textContent = fighter.dataset.name;
        blurb.textContent = fighter.dataset.blurb;
      }
    }
  }

  async function choose(fighter) {
    const id = fighter.dataset.character;
    reflect(id);
    const entry = entries.get(id);
    if (page && page.live && entry) {
      const ok = await page.setCharacter(entry);
      if (!ok) reflect(page.character);
    }
  }

  for (const fighter of fighters) {
    fighter.addEventListener('click', () => choose(fighter));
  }
  // A radio group: arrow keys move the pick, as on a select screen.
  stage.querySelector('.lineup').addEventListener('keydown', event => {
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
    if (!step) return;
    event.preventDefault();
    const index = fighters.findIndex(f => f.getAttribute('aria-checked') === 'true');
    const next = fighters[(index + step + fighters.length) % fighters.length];
    next.focus();
    choose(next);
  });
  // The Acts window can bring Clawd back; the lineup follows.
  if (page) page.onCharacter(character => reflect(character.id));
  reflect('clawd');

  if (!window.lottie || !page || !page.live) return; // the stills in the markup stay

  fetch('assets/characters/index.json')
    .then(response => response.json())
    .then(manifest => {
      entries = new Map(manifest.characters.map(entry => [entry.id, entry]));
      return Promise.all(fighters.map((fighter, index) => idle(fighter, entries.get(fighter.dataset.character), index)));
    })
    .then(players => animate(players.filter(Boolean)))
    .catch(() => {}); // the stills stay

  // Renders one character into a hidden Lottie canvas, and draws from it onto a visible one.
  function idle(fighter, entry, index) {
    if (!entry) return null;
    const name = entry.ready ? 'ready' : 'walking';
    const url = entry.builtin ? 'assets/clawd-walking.json' : `assets/characters/${entry.id}/${name}.json`;
    return fetch(url).then(response => response.json()).then(data => new Promise(resolve => {
      const still = fighter.querySelector('img');
      const source = document.createElement('div');
      source.className = 'fighter-source';
      fighter.appendChild(source);
      const anim = lottie.loadAnimation({ container: source, renderer: 'canvas', loop: false, autoplay: false, animationData: data });
      anim.addEventListener('DOMLoaded', () => {
        const from = source.querySelector('canvas');
        const to = document.createElement('canvas');
        to.width = from.width;
        to.height = from.height;
        to.setAttribute('aria-hidden', 'true');
        still.replaceWith(to);
        const player = {
          entry, anim, from, ctx: to.getContext('2d'), offset: index * 3,
          frames: data.op - data.ip, split: null,
        };
        if (!entry.ready) {
          anim.goToAndStop(entry.standingFrame, true);
          player.split = splitRow(from);
        }
        resolve(player);
      });
      anim.addEventListener('data_failed', () => resolve(null));
    }));
  }

  // A little below the middle of the figure, on a whole art pixel: the rows above it crouch and lean.
  function splitRow(canvas) {
    const { width, height } = canvas;
    const pixels = canvas.getContext('2d').getImageData(0, 0, width, height).data;
    let top = height, bottom = 0;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (pixels[(y * width + x) * 4 + 3] > 127) { top = Math.min(top, y); bottom = y; break; }
      }
    }
    const art = width / ART_COLUMNS;
    return Math.round((top + (bottom - top) * 0.55) / art) * art;
  }

  function draw(player, tick) {
    const { from, ctx, entry } = player;
    const { width, height } = from;
    ctx.clearRect(0, 0, width, height);
    if (entry.ready) {
      player.anim.goToAndStop((tick + player.offset) % player.frames, true);
      ctx.drawImage(from, 0, 0);
      return;
    }
    const [crouch, lean] = STEPS[(tick + player.offset) % STEPS.length];
    const art = width / ART_COLUMNS;
    const split = player.split;
    ctx.drawImage(from, 0, split, width, height - split, 0, split, width, height - split);
    ctx.drawImage(from, 0, 0, width, split, lean * art, crouch * art, width, split);
  }

  function animate(players) {
    for (const player of players) player.ctx.imageSmoothingEnabled = false;
    let tick = 0;
    const drawAll = () => { for (const player of players) draw(player, tick); };
    drawAll();
    if (reducedMotion) return; // one still pose each
    let timer = null;
    const run = on => {
      clearInterval(timer);
      timer = on ? setInterval(() => { tick++; drawAll(); }, 1000 / FPS) : null;
    };
    // Only while the window is on screen.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(([entry]) => run(entry.isIntersecting)).observe(stage);
    } else {
      run(true);
    }
  }
})();
