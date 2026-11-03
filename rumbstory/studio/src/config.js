// config.js: which part of "Не открывай" this page draws (?part=1..5) and its length, from timing.js.
const PART = +(new URLSearchParams(location.search).get('part') || 1);
const PROJECT = { duration: TIMING[PART].dur, bpm: 60, offset: 0 };
