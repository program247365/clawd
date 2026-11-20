// The About window's cast, as in the app: a stage light visits each character in turn, and whoever
// it lands on waves twice before it moves on. Without the animation library, or with reduced motion,
// the row of stills stays as it is.
(() => {
  const cast = document.querySelector('.about-cast');
  if (!cast || !window.lottie || matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const MOVE_MS = 550;
  const REST_MS = 350;
  const WAVES_EACH = 2;
  const slots = [...cast.querySelectorAll('li')];
  const light = document.createElement('span');
  light.className = 'about-light';
  light.setAttribute('aria-hidden', 'true');
  cast.prepend(light);

  const waveURL = id => (id === 'clawd' ? 'assets/clawd-waving.json' : `assets/characters/${id}/waving.json`);

  // Each slot gets its waving animation loaded beside its still, hidden until the light lands there.
  function load(slot) {
    return fetch(waveURL(slot.dataset.character))
      .then(response => response.json())
      .then(data => {
        const box = document.createElement('div');
        box.className = 'about-wave';
        box.hidden = true;
        slot.appendChild(box);
        const anim = lottie.loadAnimation({ container: box, renderer: 'svg', loop: true, autoplay: false, animationData: data });
        return { slot, box, anim, ms: ((data.op - data.ip) / data.fr) * 1000 * WAVES_EACH };
      })
      .catch(() => ({ slot, ms: 1200 })); // no wave: the light still stops there
  }

  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  let visible = false;
  let wake = null;

  async function perform(performers) {
    for (let index = 0; ; index = (index + 1) % performers.length) {
      while (!visible) await new Promise(resolve => { wake = resolve; });
      const { slot, box, anim, ms } = performers[index];
      light.style.transform = `translateX(${slot.offsetLeft}px)`;
      light.classList.add('on');
      await sleep(MOVE_MS);
      if (anim) {
        box.hidden = false;
        slot.classList.add('waving');
        anim.goToAndPlay(0, true);
      }
      await sleep(ms);
      if (anim) {
        anim.stop();
        box.hidden = true;
        slot.classList.remove('waving');
      }
      await sleep(REST_MS);
    }
  }

  Promise.all(slots.map(load)).then(performers => {
    // Only goes round while the window is on screen; it picks up where it left off.
    new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      if (visible && wake) { wake(); wake = null; }
    }).observe(cast);
    perform(performers);
  });
})();
