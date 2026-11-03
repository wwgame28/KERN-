#!/bin/bash
# usage: ./sheet.sh PART "f1,f2" [cols] [w] -> contact sheet at fractions f of every shot
P=$1; F=${2:-.35,.8}; C=${3:-6}; WD=${4:-240}
T=$(node -e "
const s=require('fs').readFileSync('src/timing.js','utf8'); eval(s.replace(/const /g,'var '));
const T=TIMING[$P], fr='$F'.split(',').map(Number), out=[];
T.starts.forEach((a,i)=>fr.forEach(f=>out.push((a+T.lens[i]*f).toFixed(2))));
console.log(out.join(','));")
timeout 600 node render.mjs --part=$P --sheet=$T --cols=$C --w=$WD --soft-gl --chrome=/opt/pw-browsers/chromium-1243/chrome-linux64/chrome --out=out/check/p${P}_sheet.jpg 2>&1 | grep -v "WebGL\|uniform1i" | tail -4
