// people.js: Dima, Semyonych, Aunt Valya and Olya, drawn as flat 90s-anime cels: wash colour, cel shadow, ink outline.
//
// head(C, x, y, s, o)      a head of height s centred at (x, y)
// person(C, x, y, s, pose) a whole figure; (x, y) is the HIP centre, s the head height. standY(C, groundY, s) gives the hip y.
//
// Turning is drawn, not projected: v (−1..1) slides the features toward the side the head faces and narrows the far
// half of the face, like a model sheet's 3/4 view. Keep |v| ≤ .75.

const SKIN = { dima: '#F2D3BE', sem: '#E9C2A6', valya: '#F3C8B0', olya: '#F7D9C6' };
const CHAR = {
  dima: {
    skin: SKIN.dima, hair: '#2A2226', eye: '#4D5260', top: '#9C9DA6', bottom: '#2F3F66', shoe: '#1E1E24', sole: '#E8E4DA',
    legLen: 3.55, torso: 2.45, sh: .86, hip: .56, upper: 1.32, fore: 1.22, thigh: 1.75, shin: 1.65, neck: .3, stoop: .06,
    face: { w: .36, jaw: .25, chin: .52, cheek: .14 },
  },
  sem: {
    skin: SKIN.sem, hair: '#D4D2CC', eye: '#8DB4D2', top: '#A04A3A', plaid: ['#5E2620', '#D38B6E'], bottom: '#4B4B52', shoe: '#7A5236', sole: '#5C3C26',
    legLen: 2.9, torso: 2.25, sh: .78, hip: .55, upper: 1.15, fore: 1.08, thigh: 1.45, shin: 1.38, neck: .18, stoop: .22,
    face: { w: .4, jaw: .3, chin: .5, cheek: .2 },
  },
  valya: {
    skin: SKIN.valya, hair: '#2C3E78', eye: '#6A4632', top: '#EE9DB2', dots: '#FFF0F4', bottom: '#D8B694', shoe: '#7A5236', sole: '#5C3C26',
    legLen: 2.7, torso: 2.3, sh: .9, hip: .9, upper: 1.1, fore: 1.0, thigh: 1.35, shin: 1.3, neck: .1, stoop: .08,
    face: { w: .44, jaw: .36, chin: .5, cheek: .3 },
  },
  olya: {
    skin: SKIN.olya, hair: '#5A3A22', eye: '#5A4030', top: '#F3C232', bottom: '#3C5A8A', shoe: '#B2342E', sole: '#F0E6D8',
    legLen: 2.1, torso: 1.6, sh: .62, hip: .5, upper: .82, fore: .78, thigh: 1.05, shin: 1.0, neck: .12, stoop: 0,
    face: { w: .4, jaw: .3, chin: .48, cheek: .26 },
  },
};
const standY = (C, gy, s) => gy - C.legLen * s;

// ---------------------------------------------------------------- head
// o: v (turn), tilt, eo (eye open 0..1.4), look [x,y], brow (+ raised / − frowning), mouth: {open, smile, w}, blink 0..1,
//    pupil (pupil size multiplier), sweat, flipLight (cel shadow side), shadowK (0..1 half-face darkness)
function head(name, x, y, s, o = {}) {
  const C = CHAR[name], F = C.face, v = clamp(o.v || 0, -.8, .8), tilt = o.tilt || 0, sw = swOf(s) * (o.swk || 1);
  const ca = Math.cos(tilt), sa = Math.sin(tilt);
  const X = (px, py) => [x + (px * ca - py * sa) * s, y + (px * sa + py * ca) * s];
  // horizontal squeeze: the far half narrows, everything slides toward the facing side
  const hx = px => (px * v > 0 ? px * (1 - .1 * Math.abs(v)) : px * (1 - .5 * Math.abs(v))) + v * .07;
  const Q = (px, py, slide = 0) => X(hx(px) + v * slide, py);
  const Ql = (pts, slide = 0) => pts.map(([a, b]) => Q(a, b, slide));
  const skin = C.skin, dk = shd(skin, .38);
  boilSeed('head' + name + (o.key || ''));

  // ---- behind the face: back hair, headscarf knot
  if (name === 'dima') P(Ql([[-.42, -.1], [-.47, -.4], [-.3, -.62], [.02, -.69], [.32, -.6], [.48, -.38], [.44, -.08], [.36, .05], [-.36, .05]]), C.hair, sw, { curv: .5 });
  if (name === 'olya') { // pigtails
    for (const d of [-1, 1]) { const bx = d * .5 + (d * v < 0 ? .12 * v : 0), sway = Math.sin((o.t || 0) * 3 + d) * .03;
      P(Ql([[d * .38, -.12], [bx + d * .12, .02], [bx + d * .2 + sway, .3], [bx + d * .1 + sway, .44], [bx - d * .02, .28], [d * .36, .06]]), C.hair, sw * .8);
      P(Ql(ellPts(d * .4, -.08, .06, .05, 8)), '#E2443A', sw * .6); }
    P(Ql([[-.43, -.05], [-.45, -.4], [-.2, -.6], [.15, -.6], [.42, -.42], [.44, -.05]]), C.hair, sw);
  }
  if (name === 'valya') P(Ql([[-.5, .1], [-.55, -.35], [-.3, -.62], [.1, -.68], [.42, -.55], [.56, -.25], [.52, .12], [.3, .2], [-.3, .2]]), C.hair, sw);

  // ---- ears (both peek out; the far one hides as the head turns)
  for (const d of [-1, 1]) {
    if (d * v < -.35) continue;
    const ex = d * (F.w + .02);
    P(Ql([[ex, -.06], [ex + d * .07, -.1], [ex + d * .09, .02], [ex + d * .05, .12], [ex, .1]]), mixCol(skin, '#E89A88', .2), sw * .7);
  }

  // ---- face
  const w = F.w, face = [[-w, -.32], [-w - .02, -.05], [-w + .02, F.cheek], [-F.jaw, .34], [-.1, F.chin - .02], [0, F.chin], [.1, F.chin - .02], [F.jaw, .34], [w - .02, F.cheek], [w + .02, -.05], [w, -.32], [.24, -.5], [0, -.54], [-.24, -.5]];
  const facePts = face.map(([a, b]) => Q(a, b, Math.abs(b) > .3 ? .05 : 0));
  P(facePts, skin, sw * 1.15, { curv: .55 });
  // cel shadow: the half away from the light, and under the hair line
  const sk = o.shadowK ?? .55, side = o.flipLight ? 1 : -1;
  if (sk > 0) PN(Ql([[side * w * .95, -.32], [side * (w - .02), -.05], [side * (w - .05), F.cheek], [side * (F.jaw - .03), .32], [side * .09, F.chin - .05], [side * .02, F.chin - .05], [side * .12, .28], [side * .2, .05], [side * .15, -.25], [side * .2, -.45]], .02), dk, { washOp: 255 * sk });

  // ---- cheeks / age
  if (name === 'valya' || name === 'olya') for (const d of [-1, 1]) PN(Ql(ellPts(d * .24, .2, .08, .045, 10), .15), '#F08E8E', { washOp: 150 });
  if (name === 'sem') {
    for (const d of [-1, 1]) { line(Ql([[d * .3, .12], [d * .25, .26], [d * .14, .34]], .1), sw * .45); line(Ql([[d * .33, -.04], [d * .38, .02]], .2), sw * .4); }
    line(Ql([[-.2, -.36], [0, -.38], [.2, -.36]], .05), sw * .4); line(Ql([[-.15, -.29], [.15, -.29]], .05), sw * .35);
  }
  if (name === 'dima') { // tired circles + stubble
    for (const d of [-1, 1]) line(Ql([[d * .25, .1], [d * .17, .125], [d * .09, .1]], .17), sw * .35, '#8A6C88');
    PN(Ql([[-F.jaw, .3], [-.1, F.chin - .05], [.1, F.chin - .05], [F.jaw, .3], [.1, .44], [-.1, .44]], .1), '#B8A3A0', { washOp: 70 });
  }

  // ---- eyes
  const blink = clamp(o.blink || 0), eo = (o.eo ?? 1) * (1 - blink);
  const look = o.look || [0, 0], pup = o.pupil ?? 1;
  const E = name === 'sem' ? { y: .02, sep: .19, w: .17, h: .09, ir: .045 } : name === 'valya' ? { y: .02, sep: .19, w: .15, h: .1, ir: .045 }
    : name === 'olya' ? { y: .05, sep: .18, w: .17, h: .17, ir: .07 } : { y: .02, sep: .18, w: .19, h: .13, ir: .062 };
  for (const d of [-1, 1]) {
    const far = d * v < 0, sq = far ? 1 - .45 * Math.abs(v) : 1, ex = d * E.sep, ew = E.w * sq, eh = E.h * eo;
    const C0 = (a, b) => Q(ex + a, E.y + b, .17);
    if (eh < .012) { // closed: a curved lash line
      line([C0(-ew / 2, 0), C0(0, .02), C0(ew / 2, -.005)], sw * 1.1);
      continue;
    }
    const sclera = [[-ew / 2, 0], [-ew * .3, -eh * .55], [0, -eh * .62], [ew * .32, -eh * .5], [ew / 2, -eh * .05], [ew * .25, eh * .4], [0, eh * .45], [-ew * .3, eh * .3]].map(([a, b]) => C0(a, b));
    P(sclera, '#FFF8EC', 0);
    const ir = Math.min(E.ir * sq, eh * .5), lx = look[0] * ew * .22, ly = look[1] * eh * .2;
    P([...Array(12)].map((_, i) => { const a = i / 12 * TAU; return C0(lx + Math.cos(a) * ir * .85, ly + Math.sin(a) * Math.min(ir * 1.1, eh * .5)); }), C.eye, 0);
    PN([...Array(10)].map((_, i) => { const a = i / 10 * TAU; return C0(lx + Math.cos(a) * ir * .42 * pup, ly + Math.sin(a) * ir * .5 * pup); }), '#15131A');
    if (pup > .5) PN(ellPts(...C0(lx - ir * .3, ly - ir * .35), ir * s * .22, ir * s * .22, 8), '#FFFFFF');
    // lids: thick upper lash, thin lower
    line([C0(-ew * .55, eh * .05), C0(-ew * .3, -eh * .58), C0(0, -eh * .66), C0(ew * .32, -eh * .54), C0(ew * .58, -eh * .08)], sw * (name === 'olya' ? 1.5 : 1.25));
    line([C0(-ew * .3, eh * .32), C0(0, eh * .46), C0(ew * .3, eh * .36)], sw * .4);
    if (name === 'sem' && (o.eo ?? 1) < 1.1) line([C0(-ew * .5, -eh * 1.2), C0(0, -eh * 1.5), C0(ew * .5, -eh * 1.15)], sw * .4); // heavy lids
  }
  // ---- brows
  const br = o.brow || 0;
  for (const d of [-1, 1]) {
    const far = d * v < 0, sq = far ? 1 - .45 * Math.abs(v) : 1, bx = d * E.sep, by = E.y - E.h * .9 - .06 - br * .04;
    const inner = [bx - d * .07 * sq, by + .01 - br * d * 0 + (br < 0 ? .03 : -.01)], outer = [bx + d * .1 * sq, by + (br < 0 ? -.02 : .02)];
    if (name === 'sem') P(ribbon([Q(...inner, .15), Q(bx, by - .025, .15), Q(...outer, .15)], s * .07, s * .04), '#F2F0EA', sw * .5);
    else line([Q(...inner, .15), Q(bx, by - .02, .15), Q(...outer, .15)], sw * (name === 'dima' ? 1.05 : .55), name === 'dima' ? INK : '#5A3A2A');
  }

  // ---- nose
  if (name === 'sem') { P(Ql([[0, .02], [.045, .17], [.07, .21], [.02, .235], [-.05, .215], [-.03, .14]], .22), mixCol(skin, '#D98C78', .25), sw * .6); }
  else { line(Ql([[.015, .1], [.03, .17], [-.005, .19]], .2), sw * .55); }

  // ---- mouth
  const M = o.mouth || {}, mo = clamp(M.open || 0), sm = M.smile || 0, mw = (M.w || (name === 'sem' ? .12 : .1)), my = name === 'sem' ? .33 : .32;
  if (mo > .05) {
    P(Ql([[-mw, my - sm * .02], [0, my - .01 + sm * .03], [mw, my - sm * .02], [mw * .6, my + .03 + mo * .07], [0, my + .05 + mo * .1], [-mw * .6, my + .03 + mo * .07]], .2), '#5A2430', sw * .6);
    if (sm > .3) PN(Ql([[-mw * .8, my - sm * .015], [mw * .8, my - sm * .015], [mw * .7, my + .015], [-mw * .7, my + .015]], .2), '#FFF6EA');
  } else line(Ql([[-mw, my - sm * .025], [0, my + sm * .03], [mw, my - sm * .025 + (M.smirk || 0) * -.03]], .2), sw * .7);

  // ---- front hair / scarf / bald head
  if (name === 'dima') {
    const sway = Math.sin((o.t || 0) * 1.3) * .01, H = C.hair;
    P(Ql([[-.46, -.2], [-.48, -.46], [-.3, -.64], [0, -.7], [.3, -.64], [.48, -.44], [.46, -.18], [.36, -.3], [.4, -.05], [.26, -.28], [.22, -.08 + sway], [.1, -.26], [.03, -.04 + sway], [-.06, -.27], [-.15, -.06 + sway], [-.22, -.28], [-.33, -.08], [-.36, -.3]], .03), H, sw);
    line(Ql([[-.1, -.6], [-.02, -.45], [.02, -.3]], .03), sw * .4, '#5A4A58'); line(Ql([[.2, -.58], [.24, -.42]], .03), sw * .4, '#5A4A58');
  }
  if (name === 'sem') {
    PN(Ql(ellPts(-.12, -.42, .12, .05, 10), .04), '#FFF4E6', { washOp: 150 }); // shine on the bald head
    for (const d of [-1, 1]) if (d * v > -.4) P(Ql([[d * .36, -.22], [d * .44, -.2], [d * .47, .02], [d * .4, .06], [d * .41, -.1]], .02), C.hair, sw * .6);
  }
  if (name === 'valya') {
    for (let i = 0; i < 4; i++) P(Ql(ellPts(-.3 + i * .2, -.44 + Math.abs(i - 1.5) * .02, .07, .05, 8), .03), '#F4A6C2', sw * .5);
    P(Ql([[-.52, .06], [-.56, -.3], [-.38, -.48], [-.1, -.5], [.1, -.56], [.38, -.5], [.56, -.3], [.52, .06], [.44, .12], [.44, -.2], [.3, -.4], [0, -.42], [-.3, -.4], [-.44, -.2], [-.44, .12]], .03), C.hair, sw);
    for (let i = 0; i < 6; i++) PN(Ql(ellPts(-.4 + i * .16, -.3 - Math.sin(i) * .05, .02, .02, 6), .03), '#B8C6F0');
  }
  if (name === 'olya') {
    P(Ql([[-.44, -.15], [-.43, -.42], [-.2, -.6], [.15, -.6], [.43, -.42], [.44, -.15], [.3, -.32], [.15, -.22], [.05, -.34], [-.08, -.22], [-.2, -.34], [-.32, -.2]], .03), C.hair, sw);
  }
  if (o.sweat) P(Ql(ellPts(.42, -.2, .03, .05, 8), .05), '#CDEBFF', sw * .4);
}

// ---------------------------------------------------------------- body
// pose: v (turn), lean (rad, + toward facing), arms {aL:[shoulder, elbow], aR:[...]}, legs {lL:[hip, knee], lR:[...]},
// head opts in pose.h, hand shapes in pose.handL/handR ('open' | 'fist' | 'grip'), prop(hand, x, y, ang) to hold things.
// Angles: 0 = limb hangs straight down; + swings it toward the side the figure faces (screen right when facing right
// or front). Elbow/knee angles are relative to the upper limb.
function person(name, x, y, s, pose = {}) {
  const C = CHAR[name], v = clamp(pose.v || 0, -.85, .85), face = pose.flip ? -1 : 1, sw = swOf(s);
  const lean = (pose.lean || 0) + C.stoop * .3;
  const dirX = a => Math.sin(a) * face, dirY = a => Math.cos(a);
  const shW = C.sh * (1 - .45 * Math.abs(v)), hipW = C.hip * (1 - .35 * Math.abs(v));
  const turnX = v * .18;  // the chest slides toward the facing side
  // torso frame: rotate around the hip by lean
  const cl = Math.cos(lean * face), sl = Math.sin(lean * face);
  const T = (px, py) => [x + (px * cl - py * sl) * s, y + (px * sl + py * cl) * s];
  const shY = -C.torso, neckY = -C.torso - C.neck;
  const shoulder = d => T(d * shW + turnX, shY + .08);
  const hipPt = d => [x + d * hipW * .55 * s, y];
  const A = pose.arms || {}, Lg = pose.legs || {};
  const limb = (p0, a1, l1, a2, l2) => { const p1 = [p0[0] + dirX(a1) * l1 * s, p0[1] + dirY(a1) * l1 * s]; const p2 = [p1[0] + dirX(a1 + a2) * l2 * s, p1[1] + dirY(a1 + a2) * l2 * s]; return [p0, p1, p2]; };
  // which side is near: facing right (v>0) → screen-right limbs (d=+1) are near
  const nearD = v * face >= 0 ? 1 : -1;
  const order = [-nearD, nearD];
  const top = C.top, bottom = C.bottom;
  boilSeed('body' + name + (pose.key || ''));

  const drawLeg = (d, far) => {
    const [h, k] = (d < 0 ? Lg.lL : Lg.lR) || [0, 0];
    const [p0, p1, p2] = limb(hipPt(d), h, C.thigh, k, C.shin);
    const col = far ? shd(bottom, .25) : bottom;
    if (name !== 'valya' && name !== 'olya') P(ribbon([p0, p1, p2], s * (name === 'sem' ? .46 : .44), s * .3), col, sw * .9, { curv: .3 });
    else P(ribbon([p0, p1, p2], s * .22, s * .17), far ? shd(C.bottom, .25) : C.bottom, sw * .7);
    // shoe
    const sa = h + k, fx = Math.abs(v) > .2 ? face * Math.sign(v) : 0;
    const shoe = fx ? [[-.12, -.05], [.38, -.06], [.42, .06], [-.14, .08]].map(([a, b]) => [p2[0] + (a * fx) * s, p2[1] + (b + .02) * s])
      : [[-.15, -.05], [.15, -.05], [.17, .1], [-.17, .1]].map(([a, b]) => [p2[0] + a * s, p2[1] + (b + .02) * s]);
    P(shoe, far ? shd(C.shoe, .2) : C.shoe, sw * .8);
    if (name === 'dima') PN(shoe.slice(2).concat([[shoe[3][0], shoe[3][1] - .04 * s], [shoe[2][0], shoe[2][1] - .04 * s]]).map(p => p), C.sole);
    return p2;
  };
  const drawArm = (d, far) => {
    const [sA, eA] = (d < 0 ? A.aL : A.aR) || (Math.abs(v) < .3 ? [d * face * .1, d * face * .1] : [.06, .14]);
    // arm angles are given in "toward facing" space; mirror the outward splay for the left arm in front view
    const [p0, p1, p2] = limb(shoulder(d), sA, C.upper, eA, C.fore);
    const col = far ? shd(top, .3) : top;
    P(ribbon([p0, p1, p2], s * (name === 'valya' ? .4 : .36), s * .26), col, sw * .9, { curv: .3 });
    // cuff + hand
    const ang = Math.atan2(p2[1] - p1[1], p2[0] - p1[0]);
    handAt(name, p2[0], p2[1], ang, s, (d < 0 ? pose.handL : pose.handR) || 'open', far, sw);
    if (pose.prop && pose.prop.hand === d) pose.prop.draw(p2[0] + Math.cos(ang) * s * .22, p2[1] + Math.sin(ang) * s * .22, ang);
    return p2;
  };

  // far limbs first
  drawArm(order[0], true);
  if (!pose.noLegs) drawLeg(order[0], true);
  if (!pose.noLegs) drawLeg(order[1], false);

  // torso
  const tp = [[-hipW, .02], [-hipW * 1.04, -.55], [-shW * .86, -C.torso * .68], [-shW * .98, shY + .32], [-shW * .9, shY + .06], [-shW * .55, shY - .04], [-.2, neckY + .12], [.2, neckY + .12], [shW * .55, shY - .04], [shW * .9, shY + .06], [shW * .98, shY + .32], [shW * .86, -C.torso * .68], [hipW * 1.04, -.55], [hipW, .02]]
    .map(([a, b]) => T(a + (b < -1 ? turnX * clamp(-b / C.torso) : 0), b));
  // neck
  P([T(-.1 + turnX, neckY - .05), T(.1 + turnX, neckY - .05), T(.12 + turnX, neckY + .2), T(-.12 + turnX, neckY + .2)], C.skin, sw * .7);
  if (name === 'valya') { // robe hangs to the knees
    P([T(-hipW * 1.1, 1.4), T(-hipW * 1.05, 0), ...tp.slice(1, -1), T(hipW * 1.05, 0), T(hipW * 1.1, 1.4)], top, sw);
    for (let i = 0; i < 26; i++) PN(ellPts(...T((hash(i) - .5) * 1.6 * hipW, -C.torso + .3 + hash(i + 40) * (C.torso + 1)), s * .025, s * .025, 6), C.dots);
    line([T(-hipW, -.55), T(0, -.5), T(hipW, -.55)], sw * 1.4, '#C9708A');
  } else if (name === 'olya') { // raincoat, A-line
    P([T(-hipW * 1.25, 1.1), T(-hipW * .9, -.4), ...tp.slice(2, -2), T(hipW * .9, -.4), T(hipW * 1.25, 1.1)], top, sw);
    for (let i = 0; i < 3; i++) P(ellPts(...T(turnX * .5, -C.torso + .45 + i * .45), s * .045, s * .045, 8), '#FFF2C0', sw * .4);
  } else P(tp, top, sw, { curv: .3 });
  // cel shadow on the far side of the torso
  PN([T(-nearD * shW * .95, shY + .15), T(-nearD * shW * .45, shY + .3), T(-nearD * hipW * .5, -.1), T(-nearD * hipW, -.05)], shd(top, .35), { washOp: 200 });
  if (name === 'dima') { // hoodie: pocket, drawstrings, hood
    line([T(-hipW * .6 + turnX * .4, -.75), T(-hipW * .5 + turnX * .4, -1.25), T(hipW * .5 + turnX * .4, -1.25), T(hipW * .6 + turnX * .4, -.75)], sw * .6);
    for (const d of [-1, 1]) line([T(d * .1 + turnX, neckY + .25), T(d * .12 + turnX, neckY + .9)], sw * .5, '#F2EEE6');
    P([T(-shW * .7 + turnX, shY + .05), T(-.25 + turnX, neckY + .2), T(.25 + turnX, neckY + .2), T(shW * .7 + turnX, shY + .05), T(shW * .4 + turnX, shY + .25), T(-shW * .4 + turnX, shY + .25)], shd(top, .12), sw * .7);
  }
  if (name === 'sem') { // plaid: two hatchings in the shirt's own shape
    paint(tp, { hatch: { d: s * .22, a: 0, b: 'HB', c: L(C.plaid[0]), w: 1.6 }, ink: null });
    paint(tp, { hatch: { d: s * .22, a: Math.PI / 2, b: 'HB', c: L(C.plaid[1]), w: 1.1 }, ink: null });
    for (let i = 0; i < 4; i++) P(ellPts(...T(turnX, neckY + .35 + i * .45), s * .03, s * .03, 6), '#E8DCCB', sw * .3);
    P([T(-.22 + turnX, neckY + .12), T(0 + turnX, neckY + .32), T(.22 + turnX, neckY + .12), T(.16 + turnX, neckY + .04), T(-.16 + turnX, neckY + .04)], C.top, sw * .6);
  }

  if (pose.behindHead) pose.behindHead();
  // head on the neck
  const hd = pose.h || {}, hs = pose.hs || 1, hc = T(turnX * 1.1 + (hd.dx || 0), neckY - .45 * hs + (hd.dy || 0));
  head(name, hc[0], hc[1], s * hs, { v: v * .9, ...hd, tilt: (hd.tilt || 0) + lean * face * .4, key: pose.key });
  // near arm last
  drawArm(order[1], false);
  if (pose.after) pose.after();
  return { headAt: hc, T };
}

// a simple cartoon hand at a wrist, pointing along `ang`
function handAt(name, x, y, ang, s, kind, far, sw) {
  const skin = far ? shd(CHAR[name].skin, .2) : CHAR[name].skin, k = s * (name === 'olya' ? .2 : .24);
  const H = (pts) => place(pts, x, y, k, ang);
  if (kind === 'fist' || kind === 'grip') {
    P(H([[0, -.45], [.75, -.55], [1.05, -.2], [1.05, .3], [.7, .55], [0, .45]]), skin, sw * .7);
    for (let i = 0; i < 3; i++) line(H([[.6, -.35 + i * .3], [1, -.3 + i * .3]]), sw * .35);
  } else if (kind === 'point') {
    P(H([[0, -.4], [.65, -.45], [1.5, -.2], [1.5, .02], [.75, .05], [.7, .45], [0, .4]]), skin, sw * .7);
  } else {
    P(H([[0, -.42], [.6, -.5], [1.25, -.45], [1.4, -.18], [1.35, .12], [1.2, .38], [.6, .5], [.35, .75], [.15, .62], [0, .38]]), skin, sw * .7);
    for (let i = 0; i < 3; i++) line(H([[.8, -.28 + i * .22], [1.32, -.3 + i * .25]]), sw * .3);
  }
}

// ---------- acting helpers (pure functions of time) ----------
// blink: 0..1, a quick close every few seconds, offset per seed
function blinkAt(t, seed = 0, every = 3.4) { const ph = frac((t + hash(seed) * every) / every) * every; return ph < .14 ? Math.sin(ph / .14 * Math.PI) : 0; }
// talking mouth between a and b (shot time): returns open 0..1, syllable-like
function talk(lt, a, b, amt = .6, seed = 0) {
  if (lt < a || lt > b) return 0;
  const x = (lt - a) * 7.5 + seed, v = Math.abs(Math.sin(x * 1.7) * .6 + Math.sin(x * 3.1 + 1) * .4);
  return amt * v * clamp(Math.min((lt - a) / .1, (b - lt) / .1));
}
// walk cycle: leg + arm angles from a phase (radians); returns {lL, lR, aL, aR, bob}
function walkPose(ph, k = 1) {
  const s = Math.sin(ph), c = Math.cos(ph);
  return { lL: [s * .38 * k, -Math.max(0, -c) * .6 * k], lR: [-s * .38 * k, -Math.max(0, c) * .6 * k],
           aL: [-s * .3 * k, .25], aR: [s * .3 * k, .25], bob: Math.abs(c) * .05 };
}
