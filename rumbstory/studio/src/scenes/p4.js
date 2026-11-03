// Part 4/5 — «Третья ночь». The dead man knocks on his own door; then, all night, it talks in Dima's voice.
(() => {
  // the hallway, third night: wardrobe pushed against the door, light off; Dima on the floor facing it
  function barricade(t, lt, o = {}) {
    setLight(o.light || 'dark', o.k);
    hallway(t, { gap: { col: '#FFC870', a: .75, feet: o.feet ?? 0, feetDx: o.feetDx || 0 } });
    const j = o.jolt || 0, jx = j * 10 * Math.sin(BOILN * 2.7);
    wardrobe(HALL.dx - 40 + jx, HALL.dy + HALL.dh + 6, HALL.dw + 80, 640);
  }
  // a cheap clock on the floor by him (screen space close-up)
  function floorClock(txt, a = 1) { alarmClock(540, 1210, 200, txt, { a }); }

  // 1 · Semyonych's door from inside; the peephole is dark; knocking
  function s1(t, lt, dur) {
    setLight('night');
    const kv = knocks(lt, V(.05), .3, .85, 3, 3), sh = shakeXY(lt, 10 * kv);
    camBegin(540 + sh[0], 960 + sh[1], 1.25);
    semApt(t, { beam: false });
    door(250, 380, 580, 1400, { inside: true, jolt: kv, key: 'semdoor', frame: '#2A1E18' });
    camEnd();
    capAt('Мёртвый сосед стучал в свою же дверь', lt, .4, dur - .2, 1460, 72);
    fadeIn(lt, .4); fadeOut(lt, dur, .3);
  }

  // 2 · the landing, empty: wet slipper prints going down. Then evening: the wardrobe against his door, light off
  function s2(t, lt, dur) {
    const cut = V(.5);
    if (lt < cut) {
      setLight('night');
      camBegin(540, 1250, 1.2 + .02 * lt);
      stairwell(t, { line: 950, floor: 1400, stairs: 'right', stairX: 560, bulb: { x: 300, y: 500, on: bulbFlicker(lt) }, doors: [{ x: 60, num: '36', seal: true, w: 280, h: 560 }] });
      for (let i = 0; i < 7; i++) { // prints: from the door, across, down the steps
        const k = i / 6, px = lerp(260, 900, k), py = i < 3 ? 1440 + 40 * (i % 2) : 1400 + (i - 2) * 70;
        PN(ellPts(px + (i % 2) * 30, py, 26, 13, 10, 0, .2), '#0E1A20', { washOp: 200 });
        glow(px + (i % 2) * 30 - 8, py - 4, 18, '#9FD6E8', .5);
      }
      camEnd();
    } else {
      const lt2 = lt - cut, off = lt2 > (dur - cut) * .6;
      setLight(off ? 'dark' : 'dusk');
      camBegin(540, 1150, 1.3);
      hallway(t, {});
      const push = ease(seg(lt2, 0, (dur - cut) * .5));
      wardrobe(lerp(-160, HALL.dx - 40, push), HALL.dy + HALL.dh + 6, HALL.dw + 80, 640);
      const s = 150;
      person('dima', lerp(-160, HALL.dx - 120, push) - 20, standY(CHAR.dima, 1620, s), s, { v: .6, lean: .25, key: 'd2',
        arms: { aL: [1.3, .2], aR: [1.4, .1] }, legs: { lL: [-.3, .2], lR: [.35, -.1] },
        h: { t: lt, look: [.8, 0], brow: -.5, eo: .8, mouth: { open: .15 } } });
      camEnd();
      capAt('Ночь третья', lt2, .3, dur - cut - .2, 430, 92);
      if (lt2 < .2) { flushLetters(); flash(1 - lt2 / .2, BLACK); }
    }
    seams(lt, dur);
  }

  // 3 · 03:00. Nothing.
  function s3(t, lt, dur) {
    camBegin(540, 1000, 1.0);
    barricade(t, lt);
    camEnd();
    floorClock('03:00');
    capAt('03:00', lt, .2, dur - .15, 430, 110);
    seams(lt, dur, .25, .2);
  }

  // 4 · 03:15 … 03:30. He doesn't take his eyes off the door
  function s4(t, lt, dur) {
    const half = V(.45), txt = lt < half ? '03:15' : '03:30';
    camBegin(540, 1000, 1.0 + .03 * lt);
    barricade(t, lt);
    camEnd();
    floorClock(txt);
    P(ribbon([[250, 1700], [240, 1850], [230, 2100]], 260, 330), CHAR.dima.top, 1); P(rectPts(225, 1660, 60, 90), CHAR.dima.skin, .7);
    head('dima', 260, 1560, 300, { t: lt, v: .55, look: [1, -.4], eo: .75, brow: -.3, blink: blinkAt(lt, 1, 6), shadowK: .8, key: 'h4' });
    capAt('03:15 · 03:30', lt, .2, dur - .15, 430, 100);
    seams(lt, dur, .2, .2);
  }

  // 5 · 03:33 — the wardrobe jumps with the knocks. And a voice
  function s5(t, lt, dur) {
    const kv = knocks(lt, V(.3), .3, .8), sh = shakeXY(lt, 12 * kv);
    camBegin(540 + sh[0], 1000 + sh[1], 1.05);
    barricade(t, lt, { jolt: kv, feet: 1 });
    camEnd();
    floorClock('03:33');
    capAt('03:33', lt, .2, dur - .15, 430, 110);
    seams(lt, dur, .2, .3);
  }

  // 6 · his face, close: he slowly raises his eyes to the door — it's his own voice
  function s6(t, lt, dur) {
    setLight('dark');
    const up = ease(seg(lt, .4, V(.45)));
    camBegin(540, 960, 1.0 + .03 * lt);
    bgFill('#151C22');
    glow(900, 1700, 520, '#FFC870', .25);
    P(ribbon([[540, 1300], [520, 1600], [500, 2000]], 470, 600), CHAR.dima.top, 1.4);
    P(rectPts(480, 1200, 120, 200), CHAR.dima.skin, 1);
    head('dima', 540, 980, 600, { t: lt, v: .2, tilt: lerp(.12, -.05, up), look: [lerp(0, .4, up), lerp(.9, -.7, up)], eo: lerp(.55, 1.25, up), pupil: lerp(1, .55, up), brow: lerp(-.3, .9, up), blink: 0, shadowK: .85, flipLight: true });
    camEnd();
    capAt('«Это был его собственный голос»', lt, V(.5), dur - .2, 1480, 76);
    seams(lt, dur);
  }

  // 7 · under the door the shadow shifts; the picture trembles
  function s7(t, lt, dur) {
    const sh = shakeXY(lt, 5 + 3 * Math.sin(lt * 2));
    camBegin(540 + sh[0], 1310 + sh[1], 2.2 + .03 * lt);
    barricade(t, lt, { feet: 1, feetDx: 40 * Math.sin(lt * 1.3) });
    camEnd();
    seams(lt, dur);
  }

  // 8 · on the wall, shadows from the gap crawl and stretch until dawn
  function s8(t, lt, dur) {
    setLight('dark');
    camBegin(540, 960, 1.0);
    bgFill(PAPERWALL);
    for (let i = 0; i < 40; i++) PN(starPts(-100 + hash(i) * 1300, -100 + hash(i + 4) * 2200, 12, .45, 4), '#9C7A4E', { washOp: 150 });
    glow(540, 1950, 900, '#FFC870', .45);
    for (let i = 0; i < 5; i++) { // long finger-like shadows, rising from the floor line
      const k = ease(seg(lt, .3 + i * .4, dur - .3)), bx = 120 + i * 210 + 40 * Math.sin(lt * .7 + i), top = lerp(1900, 500 + 120 * hash(i), k);
      PN([[bx - 60, 2000], [bx + 60, 2000], [bx + 30 + 60 * Math.sin(lt + i), top + 80], [bx + 10 * Math.sin(lt * 1.3 + i), top], [bx - 30 + 40 * Math.sin(lt + i * 2), top + 80]], '#0A0E12', { washOp: 220 });
    }
    camEnd();
    seams(lt, dur, .4, .4);
  }

  // 9 · a pink dawn in the window; Dima on the floor, arms round his knees
  function s9(t, lt, dur) {
    setLight('dawn', .3);
    camBegin(540, 1100, 1.15);
    bgFill('#BFA9A6');
    P(rectPts(560, 300, 420, 660), '#E9DCD0', 1); PN(rectPts(585, 325, 370, 610), '#F2B8A8');
    glow(770, 620, 420, '#FFD2B8', .7);
    P([[-200, 1450], [W + 200, 1450], [W + 400, H + 400], [-400, H + 400]], LINO, 1);
    const s = 160;
    person('dima', 420, 1430, s, { v: .55, key: 'd9', legs: { lL: [2.35, -2.75], lR: [2.25, -2.65] }, arms: { aL: [1.35, 1.6], aR: [1.45, 1.5] }, handL: 'grip', handR: 'grip',
      h: { t: lt, v: .3, look: [.6, .2], eo: .55, brow: .2, blink: blinkAt(lt, 6, 4), tilt: .1 } });
    camEnd();
    capAt('06:00', lt, .3, dur - .2, 1480, 110);
    seams(lt, dur);
  }

  // 10 · a torn page slides in under the door; push in on the last line: his name, the ink still wet
  function s10(t, lt, dur) {
    setLight('dawn', .25);
    const hold = 1.6, end = dur - hold, slideK = easeOut(seg(lt, .3, V(.3))), push = easeIn(seg(lt, V(.45), V(.9)));
    camBegin(lerp(540, 470, push), lerp(1250, 1330, push), lerp(1.2, 2.6, push));
    bgFill('#3A2A22');
    P(rectPts(-400, -400, W + 800, 1240), '#5A3A26', 1);                         // door bottom
    PN(rectPts(-400, 820, W + 800, 30), '#140F0C');                               // gap
    P([[-400, 850], [W + 400, 850], [W + 800, H + 800], [-800, H + 800]], LINO, 1); // floor
    const py = lerp(780, 1290, slideK);
    notePaper(540, py, 820, 520, 'Корнеевы — открыли\nЛюба — открыла\nДима, кв. 32 —', { torn: true, rot: .04, size: 64, lh: 1.25, key: 'p10' });
    if (slideK < 1) PN(rectPts(-400, 400, W + 800, 450), '#5A3A26');           // the door still hides the top part
    glow(330, 1440, 70, '#CFE8FF', .55 * push * (0.7 + .3 * Math.sin(lt * 6)));    // the wet ink glints
    camEnd();
    capAt('Внизу — имя Димы', lt, V(.6), end - .05, 1560, 84);
    fadeIn(lt, .3);
    endCard(lt, dur, 'Часть 5 — завтра', hold);
  }

  partShots(4, [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]);
})();
