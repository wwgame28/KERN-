"""Sound for RumbStory "Не открывай": a dark ambient bed, synthesized effects on the picture's cues, and the narration.

usage: python3 tools/sound.py [part ...]      -> audio/mix_p{N}.wav (48 kHz stereo)
Cue times mirror the scenes: shot start + V(f), where V(f) = LEAD + f * narration length (audio/timing.json).
"""
import json, os, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
TM = json.load(open(f"{ROOT}/audio/timing.json"))
TEMPO, LEAD = TM["tempo"], .45
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- synthesis helpers
def t_(d): return np.arange(int(d * SR)) / SR
def env(n, a=.005, r=.1):
    e = np.ones(n); na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e
def lp(x, fc):  # one-pole low-pass
    a = np.exp(-2 * np.pi * fc / SR); y = np.empty_like(x); s = 0.0
    for i in range(len(x)): s = (1 - a) * x[i] + a * s; y[i] = s
    return y
def lp_fast(x, fc):  # FFT brick-ish low-pass for long signals
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X *= 1 / (1 + (f / fc) ** 4); return np.fft.irfft(X, len(x))
def bp_fast(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X *= (1 / (1 + (lo / np.maximum(f, 1)) ** 4)) * (1 / (1 + (f / hi) ** 4)); return np.fft.irfft(X, len(x))
def noise(d): return rng.standard_normal(int(d * SR))
def brown(d):
    w = np.cumsum(rng.standard_normal(int(d * SR))); w -= lp_fast(w, 2); return w / (np.abs(w).max() + 1e-9)

def knock(strength=1.0):
    t = t_(.35); body = np.sin(2 * np.pi * (95 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 22)
    thud = lp(noise(.35), 900) * np.exp(-t * 45) * 3
    return (body * .9 + thud * .5) * strength
def click(bright=1.0):
    t = t_(.08); return (bp_fast(noise(.08), 1500, 6000) * np.exp(-t * 90) * 1.4 + np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 60) * .4) * bright
def latch():
    return np.concatenate([click(.8), np.zeros(int(.05 * SR)), click(1.2) * 1.3])
def tick(): t = t_(.03); return bp_fast(noise(.03), 2500, 8000) * np.exp(-t * 200) * .6
def heartbeat():
    t = t_(.5); b = lambda: np.sin(2 * np.pi * 52 * t) * np.exp(-t * 14) * (1 - np.exp(-t * 400))
    out = np.zeros(int(.75 * SR)); out[:len(t)] += b(); s = int(.22 * SR); out[s:s + len(t)] += b() * .7; return out * 1.4
def boom(d=2.5):
    t = t_(d); x = np.sin(2 * np.pi * (48 + 30 * np.exp(-t * 4)) * t) * np.exp(-t * 1.8)
    return x + lp(noise(d), 300) * np.exp(-t * 3) * .8
def swell(d=1.2):
    t = t_(d); return bp_fast(noise(d), 200, 3000) * (t / d) ** 3 * .8
def rustle(d=.6):
    t = t_(d); n = bp_fast(noise(d), 1500, 9000); am = np.abs(lp(noise(d), 25)); am /= am.max() + 1e-9
    return n * am * env(len(n), .02, .15) * .5
def tear(d=.5): t = t_(d); return bp_fast(noise(d), 800, 7000) * (np.abs(np.sin(t * 180)) ** 6 + .3) * env(len(t), .01, .1) * .7
def scrape(d=1.5):
    t = t_(d); x = bp_fast(noise(d), 120, 900) * (1 + .6 * np.sin(2 * np.pi * 13 * t)); return x * env(len(t), .1, .3) * .7
def creak(d=1.2):
    t = t_(d); f = 180 + 90 * np.sin(t * 3) ; ph = np.cumsum(f) / SR * 2 * np.pi
    x = np.sign(np.sin(ph)) * (np.sin(ph * 7) > .6); return bp_fast(x.astype(float), 300, 3000) * env(len(t), .05, .3) * .25
def drip(): t = t_(.25); return np.sin(2 * np.pi * (1400 - 900 * t) * t) * np.exp(-t * 30) * .35
def beep_busy(d):
    t = t_(d); return np.sin(2 * np.pi * 425 * t) * (np.floor(t / .35) % 2 == 0) * .25
def vibrate(d):
    t = t_(d); on = (np.mod(t, 1.0) < .55).astype(float); return lp(np.sign(np.sin(2 * np.pi * 160 * t)) * on, 600) * .35
def ring(d):
    t = t_(d); f = np.where(np.mod(t, .5) < .25, 880, 660); return np.sin(2 * np.pi * np.cumsum(f) / SR) * (np.mod(t, 2) < 1.2) * .12
def step(): t = t_(.12); return lp(noise(.12), 700) * np.exp(-t * 40) * .5
def keys():
    out = np.zeros(int(.5 * SR))
    for f, o in [(3100, 0), (4300, .03), (2700, .07)]:
        x = np.sin(2 * np.pi * f * t_(.4)) * np.exp(-t_(.4) * 12) * .12; s = int(o * SR); out[s:s + len(x)] += x
    return out
def chirp():
    t = t_(.18); f = 3200 + 1600 * np.sin(t * 40); return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), .01, .06) * .1
def whisper_bed(d):
    t = t_(d); x = bp_fast(noise(d), 1800, 7000); am = np.abs(lp(noise(d), 6)); am /= am.max() + 1e-9; return x * am * .25
def wail(d):
    t = t_(d); f = 420 + 60 * np.sin(2 * np.pi * .7 * t) + 8 * np.sin(2 * np.pi * 6 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + .4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return bp_fast(x, 300, 2500) * env(len(t), .4, .8) * .06
def hum(d, f=50, lvl=.05): t = t_(d); return (np.sin(2 * np.pi * f * t) + .3 * np.sin(4 * np.pi * f * t)) * lvl
def buzz(d, flick=None):
    t = t_(d); x = lp(np.sign(np.sin(2 * np.pi * 100 * t)), 1200) * .025; return x


# ---------------------------------------------------------------- the bed: drone pad with a slow filter, per light
def bed(d, mood):
    t = t_(d)
    if mood == 'silence': return lp_fast(noise(d), 200) * .004
    base = {'night': [55, 82.4, 116.5], 'day': [65.4, 98, 130.8], 'dawn': [61.7, 92.5, 138.6], 'yard': [65.4, 98, 130.8]}[mood]
    x = np.zeros_like(t)
    for i, f in enumerate(base):
        lfo = .6 + .4 * np.sin(2 * np.pi * (.05 + .02 * i) * t + i)
        x += np.sin(2 * np.pi * f * t + .3 * np.sin(2 * np.pi * .1 * t)) * lfo / (i + 1)
    room = lp_fast(brown(d), 180) * (.5 if mood == 'night' else .3)
    hiss = bp_fast(noise(d), 3000, 9000) * .01
    lvl = {'night': .06, 'day': .035, 'dawn': .04, 'yard': .03}[mood]
    out = (x * .5 + room) * lvl + hiss
    if mood == 'night':  # glassy high tones, now and then
        for k in range(int(d / 7)):
            s = int((3 + k * 7 + rng.uniform(0, 3)) * SR); tt = t_(4)
            g = np.sin(2 * np.pi * rng.choice([880, 932, 1245]) * tt) * np.sin(np.pi * tt / 4) ** 2 * .006
            out[s:s + len(g)] += g[:max(0, len(out) - s)]
    if mood == 'yard': out += lp_fast(brown(d), 120) * .03
    return out


# ---------------------------------------------------------------- per-part cue sheets
# each shot: (bed mood, [cues]); cue = (f or ('abs', seconds), sound name, args...). f = narration fraction (V(f)).
def K(f, gap=.3, pause=.9, n=3, groups=2, vol=1.0): return ('knocks', f, gap, pause, n, groups, vol)
CUES = {
    1: [('night', []),
        ('day', [(('abs', 1.0), 'coo'), (.55, 'steps', 2.2, .35)]),
        ('day', [(('abs', .25), 'latch'), (('abs', .6), 'keys')]),
        ('night', [(('abs', 0), 'ticks', 10), (.55, 'click')]),
        ('night', [K(.32, .3, .95)]),
        ('night', []),
        ('night', [(.5, 'swell', 2.0)]),
        ('night', [(('abs', .6), 'steps', 9, .28, 'fade')]),
        ('day', [(('abs', .5), 'chirps', 5)]),
        ('day', [(.35, 'rustle', .6), (.82, 'boom'), ('end', 'cutsilence')])],
    2: [('day', [(('abs', .3), 'rustle', .5)]),
        ('day', [(.1, 'tear'), (.25, 'keysdrop'), (.4, 'rustle', .8)]),
        ('day', [(0, 'scratch', .9)]),
        ('day', [(('abs', 0), 'ticks', 12)]),
        ('night', [(('abs', 0), 'hum', 12, 50)]),
        ('night', [K(.15, .3, .9)]),
        ('night', []),
        ('night', [(.1, 'busy', 3.0)]),
        ('night', [(('abs', 0), 'heart', 10, 1.1, 1.8)]),
        ('night', [(.55, 'latch'), (.56, 'boom'), ('end', 'cutsilence')])],
    3: [('night', [(('abs', 0), 'heart', 8, 1.25, 1.25)]),
        ('night', [(.25, 'vibrate', 4.0), (.25, 'ring', 4.0)]),
        ('night', [(.62, 'swell', 1.5)]),
        ('night', [(('abs', .3), 'latch'), (.35, 'wail', 6.0)]),
        ('day', [(.62, 'latch'), (.75, 'creak', 1.4)]),
        ('silence', []),
        ('silence', []),
        ('silence', [(0, 'rustle', .7), (.5, 'rustle', .6)]),
        ('silence', [(('abs', .3), 'rustle', 1.0)]),
        ('night', [K(.12, .3, .8), (.55, 'swell', 1.0), ('end', 'boomcut')])],
    4: [('night', [K(.05, .3, .85, 3, 3)]),
        ('night', [(('abs', .5), 'drips', 4), (.6, 'scrape', 2.5), (.92, 'click')]),
        ('night', [(('abs', 0), 'ticks', 6)]),
        ('night', [(('abs', 0), 'ticks', 10, 1.6)]),
        ('night', [K(.3, .3, .8)]),
        ('night', [(.3, 'swell', 2.0)]),
        ('night', [(('abs', .5), 'creak', 1.6)]),
        ('night', [(0, 'whisper', 9)]),
        ('dawn', [(('abs', .3), 'chirps', 6)]),
        ('dawn', [(('abs', .3), 'rustle', 1.2), (.9, 'boom'), ('end', 'cutsilence')])],
    5: [('dawn', [(.15, 'rustle', .8)]),
        ('day', [(0, 'scratch', .9)]),
        ('day', [(.45, 'boom')]),
        ('day', []),
        ('yard', [(('abs', .5), 'chirps', 4)]),
        ('day', [(('abs', 0), 'ticks', 10)]),
        ('night', [(('abs', .2), 'steps', 7, .5), (('abs', 0), 'buzz', 8)]),
        ('night', [K(.12, .3, .8)]),
        ('night', [(('abs', .2), 'creak', 1.2)]),
        ('night', [('endm', 'boom', 1.4)])],
}


def place(buf, x, at, vol=1.0):
    s = int(at * SR)
    if s >= len(buf) or s + len(x) <= 0: return
    if s < 0: x = x[-s:]; s = 0
    n = min(len(x), len(buf) - s); buf[s:s + n] += x[:n] * vol


def render_part(p):
    T = TM["parts"][str(p)]; D = T["dur"]; n = int((D + .5) * SR)
    fx, bd, vo = np.zeros(n), np.zeros(n), np.zeros(n)
    for i, (mood, cues) in enumerate(CUES[p]):
        a, ln, vod = T["starts"][i], T["lens"][i], T["vod"][i]
        V = lambda f: a + LEAD + f * vod
        # bed for the shot with 0.4 s crossfades
        b = bed(ln + .8, mood); b *= env(len(b), .4, .4); place(bd, b, a - .4)
        for c in cues:
            if c[0] == 'knocks':
                _, f, gap, pause, kn, groups, vol = c; t0 = V(f)
                for g in range(groups):
                    for j in range(kn): place(fx, knock(1 - .1 * j), t0 + g * ((kn - 1) * gap + pause) + j * gap, .9 * vol)
                continue
            when, name, *args = c
            if when == 'end':
                if name == 'cutsilence': fx[int((a + ln - 1.6) * SR):int((a + ln) * SR)] *= 0; bd[int((a + ln - 1.55) * SR):int((a + ln) * SR)] *= np.linspace(1, 0, int((a + ln) * SR) - int((a + ln - 1.55) * SR)) ** 4
                if name == 'boomcut': place(fx, boom(), a + ln - 1.65, .45); bd[int((a + ln - 1.55) * SR):int((a + ln) * SR)] *= .1
                continue
            if when == 'endm': at = a + ln - args[0]; place(fx, boom(3), at, .45); continue
            at = a + when[1] if isinstance(when, tuple) else V(when)
            if name == 'latch': place(fx, latch(), at, .8)
            elif name == 'click': place(fx, click(), at, .6)
            elif name == 'keys': place(fx, keys(), at, 1)
            elif name == 'keysdrop': place(fx, keys(), at + .45, 1.4); place(fx, click(.5), at + .45, .5)
            elif name == 'boom': place(fx, boom(), at, .45)
            elif name == 'swell': place(fx, swell(args[0]), at - args[0], .5)
            elif name == 'rustle': place(fx, rustle(args[0]), at, .8)
            elif name == 'tear': place(fx, tear(), at, .8)
            elif name == 'scrape': place(fx, scrape(args[0]), at, .9)
            elif name == 'creak': place(fx, creak(args[0]), at, .9)
            elif name == 'wail': place(fx, wail(args[0]), at, 1)
            elif name == 'whisper': place(fx, whisper_bed(args[0]), at, .9)
            elif name == 'busy': place(fx, beep_busy(args[0]), at, .8)
            elif name == 'vibrate': place(fx, vibrate(args[0]), at, .8)
            elif name == 'ring': place(fx, ring(args[0]), at, .8)
            elif name == 'hum': place(fx, hum(args[0], args[1], .03), at, 1)
            elif name == 'buzz': place(fx, buzz(args[0]), at, 1)
            elif name == 'coo':
                for k in range(3): tt = t_(.5); place(fx, np.sin(2 * np.pi * (420 - 60 * tt) * tt) * np.sin(np.pi * tt / .5) * .05, at + k * .9)
            elif name == 'chirps':
                for k in range(int(args[0] * 2)): place(fx, chirp(), at + k * .5 + rng.uniform(0, .3), .8)
            elif name == 'drips':
                for k in range(int(args[0] * 1.5)): place(fx, drip(), at + k * .66 + rng.uniform(0, .2), .7)
            elif name == 'ticks':
                dur, vol = args[0], (args[1] if len(args) > 1 else 1)
                for k in range(int(dur)): place(fx, tick(), at + k, .5 * vol)
            elif name == 'steps':
                dur, gap = args[0], args[1]; fade = len(args) > 2
                for k in range(int(dur / gap)): place(fx, step(), at + k * gap, .7 * ((1 - k * gap / dur) if fade else 1))
            elif name == 'heart':
                dur, r0, r1 = args
                tt = 0.0
                while tt < dur: place(fx, heartbeat(), at + tt, .9); tt += 1 / lerp(r0, r1, tt / dur)
            elif name == 'scratch':
                d = args[0] * vod; tt = t_(d); x = bp_fast(noise(d), 2500, 9000) * (np.abs(np.sin(tt * 23)) ** 4) * .08
                place(fx, x, at)
    # narration: each line time-stretched by TEMPO, slightly warmed, at its start
    for i in range(10):
        wav = f"{ROOT}/audio/vo/p{p}_{i + 1:02d}.wav"
        if not os.path.exists(wav): print(f"  (no narration for p{p}_{i + 1:02d})"); continue
        raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", wav, "-af", f"atempo={TEMPO},highpass=f=70,lowpass=f=11000",
                                       "-ar", str(SR), "-ac", "1", "-f", "f32le", "-"])
        x = np.frombuffer(raw, dtype=np.float32).astype(float)
        place(vo, x, T["vo"][i], 1.0)
    # duck the bed under the voice
    talk = np.abs(vo); talk = lp_fast(talk, 3); duck = 1 - .45 * np.clip(talk / (talk.max() + 1e-9) * 4, 0, 1)
    mix_l = vo * .9 + fx * .55 + bd * duck
    # a touch of room on effects + voice, stereo by small delay
    ir = np.exp(-t_(1.2) * 5) * rng.standard_normal(int(1.2 * SR)) * .02; ir[0] = 1
    wet = np.fft.irfft(np.fft.rfft(fx * .55 + vo * .25, len(mix_l) + len(ir)) * np.fft.rfft(ir, len(mix_l) + len(ir)))[:len(mix_l)]
    L = mix_l + wet * .12; R = np.roll(mix_l, int(.0006 * SR)) + np.roll(wet, int(.011 * SR)) * .12
    st = np.stack([L, R], 1); st /= max(1e-9, np.abs(st).max()) / .89
    out = f"{ROOT}/audio/mix_p{p}.wav"
    import wave
    with wave.open(out, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
    print(f"part {p}: {D:.1f} s -> {out}")


def lerp(a, b, k): return a + (b - a) * k


if __name__ == "__main__":
    for p in [int(a) for a in sys.argv[1:]] or [1, 2, 3, 4, 5]:
        render_part(p)
