"""Narration for RumbStory via OpenRouter gpt-audio. One WAV per frame line.

usage: python3 tools/tts.py vo_lines.json audio/vo [voice]
Writes audio/vo/p1_01.wav ... and audio/vo/durations.json. Skips lines already done.
"""
import base64, difflib, json, os, re, subprocess, sys, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor

SRC, OUT = sys.argv[1], sys.argv[2]
VOICE = sys.argv[3] if len(sys.argv) > 3 else "ash"
SYSTEM = (
    "Ты профессиональный диктор аудиокниг в жанре триллер-ужасы. Прочитай текст пользователя дословно, по-русски, "
    "ничего не добавляя, не пропуская и не комментируя. Голос низкий, сдержанный, зловещий; темп живой, чуть быстрее "
    "обычного, без длинных пауз между фразами. Подсказки в квадратных скобках — указания по интонации, их НЕ произносить: "
    "[шёпотом] — шёпот, [пауза] — короткая пауза, [медленно] — медленнее, [ласково] — ласково и жутко, [сонно] — сонно, "
    "[мягко] — мягко. Реплики героев в кавычках читай тем же голосом, слегка меняя интонацию."
)
os.makedirs(OUT, exist_ok=True)


def norm(s):
    s = re.sub(r"\[[^\]]*\]", " ", s).lower().replace("ё", "е")
    return " ".join(re.findall(r"[а-яa-z0-9]+", s))


def call(text):
    body = {"model": "openai/gpt-audio", "stream": True, "modalities": ["text", "audio"],
            "audio": {"voice": VOICE, "format": "pcm16"}, "max_tokens": 600,
            "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": text}]}
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer sk-or-proxy"})
    pcm, tr = bytearray(), []
    with urllib.request.urlopen(req, timeout=300) as r:
        for line in r:
            line = line.decode().strip()
            if not line.startswith("data:") or line.endswith("[DONE]"):
                continue
            d = json.loads(line[5:])
            if "error" in d:
                raise RuntimeError(d["error"])
            for ch in d.get("choices", []):
                a = ch.get("delta", {}).get("audio") or {}
                if a.get("data"):
                    pcm += base64.b64decode(a["data"])
                if a.get("transcript"):
                    tr.append(a["transcript"])
    return bytes(pcm), "".join(tr)


def job(key, text):
    wav = f"{OUT}/{key}.wav"
    if os.path.exists(wav):
        return key, "cached"
    best = None
    attempt = 0
    while attempt < 4:
        try:
            pcm, tr = call(text)
        except urllib.error.HTTPError as e:
            if e.code == 402:  # OpenRouter in-flight budget: wait for it to settle, doesn't count as an attempt
                print(key, "402, waiting", flush=True)
                time.sleep(45)
                continue
            print(key, "error", e, flush=True)
            attempt += 1
            continue
        except Exception as e:  # network / API hiccup: retry
            print(key, "error", e, flush=True)
            attempt += 1
            continue
        attempt += 1
        sim = difflib.SequenceMatcher(None, norm(text), norm(tr)).ratio()
        if best is None or sim > best[0]:
            best = (sim, pcm, tr)
        if sim > .93:
            break
        print(f"{key} retry (sim {sim:.2f}): {tr}", flush=True)
    if best is None:
        return key, "FAILED"
    sim, pcm, tr = best
    raw = wav + ".pcm"
    open(raw, "wb").write(pcm)
    # trim leading/trailing silence, keep 24 kHz mono
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", raw,
                    "-af", "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,"
                           "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse",
                    wav], check=True)
    os.remove(raw)
    json.dump({"text": text, "transcript": tr, "sim": round(sim, 3)}, open(wav + ".json", "w"), ensure_ascii=False)
    return key, f"sim {sim:.2f}"


lines = json.load(open(SRC))
jobs = [(f"{p}_{i + 1:02d}", t) for p, ls in lines.items() for i, t in enumerate(ls)]
with ThreadPoolExecutor(1) as ex:
    for key, st in ex.map(lambda j: job(*j), jobs):
        print(key, st, flush=True)

dur = {}
for key, _ in jobs:
    wav = f"{OUT}/{key}.wav"
    if os.path.exists(wav):
        dur[key] = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                                  "-of", "csv=p=0", wav]).decode().strip())
json.dump(dur, open(f"{OUT}/durations.json", "w"), indent=1)
print("total", round(sum(dur.values()), 1), "s over", len(dur), "lines")
