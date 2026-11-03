// lib.js: the story's shared look. Light (day / night / dark / dawn), ink, cel shadows, captions,
// painted lettering (notes, envelopes, clocks), transitions and small effects.

const INK = '#19161D';
// Light: every colour goes through L() so a whole shot shifts toward its light (warm day, cold night).
const LIGHTS = {
  day:   { col: '#F1DE9C', k: .10 },
  dusk:  { col: '#4B3A62', k: .30 },
  night: { col: '#0F2C38', k: .52 },
  dark:  { col: '#08161C', k: .70 },
  dawn:  { col: '#F0A9A0', k: .22 },
};
let LIGHT = LIGHTS.day;
const setLight = (name, k) => { LIGHT = { ...LIGHTS[name] }; if (k != null) LIGHT.k = k; };
const L = c => LIGHT.k ? mixCol(c, LIGHT.col, LIGHT.k) : c;
// cel shadow / highlight of a colour (shadows are tinted cool, like 90s cels)
const shd = (c, k = .32) => mixCol(c, '#2A2346', k);
const hil = (c, k = .25) => mixCol(c, '#FFF3DA', k);
const swOf = s => clamp(s / 230, .35, 1.5);

// flat painted shape in the current light
const P = (pts, col, sw = 1, o = {}) => paint(pts, { wash: L(col), ink: sw ? INK : null, sw, ...o });
const PN = (pts, col, o = {}) => paint(pts, { wash: L(col), ink: null, ...o });
// Fine decorative lines ('inkfine': stitching, paper grids, cracks) are painted as thin flat strips: a brush stroke costs
// hundreds of stamps in software WebGL, a strip costs one polygon. Character and prop outlines keep the real ink brush.
const line = (pts, sw = 1, col = INK, br = 'ink', curv = .5) => {
  if (br === 'inkfine') { const c = col === INK ? INK : L(col); for (let i = 0; i + 1 < pts.length; i++) paint(ribbon([pts[i], pts[i + 1]], sw * 7, sw * 7), { wash: c, ink: null }); return; }
  inkLine(pts, sw, col === INK ? INK : L(col), br, curv);
};

// rotate/scale a local point list into place
const place = (pts, x, y, s = 1, a = 0) => { const c = Math.cos(a), si = Math.sin(a); return pts.map(([px, py]) => [x + (px * c - py * si) * s, y + (px * si + py * c) * s]); };
const rr = (x, y, w, h, r) => rrPts(x, y, w, h, Math.min(r, w / 2 - .01, h / 2 - .01));

// ---------- transitions (screen space, after camEnd) ----------
const BLACK = '#0A0B0E';
function fadeIn(lt, d = .5, col = BLACK) { if (lt < d) { flushLetters(); flash(1 - ease(lt / d), col); } }
function fadeOut(lt, dur, d = .5, col = BLACK) { if (lt > dur - d) { flushLetters(); flash(ease((lt - (dur - d)) / d), col); } }
// hard cut to black for the last `d` seconds (the script's "склейка в чёрное")
function smashBlack(lt, dur, d = .35) { if (lt > dur - d) { flushLetters(); flash(1, BLACK); } }
// knock: 3 hits, pause, 3 hits from t0. Returns 0..1 impact envelope for shakes and door jolts.
function knocks(t, t0, gap = .32, pause = .9, n = 3, groups = 2) {
  let v = 0;
  for (let g = 0; g < groups; g++) for (let i = 0; i < n; i++) {
    const at = t0 + g * ((n - 1) * gap + pause) + i * gap, a = t - at;
    if (a >= 0) v = Math.max(v, Math.exp(-a * 14));
  }
  return v;
}
const knockTimes = (t0, gap = .32, pause = .9, n = 3, groups = 2) => { const r = []; for (let g = 0; g < groups; g++) for (let i = 0; i < n; i++) r.push(t0 + g * ((n - 1) * gap + pause) + i * gap); return r; };

// ---------- lettering ----------
const FONT_CAP = '700 {s}px Oswald', FONT_HAND = '600 {s}px Caveat', FONT_DIGI = '700 {s}px "JetBrains Mono"';
const fnt = (f, s) => f.replace('{s}', s);
let _mctx = null;
function measure(txt, font) { if (!_mctx) _mctx = document.createElement('canvas').getContext('2d'); _mctx.font = font; return _mctx.measureText(txt).width; }
function wrap(txt, font, maxW) {
  const out = []; for (const para of txt.split('\n')) {
    let cur = ''; for (const w of para.split(' ')) { const nx = cur ? cur + ' ' + w : w; if (cur && measure(nx, font) > maxW) { out.push(cur); cur = w; } else cur = nx; }
    out.push(cur);
  } return out;
}
// Reels caption: big condensed letters, cream with an ink stroke, inside the safe zone (top 15%, bottom 20% stay clear).
// k = 0..1 visibility (pop in / out). y = centre of the block.
function caption(txt, k, y = 1330, size = 78, col = '#FFF4DE', o = {}) {
  if (k <= .01) return;
  const font = fnt(FONT_CAP, size), lines = wrap(txt.toUpperCase(), font, o.maxW || 900), lh = size * 1.12;
  lines.forEach((ln, i) => letter(ln, W / 2, y + (i - (lines.length - 1) / 2) * lh, size, o.col || col,
    { font, screen: true, stroke: INK, ink: true, pop: o.pop === false ? null : k, alpha: clamp(k * 2), rot: o.rot || 0 }));
}
// caption that pops in at a and out at b (seconds of shot time)
function capAt(txt, lt, a, b, y, size, o) { caption(txt, clamp(Math.min((lt - a) / .3, (b - lt) / .25)), y, size, undefined, o); }
// handwriting painted into the scene (camera-aware). reveal 0..1 types it out left→right; shaky jitters each glyph line.
function hand(txt, x, y, size, col = '#2B2C55', o = {}) {
  const font = fnt(FONT_HAND, Math.round(size)), lines = o.maxW ? wrap(txt, font, o.maxW) : txt.split('\n'), lh = size * (o.lh || 1.05);
  const total = lines.reduce((s, l) => s + l.length, 0); let shown = Math.round((o.reveal ?? 1) * total);
  lines.forEach((ln, i) => {
    if (shown <= 0) return; const part = ln.slice(0, shown); shown -= ln.length;
    letter(part, x, y + i * lh, size, L(col), { font, align: o.align || 'left', ink: false, rot: (o.rot || 0) + (o.shaky ? Math.sin(i * 2.3 + BOILN) * .012 : 0), alpha: o.alpha ?? .92 });
  });
}
// digital clock digits with glow
function digits(txt, x, y, size, col = '#58F0A0', a = 1) {
  const [sx, sy] = CAM ? toScreen(x, y) : [x, y];
  letter(txt, x, y, size, col, { font: fnt(FONT_DIGI, Math.round(size)), ink: false, alpha: a });
  return [sx, sy];
}

// ---------- small effects ----------
// dust motes floating in a light beam (stable per mote: hash)
function dust(t, x0, y0, w, h, n = 40, col = '#FFF1C8', a = .7) {
  for (let i = 0; i < n; i++) {
    const px = x0 + w * frac(hash(i) + t * .012 * (hash(i + 7) - .5)), py = y0 + h * frac(hash(i + 3) - t * .01 * (.4 + hash(i + 5)));
    glow(px, py, 6 + 10 * hash(i + 9), col, a * (.4 + .6 * Math.abs(Math.sin(t * .7 + i))));
  }
}
// light strip under a door (warm), with optional shadow of two feet blocking it
function doorGap(x, y, w, h, t, o = {}) {
  glow(x + w / 2, y + h / 2, w * .6, o.col || '#FFC56A', o.a ?? .8);
  PN(rectPts(x, y, w, h), o.col || '#FFD27C', { washOp: 200 });
  if (o.feet) {
    for (const f of [-1, 1]) {
      const fx = x + w / 2 + f * w * .13 + (o.feetDx || 0), fw = w * .12;
      PN(rectPts(fx - fw / 2, y - 2, fw, h + 4), '#140F12', { washOp: 255 * clamp(o.feet) });
    }
  }
}

// ---------- shots of a part ----------
// partShots(n, [fn, ...]) registers part n's shots at the narration-driven starts from timing.js.
// Inside a shot, V(f) is the shot time at which the narration is fraction f of the way through its line.
let SH = { i: 0, vod: 1 };
function partShots(part, fns) {
  if (PART !== part) return;
  const T = TIMING[part];
  shots(fns.map((fn, i) => [T.starts[i], (t, lt, dur) => { SH = { i, vod: T.vod[i] }; fn(t, lt, dur); }]));
}
const V = f => VO_LEAD + f * SH.vod;
// a short dip through black at both ends of a shot (the default seam), unless the shot does its own
function seams(lt, dur, inD = .3, outD = .3) { fadeIn(lt, inD); fadeOut(lt, dur, outD); }
// "Часть N — завтра" end card over black for the last `hold` seconds
function endCard(lt, dur, txt, hold = 1.6) {
  if (lt < dur - hold) return;
  flushLetters(); flash(1, BLACK);
  const k = clamp((lt - (dur - hold)) / .35);
  caption(txt, k, H * .47, 92, '#F2E6CC');
}
