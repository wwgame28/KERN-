// Headless balance simulator for Merge Bastion.
// Plays the real game code (index.html) with a bot, much faster than real time.
//
//   node tools/balance-sim.js [minutes=45] [secondsPerAction=3] ['{"wave":{"hpGrowth":1.08}}']
//
// secondsPerAction: 3 ≈ casual player, 1 ≈ active player, 0 = instant "perfect" bot.
// Needs Playwright with Chromium installed.
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const minutes = +(process.argv[2] || 45);
  const every = +(process.argv[3] || 3);
  const overrides = JSON.parse(process.argv[4] || '{}');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.goto('file://' + path.resolve(__dirname, '../index.html'));
  await page.waitForTimeout(300);
  const r = await page.evaluate(([ov, minutes, every]) => {
    const deep = (t, s) => { for (const k in s) { if (s[k] && typeof s[k] === 'object') deep(t[k], s[k]); else t[k] = s[k]; } };
    deep(CONFIG, ov);
    SIM = true; newWorld(); layout(); setState('play');
    const perfect = every <= 0, tension = {}, reached = {};
    const cleared = waveCleared;
    waveCleared = function () { if (!(world.wave in tension)) tension[world.wave] = CONFIG.base.hp - world.baseHp; cleared(); };
    const lost = defeat;
    defeat = function () { tension[world.wave] = (tension[world.wave] || '') + 'X'; lost(); };
    function act() {                         // one action per tick (or everything, for the perfect bot)
      let n = perfect ? 1e9 : 1;
      let pair;
      while (n > 0 && (pair = findMergePair())) { tryDrop(pair[0], pair[1]); n--; }
      while (n > 0 && findFreeCell() >= 0 && world.coins >= costOf(world.purchases)) { buyTurret(); n--; }
      if (n <= 0) return;
      let dMin = 0, gMax = CONFIG.cols;      // keep the strongest turrets in the defense row
      for (let i = 1; i < CONFIG.cols; i++) if (world.cells[i].lvl < world.cells[dMin].lvl) dMin = i;
      for (let i = CONFIG.cols; i < world.cells.length; i++) if (world.cells[i].lvl > world.cells[gMax].lvl) gMax = i;
      if (world.cells[gMax].lvl > world.cells[dMin].lvl) tryDrop(gMax, dMin);
    }
    let t = 0;
    for (let s = 0; s < minutes * 3600; s++) {
      simulate(CONFIG.STEP);
      if ((t += CONFIG.STEP) >= (perfect ? 0.5 : every)) { t = 0; act(); }
      if (world.phase === 'lost') retreat(false);
      if (!(world.wave in reached)) reached[world.wave] = (world.time / 60).toFixed(1);
    }
    return { tension, reached, maxWave: Math.max(...Object.keys(reached).map(Number)) };
  }, [overrides, minutes, every]);
  await browser.close();

  // wall damage in regular waves (a lost wave counts as the full 10 HP)
  const leaks = (a, b) => Object.entries(r.tension).filter(([w]) => +w >= a && +w <= b && +w % 10)
    .reduce((s, [, v]) => s + (typeof v === 'number' ? v : 10), 0);
  const tries = w => String(r.tension[w] ?? '').split('X').length - 1;
  console.log(`bot: ${every <= 0 ? 'perfect' : `1 action / ${every}s`}, ${minutes} min`);
  console.log(`wall damage taken  waves 5-9: ${leaks(5, 9)}  11-19: ${leaks(11, 19)}  21-29: ${leaks(21, 29)}`);
  console.log(`defeats on bosses  10: ${tries(10)}  20: ${tries(20)}  30: ${tries(30)}  40: ${tries(40)}`);
  console.log('time to reach      ' + [10, 20, 30, 40, 50].map(w => `w${w}: ${r.reached[w] ? r.reached[w] + 'm' : '—'}`).join('  '));
  console.log(`max wave: ${r.maxWave}`);
})();
