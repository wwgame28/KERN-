#!/usr/bin/env python3
"""YASMI type beat — «Showbiz 162» (140 BPM, F minor).

Полностью синтезированный трэп-бит в духе YASMI: тёмный колокольчик в
гармоническом миноре, флейта на хуке, перегруженный 808 со слайдами,
хэты с триольными роллами, хлопок на третью долю. Никаких сэмплов —
весь звук считается numpy/scipy; на выходе WAV/MP3, MIDI и стемы.

    python generate_beat.py            # master WAV + MP3 + MIDI
    python generate_beat.py --stems    # плюс стемы по инструментам
"""
import argparse
import os
import re
import shutil
import subprocess

import mido
import numpy as np
import soundfile as sf
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d

SR = 44100
BPM = 140
SPB = 60 / BPM          # seconds per beat
STEPS = 16              # 16th grid per bar
TITLE = 'yasmi_type_beat_showbiz162_140bpm_Fmin'

NOTE = {'C': 0, 'Db': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6,
        'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}


def n(name):
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def smp(sec):
    return int(round(sec * SR))


# ---------------------------------------------------------------- composition
# Структура ~2 минуты, как у его треков (мовалола 2:03, В цвет 2:16).
SECTIONS = [('intro', 4), ('hook', 8), ('verse', 16), ('hook', 8),
            ('verse2', 16), ('hook', 8), ('outro', 4)]

# i – VI – iv – V в фа миноре; на V мажорная терция (ми бекар) — гармонический минор.
CHORDS = [
    ['F3', 'C4', 'F4', 'Ab4'],    # Fm
    ['Db3', 'Ab3', 'Db4', 'F4'],  # Db
    ['Bb2', 'F3', 'Bb3', 'Db4'],  # Bbm
    ['C3', 'G3', 'Bb3', 'E4'],    # C7
]

# Колокольчик: ритм 3-3-2 + восьмые, нисходящая секвенция.
BELL = [
    [(0, 'C6'), (3, 'Ab5'), (6, 'F5'), (8, 'G5'), (10, 'Ab5'), (12, 'G5'), (14, 'Eb5')],
    [(0, 'Ab5'), (3, 'F5'), (6, 'Db5'), (8, 'Eb5'), (10, 'F5'), (12, 'Eb5'), (14, 'C5')],
    [(0, 'Db6'), (3, 'Bb5'), (6, 'F5'), (8, 'Ab5'), (10, 'Bb5'), (12, 'Ab5'), (14, 'F5')],
    [(0, 'E5'), (3, 'G5'), (6, 'C6'), (8, 'Bb5'), (10, 'G5'), (12, 'E5')],
]

# Флейта на хуке: длинные ноты, отвечает колокольчику.
LEAD = [
    [(0, 'Ab5', 6), (6, 'G5', 2), (8, 'F5', 8)],
    [(0, 'Ab5', 6), (6, 'Bb5', 2), (8, 'Ab5', 4), (12, 'F5', 4)],
    [(0, 'Db6', 6), (6, 'C6', 2), (8, 'Bb5', 8)],
    [(0, 'C6', 4), (4, 'Bb5', 2), (6, 'G5', 2), (8, 'E5', 8)],
]

ROOTS = ['F1', 'Db2', 'Bb1', 'C2']
# 808: (step, semitones over root, length in steps, glide). 'up' = слайд вверх.
BASS = {
    'verse': [(0, 0, 6, False), (7, 0, 3, False), (10, 0, 4, False), (14, 'up', 2, True)],
    'hook': [(0, 0, 5, False), (5, 0, 2, False), (7, 0, 3, False), (10, 0, 3, False),
             (13, 'up', 2, True), (15, 0, 1, True)],
    'verse2': [(0, 0, 3, False), (3, 0, 3, False), (6, 0, 4, False), (10, 0, 2, False),
               (12, 'up', 4, True)],
}

INSTRUMENTS = ['bell', 'lead', 'pad', '808', 'kick', 'clap', 'hat', 'ohat', 'rim',
               'crash', 'rcrash', 'riser']


def roll(a, b, spacing, v0=0.45, v1=0.85, p0=1.0, p1=1.0):
    k = int(round((b - a) / spacing))
    d = max(k - 1, 1)
    return [(a + i * spacing, v0 + (v1 - v0) * i / d, p0 + (p1 - p0) * i / d) for i in range(k)]


def hats_for(name, b):
    """Closed hats for one bar: (step, velocity, pitch)."""
    if name == 'verse2' and b < 4:
        # триольные восьмые — флоу «2015» для смены во втором куплете
        return [(i * 4 / 3, 0.85 if i % 3 == 0 else 0.55, 1.0) for i in range(12)]
    if name == 'hook':
        base = [(st, 0.9 if st % 4 == 0 else (0.68 if st % 2 == 0 else 0.48), 1.0)
                for st in range(16)]
        if b % 4 == 1:
            return [h for h in base if h[0] < 12] + roll(12, 16, 0.5, 0.35, 0.8)
        if b % 4 == 3:
            return ([h for h in base if h[0] < 8 or 12 <= h[0] < 14] + roll(8, 12, 2 / 3)
                    + roll(14, 16, 0.5, 0.5, 0.9, 1.0, 1.25))
        return base
    base = [(st, 0.85 if st % 4 == 0 else 0.62, 1.0) for st in range(0, 16, 2)]
    if b % 8 == 7:
        return [h for h in base if h[0] < 8] + roll(8, 12, 0.5) + roll(12, 16, 2 / 3, 0.5, 0.9, 1.0, 1.2)
    if b % 4 == 1:
        return [h for h in base if h[0] < 14] + roll(14, 16, 0.5, 0.4, 0.75)
    if b % 4 == 3:
        return [h for h in base if h[0] < 12] + roll(12, 16, 2 / 3)
    return base


def build_events(rng):
    ev = {k: [] for k in INSTRUMENTS}
    sections, bar = [], 0
    for name, bars in SECTIONS:
        sections.append((name, bar, bars))
        bar += bars
    hook_no = 0
    for i, (name, start, bars) in enumerate(sections):
        nxt = sections[i + 1][0] if i + 1 < len(sections) else None
        if name == 'hook':
            hook_no += 1
        drums = name in ('hook', 'verse', 'verse2')
        for b in range(bars):
            bar_i = start + b
            ci = bar_i % 4
            t0 = bar_i * 4

            def at(step, t0=t0):
                return t0 + step / 4

            cut = STEPS
            if b == bars - 1 and nxt == 'hook' and name != 'intro':
                cut = 12                      # стоп перед хуком — место под панч
            elif name == 'verse' and b == 7:
                cut = 14

            for note in CHORDS[ci]:
                ev['pad'].append((t0, 4, n(note), 0.8, {}))

            if not (name == 'verse2' and b < 4):
                for step, note in BELL[ci]:
                    vel = 1.0 if step == 0 else float(rng.uniform(0.72, 0.9))
                    ev['bell'].append((at(step), 0.5, n(note), vel, {}))

            if name == 'hook' and not (hook_no == 1 and b < 4):
                for step, note, ln in LEAD[ci]:
                    ev['lead'].append((at(step), ln / 4, n(note), 0.9, {}))

            if name == 'outro' and b == 0:
                ev['808'].append((t0, 8, n(ROOTS[ci]), 1.0, {'glide': False}))

            if not drums:
                continue

            root = n(ROOTS[ci])
            up = 12 if root <= n('Bb1') else 7
            for step, semi, ln, glide in BASS[name]:
                if step >= cut:
                    continue
                pitch = root + (up if semi == 'up' else semi)
                ev['808'].append((at(step), ln / 4, pitch, 1.0, {'glide': glide}))
                if not glide:
                    ev['kick'].append((at(step), 0.25, 36, 1.0 if step == 0 else 0.85, {}))

            ev['clap'].append((at(8), 0.25, 39, 1.0, {}))
            if name == 'hook' and b == bars - 1:
                for step, v in ((13, 0.45), (14, 0.6), (15, 0.8)):
                    ev['clap'].append((at(step), 0.25, 38, v, {}))

            for step, vel, pitch in hats_for(name, b):
                if step < cut:
                    ev['hat'].append((at(step), 0.125, 42, vel, {'pitch': pitch}))

            ohats = []
            if name == 'hook' and b % 2 == 0:
                ohats = [6, 14]
            elif name != 'hook' and b % 4 == 2:
                ohats = [14]
            for step in ohats:
                if step < cut:
                    ev['ohat'].append((at(step), 0.5, 46, 0.7, {}))

            rims = []
            if b % 2 == 1:
                rims.append(11)
            if name == 'hook' and b % 4 == 3:
                rims.append(13)
            if name != 'hook' and b % 4 == 2:
                rims.append(3)
            for step in rims:
                if step < cut:
                    ev['rim'].append((at(step), 0.25, 37, 0.8, {}))

        # переходы
        if name in ('hook', 'verse2'):
            ev['crash'].append((start * 4, 4, 49, 0.8, {}))
            ev['rcrash'].append((start * 4 - 2, 2, 49, 0.7, {}))
        if name == 'intro':
            ev['riser'].append(((start + bars - 2) * 4, 8, 0, 1.0, {}))
    total_beats = bar * 4
    return ev, sections, total_beats


# ---------------------------------------------------------------- dsp helpers
def lowpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, 'low', fs=SR, output='sos'), x, axis=0)


def highpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, 'high', fs=SR, output='sos'), x, axis=0)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], 'band', fs=SR, output='sos'), x, axis=0)


def pan_gains(pan):
    a = (pan + 1) * np.pi / 4
    return np.cos(a) * np.sqrt(2), np.sin(a) * np.sqrt(2)


def place(buf, x, start, gain=1.0, pan=0.0):
    """Mix mono or stereo x into stereo buf at sample index start."""
    if start >= len(buf):
        return
    if start < 0:
        x = x[-start:]
        start = 0
    end = min(len(buf), start + len(x))
    x = x[:end - start]
    if x.ndim == 1:
        gl, gr = pan_gains(pan)
        buf[start:end, 0] += x * gain * gl
        buf[start:end, 1] += x * gain * gr
    else:
        buf[start:end] += x * gain


def attack(nsmp, sec):
    a = np.ones(nsmp)
    k = min(nsmp, max(1, smp(sec)))
    a[:k] = np.linspace(0, 1, k) ** 2
    return a


def release_tail(env, start_sec, sec):
    s0, k = smp(start_sec), smp(sec)
    if s0 < len(env):
        r = np.zeros(len(env) - s0)
        m = min(k, len(r))
        r[:m] = np.linspace(1, 0, m)
        env[s0:] *= r
    return env


def make_ir(rng, rt60=2.2, length=2.6, predelay=0.025, lp=5500):
    k = smp(length)
    t = np.arange(k) / SR
    decay = np.exp(-6.9 * t / rt60)
    ir = rng.standard_normal((k, 2)) * decay[:, None]
    ir = lowpass(ir, lp)
    ir[:smp(0.004)] *= np.linspace(0, 1, smp(0.004))[:, None]
    ir = np.vstack([np.zeros((smp(predelay), 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def convolve_stereo(x, ir):
    out = np.zeros_like(x)
    for c in range(2):
        out[:, c] = signal.fftconvolve(x[:, c], ir[:, c])[:len(x)]
    return out


def pingpong(x, delay_sec, feedback=0.38, taps=6):
    d = smp(delay_sec)
    out = np.zeros_like(x)
    mono = x.mean(axis=1)
    for k in range(1, taps + 1):
        shift = k * d
        if shift >= len(x):
            break
        ch = (k + 1) % 2
        out[shift:, ch] += mono[:-shift] * feedback ** k
    return lowpass(highpass(out, 400), 4500)


def pitch_shift(x, ratio):
    if ratio == 1.0:
        return x
    idx = np.arange(0, len(x) - 1, ratio)
    return np.interp(idx, np.arange(len(x)), x)


# ---------------------------------------------------------------- instruments
def bell_voice(f, dur):
    t = np.arange(smp(dur + 1.6)) / SR
    mod = (1.8 * np.exp(-t / 0.08) * np.sin(2 * np.pi * 4 * f * t)
           + 0.6 * np.exp(-t / 0.3) * np.sin(2 * np.pi * 3.5 * f * t))
    tone = np.sin(2 * np.pi * f * t + mod) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.35)
    env = np.exp(-t / 0.85) * attack(len(t), 0.002)
    return release_tail(tone * env, dur + 1.2, 0.4)


def bell_note(f, dur):
    a = bell_voice(f, dur)
    b = bell_voice(f * 2 ** (7 / 1200), dur)
    return np.stack([a + 0.55 * b, b + 0.55 * a], axis=1) * 0.6


def flute_note(f, dur, rng):
    t = np.arange(smp(dur + 0.3)) / SR
    vib_amt = np.clip((t - 0.15) / 0.25, 0, 1)
    fm = f * (1 + (2 ** (16 / 1200) - 1) * np.sin(2 * np.pi * 5.3 * t) * vib_amt)
    ph = 2 * np.pi * np.cumsum(fm) / SR
    tone = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    breath = bandpass(rng.standard_normal(len(t)), f * 0.9, min(f * 4, 16000)) * 0.35
    breath *= np.exp(-t / 0.12) + 0.25
    env = attack(len(t), 0.06)
    env = release_tail(env, dur, 0.18)
    return (tone + breath) * env


def pad_note(f, dur, rng):
    t = np.arange(smp(dur + 0.7)) / SR
    out = np.zeros((len(t), 2))
    for i, cents in enumerate((-14, -9, -4, 0, 4, 9, 14)):
        fi = f * 2 ** (cents / 1200)
        ph = (fi * t + rng.random()) % 1.0
        saw = 2 * ph - 1
        out[:, i % 2] += saw
        if i == 3:
            out[:, 1] += saw
    out = lowpass(out, 950, 2)
    env = attack(len(t), 0.3)
    env = release_tail(env, dur, 0.6)
    return out * env[:, None] / 7


def render_808(notes, nsmp, tau=1.4):
    """Monophonic 808 with retriggers, pitch punch and glides."""
    freq = np.zeros(nsmp)
    amp = np.zeros(nsmp)
    phase_out = np.zeros(nsmp)
    notes = sorted(notes, key=lambda e: e[0])
    prev_f, prev_level, prev_end, phase = None, 0.0, -1, 0.0
    for i, (beat, dur, midi, vel, ex) in enumerate(notes):
        s0 = smp(beat * SPB)
        s1 = smp((beat + dur) * SPB)
        if i + 1 < len(notes):
            s1 = min(s1, smp(notes[i + 1][0] * SPB))
        s1 = min(s1, nsmp)
        if s1 <= s0:
            continue
        t = np.arange(s1 - s0) / SR
        f = hz(midi)
        glide = ex.get('glide') and prev_f is not None and abs(prev_end - s0) < 2
        if glide:
            ratio = f / prev_f
            fseg = prev_f * ratio ** (1 - np.exp(-t / 0.03))
            lvl0 = max(prev_level, 0.8 * vel)
        else:
            fseg = f * (1 + 0.6 * np.exp(-t / 0.012))
            lvl0 = vel
            phase = 0.0
        aseg = lvl0 * np.exp(-t / tau)
        nxt_glide = (i + 1 < len(notes) and notes[i + 1][4].get('glide')
                     and smp(notes[i + 1][0] * SPB) == s1)
        if not nxt_glide:
            k = min(len(aseg), smp(0.018))
            aseg[-k:] *= np.linspace(1, 0, k)
        ph = phase + 2 * np.pi * np.cumsum(fseg) / SR
        phase = ph[-1]
        freq[s0:s1] = fseg
        amp[s0:s1] = aseg
        phase_out[s0:s1] = ph
        prev_f, prev_level, prev_end = f, aseg[-1] if nxt_glide else 0.0, s1
    # сглаживаем огибающую от щелчков на стыках
    b, a = signal.butter(1, 400, fs=SR)
    amp = signal.filtfilt(b, a, amp)
    x = np.sin(phase_out) * amp
    sat = np.tanh(2.4 * x) / np.tanh(2.4)
    y = 0.72 * sat + 0.28 * x
    return lowpass(y, 2600, 2)


def kick_sample():
    t = np.arange(smp(0.32)) / SR
    f = 52 + 135 * np.exp(-t / 0.022)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.15)
    rng = np.random.default_rng(1)
    click = highpass(rng.standard_normal(len(t)), 2500) * np.exp(-t / 0.0025)
    k = np.tanh(1.6 * (body + 0.35 * click))
    return k * attack(len(t), 0.0008)


def clap_sample(rng):
    t = np.arange(smp(0.45)) / SR
    noise = rng.standard_normal(len(t))
    env = np.zeros(len(t))
    for off in (0.0, 0.009, 0.018, 0.028):
        m = t >= off
        env[m] += np.exp(-(t[m] - off) / 0.007)
    m = t >= 0.028
    env[m] += 0.55 * np.exp(-(t[m] - 0.028) / 0.13)
    clap = bandpass(noise * env, 900, 3200, 2) * 1.6
    snare_n = highpass(rng.standard_normal(len(t)), 1800) * np.exp(-t / 0.12)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    x = clap + 0.45 * snare_n + 0.5 * tone
    return x / np.max(np.abs(x))


def metal(t, scale=1.0):
    freqs = np.array([205.3, 304.4, 369.6, 522.7, 540.0, 800.0]) * scale
    return sum(np.sign(np.sin(2 * np.pi * f * t)) for f in freqs) / 6


def hat_sample(rng, decay):
    t = np.arange(smp(decay * 7)) / SR
    x = 0.6 * metal(t, 1.7) + 0.7 * rng.standard_normal(len(t))
    x = highpass(bandpass(x, 6500, 15000, 2), 7000)
    x *= np.exp(-t / decay) * attack(len(t), 0.0005)
    return x / np.max(np.abs(x))


def rim_sample(rng):
    t = np.arange(smp(0.12)) / SR
    x = (np.sin(2 * np.pi * 1750 * t) + 0.6 * np.sin(2 * np.pi * 820 * t)) * np.exp(-t / 0.018)
    x += 0.4 * highpass(rng.standard_normal(len(t)), 3000) * np.exp(-t / 0.004)
    return bandpass(x, 500, 6000) / np.max(np.abs(x))


def crash_sample(rng, length=3.0):
    t = np.arange(smp(length)) / SR
    x = 0.8 * rng.standard_normal(len(t)) + 0.4 * metal(t, 2.3)
    x = highpass(x, 3500)
    x *= np.exp(-t / 1.1) * attack(len(t), 0.002)
    return x / np.max(np.abs(x))


def riser(rng, dur):
    k = smp(dur)
    noise = rng.standard_normal(k)
    out = np.zeros(k)
    chunk = 512
    zi = None
    for s0 in range(0, k, chunk):
        frac = s0 / k
        fc = 300 * (8000 / 300) ** frac
        sos = signal.butter(2, fc, 'low', fs=SR, output='sos')
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[s0:s0 + chunk], zi = signal.sosfilt(sos, noise[s0:s0 + chunk], zi=zi)
    env = np.linspace(0, 1, k) ** 2.2
    return highpass(out, 250) * env


# ---------------------------------------------------------------- render
def automation(nsmp, points):
    """Piecewise-linear curve from [(sec, value), ...]."""
    xs = np.array([p[0] for p in points]) * SR
    ys = np.array([p[1] for p in points])
    return np.interp(np.arange(nsmp), xs, ys)


def render(ev, sections, total_beats, rng):
    nsmp = smp(total_beats * SPB + 3.0)
    stems = {}

    def track():
        return np.zeros((nsmp, 2))

    # bell
    bell = track()
    for beat, dur, midi, vel, _ in ev['bell']:
        place(bell, bell_note(hz(midi), dur * SPB), smp(beat * SPB), vel)
    stems['bell'] = bell

    lead = track()
    for beat, dur, midi, vel, _ in ev['lead']:
        place(lead, flute_note(hz(midi), dur * SPB, rng), smp(beat * SPB), vel, pan=-0.12)
    stems['lead'] = lead

    pad = track()
    for beat, dur, midi, vel, _ in ev['pad']:
        place(pad, pad_note(hz(midi), dur * SPB, rng), smp(beat * SPB), vel)
    stems['pad'] = highpass(pad, 180)

    b808 = render_808(ev['808'], nsmp)
    stems['808'] = np.stack([b808, b808], axis=1)

    one = {
        'kick': kick_sample(),
        'clap': clap_sample(rng),
        'hat': hat_sample(rng, 0.028),
        'ohat': hat_sample(rng, 0.17),
        'rim': rim_sample(rng),
        'crash': crash_sample(rng),
    }
    for name in ('kick', 'clap', 'hat', 'ohat', 'rim', 'crash'):
        buf = track()
        for i, (beat, dur, midi, vel, ex) in enumerate(ev[name]):
            x = one[name]
            jitter = 0.0
            pan = 0.0
            if name == 'clap' and midi == 38:
                x = pitch_shift(x, 1.15)
            if name == 'hat':
                x = pitch_shift(x, ex.get('pitch', 1.0))
                jitter = rng.uniform(-0.002, 0.002)
                vel *= rng.uniform(0.9, 1.05)
                pan = 0.12 if i % 2 else -0.08
            if name == 'ohat':
                pan = 0.18
            if name == 'rim':
                pan = -0.25
            place(buf, x, smp(beat * SPB + jitter), vel, pan)
        stems[name] = buf

    fx = track()
    rc = crash_sample(rng, 2 * SPB + 0.3)[::-1]
    for beat, dur, midi, vel, _ in ev['rcrash']:
        place(fx, rc, smp(beat * SPB) - (len(rc) - smp(2 * SPB)), vel * 0.8)
    for beat, dur, midi, vel, _ in ev['riser']:
        r = riser(rng, dur * SPB)
        place(fx, np.stack([r, np.roll(r, 300)], axis=1), smp(beat * SPB), vel)
    stems['fx'] = fx

    # ---- automation
    bar = 4 * SPB
    sec_start = {}
    for name, start, bars in sections:
        sec_start.setdefault(name, []).append((start * bar, (start + bars) * bar))
    intro_end = sec_start['intro'][0][1]
    outro_s, outro_e = sec_start['outro'][0]

    # колокольчик «из телефона» в интро/аутро, тише в куплетах (место под голос)
    bell_lp = lowpass(highpass(stems['bell'], 500), 900)
    filt = automation(nsmp, [(0, 1), (intro_end - bar, 1), (intro_end, 0),
                             (outro_s, 0), (outro_s + 2 * bar, 1), (nsmp / SR, 1)])
    vol = np.ones(nsmp)
    for s, e in sec_start.get('verse', []) + sec_start.get('verse2', []):
        vol[smp(s):smp(e)] = 0.72
    vol = uniform_filter1d(vol, smp(0.05))
    stems['bell'] = (stems['bell'] * (1 - filt)[:, None] + bell_lp * filt[:, None] * 1.6) * vol[:, None]

    # сайдчейн пэда и флейты от бочки/808
    imp = np.zeros(nsmp)
    for beat, *_ in ev['kick']:
        imp[min(nsmp - 1, smp(beat * SPB))] = 1.0
    kern = np.exp(-np.arange(smp(0.25)) / SR / 0.11)
    duck = 1 - 0.4 * np.clip(signal.fftconvolve(imp, kern)[:nsmp], 0, 1)
    stems['pad'] *= duck[:, None]
    stems['lead'] *= (1 - 0.5 * (1 - duck))[:, None]

    return stems, (outro_s, outro_e)


# Уровни подобраны по пикам: хлопок и бочка пробивают над 808, 808 — самый плотный по RMS.
GAINS = {'bell': 0.28, 'lead': 0.22, 'pad': 0.42, '808': 0.5, 'kick': 0.5,
         'clap': 0.7, 'hat': 0.35, 'ohat': 0.2, 'rim': 0.3, 'crash': 0.14, 'fx': 0.2}
SENDS = {'bell': 0.32, 'lead': 0.35, 'pad': 0.45, 'clap': 0.16, 'rim': 0.3,
         'hat': 0.04, 'ohat': 0.1, 'crash': 0.2, 'fx': 0.2}


def mixdown(stems, outro, rng):
    nsmp = len(stems['808'])
    dry = np.zeros((nsmp, 2))
    send = np.zeros((nsmp, 2))
    for k, x in stems.items():
        dry += x * GAINS[k]
        send += x * GAINS[k] * SENDS.get(k, 0)
    verb = convolve_stereo(highpass(send, 250), make_ir(rng))
    delay = pingpong(stems['bell'] * GAINS['bell'], 0.75 * SPB)
    mix = highpass(dry + 0.32 * verb + 0.3 * delay, 27)
    fade = automation(nsmp, [(0, 1), (outro[1] - 4 * SPB, 1), (outro[1] + 2.5, 0), (nsmp / SR, 0)])
    return mix * fade[:, None]


def softclip(x, knee=0.7):
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    return y


def master(mix, gain_db, ceiling=0.891):
    """Gain into a soft clipper, then a look-ahead brickwall at -1 dBFS."""
    return limiter(softclip(mix * 10 ** (gain_db / 20)), ceiling)


def limiter(x, ceiling):
    peak = np.max(np.abs(x), axis=1)
    g = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    g = minimum_filter1d(g, smp(0.012))
    g = uniform_filter1d(g, smp(0.005))
    g = np.minimum(g, ceiling / np.maximum(peak, 1e-9))
    return np.clip(x * g[:, None], -ceiling, ceiling)


# ---------------------------------------------------------------- export
GM = {'bell': (0, 9), 'lead': (1, 73), 'pad': (2, 89), '808': (3, 38)}
DRUMS = ['kick', 'clap', 'hat', 'ohat', 'rim', 'crash']


def write_midi(ev, path):
    tpb = 480
    mid = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage('track_name', name='YASMI type beat - Showbiz 162'))
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    meta.append(mido.MetaMessage('key_signature', key='Fm'))
    mid.tracks.append(meta)

    def add(name, events, ch, program=None):
        tr = mido.MidiTrack()
        tr.append(mido.MetaMessage('track_name', name=name))
        if program is not None:
            tr.append(mido.Message('program_change', channel=ch, program=program))
        msgs = []
        for beat, dur, midi, vel, _ in events:
            on = int(round(beat * tpb))
            off = on + max(1, int(round(min(dur, 4) * tpb)) - 1)
            v = max(1, min(127, int(vel * 110)))
            msgs.append((on, 1, mido.Message('note_on', channel=ch, note=midi, velocity=v)))
            msgs.append((off, 0, mido.Message('note_off', channel=ch, note=midi, velocity=0)))
        msgs.sort(key=lambda m: (m[0], m[1]))
        now = 0
        for tick, _, msg in msgs:
            tr.append(msg.copy(time=tick - now))
            now = tick
        mid.tracks.append(tr)

    for name, (ch, prog) in GM.items():
        add(name, ev[name], ch, prog)
    drums = [e for k in DRUMS for e in ev[k]]
    add('drums', drums, 9)
    mid.save(path)


def lufs(path):
    out = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    m = re.findall(r'I:\s+(-?[\d.]+) LUFS', out)
    return float(m[-1]) if m else None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output'))
    ap.add_argument('--stems', action='store_true', help='also write per-instrument WAV stems')
    ap.add_argument('--seed', type=int, default=162)
    ap.add_argument('--lufs', type=float, default=-9.5, help='target integrated loudness')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    ev, sections, total_beats = build_events(rng)
    stems, outro = render(ev, sections, total_beats, rng)
    mix = mixdown(stems, outro, rng)

    # громкость под стриминговый трэп: подгоняем gain в лимитер до целевого LUFS
    wav = os.path.join(args.out, TITLE + '.wav')
    gain_db = -20 * np.log10(np.sqrt(np.mean(mix ** 2)) / 0.25)
    for _ in range(4):
        out = master(mix, gain_db)
        sf.write(wav, out, SR, subtype='PCM_24')
        loud = lufs(wav)
        if loud is None or abs(loud - args.lufs) < 0.3:
            break
        gain_db += args.lufs - loud
    write_midi(ev, os.path.join(args.out, TITLE + '.mid'))
    if shutil.which('ffmpeg'):
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame',
                        '-b:a', '320k', '-metadata', 'title=YASMI type beat — Showbiz 162',
                        '-metadata', 'bpm=140', '-metadata', 'TKEY=Fm',
                        os.path.join(args.out, TITLE + '.mp3')], check=True)
    if args.stems:
        sdir = os.path.join(args.out, 'stems')
        os.makedirs(sdir, exist_ok=True)
        for k, x in stems.items():
            peak = np.max(np.abs(x)) or 1.0
            sf.write(os.path.join(sdir, f'{k}.wav'), x / peak * 0.89, SR, subtype='PCM_24')

    print(f'{TITLE}: {len(out) / SR:.1f}s, {BPM} BPM, F minor, peak {20 * np.log10(np.max(np.abs(out))):.2f} dBFS,'
          f' loudness {loud} LUFS')


if __name__ == '__main__':
    main()
