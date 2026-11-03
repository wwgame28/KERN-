// Part 2/5 — «Конверт». A key, a note, and the second night: the voice behind the door is Mum's.
(() => {
  // shared: a phone held low in the frame by Dima's hand (screen content from phone())
  function heldPhone(x, y, s, o) {
    P(ribbon([[x + s * .2, H + 300], [x + s * .1, y + s * .9], [x, y + s * .45]], s * .42, s * .34), CHAR.dima.top, swOf(s));
    P(ellPts(x, y + s * .42, s * .3, s * .26, 14), CHAR.dima.skin, swOf(s) * .8);
    phone(x, y, s, o);
    P(ribbon([[x + s * .32, y + s * .5], [x + s * .3, y + s * .25], [x + s * .24, y + s * .1]], s * .1, s * .08), CHAR.dima.skin, swOf(s) * .7);
  }
  // shared: the dark hallway seen from the stool, door at the end
  function nightHall(t, lt, o = {}) { setLight('dark', o.k); return hallway(t, { gap: { col: '#FFC870', a: .7, feet: o.feet || 0 }, door: { jolt: o.jolt || 0, latch: o.latch || 0 } }); }

  // 1 · the envelope's back, the date, the camera pulls away
  function s1(t, lt, dur) {
    setLight('day');
    camBegin(lerp(690, 540, ease(seg(lt, 0, 2.2))), lerp(1010, 960, ease(seg(lt, 0, 2.2))), lerp(2.6, 1.1, ease(seg(lt, 0, 2.6))));
    bgFill('#3C5A48'); PN(rectPts(-400, 1200, W + 800, 1200), '#2F4A3A');
    for (const d of [-1, 1]) { const hx = 540 + d * 245;
      P(ribbon([[hx + d * 160, 1950], [hx + d * 70, 1500], [hx + d * 10, 1200]], 170, 140), CHAR.dima.top, 1.1);
      P(ellPts(hx, 1130, 80, 95, 16), CHAR.dima.skin, 1); }
    envelope(540, 900, 330, { to: '', date: '3 ноября' });
    for (const d of [-1, 1]) { const hx = 540 + d * 245; P(ribbon([[hx + d * 30, 1150], [hx + d * 10, 1080], [hx - d * 12, 1035]], 52, 40), CHAR.dima.skin, .9); }
    camEnd();
    capAt('Письмо от мертвеца — с сегодняшней датой', lt, .7, dur - .2, 1440, 72);
    fadeIn(lt, .35); fadeOut(lt, dur, .3);
  }

  // 2 · the kitchen table: he tears it open; an old key and a checked page fall out
  function s2(t, lt, dur) {
    setLight('day');
    camBegin(540, 1180, 1.25 + .01 * lt);
    kitchen(t);
    const tear = V(.1), fall = V(.25);
    // the envelope held above the table, tipping
    const tip = ease(seg(lt, fall - .3, fall + .2));
    for (const d of [-1, 1]) P(ribbon([[540 + d * 420, 1950], [540 + d * 300, 1500], [540 + d * 210, 1000]], 150, 120), CHAR.dima.top, 1);
    envelope(540, 900 - tip * 40, 300, { back: true, torn: lt > tear, rot: -tip * .5 });
    for (const d of [-1, 1]) P(ellPts(540 + d * 200, 990 - tip * 40 * (d > 0 ? 1.5 : .5), 60, 72, 14), CHAR.dima.skin, .9);
    // key and note fall on arcs and land
    const kk = seg(lt, fall, fall + .45), nk = seg(lt, fall + .15, fall + 1.1);
    if (kk > 0) { const p = arcPt([480, 880], [380, 1400], -60, easeIn(kk)); oldKey(p[0], p[1] - (kk >= 1 ? 30 * Math.abs(spring(lt, fall + .45, 8, 30)) : 0), 110, lerp(-.5, .35, kk)); }
    if (nk > 0) { const p = arcPt([560, 880], [640, 1420], 40, nk); notePaper(p[0], p[1], 360, 240, '', { rot: lerp(-.6, .12, nk) + Math.sin(nk * 9) * .15 * (1 - nk), key: 'n2' }); }
    camEnd();
    seams(lt, dur);
  }

  // 3 · the note, close: the shaky lines appear one by one
  function s3(t, lt, dur) {
    setLight('day', .14);
    camBegin(540, 940 + 10 * Math.sin(lt * .4), 1.04 + .01 * lt);
    bgFill('#E9E2D2');
    notePaper(540, 940, 940, 760, 'Оно ходит три ночи. Говорит голосами тех, кого любишь. Не открывай. Ни разу.',
      { rot: -.03, reveal: seg(lt, V(0), V(.92)), size: 92, lh: 1.2, margin: true, key: 'n3', col: '#1C2358' });
    camEnd();
    seams(lt, dur);
  }

  // 4 · Dima turns the key in his fingers and looks up at the ceiling (upstairs)
  function s4(t, lt, dur) {
    setLight('day');
    camBegin(540, 900, 1.0);
    kitchen(t);
    const s = 230, up = ease(seg(lt, V(.3), V(.45)));
    person('dima', 520, 1420, s, { v: .15, key: 'd4', noLegs: true,
      arms: { aL: [-.1, .2], aR: [.6, 2.3] }, handR: 'grip',
      prop: { hand: 1, draw: (hx, hy) => oldKey(hx - 10, hy - 30, 120, lt * 2.4) },
      h: { t: lt, look: [lerp(.3, 0, up), lerp(.2, -1, up)], tilt: -.12 * up, eo: lerp(.85, 1.05, up), brow: lerp(0, .6, up), mouth: {}, blink: blinkAt(lt, 7) } });
    camEnd();
    // the postscript, as the narrator reads it
    capAt('«Если не выдержишь — поднимись. Там поймёшь»', lt, V(.35), dur - .2, 1450, 66);
    seams(lt, dur);
  }

  // 5 · the second night: on the stool, cold tea in his hands, watching the door
  function s5(t, lt, dur) {
    camBegin(560, 1200, 1.1 + .015 * lt);
    nightHall(t, lt);
    const s = 150;
    stool(300, 1880, 200);
    person('dima', 300, 1690, s, { v: .55, key: 'd5',
      legs: { lL: [1.45, -1.45], lR: [1.35, -1.4] }, arms: { aL: [.75, 1.1], aR: [.85, 1.05] }, handL: 'grip', handR: 'grip',
      prop: { hand: 1, draw: (hx, hy) => mug(hx + 10, hy - 10, 70) },
      h: { t: lt, look: [.8, -.1], eo: .7, brow: -.2, blink: blinkAt(lt, 3, 5.5) } });
    camEnd();
    capAt('Ночь вторая', lt, .4, dur - .2, 430, 92);
    seams(lt, dur, .5, .3);
  }

  // 6 · 03:00 on the phone; the door jumps: three knocks, pause, three
  function s6(t, lt, dur) {
    const kt = V(.15), kv = knocks(lt, kt, .3, .9), sh = shakeXY(lt, 12 * kv);
    camBegin(540 + sh[0], 1000 + sh[1], 1.45);
    nightHall(t, lt, { jolt: kv });
    camEnd();
    heldPhone(560, 1250, 520, { screen: 'time', time: '03:00', glowA: .35 });
    capAt('03:00', lt, .3, V(.15), 430, 110);
    seams(lt, dur);
  }

  // 7 · through the peephole: nobody. Mum's voice, from nowhere
  function s7(t, lt, dur) {
    setLight('night');
    peepView(t, 540, 900, 470, () => {
      camBegin(540, 900, 1 + .02 * lt);
      stairwell(t, { line: 980, floor: 1420, bulb: { x: 540, y: 420, on: bulbFlicker(lt) }, doors: [{ x: 140, num: '31', w: 210, h: 440 }, { x: 760, num: '30', w: 210, h: 440 }] });
      camEnd();
    });
    capAt('«Мама живёт в другом городе»', lt, V(.72), dur - .2, 1450, 76);
    seams(lt, dur);
  }

  // 8 · he calls her: "Абонент недоступен"
  function s8(t, lt, dur) {
    camBegin(540, 1000, 1.45);
    nightHall(t, lt);
    camEnd();
    heldPhone(540, 1030, 720, { screen: lt < V(.1) ? 'call' : 'dead', glowA: .45 });
    seams(lt, dur);
  }

  // 9 · his hand drifts toward the latch
  function s9(t, lt, dur) {
    const k = ease(seg(lt, .3, dur - .2));
    camBegin(lerp(700, 820, k), lerp(1080, 1120, k), lerp(1.9, 2.4, k));
    nightHall(t, lt, { feet: 1 });
    // the arm comes from bottom-left toward the lock at (HALL.dx + .84 * dw, HALL.dy + .53 * dh)
    const lx = HALL.dx + HALL.dw * .84, ly = HALL.dy + HALL.dh * .53, hx = lerp(380, lx - 70, k), hy = lerp(1500, ly + 40, k);
    P(ribbon([[hx - 400, hy + 500], [hx - 160, hy + 150], [hx, hy]], 90, 70), CHAR.dima.top, .8);
    handAt('dima', hx, hy, -.7, 210, 'point', false, .7);
    camEnd();
    capAt('«Пончиком его звала только мама»', lt, V(.4), dur - .2, 1450, 70);
    seams(lt, dur);
  }

  // 10 · fingers turn the latch. Click. Black.
  function s10(t, lt, dur) {
    setLight('dark');
    const hold = 1.6, end = dur - hold, turnT = V(.55), k = ease(seg(lt, turnT - .5, turnT));
    const sh = shakeXY(lt, lt > turnT ? 16 * Math.exp(-(lt - turnT) * 6) : 0);
    camBegin(540 + sh[0], 900 + sh[1], 1 + .03 * lt);
    bgFill(LEATHER);
    for (let i = -4; i < 8; i++) line([[-200, i * 300], [1300, i * 300 + 1500]], 1, '#3A1E14', 'ink', 0);
    latchClose(540, 900, 520, k * .55);
    // thumb and finger pinching the bar, rotating with it
    const a = lerp(0, Math.PI / 2, k * .55), tip = place([[260, -40]], 540, 900, 1, a)[0], tip2 = place([[-260, 40]], 540, 900, 1, a)[0];
    P(ribbon([[tip[0] + 500, tip[1] + 700], [tip[0] + 220, tip[1] + 240], tip], 150, 110), CHAR.dima.skin, 1.2);
    P(ribbon([[tip2[0] + 300, tip2[1] + 900], [tip2[0] + 60, tip2[1] + 300], tip2], 140, 100), shd(CHAR.dima.skin, .2), 1.2);
    camEnd();
    smashBlack(lt, end + .02, .02);
    if (lt < end) fadeIn(lt, .3);
    endCard(lt, dur, 'Часть 3 — завтра', hold);
  }

  partShots(2, [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]);
})();
