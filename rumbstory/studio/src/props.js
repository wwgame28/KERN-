// props.js: the objects the story turns on. All in world coordinates, all lit through L().

const BRASS = '#C9A044', BRASS_DK = '#7A5A1E', LEATHER = '#6E3B26', WOOD = '#5A3A26', PAPER = '#F4EEDC', BLUEINK = '#26306A';

// ---------- the padded front door (seen from inside the flat) ----------
// o: latch 0 (locked, bar horizontal) .. 1 (bar vertical, open), jolt 0..1 (knock impact), num (plate text), seal (paper strip),
//    inside (true: thumb-turn latch; false: outside view with keyhole + number plate), peep (show peephole), gapLight
function door(x, y, w, h, o = {}) {
  const j = (o.jolt || 0), jx = j * 6 * Math.sin(BOILN * 2.1), sw = swOf(w * 1.2);
  boilSeed('door' + (o.key || ''));
  // frame
  P(rectPts(x - w * .07, y - w * .07, w * 1.14, h + w * .07), o.frame || '#3E2A22', sw);
  push(); translate(jx, 0);
  P(rectPts(x, y, w, h), LEATHER, sw);
  // diamond stitching: two families of diagonals clipped to the panel, brass studs at the crossings
  const st = w / 3.2, inset = w * .06, X0 = x + inset, Y0 = y + inset, X1 = x + w - inset, Y1 = y + h - inset;
  const clipDiag = (c, sgn) => { // line y = sgn*x + c, clipped to the inset rect
    const pts = [];
    for (const xx of [X0, X1]) { const yy = sgn * xx + c; if (yy >= Y0 && yy <= Y1) pts.push([xx, yy]); }
    for (const yy of [Y0, Y1]) { const xx = (yy - c) / sgn; if (xx > X0 && xx < X1) pts.push([xx, yy]); }
    return pts.length >= 2 ? pts.slice(0, 2) : null;
  };
  for (const sgn of [1, -1]) for (let k = -12; k <= 30; k++) {
    const c = (sgn > 0 ? Y0 - X0 : Y0 + X0) + k * st * 1.0;
    const seg2 = clipDiag(c, sgn); if (seg2) line(seg2, sw * .35, '#3A1E14', 'inkfine', 0);
  }
  for (let i = 0; i < 4; i++) for (let k = 0; k < Math.ceil(h / st) + 1; k++) {
    const px = X0 + i * (X1 - X0) / 3, py = Y0 + k * st * 1;
    if (py < Y1 && (i + k) % 2 === 0) PN(ellPts(px, py, w * .018, w * .018, 6), BRASS);
  }
  // shading: cel shadow down the hinge side
  PN(rectPts(x, y, w * .16, h), '#2A1410', { washOp: 110 });
  // peephole
  if (o.peep !== false) { const pr = w * .055, px = x + w / 2, py = y + h * .3;
    P(ellPts(px, py, pr, pr, 14), BRASS, sw * .5); P(ellPts(px, py, pr * .5, pr * .5, 10), '#141820', sw * .3);
    if (o.peepLight) glow(px, py, pr * 1.2, o.peepLight, .8); }
  // lock
  if (o.inside !== false) {
    const lx = x + w * .84, ly = y + h * .53;
    P(rr(lx - w * .06, ly - w * .1, w * .12, w * .2, w * .03), BRASS, sw * .5);
    const a = lerp(0, Math.PI / 2, clamp(o.latch || 0));
    P(place([[-.9, -.22], [.9, -.22], [.9, .22], [-.9, .22]], lx, ly, w * .055, a), BRASS_DK, sw * .45);
    P(rr(lx - w * .05, ly + w * .16, w * .1, w * .2, w * .02), BRASS, sw * .4);  // handle base
    P(rr(lx - w * .2, ly + w * .2, w * .2, w * .06, w * .03), BRASS, sw * .45);  // lever handle
  } else {
    const lx = x + w * .84, ly = y + h * .53;
    P(rr(lx + w * .02 - w * .2, ly + w * .2, w * .2, w * .06, w * .03), BRASS, sw * .45);
    P(ellPts(lx, ly, w * .03, w * .03, 8), BRASS, sw * .3); line([[lx, ly - w * .01], [lx, ly + w * .02]], sw * .4);
    // number plate
    P(rectPts(x + w * .38, y + h * .18 - w * .05, w * .24, w * .13), '#B7B9BC', sw * .4);
    if (o.num) letter(o.num, x + w * .5, y + h * .18 + w * .015, w * .1, L('#2A2A30'), { font: fnt(FONT_CAP, Math.round(w * .1)), ink: false });
  }
  if (o.seal) { // paper strip across the gap with a round stamp
    const sy = y + h * .45;
    P(place([[-.62, -.07], [.62, -.06], [.62, .07], [-.62, .06]], x + w * .55, sy, w, -.08), '#F2EEE2', sw * .3);
    P(ellPts(x + w * .62, sy - w * .01, w * .07, w * .06, 14), '#F2EEE2', 0);
    line(ellPts(x + w * .62, sy - w * .01, w * .06, w * .05, 14).concat([ellPts(x + w * .62, sy - w * .01, w * .06, w * .05, 14)[0]]), sw * .4, '#6A5BB8', 'inkfine', 0);
    line([[x + w * .3, sy + w * .02], [x + w * .45, sy]], sw * .3, '#5B5B70');
  }
  pop();
}

// close-up of the peephole: brass rings, a convex lens with a pinpoint of light
function peepholeClose(cx, cy, r, o = {}) {
  const sw = swOf(r * 2);
  boilSeed('peepc');
  P(ellPts(cx, cy, r * 1.25, r * 1.25, 30), BRASS_DK, sw);
  P(ellPts(cx, cy, r, r, 30), BRASS, sw * .8);
  PN(ellPts(cx - r * .25, cy - r * .3, r * .5, r * .28, 18, 0, -.6), '#F4DC96', { washOp: 150 });
  P(ellPts(cx, cy, r * .58, r * .58, 26), '#121722', sw * .8);
  PN(ellPts(cx - r * .14, cy - r * .16, r * .2, r * .12, 12, 0, -.6), '#5D7488', { washOp: 160 });
  for (let i = 0; i < 4; i++) line([[cx + r * (.62 + .1 * hash(i)), cy - r * .5 + i * r * .3], [cx + r * (.8 + .1 * hash(i + 3)), cy - r * .45 + i * r * .32]], sw * .3, '#8A6A2A');
  if (o.light) glow(cx + r * .05, cy + r * .05, r * .5, o.light, o.lightA ?? .7);
}

// thumb-turn latch close-up; turn 0 = locked (horizontal) .. 1 = open (vertical)
function latchClose(cx, cy, s, turn, o = {}) {
  const sw = swOf(s);
  boilSeed('latch');
  P(rr(cx - s * .5, cy - s * .9, s, s * 1.8, s * .2), BRASS, sw);
  PN(rr(cx - s * .45, cy - s * .85, s * .3, s * 1.7, s * .15), '#F0D78A', { washOp: 120 });
  P(ellPts(cx, cy, s * .38, s * .38, 24), BRASS_DK, sw * .7);
  const a = lerp(0, Math.PI / 2, clamp(turn));
  P(place([[-1, -.24], [1, -.24], [1.08, 0], [1, .24], [-1, .24], [-1.08, 0]], cx, cy, s * .52, a), '#B88A36', sw * .8);
  line(place([[-.85, 0], [.85, 0]], cx, cy, s * .52, a), sw * .3, '#6E4E18');
  for (const d of [-1, 1]) P(ellPts(cx, cy + d * s * .7, s * .06, s * .06, 8), BRASS_DK, sw * .3);
}

// ---------- clocks & phones ----------
function alarmClock(x, y, s, txt, o = {}) {
  const sw = swOf(s);
  boilSeed('alarm');
  P([[x - s, y - s * .35], [x + s, y - s * .35], [x + s * 1.1, y + s * .4], [x - s * 1.1, y + s * .4]], '#1C1D22', sw);
  PN(rr(x - s * .82, y - s * .22, s * 1.64, s * .5, s * .06), '#0B1610');
  glow(x, y + s * .03, s * 1.1, '#3BE38A', .55 * (o.a ?? 1));
  digits(txt, x, y + s * .04, s * .42, '#7CFFB5', o.a ?? 1);
}
// smartphone held upright; screen: 'time' | 'call' | 'dead' | 'off'. glowA lights the scene.
function phone(x, y, s, o = {}) {
  const sw = swOf(s), w = s * .52, h = s;
  boilSeed('phone' + (o.key || ''));
  P(rr(x - w / 2, y - h / 2, w, h, s * .07), '#16171C', sw);
  const sc = o.screen || 'off', on = sc !== 'off';
  PN(rr(x - w / 2 + s * .03, y - h / 2 + s * .05, w - s * .06, h - s * .1, s * .04), on ? '#DDE9F4' : '#0B0C10');
  if (on) glow(x, y, s * .9, '#BFDFFF', o.glowA ?? .6);
  const F = (txt, yy, sz, col, font = FONT_CAP) => letter(txt, x, y + yy * s, s * sz, col, { font: fnt(font, Math.round(s * sz)), ink: false });
  if (sc === 'time') { F(o.time || '03:00', -.12, .17, '#1A2340'); F('ночь', .02, .05, '#5B6680'); }
  if (sc === 'call') { F('Мама', -.25, .1, '#1A2340'); F('входящий вызов', -.15, .04, '#5B6680');
    P(ellPts(x - w * .25, y + s * .3, s * .06, s * .06, 14), '#3CC46A', sw * .3); P(ellPts(x + w * .25, y + s * .3, s * .06, s * .06, 14), '#E2483C', sw * .3);
    PN(ellPts(x, y - s * .02, s * .1, s * .1, 16), '#9EB0C8'); }
  if (sc === 'dead') { F('Мама', -.25, .1, '#1A2340'); F('Абонент', -.02, .065, '#A8342C'); F('недоступен', .07, .065, '#A8342C');
    P(ellPts(x, y + s * .3, s * .06, s * .06, 14), '#E2483C', sw * .3); }
}
// round wall clock with hands at h:m (default 3:00)
function wallClock(x, y, r, kind = 0, hh = 3, mm = 0) {
  const sw = swOf(r * 2.2), rims = ['#5A3A26', '#C9C2B2', '#8A2E2A', '#2E3A4A', '#B48A40'];
  boilSeed('wclock' + x + '_' + y);
  if (kind === 3) P([[x - r * 1.1, y - r * 1.3], [x + r * 1.1, y - r * 1.3], [x + r * 1.1, y + r * 2.6], [x - r * 1.1, y + r * 2.6]], '#4A2E1E', sw);  // pendulum case
  if (kind === 4) P([[x - r * 1.2, y - r * .2], [x, y - r * 1.6], [x + r * 1.2, y - r * .2]], '#4A2E1E', sw);  // cuckoo roof
  P(ellPts(x, y, r, r, 22), rims[kind % 5], sw);
  P(ellPts(x, y, r * .82, r * .82, 22), '#F2EAD6', sw * .5);
  for (let i = 0; i < 12; i++) { const a = i / 12 * TAU; line([[x + Math.cos(a) * r * .68, y + Math.sin(a) * r * .68], [x + Math.cos(a) * r * .78, y + Math.sin(a) * r * .78]], sw * .3, '#3A3440', 'inkfine', 0); }
  const ah = (hh % 12 + mm / 60) / 12 * TAU - Math.PI / 2, am = mm / 60 * TAU - Math.PI / 2;
  line([[x, y], [x + Math.cos(ah) * r * .45, y + Math.sin(ah) * r * .45]], sw * .9);
  line([[x, y], [x + Math.cos(am) * r * .68, y + Math.sin(am) * r * .68]], sw * .6);
  if (kind === 3) { line([[x, y + r], [x, y + r * 2.1]], sw * .4, BRASS); P(ellPts(x, y + r * 2.15, r * .2, r * .2, 10), BRASS, sw * .4); }
}

// ---------- paper ----------
function envelope(x, y, s, o = {}) {
  const sw = swOf(s), w = s * 1.6, h = s;
  boilSeed('env');
  const a = o.rot || 0, Q = pts => place(pts, x, y, 1, a);
  P(Q([[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]]), '#EDE3C8', sw);
  if (o.back) {
    line(Q([[-w / 2, -h / 2], [0, h * .08], [w / 2, -h / 2]]), sw * .5, '#9C8E70');
    if (o.torn) PN(Q([[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, -h * .38], [-w / 2, -h * .4]]), '#D9CDB0');
  } else {
    if (o.to !== '') hand(o.to ?? 'Диме, кв. 32', ...Q([[-w * .3, -h * .08]])[0], s * .2, BLUEINK, { rot: a - .04, shaky: true });
    if (o.date) hand(o.date, ...Q([[w * .12, h * .3]])[0], s * .13, BLUEINK, { rot: a - .06, shaky: true, alpha: o.dateA ?? .92 });
  }
}
// checked notebook paper; lines of handwriting typed in by reveal (0..1)
function notePaper(x, y, w, h, txt, o = {}) {
  const sw = swOf(w), a = o.rot || 0;
  boilSeed('note' + (o.key || ''));
  const Q = pts => place(pts, x, y, 1, a);
  const edge = o.torn ? [...Array(9)].map((_, i) => [-w / 2 + w * i / 8, -h / 2 + (i % 2 ? 8 : -6) * (w / 600)]) : [[-w / 2, -h / 2], [w / 2, -h / 2]];
  P(Q([...edge, [w / 2, h / 2], [-w / 2, h / 2]]), PAPER, sw * .7);
  const g = w / 16;
  for (let i = 1; i < 16; i++) line(Q([[-w / 2 + i * g, -h / 2 + g * .3], [-w / 2 + i * g, h / 2 - 4]]), sw * .15, '#9DB8D6', 'inkfine', 0);
  for (let i = 1; i < h / g; i++) line(Q([[-w / 2 + 4, -h / 2 + i * g], [w / 2 - 4, -h / 2 + i * g]]), sw * .15, '#9DB8D6', 'inkfine', 0);
  if (o.margin) line(Q([[-w / 2 + g * 2, -h / 2], [-w / 2 + g * 2, h / 2]]), sw * .3, '#D86A6A', 'inkfine', 0);
  if (txt) hand(txt, ...Q([[-w / 2 + (o.pad || g * .8), -h / 2 + g * 1.6]])[0], o.size || g * 1.15, o.col || BLUEINK,
    { reveal: o.reveal, shaky: true, rot: a, maxW: w - g * 2, lh: (o.lh || 1.15) });
}
// thick school notebook, closed (cover text) or open (two pages via draw callbacks)
function notebook(x, y, w, h, o = {}) {
  const sw = swOf(w), a = o.rot || 0, Q = pts => place(pts, x, y, 1, a);
  boilSeed('nb');
  if (!o.open) {
    P(Q([[-w / 2 + 6, -h / 2 + 8], [w / 2 + 6, -h / 2 + 8], [w / 2 + 6, h / 2 + 8], [-w / 2 + 6, h / 2 + 8]]), '#D8CCAE', sw * .6); // page block
    P(Q([[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]]), '#3F5A4A', sw);
    P(Q([[-w * .3, -h * .32], [w * .3, -h * .32], [w * .3, -h * .1], [-w * .3, -h * .1]]), '#EFE6CC', sw * .4);
    if (o.cover) hand(o.cover, ...Q([[0, -h * .2]])[0], h * .1, BLUEINK, { align: 'center', rot: a });
    return;
  }
  P(Q([[-w, -h / 2 - 6], [w, -h / 2 - 6], [w + 8, h / 2 + 10], [-w - 8, h / 2 + 10]]), '#3F5A4A', sw);
  for (const d of [-1, 1]) {
    const cx = d * w / 2, pts = Q([[cx - w / 2 + 4, -h / 2], [cx + w / 2 - 4, -h / 2], [cx + w / 2 - 4, h / 2], [cx - w / 2 + 4, h / 2]]);
    if (d > 0 && o.tornRight) continue;
    P(pts, PAPER, sw * .5);
    const g = w / 14; for (let i = 1; i < h / g; i++) line(Q([[cx - w / 2 + 8, -h / 2 + i * g], [cx + w / 2 - 8, -h / 2 + i * g]]), sw * .14, '#9DB8D6', 'inkfine', 0);
  }
  if (o.tornRight) { // only a ragged stub of the last page by the spine
    const stub = [...Array(10)].map((_, i) => [8 + (i % 2 ? 14 : 4) * (w / 400), -h / 2 + h * i / 9]);
    P(Q([[0, -h / 2], ...stub, [0, h / 2]]), PAPER, sw * .4);
  }
  line(Q([[0, -h / 2], [0, h / 2]]), sw * .6, '#6A6050');
  if (o.left) o.left(...Q([[-w / 2, 0]])[0]);
  if (o.right) o.right(...Q([[w / 2, 0]])[0]);
}
function oldKey(x, y, s, a = 0) {
  const sw = swOf(s * 1.5);
  boilSeed('key');
  P(place(ellPts(0, 0, .32, .32, 14), x, y, s, a), '#B8933E', sw);
  PN(place(ellPts(0, 0, .14, .14, 10), x, y, s, a), '#2A2420');
  P(place([[.3, -.07], [1.3, -.07], [1.3, .07], [.3, .07]], x, y, s, a), '#B8933E', sw);
  P(place([[1.05, .05], [1.3, .05], [1.3, .3], [1.18, .3], [1.18, .2], [1.05, .2]], x, y, s, a), '#B8933E', sw * .7);
}

// ---------- furniture & light ----------
function bulb(x, y, s, on = 1, wire = 300) {
  const sw = swOf(s * 2);
  boilSeed('bulb' + x);
  line([[x, y - wire], [x, y - s * .6]], sw * .5);
  P(rectPts(x - s * .18, y - s * .7, s * .36, s * .3), '#6A6A70', sw * .5);
  if (on > 0) glow(x, y, s * 6, '#FFC768', .9 * on);
  P(ellPts(x, y, s * .38, s * .45, 14), on > 0 ? mixCol('#FFE7A8', '#FFF8E2', on) : '#B7B0A0', sw * .5);
  if (on > 0) glow(x, y, s * 1.4, '#FFF0C0', on);
}
function stool(x, y, s) {
  const sw = swOf(s);
  boilSeed('stool');
  P(rectPts(x - s * .5, y - s * 1.0, s, s * .16), '#8A5A34', sw);
  for (const d of [-1, 1]) P([[x + d * s * .38, y - s * .86], [x + d * s * .28, y - s * .86], [x + d * s * .42, y], [x + d * s * .52, y]], '#6E4426', sw * .7);
}
function wardrobe(x, y, w, h, o = {}) { // (x, y) = bottom-left
  const sw = swOf(w);
  boilSeed('wardrobe');
  P(rectPts(x, y - h, w, h), '#7A4E30', sw);
  line([[x + w / 2, y - h + 10], [x + w / 2, y - 12]], sw * .5);
  for (const d of [-1, 1]) P(ellPts(x + w / 2 + d * w * .06, y - h * .52, w * .018, w * .035, 8), BRASS, sw * .3);
  PN(rectPts(x + w * .52, y - h, w * .48, h), '#2C1A10', { washOp: 90 });
  P(rectPts(x - w * .02, y - h - w * .06, w * 1.04, w * .07), '#5E3A22', sw * .6);
}
function mug(x, y, s, steam = 0) {
  const sw = swOf(s * 2);
  boilSeed('mug');
  P(rr(x - s * .4, y - s * .5, s * .8, s, s * .1), '#E6E0D0', sw);
  line(through([[x + s * .4, y - s * .3], [x + s * .62, y - s * .1], [x + s * .4, y + s * .15]]), sw * .9, L('#E6E0D0'));
  P(ellPts(x, y - s * .45, s * .34, s * .07, 12), '#6A3E22', sw * .4);
}
