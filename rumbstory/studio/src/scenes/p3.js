// Part 3/5 — «Дневник». Mum calls from home; upstairs, ten stopped clocks and a notebook of everyone who opened.
(() => {
  const lightMix = (a, b, k) => { LIGHT = { col: mixCol(LIGHTS[a].col, LIGHTS[b].col, k), k: lerp(LIGHTS[a].k, LIGHTS[b].k, k) }; };

  // 1 · the latch, half turned; a heartbeat in the camera
  function s1(t, lt, dur) {
    setLight('dark');
    const beat = Math.exp(-frac(lt * 1.25) * 7) + .6 * Math.exp(-frac(lt * 1.25 - .22) * 9);
    camBegin(540, 900, 1.05 + .025 * beat + .01 * lt);
    bgFill(LEATHER);
    for (let i = -4; i < 8; i++) line([[-200, i * 300], [1300, i * 300 + 1500]], 1, '#3A1E14', 'ink', 0);
    latchClose(540, 900, 520, .55 + .05 * ease(seg(lt, V(.5), V(.8))));
    camEnd();
    capAt('Он начал открывать', lt, .3, dur - .2, 1460, 84);
    fadeIn(lt, .25); fadeOut(lt, dur, .2);
  }

  // 2 · in his other hand the phone lights up: Mum calling
  function s2(t, lt, dur) {
    setLight('dark');
    const ring = lt > V(.25), buzz = ring ? Math.sin(lt * 60) * 4 * (frac(lt * 1.2) < .5 ? 1 : 0) : 0;
    camBegin(540, 1000, 1.45);
    hallway(t, { gap: { col: '#FFC870', a: .7, feet: 1 }, door: { latch: .55 } });
    camEnd();
    const s = 720, x = 540 + buzz, y = 1050;
    P(ribbon([[x + s * .2, H + 300], [x + s * .1, y + s * .9], [x, y + s * .45]], s * .42, s * .34), CHAR.dima.top, 1.4);
    P(ellPts(x, y + s * .42, s * .3, s * .26, 14), CHAR.dima.skin, 1.2);
    phone(x, y, s, { screen: ring ? 'call' : 'off', glowA: ring ? .7 : 0 });
    capAt('Звонит мама', lt, V(.5), dur - .2, 430, 92);
    seams(lt, dur);
  }

  // 3 · phone to his ear; under the door the shadow of two feet goes still
  function s3(t, lt, dur) {
    setLight('dark');
    camBegin(560, 1060, 1.3 + .015 * lt);
    hallway(t, { gap: { col: '#FFC870', a: .7, feet: 1, feetDx: Math.sin(Math.min(lt, V(.5)) * 3) * 8 } });
    const s = 165, whisper = lt > V(.62);
    person('dima', 760, standY(CHAR.dima, 1950, s), s, { v: -.35, flip: true, key: 'd3',
      arms: { aL: [.05, .1], aR: [.35, 2.75] }, handR: 'grip',
      prop: { hand: 1, draw: (hx, hy, a) => P(place([[-.55, -.22], [.55, -.22], [.55, .22], [-.55, .22]], hx, hy - 10, 120, a + Math.PI / 2), '#16171C', .7) },
      h: { t: lt, look: whisper ? [-.9, .3] : [-.3, 0], eo: whisper ? 1.3 : .9, pupil: whisper ? .6 : 1, brow: whisper ? .8 : .2, blink: whisper ? 0 : blinkAt(lt, 2), mouth: { open: whisper ? .25 : 0 } } });
    camEnd();
    seams(lt, dur);
  }

  // 4 · he snaps the lock back and slides down the door to the floor; the window greys toward 04:00
  function s4(t, lt, dur) {
    const dawn = ease(seg(lt, V(.35), dur - .2));
    lightMix('dark', 'dawn', dawn * .55);
    camBegin(540, 1250, 1.25);
    hallway(t, { door: { latch: lerp(.55, 0, ease(seg(lt, .2, .5))) } });
    const s = 165, slide = ease(seg(lt, .7, 2.0)), hipY = lerp(standY(CHAR.dima, 1500, s), 1430, slide);
    person('dima', 540, hipY, s, { v: .25 * slide, key: 'd4',
      legs: { lL: [lerp(0, 2.1, slide), lerp(0, -2.5, slide)], lR: [lerp(0, 1.9, slide), lerp(0, -2.3, slide)] },
      arms: { aL: [lerp(.1, 1.1, slide), lerp(.1, 1.2, slide)], aR: [lerp(.1, 1.0, slide), lerp(.1, 1.3, slide)] },
      h: { t: lt, look: [0, .3], eo: lerp(1, .6, dawn), brow: .5, blink: blinkAt(lt, 8), tilt: .1 * slide } });
    camEnd();
    capAt('04:00', lt, V(.6), dur - .2, 430, 110);
    seams(lt, dur);
  }

  // 5 · by day, the ninth floor: the key fits the sealed door
  function s5(t, lt, dur) {
    setLight('day');
    camBegin(520, 1080, 1.3);
    stairwell(t, { line: 950, floor: 1650, doors: [{ x: 160, num: '36', seal: true, w: 330, h: 660 }], window: { x: 900, y: 560, pigeon: false } });
    const s = 130, turnK = ease(seg(lt, V(.55), V(.7)));
    person('dima', 760, standY(CHAR.dima, 1660, s), s, { v: -.6, flip: true, key: 'd5',
      arms: { aL: [.1, .1], aR: [1.45, .15] }, handR: 'grip',
      prop: { hand: 1, draw: (hx, hy) => oldKey(hx - 10, hy, 70, Math.PI + turnK * 1.2) },
      h: { t: lt, look: [-.6, .1], eo: .85, brow: -.3, blink: blinkAt(lt, 5) } });
    camEnd();
    seams(lt, dur);
  }

  // 6 · inside: dust in the light, and ten clocks stopped at three
  function s6(t, lt, dur) {
    setLight('day', .2);
    camBegin(lerp(540, 520, lt / dur), lerp(900, 860, lt / dur), 1.0 + .03 * lt);
    semApt(t, {});
    camEnd();
    capAt('Все часы стояли на трёх', lt, V(.5), dur - .2, 1460, 82);
    seams(lt, dur, .45, .3);
  }

  // 7 · the desk by the window; a thick notebook; on the cover, Dima's flat number
  function s7(t, lt, dur) {
    setLight('day', .18);
    camBegin(540, lerp(1000, 1080, ease(lt / dur)), lerp(1.0, 1.5, ease(lt / dur)));
    bgFill('#6A5C4C');
    P(rectPts(140, 120, 800, 760), '#E8E2D2', 1.2); PN(rectPts(170, 150, 740, 700), '#CFE0E4');
    glow(540, 500, 380, '#FFF0C8', .55);
    for (let i = 0; i < 18; i++) line([[150 + i * 44, 140], [160 + i * 44 + 20 * Math.sin(i), 860]], .4, '#F6F0E0', 'inkfine', .3);  // lace
    P([[-60, 900], [1140, 900], [1200, 2000], [-120, 2000]], '#5A3A26', 1.2);
    for (let i = 0; i < 3; i++) { const bx = 790 + i * 70; P(rr(bx, 760 + i * 10, 52, 150, 12), ['#7A5A3A', '#3A5A7A', '#E8E2D2'][i], .6); P(rectPts(bx + 10, 740 + i * 10, 32, 26), '#E8E2D2', .4); }
    notebook(500, 1180, 520, 680, { cover: 'Кв. 32', rot: -.06 });
    camEnd();
    capAt('Кв. 32', lt, V(.55), dur - .2, 430, 110);
    seams(lt, dur);
  }

  // 8 · the pages: a list of years and names, each one "opened"; two lines light up as he reads
  function s8(t, lt, dur) {
    setLight('day', .12);
    const hiA = seg(lt, V(0), V(.12)) * (1 - seg(lt, V(.5), V(.56))), hiB = seg(lt, V(.52), V(.62));
    camBegin(540, 980 + 30 * Math.sin(lt * .3), 1.02);
    bgFill('#5A3A26');
    const lines = [['1979 — Гусевы. Открыли', '1987 — Люба. Открыла', '1993 — Тимур. Открыл'], ['2004 — Корнеевы. Открыли', '2011 — Аня. Открыла', '2019 — Шумилин. Открыл']];
    const pageW = 480, pageH = 900, rows = [-.25, -.02, .21];
    // highlights first (under the ink): a warm marker band behind the line being read
    notebook(540, 980, pageW, pageH, { open: true });
    if (hiA > 0) glow(300, 980 + rows[1] * pageH, 200, '#FFD873', .9 * hiA);
    if (hiB > 0) glow(780, 980 + rows[0] * pageH, 200, '#FFD873', .9 * hiB);
    lines.forEach((col, ci) => col.forEach((txt, r) => hand(txt.replace(' — ', ' —\n'), (ci ? 560 : 80) + 20, 980 + rows[r] * pageH - 30, 52, BLUEINK, { shaky: true, lh: 1.05 })));
    camEnd();
    seams(lt, dur);
  }

  // 9 · he flips to the end: the last page is torn out
  function s9(t, lt, dur) {
    setLight('day', .12);
    const flip = ease(seg(lt, .3, 1.3));
    camBegin(560, 980, lerp(1.02, 1.35, ease(seg(lt, 1.3, dur))));
    bgFill('#5A3A26');
    notebook(540, 980, 480, 900, { open: true, tornRight: flip > .55 });
    if (flip < 1) { // a page swinging over the spine
      const w = 480 * Math.cos(flip * Math.PI), x0 = 540;
      P([[x0, 530], [x0 + w, 530 + 30 * Math.sin(flip * Math.PI)], [x0 + w, 1430 - 30 * Math.sin(flip * Math.PI)], [x0, 1430]], PAPER, .8);
    }
    P(ribbon([[1250, 1700], [980, 1330], [lerp(1000, 640, flip), 1180]], 120, 80), CHAR.dima.top, 1);
    P(ellPts(lerp(1000, 640, flip), 1150, 60, 70, 12), CHAR.dima.skin, .9);
    camEnd();
    capAt('Последняя страница вырвана', lt, V(.55), dur - .2, 1480, 76);
    seams(lt, dur);
  }

  // 10 · knocks — on THIS door, from outside. He spins round. His voice, kindly. Black.
  function s10(t, lt, dur) {
    setLight('day', .3);
    const hold = 1.6, end = dur - hold, kt = V(.12), kv = knocks(lt, kt, .3, .8), turn = ease(seg(lt, kt + .15, kt + .45));
    const sh = shakeXY(lt, 14 * kv + (lt > V(.5) ? 4 : 0));
    camBegin(540 + sh[0], 1000 + sh[1], 1.15 + .02 * lt);
    semApt(t, { beam: false });
    door(-240, 380, 520, 1300, { inside: true, jolt: kv, key: 'semdoor', frame: '#2A1E18' });
    P(ribbon([[640, 1300], [600, 1500], [560, 1950]], 420, 520), CHAR.dima.top, 1.4);
    P(rectPts(580, 1200, 120, 200), CHAR.dima.skin, 1);
    head('dima', 640, 1080, 470, { t: lt, v: lerp(.55, -.55, turn), look: [lerp(.4, -1, turn), 0], eo: lerp(.9, 1.35, turn), pupil: lerp(1, .55, turn), brow: lerp(0, 1, turn), blink: 0, mouth: { open: .2 * turn } });
    camEnd();
    capAt('«Это его голос»', lt, V(.55), end - .05, 1500, 84);
    fadeIn(lt, .2);
    endCard(lt, dur, 'Часть 4 — завтра', hold);
  }

  partShots(3, [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]);
})();
