# `vinyl` — VINYL NUDGE

One ColdFire module and the stock effects. For DJ-style use of STATIC and
FLEX tracks: the track keys nudge a track like a turntable, ride a tempo
fader, show the time a track has left and set cues.

## What is in it

- **VINYL NUDGE** — [TRACK] + [LEFT]/[RIGHT] on a dry (OFF) track bends its speed and pitch, eased in and out; NORM and BEAT keep stock's tempo nudge. [TRACK] + LEVEL (pushed: coarse) or UP/DOWN moves the track's sample tempo, a pitch fader that stays, its signed percentage shown at the BPM field; a held track shows its time left there. [TRACK] + REC adds a slice from the play position to the end: a cue. `modules/vinyl-nudge/README.md`.
- the 14 stock FX2 effects, listed so the chooser is stock's.

## Status

The module ran on MistaTwista's MKII as OCTABAM1-5 (17-18 Oct 2026) with repeat98's REPITCH beside it, before REPITCH left main; this selection, without REPITCH, is gated under the port by `verify_vinyl_nudge` and not flashed as such.

## Build

```bash
make image REMIX=vinyl BUILD=1    # -> out/OCTATRACK_OCTABAM1.bin
```

[BUILDING.md](../../../docs/guide/BUILDING.md) is the walk-through from a fresh machine to a flashed unit. `make check REMIX=vinyl` runs every gate first.
