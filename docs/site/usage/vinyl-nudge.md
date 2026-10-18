The track keys become a DJ deck's controls: hold a track and push its
speed like a hand on a turntable, ride a pitch fader that stays, read how
long the track has left, and drop a cue to start it from later.

## The Keys

| Keys | Does |
|---|---|
| [TRACK] + LEFT / RIGHT | slows down / speeds up the held track while held, and eases back when let go |
| [TRACK] + LEVEL | the held track's tempo, 1/24 BPM a detent; clockwise is faster |
| [TRACK] + LEVEL turned while pushed | the same, a whole BPM a detent |
| [TRACK] + UP / DOWN | the held track's tempo, 1/24 BPM a press; UP is faster |
| [TRACK] held | the BPM field shows the time the track has left |
| [TRACK] + REC | adds a slice from where the track plays to its end: a cue |
| [TRACK] + PLAY / STOP | as stock: start the held track from the top, stop it |

LEFT and RIGHT with no track held still nudge the master tempo, and LEVEL
with no track held is still the track level.

## The Nudge

On a track whose TSTR is OFF, the nudge moves speed and pitch together,
as a record does, and glides to its speed and back instead of jumping:
the size is stock's nudge (1 % on the press, 2 % more each repeat, 10 %
at most). A track on NORM or BEAT keeps stock's nudge, which moves its
tempo and keeps its pitch.

## The Tempo Fader

LEVEL and UP/DOWN with a track held change the tempo the sample is set
to, the TEMPO the audio editor's ATTR page shows. A track on NORM or BEAT
plays at the project tempo divided by that tempo, so lowering it plays
the track faster; the keys are turned around so that clockwise and UP
are faster, as a pitch fader pushed toward +. While the fader moves, the
BPM field at the top left shows how far the track runs from its own
speed, in percent, with its sign: `+1.9`, `-0.5`. About a second after
the last step it goes back to the time left (track still held) or the
BPM.

The value is the sample slot's and is saved with the project. The
sample's `.ot` file keeps its own until the audio editor saves it. On an
OFF track the sample tempo is not used, so the fader does nothing there.

## The Time Left

While a track key is held and its STATIC or FLEX sample plays, the BPM
field shows the time to the end of its trim at the speed it plays now,
nudge and fader included: `-1:42`, and `-12'` (minutes only) from ten
minutes. A looped track counts to its trim end, not the loop's; a track
playing backwards shows the BPM.

## The Cue

[TRACK] + REC adds a slice to the held track's sample, from where it
plays now (or where it stopped) to the end of its trim, and sorts it in
among the sample's slices as the audio editor's ADD SLICE does; the
screen shows `ADDED SLICE!`. The track keeps playing. To start it there,
set SLIC to ON in the track's playback setup, choose SLICES with
FUNC + UP/DOWN and press the slice's trig key. The slices are saved with
the project and are there after a power cycle.
