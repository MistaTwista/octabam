"""Stock effects, REPITCH and VINYL NUDGE: a dry track a hand can bend."""

from remix.schema import Proof, Remix

REMIX = Remix(
    name="vinyl",
    family="mods", proof=Proof.CHECK, proof_note="builds and boots under the port",
    doc="stock effects, REPITCH in the TSTR selector, and VINYL NUDGE: [TRACK] + [LEFT]/[RIGHT] nudge, [TRACK] + LEVEL / UP / DOWN tempo fader.",
    modules=("REPITCH", "VINYL NUDGE", "FILTER", "EQUALIZER", "DJ EQ", "PHASER", "FLANGER",
             "CHORUS", "SPATIALIZER", "COMB FILTER", "COMPRESSOR", "LO-FI",
             "DELAY", "PLATE REV", "SPRING REV", "DARK REV"),
    fallback="NONE",
)
