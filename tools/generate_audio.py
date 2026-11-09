"""Original synthesized sounds. Run with Python 3; ffmpeg encodes the ambient loop."""
from pathlib import Path
import math
import random
import struct
import subprocess
import wave

OUT = Path(__file__).resolve().parents[1] / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def write(name, seconds, sample):
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, sample(i / RATE))) * 25000)) for i in range(int(RATE * seconds))))

def tone(t, hz):
    return math.sin(t * hz * math.tau)

write("click", .09, lambda t: .18 * tone(t, 740) * math.exp(-t * 50))
write("build", .5, lambda t: .28 * (tone(t, 440) + .5 * tone(t, 660) + .3 * tone(t, 880)) * math.exp(-t * 8) * min(1, t * 150))
write("gather", .35, lambda t: .22 * tone(t, 880 if t < .1 else 1174) * math.exp(-t * 9) * min(1, t * 100))
rng = random.Random(22)
write("cannon", .38, lambda t: (.45 * rng.uniform(-1, 1) + .38 * tone(t, 65 - t * 70)) * math.exp(-t * 17))
write("victory", 1.9, lambda t: .18 * sum(tone(t, hz) * math.exp(-max(0, t - j * .2) * 3) if t >= j * .2 else 0 for j, hz in enumerate([392, 494, 587, 784])))
write("defeat", 1.5, lambda t: .22 * (tone(t, 196) + .4 * tone(t, 233)) * math.exp(-t * 3) * min(1, t * 30))

# Quiet plucked pentatonic melody over warm open fifths. Seamless 32-second loop.
notes = [196, 246.94, 293.66, 329.63, 392, 329.63, 293.66, 246.94,
         164.81, 196, 246.94, 293.66, 329.63, 293.66, 246.94, 196]
def ambient(t):
    i = int(t / 2)
    phase = t % 2
    melody = .12 * (tone(phase, notes[i % 16]) + .2 * tone(phase, notes[i % 16] * 2)) * math.exp(-phase * 2.4) * min(1, phase * 40)
    pad = .025 * (tone(t, 98) + tone(t, 147)) * math.sin(math.pi * t / 32) ** 2
    return melody + pad

write("hearth", 32, ambient)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(OUT / "hearth.wav"), "-c:a", "libvorbis", "-q:a", "3", str(OUT / "hearth.ogg")], check=True)
(OUT / "hearth.wav").unlink()
print("Generated original audio in", OUT)
