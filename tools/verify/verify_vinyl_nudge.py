#!/usr/bin/env python3
"""VINYL NUDGE gates: [TRACK] + [RIGHT] bends a dry track's speed, eased in
and out; a stretched track keeps stock's tempo nudge.

    python3 tools/verify/verify_vinyl_nudge.py [REMIX] [--project <dir>] [--case NAME]
    make check REMIX=vinyl          # OT_PROJECT adds playback

With a project, a copy gets verify_repitch's loop on T1 (a two-second
440 Hz stereo loop attributed 120 BPM, LOOP on, the project at 120 BPM, so
a REPITCH track plays at 1.0). The port boots the image with the
transport STOPPED and plays a live script: NO (the date prompt); T1 held
+ PLAY, stock's own track trigger (0x40083a30), with no trig and no
sequencer; then T1 held + RIGHT held for two seconds, released; then
nothing. Every write to T1's sample position (voice +68) is watched, and
the speed (source frames per output sample) is measured in 50 ms windows.

Cases:
  dry       FLEX, TSTR REPITCH: speed 1 -> above 1 while held -> back to 1,
            eased: no 50 ms window carries more than STEP_SHARE of the
            swing, and the way back takes RETURN_MIN windows or more
  off       STATIC, TSTR OFF: the same
  stretch   FLEX, TSTR NORM: stock's tempo nudge, untouched: the speed
            still moves while held (the renderer's tempo ratio)
  control   FLEX, TSTR REPITCH on the same remix WITHOUT this module (the
            REPITCH test remix): the speed must not move -- stock's nudge
            is inert on a dry track, so a move in `dry` is the module's

  fader     FLEX, TSTR REPITCH: T1 held, then LEVEL +5, UP, UP, LEVEL pushed
            +2, LEVEL -1, T1 released. The slot's tempo (BPMx24, FLEX
            settings 0x100b14f0 + 0x114) must be written by the audio
            editor's own setter (0x40099126) as 2875, 2874, 2873, 2825,
            2826; T1's level (0x80000c50) must not be written after the
            trigger (LEVEL is the tempo's while a track is held); the track
            must end at 2880 / 2826 = 1.0191 (REPITCH: project / sample);
            and the readout timer must count show_left back to 0. The
            module's text buffer must end as "+1.9" (2880 / 2826 - 1, the
            percentage the field showed), and the LCD plane at the end
            (the field stock's again) must have nothing in x 36..41 of the
            field's rows, where our text overhangs stock's clear.
  remain    FLEX, TSTR REPITCH: T1 started, its voice's trim end poked to
            4,418,304 frames (100.2 s), T1 held, the run ended while held:
            the text buffer must read "-1:38" or "-1:39".
  steady    STATIC, TSTR OFF: T1 started, then held for 3 s: the field must
            hold the time left the whole while (the module's `drawn` is
            never cleared, which is what a draw of stock's BPM does). A
            STATIC voice's play-state byte cycles 1, 0, 0xff every ~58 ms as
            it streams; reading it alone, OCTABAM3 flashed stock's BPM into
            the time on the unit (18 Oct 2026).
  cue       FLEX, TSTR REPITCH: T1 started; T1 + REC at about 0.9 s and
            1.9 s, then REC alone. Slot 1 must end with two slices, sorted,
            the first starting between 0.7 and 1.1 s and the second later,
            both ending at the trim end with no loop (-1); grid recording
            (0x460d1736) must be switched on by the lone REC only; and the
            track must play through both cues, every frame advancing 16.

What it cannot see: pitch by ear, hardware timing, the glyphs themselves
(the field was read from LCD planes by eye, 18 Oct 2026: "+1.9", "-1:38",
and stock's "120.0" back with nothing left over).
"""
import argparse, os, pathlib, re, shutil, subprocess, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1])); import toolpath  # noqa: E402,F401
from remix import registry  # noqa: E402
import verify_repitch as vr  # noqa: E402  the loop, the project edit, the card, the position parse

ROOT = pathlib.Path(__file__).resolve().parents[2]
EMU = ROOT / "out/emu/ot_emu"
PY = ROOT / ".venv/bin/python3"
OUT = ROOT / "out/vinylnudge"
SR = vr.SR
FRAME = 16                          # samples a frame
WINDOW_FRAMES = 138                 # 50 ms
WINDOW = WINDOW_FRAMES * FRAME
STEP_SHARE = 0.35                   # the most of the swing one 50 ms window may carry, eased
RETURN_MIN = 3                      # windows from the peak back to within 10 % of the base, eased
K = dict(no=0x32, t1=0x10, play=0x28, right=0x21, up=0x33, level=0x3e)
TEMPO_WORD = 0x100b14f0 + 0x114     # FLEX slot 1's BPMx24
SET_TEMPO_STORE = 0x40099126        # the setter's store
LEVEL_T1 = 0x80000c50               # T1's track level (tools/panel/KEYMAP.md, 108 -> 110 a turn)
FADER_WANT = (2875, 2874, 2873, 2825, 2826)
T_TRIG, T_HOLD, T_RELEASE, T_END = 2500, 4500, 6500, 10000   # emulated ms

CASES = {  # name: machine, SETUP TSTR, sample TSMODE, which image, the speed must move while held
    "dry": ("flex", 4, 2, "module", True),
    "off": ("static", 0, 2, "module", True),
    "stretch": ("flex", 2, 2, "module", True),
    "control": ("flex", 4, 2, "control", False),
    "fader": ("flex", 4, 2, "module", None),
    "remain": ("flex", 4, 2, "module", None),
    "steady": ("static", 0, 2, "module", None),
    "cue": ("flex", 4, 2, "module", None),
}
FLEX_1 = 0x100b14f0                 # FLEX slot 1's settings
GRID_REC = 0x460d1736
VOICE_END_T1 = 0x800049d8 + 44


def script():
    lines = []
    def ev(t, k, d): lines.append(f"{t} key {K[k]:#x} {d}")
    ev(1500, "no", "down"); ev(1540, "no", "up")
    ev(T_TRIG, "t1", "down"); ev(T_TRIG + 100, "play", "down"); ev(T_TRIG + 140, "play", "up")
    ev(T_TRIG + 240, "t1", "up")
    ev(T_HOLD, "t1", "down"); ev(T_HOLD + 100, "right", "down")
    ev(T_RELEASE, "right", "up"); ev(T_RELEASE + 100, "t1", "up")
    lines.append(f"{T_END} quit")
    return "\n".join(lines) + "\n"


def fader_script():
    lines = []
    def ev(t, k, d): lines.append(f"{t} key {K[k]:#x} {d}")
    ev(1500, "no", "down"); ev(1540, "no", "up")
    ev(T_TRIG, "t1", "down"); ev(T_TRIG + 100, "play", "down"); ev(T_TRIG + 140, "play", "up")
    ev(T_TRIG + 240, "t1", "up")
    ev(4000, "t1", "down")
    lines.append("4200 enc 6 5")
    ev(4500, "up", "down"); ev(4540, "up", "up")
    ev(4800, "up", "down"); ev(4840, "up", "up")
    ev(5100, "level", "down"); lines.append("5200 enc 6 2"); ev(5300, "level", "up")
    lines.append("5400 enc 6 -1")
    ev(5600, "t1", "up")
    lines.append(f"{T_END} quit")
    return "\n".join(lines) + "\n"


def remain_script():
    lines = []
    def ev(t, k, d): lines.append(f"{t} key {K[k]:#x} {d}")
    ev(1500, "no", "down"); ev(1540, "no", "up")
    ev(T_TRIG, "t1", "down"); ev(T_TRIG + 100, "play", "down"); ev(T_TRIG + 140, "play", "up")
    ev(T_TRIG + 240, "t1", "up")
    end = (4418304).to_bytes(4, "big")
    lines.append(f"{T_TRIG + 400} poke " + ";".join(f"{VOICE_END_T1 + i:#x}={b:#x}" for i, b in enumerate(end)))
    ev(T_TRIG + 700, "t1", "down")
    lines.append(f"{T_TRIG + 1400} quit")
    return "\n".join(lines) + "\n"


def steady_script():
    lines = []
    def ev(t, k, d): lines.append(f"{t} key {K[k]:#x} {d}")
    ev(1500, "no", "down"); ev(1540, "no", "up")
    ev(T_TRIG, "t1", "down"); ev(T_TRIG + 100, "play", "down"); ev(T_TRIG + 140, "play", "up")
    ev(T_TRIG + 240, "t1", "up")
    ev(T_TRIG + 500, "t1", "down")
    lines.append(f"{T_TRIG + 3500} quit")
    return "\n".join(lines) + "\n"


def cue_script():
    lines = []
    def ev(t, k, d): lines.append(f"{t} key {k:#x} {d}")
    ev(1500, K["no"], "down"); ev(1540, K["no"], "up")
    ev(T_TRIG, K["t1"], "down"); ev(T_TRIG + 100, K["play"], "down"); ev(T_TRIG + 140, K["play"], "up")
    ev(T_TRIG + 240, K["t1"], "up")
    for t in (T_TRIG + 900, T_TRIG + 1900):
        ev(t, K["t1"], "down"); ev(t + 100, 0x29, "down"); ev(t + 140, 0x29, "up"); ev(t + 200, K["t1"], "up")
    ev(T_TRIG + 2700, 0x29, "down"); ev(T_TRIG + 2740, 0x29, "up")
    lines.append(f"{T_TRIG + 3300} quit")
    return "\n".join(lines) + "\n"


def frame_positions(text):
    """T1's position after each frame, counted in order (as speeds)."""
    last, prev = [], None
    for m in re.finditer(rf"^\s+\[\s*([\d.]+)\] \[{vr.POSITION:#x}\] <- (0x[0-9a-f]+|0)", text, re.M):
        s = float(m.group(1))
        if prev is None or s - prev > FRAME / 2:
            last.append(None)
        last[-1] = int(m.group(2), 16)
        prev = s
    return last


def plane_clear(path, x0, x1, y0, y1):
    """No pixel set in screen x0..x1, y0..y1 of an --lcd plane (tools/emu/README.md: 64
    columns x 128 rows, 8 bytes a row; pixel (x, y) is column 63 - y of row x)."""
    p = path.read_bytes()
    return not any((p[x * 8 + (63 - y) // 8] >> (7 - (63 - y) % 8)) & 1
                   for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))


def symbol(name):
    """A module symbol's address in the runtime the last build linked."""
    r = subprocess.run(["m68k-elf-nm", str(ROOT / "out/platform/runtime/runtime.elf")],
                       capture_output=True, text=True)
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] == name:
            return int(parts[0], 16)
    sys.exit(f"verify_vinyl_nudge: no {name} in the linked runtime")


def writes(text, addr):
    return [(float(m.group(1)), int(m.group(2), 16), int(m.group(3), 16)) for m in re.finditer(
        rf"^\s+\[\s*([\d.]+)\] \[{addr:#x}\] <- (0x[0-9a-f]+|0) \(\d\) at pc (0x[0-9a-f]+)", text, re.M)]


def judge_fader(text, series, show_left):
    tempo = writes(text, TEMPO_WORD)
    ours = [v for _, v, pc in tempo if pc == SET_TEMPO_STORE][-len(FADER_WANT):]
    first_edit = next((s for s, v, pc in tempo if pc == SET_TEMPO_STORE and v == FADER_WANT[0]), None)
    level = [(s, v) for s, v, _ in writes(text, LEVEL_T1) if first_edit is not None and s >= first_edit - SR]
    tail = sorted(v for _, v in series[-12:])[6] if len(series) >= 12 else None
    want = 2880 / FADER_WANT[-1]
    shows = [v for _, v, _ in writes(text, show_left)]
    ok = (tuple(ours) == FADER_WANT and not level and tail is not None and abs(tail - want) < 0.001
          and shows and shows[-1] == 0 and max(shows) == 12)
    return ok, (f"tempo writes {ours} (want {list(FADER_WANT)}), level writes after the edits {len(level)}, "
                f"end speed {tail if tail is None else round(tail, 4)} (want {want:.4f}), "
                f"readout timer {max(shows) if shows else None} -> {shows[-1] if shows else None}")


def speeds(text):
    """[(sample offset from the first frame, speed)] per WINDOW, speed in
    source frames per output sample, counted on whole 16-sample frames:
    the position after each frame's last write. Frames are counted in
    order (a write more than half a frame after the one before starts the
    next), not from the stamps' values: the port's stamps run ~15.9
    samples a frame and fall at sub-frame offsets that move with what a
    frame runs. A speed over the raw stamps (verify_repitch.position_speed)
    read 1.0077 for a track whose every frame advanced exactly 16, and
    dipped to 1.002 in one window; bucketing the stamps by 16 slipped a
    frame every ~400 ms (17 Oct 2026)."""
    last, prev, k = [], None, -1
    for m in re.finditer(rf"^\s+\[\s*([\d.]+)\] \[{vr.POSITION:#x}\] <- (0x[0-9a-f]+)", text, re.M):
        s = float(m.group(1))
        if prev is None or s - prev > FRAME / 2:
            k += 1; last.append(None)
        last[k] = int(m.group(2), 16)
        prev = s
    half, out = vr.LOOP_FRAMES // 2, []
    for w in range(len(last) // WINDOW_FRAMES - 1):   # the last is cut short by the quit
        d = (last[(w + 1) * WINDOW_FRAMES] - last[w * WINDOW_FRAMES]) & 0xFFFFFFFF
        d = d - (1 << 32) if d & 0x80000000 else d
        d = d - vr.LOOP_FRAMES if d > half else d + vr.LOOP_FRAMES if d < -half else d
        out.append((w * WINDOW, d / WINDOW))
    return out


def build(remix, dest):
    env = dict(os.environ, REMIX=remix, XBUS="1", SPEC="1"); env.setdefault("BUILD", "0")
    r = subprocess.run([sys.executable, str(ROOT / "tools/build/build_bus.py")], env=env,
                       capture_output=True, text=True, cwd=ROOT)
    if r.returncode:
        sys.exit(f"verify_vinyl_nudge: building {remix} failed:\n{(r.stdout + r.stderr)[-1500:]}")
    shutil.copy2(ROOT / "out/mainos_bus.bin", dest)


def run_case(a, name, machine, tstr, tsmode, image, keys=None, watch="", extra=()):
    work = OUT / name
    work.mkdir(parents=True, exist_ok=True)
    wav = OUT / "REPITCH_440_120.wav"
    if not wav.is_file():
        vr.make_loop(wav)
    vr.build_project(pathlib.Path(a.project).expanduser(), work / "project", tstr, tsmode, 120.0, 64, 127, machine)
    card = work / "card.img"
    vr.stage(work / "project", card, wav)
    sp = work / "keys.script"
    sp.write_text(keys or script())
    cmd = [str(EMU), "--image", str(image), "--card", str(card), "--set", "OCTABAM", "--project", "RIG",
           "--load-ms", "90000", "--mkii", "--dsp", "--live-script", str(sp),
           "--watch-mem", f"{vr.POSITION:#x},4" + watch, *extra]
    log = work / "port.txt"
    with open(log, "w") as f:
        f.write(" ".join(cmd) + "\n"); f.flush()
        r = subprocess.run(cmd, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT)
    text = log.read_text()
    if r.returncode or "ended on quit" not in text:
        return dict(error=f"port run failed (exit {r.returncode}) -- {log}")
    sp_ = speeds(text)
    if len(sp_) < 20 and name not in ("remain", "steady"):
        return dict(error=f"the track did not play ({len(sp_)} windows of position writes) -- {log}")
    return dict(series=sp_, log=log, text=text, work=work)


def judge(series, moves, eased):
    """-> (ok, message). `eased`: no window may carry more than STEP_SHARE of
    the whole excursion, and the way back after the release (peak to within
    10 % of the base) takes at least RETURN_MIN windows -- an unsmoothed
    nudge (stock's, on a stretched track) does it in one or two."""
    v = [s for _, s in series]
    base = sorted(v[2:8])[3]                       # after the trigger, before the hold
    k = max(range(len(v)), key=lambda i: abs(v[i] - base))
    peak, swing = v[k], v[k] - base
    tail = v[-6:]
    step = max(abs(b - a) for a, b in zip(v, v[1:]))
    back = next((j - k for j in range(k, len(v)) if abs(v[j] - base) < 0.1 * abs(swing)), None)
    msg = (f"base {base:+.4f}, peak {peak:+.4f}, end {tail[-1]:+.4f}, largest window step {step:.4f} "
           f"({step / abs(swing) if swing else 0:.0%} of the swing), back in {back} windows")
    if not moves:
        return abs(swing) < 0.002, msg + " (want no move)"
    ok = abs(base - 1.0) < 0.001 and swing > 0.02 and all(abs(t - base) < 0.002 for t in tail)
    if eased:
        ok = ok and step <= STEP_SHARE * swing and back is not None and back >= RETURN_MIN
    return ok, msg


def main():
    global OUT
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("remix", nargs="?", default="vinyl")
    ap.add_argument("--project", default=os.environ.get("OT_PROJECT", ""))
    ap.add_argument("--control", default="repitch", help="the remix without this module")
    ap.add_argument("--work", default="")
    ap.add_argument("--case", action="append", choices=sorted(CASES), help="default: all")
    ap.add_argument("--series", action="store_true", help="print every window's speed")
    a = ap.parse_args()
    if a.work:
        OUT = pathlib.Path(a.work).resolve()
    if "VINYL NUDGE" not in registry.remix(a.remix).modules:
        print(f"  [ -- ] verify_vinyl_nudge: {a.remix} carries no VINYL NUDGE"); return 0
    if not a.project and pathlib.Path("~/.octabam_project").expanduser().is_file():
        a.project = pathlib.Path("~/.octabam_project").expanduser().read_text().strip()
    if not a.project:
        print("  [SKIP] verify_vinyl_nudge: playback needs a project (OT_PROJECT=<dir> or --project)"); return 0
    if not (pathlib.Path(a.project).expanduser() / "project.work").is_file():
        sys.exit(f"verify_vinyl_nudge: {a.project} is not an Octatrack project directory")
    if not EMU.is_file() or not PY.is_file():
        print("  [SKIP] verify_vinyl_nudge: needs the port (make emu-cf) and the .venv (make emu-setup)"); return 0
    OUT.mkdir(parents=True, exist_ok=True)
    images = {"module": OUT / "module.bin", "control": OUT / "control.bin"}
    names = a.case or list(CASES)
    build(a.remix, images["module"])
    show_left = symbol("show_left")
    text_buf = symbol("text")
    drawn = symbol("drawn")
    if any(CASES[n][3] == "control" for n in names):
        if "VINYL NUDGE" in registry.remix(a.control).modules or "REPITCH" not in registry.remix(a.control).modules:
            sys.exit(f"verify_vinyl_nudge: the control remix {a.control} must carry REPITCH and not VINYL NUDGE")
        build(a.control, images["control"])

    fails = 0
    for name in names:
        machine, tstr, tsmode, which, moves = CASES[name]
        if name == "cue":
            res = run_case(a, name, machine, tstr, tsmode, images[which], keys=cue_script(),
                           watch=f";{GRID_REC:#x},4;{FLEX_1 + 1092:#x},4",
                           extra=("--mem-dump", f"{FLEX_1 + 300:#x},40={OUT / name / 'slices.bin'}"))
        elif name == "steady":
            res = run_case(a, name, machine, tstr, tsmode, images[which], keys=steady_script(),
                           watch=f";{drawn:#x},4")
        elif name in ("fader", "remain"):
            res = run_case(a, name, machine, tstr, tsmode, images[which],
                           keys=fader_script() if name == "fader" else remain_script(),
                           watch=f";{TEMPO_WORD:#x},4;{LEVEL_T1:#x},2;{show_left:#x},4",
                           extra=("--lcd", str(OUT / name / "lcd.bin"),
                                  "--mem-dump", f"{text_buf:#x},12={OUT / name / 'text.bin'}"))
        else:
            res = run_case(a, name, machine, tstr, tsmode, images[which])
        if "error" in res:
            print(f"  [FAIL] {name}: {res['error']}", flush=True); fails += 1; continue
        if name in ("fader", "remain"):
            shown = (res["work"] / "text.bin").read_bytes().split(b"\0")[0].decode("ascii", "replace")
        if name == "fader":
            ok, msg = judge_fader(res["text"], res["series"], show_left)
            clean = plane_clear(res["work"] / "lcd.bin", 36, 41, 4, 13)
            ok = ok and shown == "+1.9" and clean
            msg += f", text {shown!r} (want '+1.9'), x 36..41 {'clear' if clean else 'NOT clear'} after the field is stock's"
        elif name == "cue":
            import struct
            raw = (res["work"] / "slices.bin").read_bytes()
            trim = struct.unpack(">3i", raw[0:12])
            sl = [struct.unpack(">3i", raw[12 + 12 * i:24 + 12 * i]) for i in range(2)]
            count = [v for _, v, _ in writes(res["text"], FLEX_1 + 1092)]
            grid = [v for _, v, _ in writes(res["text"], GRID_REC)]
            pos = frame_positions(res["text"])
            jumps = sum(1 for p, q in zip(pos, pos[1:]) if (q - p) % vr.LOOP_FRAMES != FRAME)
            ok = (count[-2:] == [1, 2] and 0.7 * SR <= sl[0][0] <= 1.1 * SR and sl[1][0] > sl[0][0]
                  and all(x[1] == trim[1] and x[2] == -1 for x in sl) and grid.count(1) == 1 and jumps == 0)
            msg = (f"slices {sl}, trim end {trim[1]}, count writes {count[-2:]}, grid recording set "
                   f"{grid.count(1)} time(s) (want 1, the lone REC), {jumps} position jumps in {len(pos)} frames")
        elif name == "steady":
            ws = [v for _, v, _ in writes(res["text"], drawn)]
            first = ws.index(1) if 1 in ws else None
            drops = 0 if first is None else ws[first:].count(0)
            ok = first is not None and drops == 0
            msg = f"{len(ws)} draws of the field, {drops} back to stock's BPM after the first time left (want 0)"
        elif name == "remain":
            ok = re.fullmatch(r"-1:3[89]", shown) is not None
            msg = f"text {shown!r} (want '-1:38' or '-1:39')"
        else:
            ok, msg = judge(res["series"], moves, eased=name in ("dry", "off"))
        fails += not ok
        print(f"  [{'ok' if ok else 'FAIL'}] {name}: {msg} -- {res['log']}", flush=True)
        if a.series:
            print("    " + " ".join(f"{s:.4f}" for _, s in res["series"]))
    print(f"verify_vinyl_nudge: {'ok' if not fails else 'FAILED'} ({fails} failure(s)) -- {OUT}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
