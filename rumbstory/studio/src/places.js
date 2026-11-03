// places.js: the nine-storey panel block. Every place paints the WHOLE frame (oversized, so cameras can drift).
// Light comes from setLight() before the call; o.bulb lights the stairwell at night.

const WALL_GREEN = '#2F6B52', WHITEWASH = '#E7E1CE', CONCRETE = '#8D8B85', PAPERWALL = '#D8C49C', LINO = '#7A5238';
const bgFill = col => paint(rectPts(-400, -400, W + 800, H + 800), { wash: L(col), ink: null });

// ---------- stairwell landing, front view ----------
// o: line (y of the green/white border), floor (y), doors [{x, num, seal, w, h}], stairs 'right'|'left'|null,
//    window {x, y}, bulb {x, y, on}, meter (x)
function stairwell(t, o = {}) {
  const ln = o.line ?? 860, fl = o.floor ?? 1560;
  boilSeed('stw');
  bgFill(WHITEWASH);
  PN(rectPts(-400, ln, W + 800, fl - ln), WALL_GREEN);
  line([[-400, ln], [W + 400, ln]], 1.2, '#1E4434', 'ink', 0);
  // chipped paint and scratches (stable)
  for (let i = 0; i < 14; i++) { const cx = -200 + hash(i) * (W + 400), cy = ln + 40 + hash(i + 20) * (fl - ln - 80);
    PN(ellPts(cx, cy, 10 + 26 * hash(i + 4), 6 + 12 * hash(i + 8), 7, 3), '#C9C6B2', { washOp: 160 }); }
  for (let i = 0; i < 9; i++) { const cx = -200 + hash(i + 50) * (W + 400), cy = ln + 60 + hash(i + 70) * (fl - ln - 120);
    line([[cx, cy], [cx + 30 + 40 * hash(i), cy + 8 - 16 * hash(i + 3)]], .4, '#173A2C', 'inkfine', 0); }
  // floor
  PN(rectPts(-400, fl, W + 800, H + 400), CONCRETE);
  line([[-400, fl], [W + 400, fl]], 1.2, INK, 'ink', 0);
  for (let i = 0; i < 6; i++) line([[-400, fl + 60 + i * 90], [W + 400, fl + 60 + i * 90]], .3, '#6E6C68', 'inkfine', 0);
  if (o.window) { const { x, y } = o.window; // window with a cracked pane and a pigeon
    P(rectPts(x - 150, y - 210, 300, 420), '#E9E4D6', 1);
    PN(rectPts(x - 128, y - 190, 256, 380), LIGHT.k > .3 ? '#1B3140' : '#BFD8E0');
    line([[x, y - 190], [x, y + 190]], 1, INK, 'ink', 0); line([[x - 128, y], [x + 128, y]], 1, INK, 'ink', 0);
    line([[x - 100, y - 160], [x - 60, y - 110], [x - 85, y - 60], [x - 40, y - 20]], .5, '#5A6A74', 'inkfine', 0);
    P(rectPts(x - 175, y + 200, 350, 26), '#D6D0C0', .9);
    if (o.window.pigeon !== false) { const px = x + 70 + 4 * Math.sin(t * 2), py = y + 186;
      P(ellPts(px, py - 28, 46, 30, 14), '#8E96A6', .8); P(ellPts(px + 40, py - 58, 18, 16, 10), '#7F889A', .7);
      P([[px + 56, py - 60], [px + 70, py - 56], [px + 56, py - 52]], '#E0A040', .4); PN(ellPts(px + 44, py - 61, 3, 3, 6), INK);
      P([[px - 40, py - 32], [px - 80, py - 18], [px - 40, py - 14]], '#6E7688', .6); }
  }
  if (o.meter != null) { P(rectPts(o.meter, ln - 300, 170, 240), '#A9AAA4', 1); line([[o.meter + 85, ln - 290], [o.meter + 85, ln - 70]], .5); }
  for (const d of o.doors || []) door(d.x, d.y ?? fl - (d.h || 600), d.w || 300, d.h || 600, { inside: false, num: d.num, seal: d.seal, peep: true, key: d.num, jolt: d.jolt });
  if (o.stairs) { // a flight rising away, drawn flat: treads as stacked strips, handrail on balusters
    const dir = o.stairs === 'right' ? 1 : -1, x0 = o.stairs === 'right' ? (o.stairX ?? 760) : (o.stairX ?? 320), n = 9, sh = 70, sd = 62;
    for (let i = n - 1; i >= 0; i--) {
      const sx = x0 + dir * i * sd, sy = fl - i * sh;
      P([[sx, sy], [sx + dir * 900, sy], [sx + dir * 900, sy + sh], [sx, sy + sh]].map(p => [Math.min(p[0], p[0]), p[1]]), i % 2 ? '#9A9892' : '#A6A49E', .7);
      PN([[sx, sy], [sx + dir * 900, sy], [sx + dir * 900, sy + 12], [sx, sy + 12]], '#C4C1B8');
    }
    const rail = [...Array(n + 1)].map((_, i) => [x0 + dir * i * sd + dir * 20, fl - i * sh - 210]);
    for (let i = 0; i <= n; i += 1) line([[rail[i][0], rail[i][1]], [rail[i][0], rail[i][1] + 210]], .5, '#3A3A40', 'inkfine', 0);
    P(ribbon(rail, 26, 26), '#4A2A1E', .8);
  }
  if (o.bulb) bulb(o.bulb.x, o.bulb.y, 34, o.bulb.on ?? 1, 600);
}

// ---------- Dima's narrow hallway, one-point view to the front door ----------
// o: door opts (latch, jolt), gap {feet}, light 'day' | 'night'; returns geometry for placing people
const HALL = { bx0: 290, bx1: 790, by0: 420, by1: 1330, dx: 370, dy: 540, dw: 340, dh: 790 };
function hallway(t, o = {}) {
  const B = HALL;
  boilSeed('hall');
  bgFill('#2A2220');
  // ceiling, side walls, floor
  PN([[-400, -400], [W + 400, -400], [B.bx1, B.by0], [B.bx0, B.by0]], '#CFC4AE');
  for (const s of [-1, 1]) {
    const ex = s < 0 ? -400 : W + 400, bx = s < 0 ? B.bx0 : B.bx1;
    P([[ex, -400], [bx, B.by0], [bx, B.by1], [ex, H + 900]], s < 0 ? PAPERWALL : shd(PAPERWALL, .12), 1);
    for (let i = 0; i < 40; i++) { // small brown wallpaper pattern, thinning toward the back
      const k = hash(i + (s < 0 ? 0 : 99)), yy = hash(i + 7 + (s < 0 ? 0 : 50)), px = lerp(ex * .6 + bx * .4, bx, k), sp = lerp(1, .35, k);
      const top = lerp(-100, B.by0, k), bot = lerp(H + 300, B.by1, k), py = lerp(top, bot, yy);
      PN(starPts(px, py, 9 * sp, .45, 4), '#9C7A4E', { washOp: 150 });
    }
  }
  P([[B.bx0, B.by1], [B.bx1, B.by1], [W + 400, H + 900], [-400, H + 900]], LINO, 1);
  PN([[B.bx0 + 140, B.by1], [B.bx1 - 140, B.by1], [W / 2 + 220, H + 900], [W / 2 - 220, H + 900]], '#94694A', { washOp: 150 });  // worn path
  // back wall with the door
  P(rectPts(B.bx0, B.by0, B.bx1 - B.bx0, B.by1 - B.by0), shd(PAPERWALL, .05), 1);
  if (o.gap) doorGap(B.dx, B.dy + B.dh - 6, B.dw, 14, t, o.gap);
  door(B.dx, B.dy, B.dw, B.dh - (o.gap ? 8 : 0), { inside: true, ...(o.door || {}), key: 'hall' });
  // switch, coat hooks + jacket and scarf (left), mirror and kitchen doorway (right), shoe rack
  P(rectPts(B.dx - 70, B.dy + 360, 34, 50), '#ECE6D8', .5);
  P([[60, 520], [200, 560], [205, 640], [62, 610]], '#3A3328', .8);
  P([[90, 600], [175, 615], [195, 980], [150, 1010], [70, 960]], '#2E3640', 1);   // jacket
  P([[150, 610], [190, 625], [175, 900], [150, 905]], '#8E2E34', .7);           // scarf
  P(ellPts(915, 760, 70, 92, 20), '#B9C6CC', 1); PN(ellPts(895, 735, 22, 40, 10, 0, .4), '#E8F0F2', { washOp: 160 });
  P([[835, 900], [1000, 860], [1000, 1560], [835, 1400]], '#1A1614', 1);        // kitchen doorway
  P([[20, 1500], [250, 1420], [250, 1470], [20, 1560]], '#6E4A30', .8);         // shoe rack
  P(ellPts(110, 1505, 55, 18, 10), '#1E1E24', .6); P(ellPts(190, 1470, 50, 16, 10), '#2E2E36', .6);
  if (o.stool) stool(o.stool.x, o.stool.y, o.stool.s || 160);
  return B;
}

// ---------- bedroom at night ----------
function bedroom(t, o = {}) {
  boilSeed('bed');
  bgFill('#2B2C38');
  // window with thin curtains and concrete blocks outside
  P(rectPts(560, 300, 400, 640), '#C9C2B0', 1);
  PN(rectPts(585, 325, 350, 590), '#16283A');
  for (let i = 0; i < 3; i++) for (let k = 0; k < 4; k++) PN(rectPts(610 + i * 110, 600 + k * 70, 60, 30), hash(i * 7 + k) > .7 ? '#E8C26A' : '#26394A');
  glow(860, 420, 70, '#DDE8FF', .35);
  P([[560, 290], [690, 290], [650, 960], [560, 970]], '#7E8CA0', .7, { washOp: 170 });
  P([[960, 290], [840, 290], [880, 960], [960, 970]], '#7E8CA0', .7, { washOp: 170 });
  // sofa-bed with a crumpled blanket and a sleeping shape
  P([[-100, 1160], [880, 1160], [900, 1420], [-100, 1420]], '#5A4A5E', 1);
  P([[-100, 1080], [700, 1050], [860, 1140], [820, 1240], [-100, 1260]], '#6A7A9A', 1);
  if (o.sleeper !== false) { head('dima', 160, 1080, 150, { v: .6, blink: 1, tilt: 1.3, shadowK: .8, key: 'sleep' }); }
  // bedside table
  P(rectPts(700, 1300, 380, 400), '#5E3E2C', 1);
  PN(rectPts(700, 1300, 380, 40), '#7A5238');
  return { clock: [870, 1240] };
}

// ---------- kitchen by day ----------
function kitchen(t, o = {}) {
  boilSeed('kit');
  bgFill('#E4D7B8');
  P(rectPts(380, 260, 520, 600), '#EDE6D4', 1); PN(rectPts(410, 290, 460, 540), '#CFE2E6');
  line([[640, 290], [640, 830]], 1); glow(640, 560, 260, '#FFF0C0', .5);
  P(rectPts(-60, 300, 300, 1100), '#E2E2DC', 1); P(rectPts(40, 520, 90, 120), '#F4EEDC', .5);  // fridge + photo
  head('dima', 85, 575, 60, { swk: .6, mouth: { smile: .3 }, key: 'photo' }); PN(rectPts(40, 600, 90, 40), '#5A6A88');
  // table with checked oilcloth
  P([[60, 1180], [1100, 1180], [1180, 1700], [-20, 1700]], '#E9E2D2', 1);
  for (let i = 0; i < 9; i++) line([[60 + i * 130, 1180], [-20 + i * 150, 1700]], .4, '#C06A5A', 'inkfine', 0);
  for (let k = 0; k < 4; k++) line([[40 - k * 20, 1240 + k * 130], [1120 + k * 20, 1240 + k * 130]], .4, '#C06A5A', 'inkfine', 0);
  return { table: 1180 };
}

// ---------- Semyonych's flat: carpet, ten clocks, dust in a beam ----------
function semApt(t, o = {}) {
  boilSeed('sem');
  bgFill('#5E5142');
  PN(rectPts(-400, 1450, W + 800, 900), '#4A3428');                         // floor
  P(rectPts(140, 420, 640, 800), '#8E2A2A', 1.2);                            // wall carpet
  for (let i = 0; i < 4; i++) line(rectPts(170 + i * 40, 450 + i * 40, 580 - i * 80, 740 - i * 80).concat([[170 + i * 40, 450 + i * 40]]), .6, i % 2 ? '#E2B46A' : '#2A3A6A', 'inkfine', 0);
  P(starPts(460, 820, 150, .5, 8), '#C88A3A', .8); P(starPts(460, 820, 70, .5, 8), '#2A3A6A', .6);
  const C = [[90, 250, 70, 0], [330, 300, 55, 1], [600, 270, 80, 2], [870, 330, 60, 1], [960, 640, 75, 3], [60, 760, 50, 4],
             [940, 1010, 48, 0], [250, 1290, 44, 2], [690, 1300, 52, 1], [460, 220, 40, 0]];
  for (const [x, y, r, k] of C) wallClock(x, y, r, k, o.hh ?? 3, o.mm ?? 0);
  // armchair with a knitted blanket, cabinet edge
  P([[-60, 1240], [260, 1220], [300, 1700], [-60, 1720]], '#5A4232', 1);
  P([[20, 1260], [220, 1250], [240, 1500], [10, 1520]], '#B89A5A', .8);
  for (let i = 0; i < 5; i++) line([[20, 1290 + i * 45], [225, 1280 + i * 45]], .3, '#7A5A2A', 'inkfine', 0);
  P(rectPts(860, 1150, 400, 700), '#3E2A1E', 1);
  for (let i = 0; i < 3; i++) P(ellPts(940 + i * 70, 1240, 28, 34, 10), '#B9C6CC', .4);
  if (o.beam !== false) { glow(820, 520, 520, '#FFE6B0', .35); dust(t, 380, 300, 640, 1100, 46, '#FFF1C8', .5); }
}

// ---------- the courtyard from above ----------
function courtyard(t, o = {}) {
  boilSeed('yard');
  bgFill('#6E6C66');
  for (let i = 0; i < 5; i++) PN(rectPts(-400, 200 + i * 360, W + 800, 6), '#5E5C58');
  P([[-200, 1250], [420, 1180], [520, 1900], [-200, 2100]], '#5E7E46', 1);            // lawn
  P([[700, -200], [1300, -200], [1300, 520], [700, 520]], '#B8AEA0', 1);              // building edge
  for (let i = 0; i < 4; i++) P(ellPts(-40 + i * 150, 1500 + (i % 2) * 140, 130, 120, 16, 6), '#3E6A3A', 1);
  // truck, top view
  const tx = 420 + 30 * Math.sin(t * .1), ty = 520;
  P(rr(tx, ty, 300, 620, 30), '#DADAD4', 1.2); P(rr(tx + 20, ty + 640, 260, 190, 30), '#3A6A9A', 1.2);
  PN(rr(tx + 50, ty + 700, 200, 70, 14), '#1E2A3A');
  // boxes and the family carrying them (heads + shoulders from above)
  const fam = [[330, 1160, '#3A3A48', 1], [290, 1290, '#8A3A3A', .9], [200, 1080, '#F3C232', .55]];
  fam.forEach(([x, y, col, sc], i) => {
    const bob = Math.sin(t * 4 + i) * 6;
    P(ellPts(x, y + bob, 46 * sc, 30 * sc, 12), col, .7);
    P(ellPts(x, y - 6 + bob, 22 * sc, 22 * sc, 10), i === 2 ? '#5A3A22' : '#2A2226', .6);
    if (i < 2) P(rectPts(x - 40 * sc, y - 70 * sc + bob, 80 * sc, 50 * sc), '#B8925A', .6);
  });
  for (let i = 0; i < 5; i++) P(rectPts(560 + (i % 3) * 70, 1200 + Math.floor(i / 3) * 80, 64, 64), '#C09A60', .7);
}

// ---------- the view through the peephole: a round fisheye cut out of black ----------
// draw() paints the landing as seen from the door; r = lens radius on screen
function peepView(t, cx, cy, r, draw) {
  push(); translate(cx, cy); scale(1); translate(-cx, -cy);
  draw();
  pop();
  // lens darkening toward the rim, then black outside
  flushLetters();
  irisShape(ellPts(cx, cy, r, r, 48), '#05080B');
  inkLine(ellPts(cx, cy, r * .97, r * .97, 48).concat([[cx + r * .97, cy]]), 6, '#05080B', 'dry', 0);
  PN(ellPts(cx - r * .35, cy - r * .45, r * .3, r * .1, 16, 0, -.5), '#FFFFFF', { washOp: 28 });
}
