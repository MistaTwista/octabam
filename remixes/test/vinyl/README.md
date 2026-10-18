# `vinyl` — REPITCH and VINYL NUDGE

Two ColdFire modules and the stock effects. For DJ-style use: a track that
follows the project tempo by speed, like a turntable, and that a held
[TRACK] + [LEFT]/[RIGHT] bends by hand to line it up.

## What is in it

- **REPITCH** — `RPCH` in the TSTR selector: speed = project BPM / sample BPM, live. `modules/repitch/README.md`.
- **VINYL NUDGE** — [TRACK] + [LEFT]/[RIGHT] on a track on OFF or RPCH bends its speed and pitch, eased in and out; NORM and BEAT keep stock's tempo nudge. [TRACK] + LEVEL (pushed: coarse) or UP/DOWN moves the track's sample tempo, a pitch fader that stays, shown at the BPM readout. `modules/vinyl-nudge/README.md`.
- the 14 stock FX2 effects, listed so the chooser is stock's.

## Status

On MistaTwista's MKII as OCTABAM1 (17 Oct 2026): the nudge glides, no clicks. `verify_vinyl_nudge` measures it under the port.

## Build

```bash
make image REMIX=vinyl BUILD=1    # -> out/OCTATRACK_OCTABAM1.bin
```

[BUILDING.md](../../../docs/guide/BUILDING.md) is the walk-through from a fresh machine to a flashed unit. `make check REMIX=vinyl` runs every gate first.
