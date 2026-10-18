# `vinyl-nudge` — VINYL NUDGE

[TRACK] + [LEFT]/[RIGHT] on a dry track bends its speed, pitch and all, the
way a hand bends a turntable, and eases in and out; [TRACK] + LEVEL and
[TRACK] + UP/DOWN move the track's sample tempo, a pitch fader that stays;
where the BPM is, the fader's percentage while it moves and the time the
held track has left; [TRACK] + REC sets a cue, a slice from where the
track plays to its end.

Hold a track key and press or hold LEFT or RIGHT: a track that plays dry
(TSTR **OFF**; any value the voice renderer resolves to OFF, as REPITCH's
RPCH did) slows down or speeds up together with its pitch, gliding there
instead of jumping, and glides back when the keys are let go. This is how
two records are lined up by ear. A track on NORM or BEAT keeps stock's
own nudge, which moves its tempo and keeps its pitch. The master tempo is
never touched, as in stock.

Hold a track key and turn LEVEL (or press UP/DOWN): the track's sample
tempo, the TEMPO an audio editor's ATTR page shows, moves by 1/24 BPM a
step, a whole BPM a step with LEVEL pushed. Clockwise and UP lower it,
which on a NORM or BEAT track (or an RPCH one) plays it faster, as a pitch fader
pushed toward + would. While the fader moves, the BPM field at the top
left shows how far the track runs from its own speed, in percent, signed
("+1.9", "-0.5": project tempo / sample tempo - 1; no "%" sign, which does
not fit), for about a second after the last step. While a track key is
only held, the field shows the time its sample has left to play at the
speed it plays now ("-1:42"; "-12'" from ten minutes). Otherwise, and on a
track that is not playing, it is stock's BPM. The value is
the slot's, saved with the project; the sample's `.ot` file keeps its own
until the audio editor saves it. On an OFF track the tempo is not used, so
the fader does nothing audible there.

[TRACK] + REC adds a slice to the held track's sample from where it plays
now (or where it stopped) to the end of its trim, sorted among the
sample's slices, as the audio editor's ADD SLICE does; the track keeps
playing. Start it there later with the SLICES trig mode (SLIC on in its
playback setup): the trig key of that slice. [TRACK] + PLAY still starts
it from the top.

## Keys

| keys | stock 1.40C | with VINYL NUDGE |
|---|---|---|
| LEFT / RIGHT | nudge the master tempo | unchanged |
| [TRACK] + LEFT / RIGHT, track on NORM or BEAT | nudge that track's tempo, pitch kept | unchanged |
| [TRACK] + LEFT / RIGHT, a dry track (OFF) | nothing audible | speed and pitch, eased |
| [TRACK] + PLAY / STOP | trigger / stop the held tracks | unchanged |
| [TRACK] + LEVEL | the track level (as LEVEL alone) | the sample tempo, 1/24 BPM a step; pushed, 1 BPM |
| [TRACK] + UP / DOWN | nothing | the sample tempo, 1/24 BPM a step (UP faster) |
| [TRACK] held | nothing shown | the BPM field shows the time left |
| [TRACK] + REC | REC alone: grid recording on | a slice from the play position to the trim end (a cue), "ADDED SLICE!" |

The size of the nudge is stock's: −1 % / +1 % on the press, another 2 % on
each key repeat, ±10 % at most, back to 0 on release. The module eases the
track toward that value every frame: `current += (target − current) >> 9`.

## REPITCH

Every hardware run (OCTABAM1-5) and the measurements before 18 Oct 2026
carried repeat98's REPITCH beside this module, and the DJ use was a
track on RPCH: it follows the project tempo by speed, so the nudge is a
turntable's and the fader moves speed and pitch together. REPITCH left
main on 13 Oct 2026 (`git show bef4ecdf^:modules/repitch/README.md`);
this module does not need it: "dry" is the renderer's resolved TSTR 0,
which OFF is and which RPCH was, and the tempo fader works on any track
that reads the sample tempo (NORM, BEAT, RPCH). The hooks sit beside
REPITCH's and share an image with it (`0x40004108` begins where its
`rate_hook` span ended). Since the rebase the test remix carries no
REPITCH and the gate's cases run on OFF and NORM.

## Measured

- 🟡 Read from the 1.40C image (10 Oct 2026, objdump): the track-held key
  layer (`0x400d164a`) binds STOP, PLAY, BANK, YES, NO and `0x18`, not the
  arrows; the main LEFT/RIGHT handler (`0x4004b970`) builds a mask of held
  track keys (`0x460d16b4`) and, when it is not empty, leaves the master
  tempo alone and calls `0x40000e78(track, offset)` per held track. The
  offset is Q16, from a per-mille factor at `0x46c7d328` (990 or 1010 on the
  press, ±20 a repeat, 900..1100); release calls it with 0 for all eight.
  `0x40000e78` writes voice `+38`, which scales the project tempo the
  renderer uses for its stretch ratio (`docs/firmware/REPITCH.md`). Its
  six callers are all in that handler.
- ✅ On an MKII with stock 1.40C (11 Oct 2026, by ear): [TRACK] + RIGHT on
  a playing STATIC track moved its tempo and not its pitch;
  [TRACK] + UP/DOWN did nothing.
- ✅ Under the port (`verify_vinyl_nudge`, 17 Oct 2026, a fresh MKII
  project; the transport stopped, T1 started with [TRACK] + PLAY, then
  [TRACK] + RIGHT held 2 s), T1's speed per 50 ms window, counted on whole
  frames:

  | case | while held | on release |
  |---|---|---|
  | `dry` FLEX, RPCH, this module | 1.000 → 1.069, a glide (largest window step 0.0145, 21 % of the swing) | back to 1.000 over 8 windows (~0.4 s) |
  | `off` STATIC, OFF, this module | 1.000 → 1.068, the same glide | the same |
  | `stretch` FLEX, NORM, this module | stock's steps: 1.010, 1.030, 1.050, 1.070, one every ~0.48 s | 1.070 → 1.000 in one window |
  | `control` FLEX, RPCH, REPITCH remix without it | 1.000 throughout: stock's nudge is inert on a dry track | -- |

  The same run with both hooks restored to stock bytes in RAM (`--poke`)
  stays at 1.000 as well, so the move in `dry` is the hooks'.
- ✅ The ease runs once a 16-sample frame: under the port T1's current
  offset steps once per frame stamp (`--watch-mem` on the module's
  `currents`), the first press setting the target to 655 (+1 %).
  `>> 9` is a time constant of 512 frames, ~0.19 s at 44.1 kHz; the
  release measured above (90 % of the way back in ~0.4 s) agrees.
- 🟡 Read from the image (17 Oct 2026): the audio editor's TEMPO edits
  (`0x4006eb00`, `0x4006eb6c`) all write through `0x40099090(settings,
  bpm24, minimum length)`, which clamps to 720..7200 and stores BPM×24
  (`+0x114`), its reciprocal from the table at `0x400abf38` (`+0x118`) and
  the trim and loop lengths (`+0x11c`, `+0x120`) under a masked SR. CUE's
  held layer (`0x400bf2a0`) has an encoder table with one LEVEL record
  (`0x400bf274`, handler `0x4004e98c`, ×7 while LEVEL is pushed at
  `0x46c7debe`); the track keys' held layer (`0x400d164a`) has none. Every
  BPM readout splits the tempo through `0x4009c5f4`, which takes it from
  `0x4009c5b8`; stock's nudge timer redraws the readout through
  `0x4004b08c`; `0x40031a0c(period, callback)` is the UI's periodic timer.
- ✅ Under the port (`verify_vinyl_nudge` `fader`, 17 Oct 2026): T1 held,
  LEVEL +5, UP, UP, LEVEL pushed +2, LEVEL −1 wrote the slot's BPM×24 as
  2880 → 2875, 2874, 2873, 2825, 2826, each by the setter's own store
  (`0x40099126`); T1's level was not written (a LEVEL turn with no track
  held writes it, 108 → 111, the control); the RPCH track ended at 1.019
  = 2880 / 2826, and the field's text read "+1.9". With T1's trim end
  poked to 100.2 s and T1 held 1.3 s into the play, the field read
  "-1:38" (`remain`). LCD planes by eye (18 Oct 2026): "+1.9", "-1:38",
  then stock's "120.0" with nothing left over. The big font draws past the
  width `0x40012f30` sums: a time right-aligned at x 35 left pixels in x 36
  and 37, where stock's clear stops; the module clears to x 39 when it
  draws and once more when the field goes back to stock, and `fader`
  checks those columns are empty at the end.
- 🟡 The voice record (T1, three dumps under the port): `+44` the trim
  end, `+68` the position, byte `+26` 1 while it plays and 0xff after
  [TRACK] + STOP, while the position keeps moving through the release.
- ✅ Under the port (`verify_vinyl_nudge` `cue`, 18 Oct 2026): T1 (FLEX,
  RPCH) started, T1 + REC at ~0.9 s and ~1.9 s, then REC alone: slot 1
  ended with slices (39680, 88200, −1) and (83792, 88200, −1), the count
  written 1 then 2 by the module, grid recording switched on once (the
  lone REC), and all 8,819 frames advanced 16: no jump at either cue.
  Read from the image (18 Oct 2026): ADD SLICE (`0x40073124`) refuses past
  62 slices, writes {start, end, −1} after the last under a masked SR and
  sorts with `0x40070c28(+312, count)`; stock REC with a track held is
  REC alone (grid recording on, under the port).
- ✅ A STATIC voice's `+26` is not steady while it plays: under the port
  (18 Oct 2026, `--watch-mem`) it cycles 1 → 0 → 0xff → 1 every ~58 ms
  (written at `0x4000863a`, `0x40008862`, `0x400084b8`), a FLEX voice's
  stays 1. OCTABAM3, reading it alone, drew stock's BPM into the time left
  about one draw in five on the unit (MistaTwista's MKII, by eye: the time
  "blinks and tries to show the tempo"). The module counts a voice as playing for 0.3 s
  of DMA timer 3 after it last read 1 (a grace counted in draws,
  OCTABAM4, held before the rebase onto main of 18 Oct 2026 and let one
  draw through after it); `steady` holds T1 of a STATIC track for 3.5 s
  and counts the draws of stock's BPM: 0, and 7 with the window set to 0
  (the control).
- ✅ "Held" is the panel's key row 2 (`0x46100b1a`, bit t = track key t),
  not the key cache word stock's LEFT/RIGHT handler tests (`0x46c7da6e +
  24·t`): under the port (18 Oct 2026) a layer rebuild at `0x4003180c`
  wrote 0 to that word 80 ms into a hold, and a draw in that moment showed
  the BPM.
- ✅ On a NORM or BEAT track the time left runs at project / sample tempo,
  the rate the renderer moves its position by; the increment stays 1.0
  there (`remain-norm`: sample tempo poked to 60 BPM at a 120 BPM project,
  the time left half, "-0:49"; before the fix it read "-1:38"). Such a
  voice re-reads its trim end from the slot every chunk.
- Builds and links (`make bus REMIX=vinyl`): three DRAM units, 1,478 B
  appended; `make check REMIX=vinyl` passes, REPITCH's hook contracts and
  playback cases included.

Not measured: hardware timing, the readout on the unit, and pitch in this
gate (speed and pitch move together on a dry track because both come from
the one increment; REPITCH's playback cases measure the pitch).

## On the unit

- ✅ MistaTwista's MKII, image OCTABAM1 (`remixes/test/vinyl`, `.bin`
  sha256 `3bfab10d…1572ed3`), 17 Oct 2026, flashed from the card, by ear:
  [TRACK] + LEFT/RIGHT bends a playing RPCH track's speed and pitch
  smoothly, no clicks.
- ✅ The same MKII, OCTABAM2 and OCTABAM3 (17-18 Oct 2026): the tempo
  fader on [TRACK] + LEVEL / UP / DOWN moves the track the right way; the
  percentage and the time left show right. OCTABAM3's time left flashed
  stock's BPM on a STATIC track (the play-state byte, under Measured);
  fixed from OCTABAM4.
- ✅ The same MKII, OCTABAM5 (`.bin` sha256 `c4a32f78…c151a`), 18 Oct
  2026: [TRACK] + REC sets cues and the slices start from the SLICES trig
  mode, and they are there again after a power cycle.

## Open

- A looped track's time left counts to its trim end, not the loop's.
- Reverse playback shows stock's BPM (the time left assumes forward).
- Pressing LEVEL shows the track level in the LEV box, as stock does; while
  a track is held it is the coarse modifier, not a level change.
- A brake to a stop and a spin back up.
- The stock factor's repeat steps on a timestretched track stay stock's
  (they jump); easing them too means writing voice `+38` from the same
  per-frame step.
- MKI: the arrows and track keys are the same codes on both models; not run.

## Gates

- `python3 tools/verify/verify_vinyl_nudge.py [REMIX] --project <dir>`
  (the manifest's gate; `make check` runs it, playback with `OT_PROJECT`):
  the stock track trigger ([TRACK] + PLAY) with the transport stopped, then
  [TRACK] + RIGHT held for two seconds; T1's sample position watched, speed
  per 50 ms window counted on whole frames. `dry` (FLEX, OFF) and `off`
  (STATIC, OFF) must start at 1.000, rise by more than 0.02 while held and
  end within 0.002 of the start, eased: no window carries more than 35 % of
  the swing, and the way back to within 10 % of the start takes at least
  three windows (stock's own nudge, `stretch`, does it in one, 88 %);
  `stretch` (NORM) must still move (stock's nudge); `control` (OFF, the
  same image with the two nudge hooks put back to stock's bytes by
  `--poke`) must not move. `fader`: the tempo writes, no
  level write, the end speed, the readout timer, the text "+1.9" and the
  columns right of the field empty at the end. `remain`: the time left.
  `remain-norm`: a NORM track whose sample tempo is poked to 60 BPM plays
  at 2× and the time left is half. `steady`: the time left holds on a
  STATIC track. `cue`: two cues,
  sorted, no grid recording, no position jump.

## The patch

| site | what |
|---|---|
| `0x40000e78` `nudge_set` | the per-track nudge setter: on a STATIC or FLEX track whose resolved TSTR (voice `+24`) is 0, the offset becomes the track's target and voice `+38` gets 0; otherwise stock |
| `0x40004108` `inc_hook` | after the increment builder's store, where stock and REPITCH's `rate_hook` both arrive: on the per-frame recompute call, ease the track's current offset toward its target and scale the increment by `1 + current/65536`, clamped to 2×, stored back to state `+36` for the CPU supplier |

| `0x400491a0` `tempo_keys` | the main layer's UP/DOWN handler: a press or repeat with a track key held steps the held tracks' sample tempo; otherwise stock |
| `0x4004b08c` `readout` | the BPM field's drawer: the fader's percentage while it moves, the first held track's time left while a track key is held, in the big font right-aligned at x 35; stock's otherwise. Registers the readout's UI timer at its first call |
| `0x40048774` `rec_cue` | REC's handler: with a track key held, a slice from each held track's position to its trim end (stock's ADD SLICE write and sort), and the press and its release go no further; otherwise stock |
| `0x400d1652` → `tempo_levels` | the track keys' held layer gets an encoder table: LEVEL calls `tempo_level` |

The first two hooks do not overlap REPITCH's (`0x40004100..0x40004107` ends
where `inc_hook` begins), so the two modules share an image.
