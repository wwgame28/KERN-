// Part 1/5 — «Правило». A neighbour asks Dima never to open at night; a week later he knocks at 3:00, a week dead.
(() => {
  const DOORLIGHT = '#9FD6E8';

  // 1 · peephole close-up from the dark hallway, slow push
  function s1(t, lt, dur) {
    setLight('night');
    camBegin(540, 860, kf(lt, [[0, 1.02], [dur, 1.32]], x => x));
    door(-310, -40, 1700, 3000, { peep: false, inside: true, key: 's1', frame: '#2A1E18' });
    peepholeClose(540, 860, 150, { light: DOORLIGHT, lightA: .35 + .25 * wob(lt, .4) });
    camEnd();
    capAt('«Если я постучу ночью — не открывай»', lt, .5, dur - .2, 1330, 80);
    fadeIn(lt, .9); fadeOut(lt, dur, .3);
  }

  // 2 · stairwell by day: Semyonych grips Dima's sleeve, says it, and goes upstairs
  function s2(t, lt, dur) {
    setLight('day');
    const leave = V(.55), gone = leave + 2.2;
    camBegin(600 + 30 * Math.sin(lt * .3), 1180, 1.42 + .015 * lt);
    stairwell(t, { doors: [{ x: 930, num: '33', w: 300, h: 620 }], window: { x: 560, y: 640 }, stairs: 'left', stairX: 150, line: 1000, floor: 1650 });
    const s = 118, gy = 1660;
    // Dima, right, facing left: half-amused, then watches him go
    const dLook = lt > leave + .3 ? -.7 : -.5;
    person('dima', 760, standY(CHAR.dima, gy, s), s, { v: -.55, flip: true, key: 'd',
      arms: { aL: [.15, .35], aR: [-.05, .1] }, handR: 'fist',
      h: { t: lt, look: [dLook, 0], brow: .4, mouth: { smile: .25, smirk: .3 }, blink: blinkAt(lt, 2) } });
    // Semyonych, left, facing right, leaning in; then turns and walks off up the stairs (left)
    const k = ease(seg(lt, leave, gone)), x = lerp(470, -140, k), walking = lt > leave && lt < gone;
    const wp = walkPose(lt * 7, walking ? 1 : 0);
    person('sem', x, standY(CHAR.sem, gy, s) - (walking ? wp.bob * s : 0) - k * 120, s, {
      v: walking ? -.6 : .6, flip: walking, lean: walking ? .08 : .14, key: 's',
      arms: walking ? { aL: wp.aL, aR: wp.aR } : { aL: [-.05, .15], aR: [1.15, .25] }, handR: walking ? 'open' : 'grip',
      legs: walking ? { lL: wp.lL, lR: wp.lR } : {},
      prop: { hand: -1, draw: (hx, hy) => { P([[hx - 40, hy], [hx + 40, hy], [hx + 50, hy + 130], [hx - 50, hy + 130]], '#ECECEE', .5, { washOp: 220 });
        P(rr(hx - 25, hy - 40, 50, 80, 20), '#C8904E', .5); } },
      h: { t: lt, brow: -.6, eo: .9, look: walking ? [-.5, 0] : [.6, -.2], mouth: { open: talk(lt, V(0), V(.38), .55) }, blink: blinkAt(lt, 5) } });
    camEnd();
    seams(lt, dur);
  }

  // 3 · Dima's hallway: he shuts the door, leans on it, smirks and shakes his head; keys dangle
  function s3(t, lt, dur) {
    setLight('day');
    camBegin(540, 1130, 1.6 + .02 * lt);
    hallway(t, { door: { latch: 1 } });
    const s = 120, shake = lt > V(.15) && lt < V(.7) ? .28 * Math.sin((lt - V(.15)) * 7) : 0;
    person('dima', 540, standY(CHAR.dima, HALL.by1 + 260, s), s, { v: .1, lean: -.05, key: 'd3',
      arms: { aL: [-.25, -.3], aR: [.35, .9] }, handR: 'grip',
      prop: { hand: 1, draw: (hx, hy) => { const sw = Math.sin(lt * 5) * .3; line([[hx, hy], [hx + 20 * sw, hy + 50]], .6, '#B9B6AE');
        P(ellPts(hx + 20 * sw, hy + 70, 16, 22, 10), '#C9C4B6', .4); P(place([[0, 0], [60, 4], [60, 14], [0, 14]], hx + 16 * sw, hy + 72, 1, 1.2 + sw), '#B8933E', .4); } },
      h: { t: lt, v: shake, look: [shake * 2, -.4], eo: .85, mouth: { smile: .5, smirk: .5 }, brow: .3, blink: blinkAt(lt, 9) } });
    camEnd();
    seams(lt, dur);
  }

  // 4 · dark bedroom: the clock flips 02:59 → 03:00
  function s4(t, lt, dur) {
    setLight('dark');
    const flip = V(.55);
    camBegin(800, 1150, kf(lt, [[0, 1.5], [dur, 1.85]]));
    const b = bedroom(t);
    alarmClock(...b.clock, 130, lt < flip ? '02:59' : '03:00', { a: lt < flip ? .8 : 1 });
    camEnd();
    if (lt > flip) capAt('03:00', lt, flip + .05, dur - .15, 1460, 120);
    seams(lt, dur, .45, .3);
  }

  // 5 · the hallway in the dark: under the door, a light strip; two feet break it; three knocks, pause, three
  function s5(t, lt, dur) {
    setLight('dark');
    const kt = V(.32), kv = knocks(lt, kt, .3, .95), sh = shakeXY(lt, 10 * kv);
    camBegin(540 + sh[0], 1190 + sh[1], 1.55 + .02 * lt);
    hallway(t, { gap: { feet: seg(lt, .5, 1.6), col: '#FFC870', a: .9 }, door: { jolt: kv } });
    camEnd();
    seams(lt, dur);
  }

  // 6 · through the peephole: fisheye Semyonych on the landing, slippers, plaid shirt, smiling
  function s6(t, lt, dur) {
    setLight('night');
    peepView(t, 540, 900, 470, () => {
      camBegin(540, 900, 1 + .02 * lt);
      stairwell(t, { line: 980, floor: 1420, bulb: { x: 540, y: 420, on: .9 + .1 * wob(lt, 3) }, doors: [{ x: 140, num: '31', w: 210, h: 440 }, { x: 760, num: '30', w: 210, h: 440 }] });
      const s = 150;
      person('sem', 540, 1420 - CHAR.sem.legLen * s * .7, s, { hs: 1.65, key: 'pv', legs: { lL: [-.05, 0], lR: [.05, 0] },
        h: { t: lt, eo: 1.15, pupil: .7, look: [0, 0], mouth: { smile: .9, w: .14 }, brow: .3, blink: 0 } });
      camEnd();
    });
    seams(lt, dur);
  }

  // 7 · his face fills the lens: wide, unblinking; the whisper; a slight tremor
  function s7(t, lt, dur) {
    setLight('night');
    const sh = shakeXY(lt, 3 + 3 * seg(lt, V(.5), dur));
    peepView(t, 540, 900, 470, () => {
      camBegin(540 + sh[0], 900 + sh[1], 1 + .05 * lt);
      stairwell(t, { line: 980, floor: 1420, bulb: { x: 260, y: 360, on: 1 } });
      head('sem', 540, 930, 620, { t: lt, eo: 1.38, pupil: .4, look: [0, .05], brow: .5, blink: 0, shadowK: .7,
        mouth: { smile: .85, open: .15 + talk(lt, V(0), V(.36), .25), w: .15 } });
      camEnd();
    });
    capAt('«Он ни разу не моргнул»', lt, V(.6), dur - .2, 1450, 82);
    seams(lt, dur);
  }

  // 8 · the stairwell from the side at night: a long shadow slides down the steps, slowly
  function s8(t, lt, dur) {
    setLight('night');
    const fl = bulbFlicker(lt);
    camBegin(540, 980, 1.05);
    stairwell(t, { line: 900, floor: 1600, stairs: 'right', stairX: 420, bulb: { x: 300, y: 420, on: fl }, doors: [{ x: 60, num: '32', w: 260, h: 560 }] });
    // shadow: a hunched figure stretched along the treads, moving down-left
    const k = ease(seg(lt, .6, dur - .6)), sx = lerp(980, 380, k), sy = lerp(1000, 1560, k);
    PN([[sx - 40, sy], [sx + 40, sy - 20], [sx + 140, sy - 380], [sx + 120, sy - 470], [sx + 60, sy - 480], [sx + 30, sy - 380], [sx - 60, sy - 40]], '#0B1418', { washOp: 190 });
    PN(ellPts(sx + 95, sy - 520, 55, 60, 14), '#0B1418', { washOp: 190 });
    camEnd();
    seams(lt, dur, .3, .5);
  }

  // 9 · morning: a paper seal on Semyonych's door; Aunt Valya crosses herself
  function s9(t, lt, dur) {
    setLight('day');
    camBegin(560, 1000, 1.12 + .01 * lt);
    stairwell(t, { line: 900, floor: 1640, doors: [{ x: 120, num: '36', seal: true, w: 330, h: 660 }], window: { x: 820, y: 560, pigeon: false } });
    const s = 128, c = crossArm(lt, V(.25));
    person('valya', 690, standY(CHAR.valya, 1650, s), s, { v: -.35, flip: true, key: 'v',
      arms: { aL: [.1, .2], aR: c.arm }, handR: 'point',
      h: { t: lt, look: [-.6, 0], brow: .9, eo: .8, mouth: { open: talk(lt, V(.3), V(.98), .5, 3) }, blink: blinkAt(lt, 4), tilt: c.tilt } });
    camEnd();
    capAt('Печать', lt, .4, V(.35), 430, 96);
    seams(lt, dur);
  }

  // 10 · the envelope: "Диме, кв. 32"; he turns it over; a date in the corner; snap in; black
  function s10(t, lt, dur) {
    setLight('day');
    const hold = 1.6, end = dur - hold, flipA = V(.35), flipB = flipA + .45, snap = V(.82);
    const zoom = lt < snap ? 1 + .03 * lt : lerp(1, 2.9, easeOut(seg(lt, snap, snap + .35)));
    const fx = lt < snap ? 540 : lerp(540, 690, easeOut(seg(lt, snap, snap + .35))), fy = lt < snap ? 900 : lerp(900, 1010, easeOut(seg(lt, snap, snap + .35)));
    camBegin(fx, fy, zoom);
    bgFill('#3C5A48');
    PN(rectPts(-400, 1200, W + 800, 1200), '#2F4A3A');
    // Valya's hand gives it (from the right), Dima's hands take it (from below)
    const give = ease(seg(lt, 0, .9)), ex = lerp(760, 540, give);
    const fl = seg(lt, flipA, flipB), sx = Math.cos(fl * Math.PI), back = fl > .5;
    // under the envelope: sleeves and palms; over it: thumbs
    if (lt < flipA) { P(ribbon([[1250, 1100], [1050, 1010], [ex + 250, 930]], 150, 120), CHAR.valya.top, 1.1);
      P(ellPts(ex + 225, 905, 70, 85, 16), CHAR.valya.skin, 1); }
    for (const d of [-1, 1]) { const hx = ex + d * 245;
      P(ribbon([[hx + d * 160, 1950], [hx + d * 70, 1500], [hx + d * 10, 1200]], 170, 140), CHAR.dima.top, 1.1);
      P(ellPts(hx, 1130, 80, 95, 16), CHAR.dima.skin, 1); }
    push(); translate(ex, 900); scale(Math.max(.04, Math.abs(sx)), 1); translate(-ex, -900);
    envelope(ex, 900, 330, back ? { to: '', date: '3 ноября', dateA: 1 } : { to: Math.abs(sx) > .9 ? 'Диме, кв. 32' : '' });
    pop();
    if (back && Math.abs(sx) < .9) LETTERS = LETTERS.filter(Lt => !Lt.txt.includes('ноября'));
    if (back) LETTERS = LETTERS.filter(Lt => !Lt.txt.includes('Диме'));
    for (const d of [-1, 1]) { const hx = ex + d * 245;
      P(ribbon([[hx + d * 30, 1150], [hx + d * 10, 1080], [hx - d * 12, 1035]], 52, 40), CHAR.dima.skin, .9); }
    if (lt < flipA) P(ribbon([[ex + 250, 880], [ex + 205, 850], [ex + 160, 845]], 50, 38), CHAR.valya.skin, .9);
    camEnd();
    const sh = lt > snap ? shakeXY(lt, 14 * Math.exp(-(lt - snap - .35) * 5)) : [0, 0];
    capAt('Дата на конверте — сегодняшняя', lt, snap + .3, end - .05, 1460 + sh[1], 74);
    fadeIn(lt, .3);
    endCard(lt, dur, 'Часть 2 — завтра', hold);
  }

  partShots(1, [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]);
})();

// the stairwell bulb buzzes: mostly on, with dips
function bulbFlicker(t) { const f = Math.floor(t * 12); return hash(f) > .86 ? .35 + .3 * hash(f + 3) : .92 + .08 * Math.sin(t * 40); }
// crossing oneself: forehead → chest → right shoulder → left shoulder, starting at t0 (returns the right arm angles)
function crossArm(t, t0) {
  const k = seg(t, t0, t0 + 2.4);
  if (k <= 0 || k >= 1) return { arm: [.15, .2], tilt: 0 };
  const keys = [[0, [.2, .3]], [.18, [1.4, 2.5]], [.42, [.9, 2.3]], [.62, [.65, 2.1]], [.82, [1.05, 2.45]], [1, [.2, .3]]];
  return { arm: kf(k, keys), tilt: -.05 * Math.sin(k * Math.PI) };
}
