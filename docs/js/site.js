// Page wiring: 3D scenes (loaded lazily, paused off-screen), gallery, lightbox, reveals.
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const BIOME_CARDS = [
  ['autumn.jpg', 'Autumn Meadow', 'Golden grass, red maples and leaves in the wind'],
  ['spring.jpg', 'Spring Meadow', 'Fresh green hills and wildflowers'],
  ['lavender.jpg', 'Lavender Hills', 'Purple rows, olive trees and warm evening light'],
  ['blossom.jpg', 'Blossom Grove', 'Pink crowns over a flowery sunken lane'],
  ['birch.jpg', 'Birch Wood', 'White trunks, ferns and golden haze'],
  ['maple.jpg', 'Red Maple Wood', 'Deep reds in the late afternoon'],
  ['forest.jpg', 'Forest Trail', 'Tall pines and a narrow path'],
  ['highlands.jpg', 'Heather Highlands', 'Misty moors, drizzle and granite'],
  ['pines.jpg', 'Mountain Pines', 'Tall pines and snowy peaks'],
  ['cliffs.jpg', 'Cliff Lands', 'Terraces, ledges and long views'],
  ['coast.jpg', 'Sunset Coast', 'Sea stacks glowing in the evening sun'],
  ['lakes.jpg', 'Lake Country', 'Birches, reeds and still water'],
  ['bog.jpg', 'Deadwood Bog', 'Bare trees and dark ponds'],
  ['desert.jpg', 'Desert Valley', 'Endless dunes, mesas and tumbleweeds'],
  ['glow.jpg', 'Glowing Forest', 'Dusk, fireflies and glowing mushrooms'],
];
const ITEMS = [["apfel", "Apple"], ["beeren", "Berries"], ["brot", "Bread"], ["muesliriegel", "Granola bar"], ["bohnen", "Can of beans"], ["wasserflasche", "Water bottle"], ["limonade", "Lemonade"], ["verband", "Bandage"], ["regenjacke", "Rain jacket"], ["pullover", "Wool sweater"], ["muetze", "Wool hat"], ["sonnenhut", "Sun hat"], ["seil", "Rope"], ["taschenlampe", "Flashlight"], ["fernglas", "Binoculars"], ["kamera", "Camera"], ["feldhandbuch", "Field guide"], ["wasserpistole", "Water pistol"], ["gummihuhn", "Rubber chicken"], ["stein", "Pretty stone"], ["kaese", "Cheese wedge"], ["pilze", "Mushrooms"], ["honig", "Jar of honey"], ["trockenobst", "Dried fruit"], ["schokolade", "Chocolate bar"], ["sandwich", "Sandwich"], ["moehre", "Carrot"], ["keks", "Cookie tin"], ["tee", "Thermos of tea"], ["kakao", "Cocoa"], ["saft", "Juice box"], ["pflaster", "Plasters"], ["erste_hilfe", "First aid kit"], ["sonnencreme", "Sunscreen"], ["schal", "Scarf"], ["handschuhe", "Gloves"], ["stiefel", "Hiking boots"], ["poncho", "Rain poncho"], ["kompass", "Compass"], ["karte", "Trail map"], ["messer", "Pocket knife"], ["stock", "Walking stick"], ["laterne", "Lantern"], ["pfeife", "Whistle"], ["mundharmonika", "Harmonica"], ["drachen", "Kite"], ["federn", "Feather"], ["muschel", "Seashell"], ["tannenzapfen", "Pinecone"], ["glueckskeks", "Fortune cookie"]];
const EMOTE_BAR = [['wave', 'Wave'], ['cheer', 'Cheer'], ['laugh', 'Laugh'], ['thumbs', 'Thumbs up'], ['point', 'Point'], ['shrug', 'Shrug'],
  ['facepalm', 'Facepalm'], ['clap', 'Clap'], ['think', 'Think'], ['salute', 'Salute'], ['stomp', 'Stomp'], ['cower', 'Cower']];

// ------------------------------------------------------------ nav + reveal
const nav = $('#nav');
const menuBtn = $('#menu-btn');
const setMenu = (open) => { nav.classList.toggle('open', open); menuBtn.setAttribute('aria-expanded', String(open)); };
menuBtn.addEventListener('click', () => setMenu(!nav.classList.contains('open')));
$$('#sheet a').forEach((a) => a.addEventListener('click', () => setMenu(false)));
addEventListener('keydown', (e) => { if (e.key === 'Escape') setMenu(false); });
const onScroll = () => nav.classList.toggle('scrolled', scrollY > 40);
addEventListener('scroll', onScroll, { passive: true });
onScroll();

const io = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { threshold: 0.12 });
$$('.reveal').forEach((el) => io.observe(el));

// counters
const cio = new IntersectionObserver((es) => es.forEach((e) => {
  if (!e.isIntersecting) return;
  cio.unobserve(e.target);
  const end = +e.target.dataset.count, t0 = performance.now();
  const step = (t) => { const k = Math.min((t - t0) / 1200, 1); e.target.textContent = Math.round(end * (1 - Math.pow(1 - k, 3))); if (k < 1) requestAnimationFrame(step); };
  requestAnimationFrame(step);
}), { threshold: 0.6 });
$$('[data-count]').forEach((el) => cio.observe(el));

// ------------------------------------------------------------ gallery + lightbox
const track = $('#track');
const items = [];
BIOME_CARDS.forEach(([file, name, text]) => {
  const f = document.createElement('figure');
  f.className = 'card';
  f.tabIndex = 0;
  f.innerHTML = `<img src="screenshots/thumb/${file}" alt="${name}" loading="lazy" width="800" height="450"><figcaption><b>${name}</b><span>${text}</span></figcaption>`;
  const idx = items.push({ src: `screenshots/${file}`, title: name, text }) - 1;
  f.addEventListener('click', () => { if (!dragMoved) openLb(idx); });
  f.addEventListener('keydown', (e) => { if (e.key === 'Enter') openLb(idx); });
  track.appendChild(f);
});
// items: icons from the game, a wobbly sticker grid
const itemBox = $('#items');
ITEMS.forEach(([id, name], i) => {
  const d = document.createElement('div');
  d.className = 'item';
  d.style.setProperty('--r', `${((i * 37) % 9) - 4}deg`);
  d.innerHTML = `<img src="img/items/${id}.webp" alt="" width="96" height="96" loading="lazy"><span>${name}</span>`;
  itemBox.appendChild(d);
});
// emote buttons under the scout editor (same gestures as the wheel in the game)
const emoteBox = $('#emotes');
EMOTE_BAR.forEach(([id, name]) => {
  const b = document.createElement('button');
  b.className = 'emote';
  b.title = name;
  b.setAttribute('aria-label', name);
  b.innerHTML = `<img src="img/emotes/${id}.webp" alt="" width="56" height="56" loading="lazy">`;
  b.addEventListener('click', () => { window.fernEmote?.(id); b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); });
  emoteBox.appendChild(b);
});
$$('.shot, .ui-shot').forEach((s) => {
  const idx = items.push({ src: s.dataset.lb, title: s.dataset.title, text: s.dataset.text }) - 1;
  s.addEventListener('click', () => openLb(idx));
});
const cardW = () => (track.firstElementChild?.getBoundingClientRect().width ?? 400) + 22;
$('#prev').addEventListener('click', () => track.scrollBy({ left: -cardW(), behavior: 'smooth' }));
$('#next').addEventListener('click', () => track.scrollBy({ left: cardW(), behavior: 'smooth' }));
// drag to scroll with the mouse
let dragX = null, dragMoved = false, startScroll = 0;
track.addEventListener('pointerdown', (e) => { if (e.pointerType !== 'mouse') return; dragX = e.clientX; startScroll = track.scrollLeft; dragMoved = false; track.style.scrollSnapType = 'none'; });
addEventListener('pointermove', (e) => { if (dragX === null) return; const d = e.clientX - dragX; if (Math.abs(d) > 5) dragMoved = true; track.scrollLeft = startScroll - d; });
addEventListener('pointerup', () => { if (dragX === null) return; dragX = null; track.style.scrollSnapType = ''; setTimeout(() => { dragMoved = false; }, 0); });

const lb = $('#lightbox');
let lbIdx = 0;
function openLb(i) {
  lbIdx = (i + items.length) % items.length;
  const it = items[lbIdx];
  $('img', lb).src = it.src;
  $('img', lb).alt = it.title;
  $('figcaption', lb).innerHTML = `<b>${it.title}</b>${it.text}`;
  lb.classList.add('open');
  $('.lb-close', lb).focus();
}
const closeLb = () => lb.classList.remove('open');
$('.lb-close', lb).addEventListener('click', closeLb);
$('.lb-prev', lb).addEventListener('click', () => openLb(lbIdx - 1));
$('.lb-next', lb).addEventListener('click', () => openLb(lbIdx + 1));
lb.addEventListener('click', (e) => { if (e.target === lb) closeLb(); });
addEventListener('keydown', (e) => {
  if (!lb.classList.contains('open')) return;
  if (e.key === 'Escape') closeLb();
  if (e.key === 'ArrowLeft') openLb(lbIdx - 1);
  if (e.key === 'ArrowRight') openLb(lbIdx + 1);
});

// ------------------------------------------------------------ 3D
function webgl() {
  try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch { return false; }
}

async function start3D() {
  if (!webgl()) { document.documentElement.classList.add('no-webgl'); return; }
  let hero, editor;
  try {
    const [{ Hero }, { Editor, savedLook }] = await Promise.all([import('./hero.js'), import('./editor.js')]);
    const nameEl = $('#biome-name');
    let nameTimer;
    hero = new Hero($('#hero-canvas'), {
      onBiome: (k) => {
        $$('.chip').forEach((c) => c.setAttribute('aria-selected', String(c.dataset.biome === k)));
      },
    });
    const showName = (label) => {
      nameEl.textContent = label;
      nameEl.classList.add('show');
      clearTimeout(nameTimer);
      nameTimer = setTimeout(() => nameEl.classList.remove('show'), 2600);
    };
    const { BIOMES } = await import('./hero.js');
    $$('.chip').forEach((c) => c.addEventListener('click', () => { hero.setBiome(c.dataset.biome); showName(BIOMES[c.dataset.biome].label); }));
    const follow = $('#follow');
    follow.addEventListener('click', () => {
      const on = follow.getAttribute('aria-pressed') !== 'true';
      follow.setAttribute('aria-pressed', String(on));
      hero.setFollow(on);
    });
    // the scout editor gets its own WebGL context only when it comes close to the screen
    const makeEditor = () => {
      if (editor) return;
      editor = new Editor($('#scout-canvas'), $('#editor'), (look) => hero.setLook(look));
      $('#surprise').addEventListener('click', () => editor.surprise());
      $('#wave').addEventListener('click', () => editor.wave());
      window.fernEmote = (id) => editor.emote(id);
    };
    new IntersectionObserver((es, obs) => { if (es.some((e) => e.isIntersecting)) { makeEditor(); obs.disconnect(); sync(); } }, { rootMargin: '600px 0px' }).observe($('.stage'));
    // only render what can be seen
    const onScreen = { hero: true, editor: false };
    function sync() { hero.setVisible(onScreen.hero && !document.hidden); editor?.setVisible(onScreen.editor && !document.hidden); }
    const vis = new IntersectionObserver((es) => {
      es.forEach((e) => { onScreen[e.target.id === 'top' ? 'hero' : 'editor'] = e.isIntersecting; });
      sync();
    }, { threshold: 0 });
    vis.observe($('#top'));
    vis.observe($('.stage'));
    addEventListener('scroll', () => { hero.scroll = Math.min(scrollY / innerHeight, 1); }, { passive: true });
    document.addEventListener('visibilitychange', sync);
  } catch (err) {
    console.error(err);
    document.documentElement.classList.add('no-webgl');
  }
}
start3D();
