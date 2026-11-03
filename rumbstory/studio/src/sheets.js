// sheets.js: model sheets as standalone loops (?loop=heads, ?loop=people) for checking the characters.
LOOPS.heads = t => {
  setLight('day');
  paint(rectPts(-20, -20, W + 40, H + 40), { wash: '#D9D4C8', ink: null });
  const rows = [['dima', {}], ['dima', { v: .5, eo: 1.3, brow: 1, mouth: { open: .5 } }], ['sem', { mouth: { smile: .5 } }], ['sem', { v: -.4, eo: 1.35, pupil: .5, mouth: { open: .4, smile: 1 } }],
    ['valya', { brow: 1, mouth: { open: .3 } }], ['valya', { v: .5 }], ['olya', {}], ['olya', { v: -.5, mouth: { smile: .6 } }]];
  rows.forEach(([n, o], i) => head(n, 290 + (i % 2) * 500, 260 + Math.floor(i / 2) * 460, 330, { t, ...o, key: i }));
};
LOOPS.heads.len = 1;
LOOPS.people = t => {
  setLight('day');
  paint(rectPts(-20, -20, W + 40, H + 40), { wash: '#D9D4C8', ink: null });
  const g1 = 900, g2 = 1820;
  person('dima', 270, standY(CHAR.dima, g1, 115), 115, { key: 1 });
  person('sem', 780, standY(CHAR.sem, g1, 115), 115, { v: -.5, key: 2, arms: { aR: [.6, .8] }, handR: 'fist' });
  person('valya', 270, standY(CHAR.valya, g2, 115), 115, { v: .4, key: 3, arms: { aR: [1.2, 1.2] } });
  person('olya', 780, standY(CHAR.olya, g2, 115), 115, { key: 4 });
};
LOOPS.people.len = 1;
LOOPS.dbg = t => {
  setLight('day');
  paint(rectPts(-20, -20, W + 40, H + 40), { wash: '#D9D4C8', ink: null });
  P(ribbon([[300, 200], [330, 500], [300, 800]], 40, 30), '#7B788F', 1);
  P(ribbon([[450, 200], [452, 500], [454, 800]], 40, 30), '#7B788F', 1);
  P(ribbon([[600, 200], [600, 500], [600, 800]], 40, 30), '#7B788F', 1);
  P(rectPts(750, 200, 40, 600), '#7B788F', 1);
  P(ribbon([[150, 200], [152, 500], [150, 800]], 40, 30), '#7B788F', 1);
  P(ribbon([[150, 900], [152, 1200], [150, 1500]], 40, 30), '#7B788F', 1);
  P(ribbon([[150, 200], [152, 500], [150, 800]].map(([x,y])=>[x+800,y+900]), 40, 30), '#7B788F', 1);
};
LOOPS.dbg.len = 1;
const SHOW = {
  stair: t => { setLight('day'); stairwell(t, { doors: [{ x: 120, num: '35' }, { x: 560, num: '36', seal: true }], stairs: null, window: { x: 820, y: 560 }, meter: 40 }); },
  stairN: t => { setLight('night'); stairwell(t, { doors: [{ x: 380, num: '32' }], stairs: 'right', stairX: 700, bulb: { x: 540, y: 380 } }); },
  hall: t => { setLight('night'); hallway(t, { gap: { feet: 1 }, stool: { x: 700, y: 1700 } }); },
  hallD: t => { setLight('day'); hallway(t, {}); },
  sem: t => { setLight('day'); semApt(t, {}); },
  bed: t => { setLight('night'); const b = bedroom(t); alarmClock(...b.clock, 130, '03:00'); },
  kit: t => { setLight('day'); kitchen(t); envelope(540, 1350, 220, { date: '3 ноября' }); oldKey(300, 1550, 120, -.3); },
  yard: t => { setLight('day'); courtyard(t); },
  props: t => { setLight('day'); bgFill('#CFC6B4'); peepholeClose(300, 300, 200); latchClose(800, 330, 260, .5);
    phone(250, 900, 420, { screen: 'call' }); phone(750, 900, 420, { screen: 'dead' });
    notePaper(540, 1500, 900, 520, 'Оно ходит три ночи. Говорит голосами тех, кого любишь. Не открывай. Ни разу.', { rot: -.03 }); },
};
for (const k in SHOW) { LOOPS[k] = SHOW[k]; LOOPS[k].len = 1; }
LOOPS.empty = t => { setLight('day'); bgFill('#CFC6B4'); };
LOOPS.empty.len = 1;
