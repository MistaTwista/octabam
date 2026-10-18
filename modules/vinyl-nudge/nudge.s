| VINYL NUDGE -- [TRACK] + [LEFT]/[RIGHT] on a track that plays dry (TSTR
| OFF, or REPITCH) bends its playback speed, pitch and all, like a hand on
| a turntable, and eases back when the keys are let go.
|
| Stock's handler for LEFT/RIGHT with track keys held (0x4004b970) computes
| a per-track nudge (Q16 offset: +-1 % on the press, +-2 % a repeat, +-10 %
| at most) and writes it through 0x40000e78(track, offset) into voice +38,
| which scales the project tempo the voice renderer uses for its
| timestretch ratio. A dry track never reads that ratio: the renderer
| advances it by the frames the DSP consumed, which the playback increment
| sets. So on a dry track the stock nudge does nothing.
|
| nudge_set takes over 0x40000e78 for dry tracks: the offset becomes the
| track's TARGET and voice +38 gets 0. A timestretched track keeps stock's
| path untouched. inc_hook sits after the increment builder's store
| (0x40004108, where stock's own path and REPITCH's rate_hook both arrive
| with the finished increment in d0): once a frame (the recompute call) the
| track's CURRENT offset moves toward its target, and the increment, which
| the ColdFire source supplier and the DSP voice command both use, is
| scaled by (1 + current / 65536).
        .text

        .global nudge_set
        .global inc_hook

        .equ    VOICES, 0x800049d8      | per-track voices, 168 B
        .equ    V_MACHINE, 20           | 0 STATIC, 1 FLEX, ... 4 PICKUP
        .equ    V_TSTR, 24              | the renderer's resolved TSTR, 0 = dry
        .equ    STATES, 0x80004898      | per-track increment states, 40 B; a3 in the builder
        .equ    S_INC, 36
        .equ    INC_MAX, 0x08000000     | 2x: stock's own ceiling
        .equ    EASE_SHIFT, 9           | current += (target - current) >> EASE_SHIFT, a frame

| 0x40000e78, void set(int track, int offset): displaced are its first two
| instructions, `move.l 4(sp),d1; movea.l 8(sp),a0`; stock resumes at
| 0x40000e80 with d1 = track, a0 = the value it writes to voice +38.
| d0/d1/a0/a1 are the callee's scratch.
nudge_set:
        move.l  4(%sp),%d1
        movea.l 8(%sp),%a0
        moveq   #7,%d0
        cmp.l   %d1,%d0
        bcs.s   .ns_stock               | stock refuses the track as well
        move.l  #168,%d0
        mulu.l  %d1,%d0
        lea     (VOICES).l,%a1
        adda.l  %d0,%a1
        moveq   #1,%d0
        cmp.b   V_MACHINE(%a1),%d0
        bcs.s   .ns_stock               | not STATIC or FLEX
        tst.b   V_TSTR(%a1)
        bne.s   .ns_stock               | stretched: stock's tempo nudge
        lea     (targets).l,%a1
        move.l  %a0,(%a1,%d1.l*4)
        suba.l  %a0,%a0                 | voice +38 stays neutral
.ns_stock:
        jmp     (0x40000e80).l

| 0x40004108: d0 = the finished increment (Q26), a3 = the track's state,
| 4(sp)..: the builder's frame (the recompute flag is bit 4 of 67(sp) until
| 0x400041ac clears it). Displaced: `movea.l 0x80001c80,a4`. Only the
| recompute call (once a frame) eases and scales; the other call reads
| S_INC back, which already carries the scaled value.
inc_hook:
        btst    #4,67(%sp)
        beq.w   .ih_out
        lea     -24(%sp),%sp
        movem.l %d1-%d5/%a0,(%sp)
        move.l  %a3,%d1
        subi.l  #STATES,%d1
        moveq   #40,%d2
        divu.l  %d2,%d1                 | the track
        moveq   #7,%d2
        cmp.l   %d1,%d2
        bcs.s   .ih_restore
        lea     (targets).l,%a0
        move.l  (%a0,%d1.l*4),%d2       | target
        lea     (currents).l,%a0
        move.l  (%a0,%d1.l*4),%d3       | current
        move.l  %d2,%d4
        sub.l   %d3,%d4                 | target - current
        beq.s   .ih_eased
        moveq   #EASE_SHIFT,%d5
        asr.l   %d5,%d4
        bne.s   .ih_step
        moveq   #1,%d4                  | the last few steps: one at a time
        cmp.l   %d3,%d2
        bgt.s   .ih_step
        moveq   #-1,%d4
.ih_step:
        add.l   %d4,%d3
        move.l  %d3,(%a0,%d1.l*4)
.ih_eased:
        tst.l   %d3
        beq.s   .ih_restore             | neutral: the increment as stock built it
        | d0 += d0 * d3 / 65536, by magnitudes: |d0| = hi:lo halves, so
        | hi * |d3| + (lo * |d3|) >> 16 stays inside 32 unsigned bits.
        move.l  %d0,%d1
        bpl.s   .ih_absinc
        neg.l   %d1
.ih_absinc:
        move.l  %d3,%d2
        bpl.s   .ih_abscur
        neg.l   %d2
.ih_abscur:
        move.l  %d1,%d4
        clr.w   %d4
        swap    %d4                     | hi
        mulu.l  %d2,%d4
        andi.l  #0xffff,%d1             | lo
        mulu.l  %d2,%d1
        clr.w   %d1
        swap    %d1
        add.l   %d4,%d1                 | |d0 * d3| >> 16
        move.l  %d0,%d4
        eor.l   %d3,%d4                 | the product's sign
        bpl.s   .ih_add
        neg.l   %d1
.ih_add:
        add.l   %d1,%d0
        tst.l   %d0
        ble.s   .ih_store
        cmpi.l  #INC_MAX,%d0
        bls.s   .ih_store
        move.l  #INC_MAX,%d0
.ih_store:
        move.l  %d0,S_INC(%a3)          | the CPU supplier reads it back at 0x40004172
.ih_restore:
        movem.l (%sp),%d1-%d5/%a0
        lea     24(%sp),%sp
.ih_out:
        movea.l (0x80001c80).l,%a4      | displaced
        jmp     (0x4000410e).l

        .data
        .balign 4
targets:  .long 0,0,0,0,0,0,0,0         | the stock nudge, as the track's goal
currents: .long 0,0,0,0,0,0,0,0         | where the track's speed is on its way there
