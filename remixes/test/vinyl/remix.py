"""Stock effects and VINYL NUDGE: track keys that nudge, fade, time and cue a track."""

from remix.schema import Proof, Remix

REMIX = Remix(
    name="vinyl",
    family="mods", proof=Proof.PORT, proof_note="verify_vinyl_nudge; the module ran on MistaTwista's MKII in OCTABAM1-5, with REPITCH beside it",
    doc="stock effects and VINYL NUDGE: [TRACK] + [LEFT]/[RIGHT] nudge, [TRACK] + LEVEL / UP / DOWN tempo fader, time left, [TRACK] + REC cue.",
    modules=("VINYL NUDGE", "FILTER", "EQUALIZER", "DJ EQ", "PHASER", "FLANGER",
             "CHORUS", "SPATIALIZER", "COMB FILTER", "COMPRESSOR", "LO-FI",
             "DELAY", "PLATE REV", "SPRING REV", "DARK REV"),
    fallback="NONE",
)
