// Part 5/5 — «Правило» (финал). The page says how to make it stop: warn the one who lives below you.
(() => {
  const PAGE = 'Оно отстанет, только если предупредишь того, кто живёт под тобой. Тогда оно пойдёт к нему. Прости, сынок. Я тоже не выдержал.';
  const SPLIT = 'Оно отстанет, только если предупредишь того, кто живёт под тобой.'.length / PAGE.length;

  // 1 · the page on the floor by the door; his hand picks it up
  function s1(t, lt, dur) {
    setLight('dawn', .2);
    const pick = ease(seg(lt, V(.15), V(.55)));
    camBegin(540, lerp(1250, 1100, pick), 1.25);
    bgFill('#3A2A22');
    P(rectPts(-400, -400, W + 800, 1240), '#5A3A26', 1); PN(rectPts(-400, 820, W + 800, 30), '#140F0C');
    P([[-400, 850], [W + 400, 850], [W + 800, H + 800], [-800, H + 800]], LINO, 1);
    notePaper(540, lerp(1290, 1050, pick), 820, 520, 'Корнеевы — открыли\nЛюба — открыла\nДима, кв. 32 —', { torn: true, rot: lerp(.04, -.05, pick), size: 64, lh: 1.25, key: 'p1' });
    const hx = lerp(1300, 900, ease(seg(lt, 0, V(.15)))), hy = lerp(1700, 1250, ease(seg(lt, 0, V(.15)))) - pick * 240;
    P(ribbon([[hx + 400, hy + 700], [hx + 150, hy + 250], [hx, hy]], 170, 130), CHAR.dima.top, 1.1);
    P(ellPts(hx - 10, hy - 20, 70, 80, 14), CHAR.dima.skin, 1);
    camEnd();
    capAt('На странице — имя Димы', lt, V(.3), dur - .2, 430, 84);
    fadeIn(lt, .4); fadeOut(lt, dur, .3);
  }

  // 2 · higher up, Semyonych's handwriting appears line by line
  function s2(t, lt, dur) {
    setLight('day', .14);
    camBegin(540, 960, 1.03 + .01 * lt);
    bgFill('#E9E2D2');
    notePaper(540, 960, 960, 1100, PAGE, { torn: true, rot: -.02, size: 84, lh: 1.25, margin: true, reveal: lerp(0, SPLIT, seg(lt, V(.05), V(.95))), key: 'p2', col: '#1C2358' });
    camEnd();
    seams(lt, dur);
  }

  // 3 · the last lines: "Прости, сынок"
  function s3(t, lt, dur) {
    setLight('day', .14);
    const hit = V(.45);
    camBegin(540, lerp(960, 1180, ease(seg(lt, hit - .3, hit + .4))), lerp(1.03, 1.35, ease(seg(lt, hit - .3, hit + .4))));
    bgFill('#E9E2D2');
    notePaper(540, 960, 960, 1100, PAGE, { torn: true, rot: -.02, size: 84, lh: 1.25, margin: true, reveal: lerp(SPLIT, 1, seg(lt, V(0), V(.9))), key: 'p2', col: '#1C2358' });
    camEnd();
    capAt('«Прости, сынок»', lt, hit, dur - .2, 430, 92);
    seams(lt, dur);
  }

  // 4 · he slides to the floor; the page drops from his fingers
  function s4(t, lt, dur) {
    setLight('day', .2);
    camBegin(540, 1200, 1.3);
    hallway(t, {});
    const s = 165, sit = ease(seg(lt, .4, 2.2)), drop = seg(lt, V(.55), V(.55) + 1.2);
    person('dima', 470, lerp(standY(CHAR.dima, 1500, s), 1430, sit), s, { v: .2 * sit, key: 'd4',
      legs: { lL: [lerp(0, 1.6, sit), lerp(0, -1.4, sit)], lR: [lerp(0, 1.4, sit), lerp(0, -1.5, sit)] },
      arms: { aL: [lerp(.1, .5, sit), .3], aR: [lerp(.3, .9, sit), lerp(.6, .4, sit)] }, handR: drop > 0 ? 'open' : 'grip',
      h: { t: lt, look: [.2, .8], eo: .55, brow: .6, blink: blinkAt(lt, 3, 5), tilt: .15 * sit } });
    if (drop > 0) { const p = arcPt([700, 1350], [820, 1780], -60, drop); notePaper(p[0], p[1], 240, 160, '', { torn: true, rot: lerp(0, 1.2, drop) + Math.sin(drop * 10) * .2, key: 'p4' }); }
    camEnd();
    seams(lt, dur);
  }

  // 5 · the courtyard from above: a truck, boxes, a family moving in — and a girl in a yellow raincoat
  function s5(t, lt, dur) {
    setLight('day');
    camBegin(lerp(500, 330, ease(seg(lt, 1, dur))), lerp(1000, 1100, ease(seg(lt, 1, dur))), lerp(1.0, 1.8, ease(seg(lt, 1, dur))));
    courtyard(t);
    camEnd();
    seams(lt, dur);
  }

  // 6 · Dima at the window, looking down; half his face in shadow
  function s6(t, lt, dur) {
    setLight('day', .25);
    camBegin(540, 960, 1.0 + .02 * lt);
    bgFill('#4A4440');
    P(rectPts(600, 200, 560, 1300), '#E8E2D2', 1); PN(rectPts(630, 230, 500, 1240), '#CFE0E4'); glow(860, 700, 520, '#FFF0C8', .6);
    P(ribbon([[440, 1300], [420, 1600], [400, 2000]], 480, 620), CHAR.dima.top, 1.4);
    P(rectPts(380, 1200, 120, 200), CHAR.dima.skin, 1);
    head('dima', 440, 980, 600, { t: lt, v: .45, tilt: .18, look: [.8, .9], eo: .65, brow: lerp(.3, -.4, seg(lt, V(.5), V(.8))), blink: blinkAt(lt, 4, 4.5), shadowK: .95 });
    camEnd();
    seams(lt, dur);
  }

  // 7 · his feet go down the stairs; the yellow bulb flickers
  function s7(t, lt, dur) {
    setLight('dusk');
    const fl = bulbFlicker(lt);
    camBegin(540, 1250, 1.4);
    stairwell(t, { line: 900, floor: 1700, stairs: 'left', stairX: 1000, bulb: { x: 780, y: 700, on: fl } });
    // he walks down the flight, top-left to bottom-right, feet on the treads
    const k = ease(seg(lt, .2, dur - .2)), stepF = lerp(8, 0, k), gx = 1000 - stepF * 62 + 30, gy = 1700 - Math.ceil(stepF) * 70 + 70 * frac(-stepF) * 0;
    const wp = walkPose(lt * 6.5), s = 130;
    person('dima', gx, standY(CHAR.dima, gy, s) - wp.bob * s, s, { v: .6, key: 'd7', arms: { aL: wp.aL, aR: wp.aR }, legs: { lL: wp.lL, lR: wp.lR },
      h: { t: lt, look: [.5, .5], eo: .7, brow: -.2, blink: blinkAt(lt, 7), shadowK: .8 } });
    camEnd();

    seams(lt, dur);
  }

  // 8 · door 28: his fist knocks. Three. Pause. Three.
  function s8(t, lt, dur) {
    setLight('dusk');
    const kt = V(.12), kts = knockTimes(kt, .3, .8), kv = knocks(lt, kt, .3, .8);
    camBegin(540, 1000, 1.2);
    stairwell(t, { line: 950, floor: 1700, doors: [{ x: 300, num: '28', w: 480, h: 1000, jolt: kv * .3 }], bulb: { x: 150, y: 420, on: bulbFlicker(lt + 3) } });
    // the fist: pulls back, strikes on each knock time
    let pull = 1; for (const k of kts) { const a = lt - k; if (a > -.15 && a < .15) pull = Math.min(pull, Math.abs(a) / .15); }
    const fx = 700, fy = 820, back = 90 * pull;
    P(ribbon([[fx + 600, fy + 700], [fx + 300 + back, fy + 260], [fx + back, fy]], 170, 130), CHAR.dima.top, 1.2);
    handAt('dima', fx + back, fy, Math.PI + .5, 700, 'fist', false, 1.1);
    camEnd();
    seams(lt, dur);
  }

  // 9 · the door opens: Olya looks up at him; he crouches to her height
  function s9(t, lt, dur) {
    setLight('dusk');
    const open = ease(seg(lt, .2, V(.3))), crouch = ease(seg(lt, V(.4), V(.4) + 1));
    camBegin(540, 1150, 1.25);
    stairwell(t, { line: 950, floor: 1700 });
    P(rectPts(80, 690, 540, 1010), '#1E1A18', 1);                                // doorway
    glow(350, 1200, 400, '#FFD08A', .55 * open);
    door(80 + 0, 690, 540 * (1 - .75 * open), 1010, { inside: false, num: '28', key: 'd28' });
    const s = 120;
    if (open > .2) person('olya', 300, standY(CHAR.olya, 1700, s), s, { v: .3, key: 'olya', hs: 1.15,
      h: { t: lt, look: [.7, -.9], eo: 1.05, brow: .4, blink: blinkAt(lt, 11), mouth: {} } });
    person('dima', 800, lerp(standY(CHAR.dima, 1710, 130), 1600, crouch), 130, { v: -.5, flip: true, key: 'dd',
      legs: { lL: [lerp(0, 1.9, crouch), lerp(0, -2.4, crouch)], lR: [lerp(0, 1.4, crouch), lerp(0, -2.2, crouch)] },
      arms: { aL: [lerp(.1, .9, crouch), .5], aR: [lerp(.1, .8, crouch), .6] },
      h: { t: lt, look: [-.8, .4 * crouch], eo: .9, mouth: { smile: .4 * crouch }, blink: blinkAt(lt, 13) } });
    camEnd();
    seams(lt, dur);
  }

  // 10 · close on Dima: he smiles; eyes wide, never blinking. "Если я постучу ночью — не открывай." Fade.
  function s10(t, lt, dur) {
    setLight('dusk', .35);
    const end = dur - .2;
    camBegin(540, lerp(980, 940, lt / dur), lerp(1.0, 1.45, ease(lt / dur)));
    bgFill('#3A3A42');
    glow(250, 600, 500, '#FFD08A', .3);
    P(ribbon([[540, 1300], [520, 1600], [500, 2000]], 470, 600), CHAR.dima.top, 1.4);
    P(rectPts(480, 1200, 120, 200), CHAR.dima.skin, 1);
    const smile = ease(seg(lt, .3, 1.3));
    head('dima', 540, 980, 600, { t: lt, v: -.15, look: [-.2, .35], eo: lerp(1, 1.35, smile), pupil: lerp(1, .5, smile), brow: .3, blink: 0, shadowK: .75,
      mouth: { smile: .9 * smile, open: .1 * smile + talk(lt, V(.55), V(1), .3), w: .14 } });
    camEnd();
    capAt('«Если я постучу ночью — не открывай»', lt, V(.6), end - 1.1, 1500, 76);
    if (lt > end - 1.4) { flushLetters(); flash(ease(seg(lt, end - 1.4, end - .6)), BLACK); caption('Конец · Завтра — новая история «Десятый этаж»', clamp((lt - (end - .9)) / .3), H * .47, 70, '#F2E6CC'); }
    fadeIn(lt, .3);
  }

  partShots(5, [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]);
})();
