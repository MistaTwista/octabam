"""VINYL NUDGE -- [TRACK] + [LEFT]/[RIGHT] bends a dry track's speed, pitch
and all, like a hand on a turntable, and eases in and out.

Stock's LEFT/RIGHT handler with track keys held writes a per-track nudge
through 0x40000e78 into voice +38, which only a timestretched track reads
(the renderer's tempo ratio). On a dry track (TSTR OFF, or REPITCH, which
the renderer resolves to OFF) this module makes that nudge the track's
target and eases the playback increment toward it once a frame: the
ColdFire source supplier and the DSP voice command both read the
increment, so position and pitch move together. A timestretched track
keeps stock's tempo nudge. Read from 1.40C's disassembly (10 Oct 2026);
the stock nudge's tempo-only effect on a NORM track was heard on an MKII
(11 Oct 2026). With a track key held, LEVEL and UP/DOWN move the track's
sample tempo through the audio editor's own setter; the BPM field shows
the fader's percentage while it moves and, while a track key is only
held, the time its sample has left. modules/vinyl-nudge/README.md.
"""

from remix.schema import Category, Detour, Gate, Kind, Linked, Module, Proof, SymbolRef

H = bytes.fromhex

MODULE = Module(
    name="vinyl-nudge",
    key="VINYL NUDGE",
    kind=Kind.CF_PATCH,
    category=Category.MACHINES, author="MistaTwista", author_url="https://github.com/MistaTwista",
    proof=Proof.HARDWARE, proof_note="MistaTwista's MKII, OCTABAM1-5, 17-18 Oct 2026; `verify_vinyl_nudge`",
    doc="[TRACK] + [LEFT]/[RIGHT] on a dry track (TSTR OFF or REPITCH): a turntable "
        "nudge, speed and pitch together, eased in and out; [TRACK] + LEVEL or UP/DOWN: "
        "the sample tempo as a pitch fader, shown at the BPM readout.",
    linked=(Linked("nudge", "modules/vinyl-nudge/nudge.s", dram=True),
            Linked("tempo", "modules/vinyl-nudge/tempo.s", dram=True),
            Linked("cue", "modules/vinyl-nudge/cue.s", dram=True)),
    detours=(
        Detour(0x40000E78, H("222f0004206f0008"), "nudge", "nudge_set",
               "the per-track nudge setter: a dry track's offset becomes its target", pad_to=8),
        Detour(0x40004108, H("287980001c80"), "nudge", "inc_hook",
               "ease toward the target and scale the shared CPU/DSP playback increment"),
        Detour(0x400491A0, H("2f02206f0008222f000c"), "tempo", "tempo_keys",
               "UP/DOWN with a track key held step its sample tempo", pad_to=10),
        Detour(0x4004B08C, H("4e56ffe048d7040c"), "tempo", "readout",
               "the BPM field: the fader's percentage while it moves, the held track's time left",
               pad_to=8),
        Detour(0x40048774, H("4aaf0008670000c0"), "cue", "rec_cue",
               "REC with a track key held: a slice from the play position to the trim end", pad_to=8),
    ),
    symbol_refs=(
        SymbolRef(0x400D1652, 0x00000000, "tempo", "tempo_levels",
                  "the track keys' held layer gets an encoder table: LEVEL moves the sample tempo"),
    ),
    gates=(Gate("tools/verify/verify_vinyl_nudge.py"),),
)
