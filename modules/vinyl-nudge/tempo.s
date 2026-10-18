| VINYL NUDGE, the tempo fader and the readout. With a track key held,
| LEVEL and UP/DOWN move the track's sample tempo (the slot's BPMx24, what
| AED > ATTR > TEMPO edits); the BPM readout at the top left shows, while
| the fader moves, how far the track runs from its own speed in percent
| ("+1.9": a signed number, which a tempo never is), and while a track
| key is only held, the time its sample has left to play ("-1:42").
| Otherwise it is stock's.
|
| A track plays at project / sample tempo on RPCH (and NORM/BEAT), so a
| LOWER sample tempo is a FASTER track: LEVEL clockwise and UP lower it,
| as a pitch fader pushed toward + would, and the percentage the readout
| shows, project / sample - 1, rises with it. One step is 1/24 BPM; LEVEL
| turned while pushed steps a whole BPM. The write is the audio editor's
| own, 0x40099090(settings, bpm24, 64): it clamps to 720..7200 and
| derives the reciprocal and the trim/loop lengths under a masked SR.
|
| Input: the track keys' held layer (0x400d164a) has no encoder table;
| the manifest points it at tempo_levels, one record for LEVEL, the shape
| of CUE's (0x400bf274). UP/DOWN with a track held reach the main layer's
| handler (0x400491a0), which tempo_keys enters first. "Held" is the panel
| link's own record of key row 2 (0x46100b18 + 2, the parser's last state
| of the row, docs/firmware/PANEL.md section 4b): bit t is track key t.
| Not the key cache word stock's LEFT/RIGHT handler tests (0x46c7da6e +
| 24 * track): a layer rebuild zeroes it for a moment while the key is
| held (0x4003180c, under the port, 18 Oct 2026), and a draw then showed
| the BPM.
|
| Readout: 0x4004b08c draws the BPM field (cleared x 13..35, y 51..59 with
| 0x40012254; the whole BPM in the big font 0x400ba83a, then the tenths).
| readout draws its own string in the big font, right-aligned at the
| field's edge as stock's "P%d" is, when it has one, and runs stock's
| otherwise. A stock UI timer (0x40031a0c, every TICK_PERIOD ticks,
| registered at the first draw) counts show_left down and redraws while a
| track key is held and once more when it is let go.
        .text

        .global tempo_keys
        .global tempo_levels
        .global readout

        .equ    VOICES, 0x800049d8      | per-track voices, 168 B
        .equ    V_SETTINGS, 8           | the bound sample's settings
        .equ    V_MACHINE, 20           | 0 STATIC, 1 FLEX
        .equ    V_TSTR, 24              | the renderer's resolved TSTR: 0 dry, else stretched
        .equ    V_STATE, 26             | 1 while it plays; a STATIC voice cycles 1, 0, 0xff every
                                        | ~58 ms as it streams (under the port, 18 Oct 2026), so a
                                        | voice counts as playing for LIVE_COUNTS after its last 1
        .equ    V_END, 44               | the trim end, frames
        .equ    V_POS, 68               | the play position, frames
        .equ    STATES, 0x80004898      | per-track increment states, 40 B
        .equ    S_INC, 36               | the playback increment, Q26 (nudge and fader included)
        .equ    TRACK_ROW, 0x46100b1a   | the panel's key row 2 as last reported: bit t = track key t held
        .equ    LEVEL_PUSHED, 0x46c7debe
        .equ    PROJECT_BPM24, 0x80001814
        .equ    S_BPM24, 0x114
        .equ    SET_TEMPO, 0x40099090   | (settings, bpm24, minimum length)
        .equ    TIMER_ADD, 0x40031a0c   | (period, callback) -> slot, periodic
        .equ    CLEAR, 0x40012254       | (surface, x0, y0, x1, y1, ink)
        .equ    TEXT_W, 0x40012f30      | (font, limit, string) -> width
        .equ    TEXT, 0x40012bd8        | (font, surface, x, y, limit, string)
        .equ    SURFACE, 0x400bf10a
        .equ    BIG, 0x400ba83a
        .equ    DIRTY, 0x46c7c72c       | stock's drawer sets it last
        .equ    KEY_UP, 0x33
        .equ    COARSE, 24              | BPMx24 a step with LEVEL pushed: 1 BPM
        .equ    TICK_PERIOD, 5          | UI ticks a timer call, as stock's nudge
        .equ    SHOW_CALLS, 12          | timer calls the percentage stays after the last step
        .equ    SR, 44100
        .equ    DTCN3, 0xfc07c00c       | DMA timer 3's count: 132 MHz, free-running
        .equ    LIVE_COUNTS, 39600000   | 0.3 s: a voice that read 1 that recently still plays

| d0 = the first held track key (0..7), or -1. d1 clobbered.
first_held:
        moveq   #0,%d1
        move.b  (TRACK_ROW).l,%d1
        moveq   #0,%d0
.fh_loop:
        btst    %d0,%d1
        bne.s   .fh_out
        addq.l  #1,%d0
        cmpi.l  #8,%d0
        bne.s   .fh_loop
        moveq   #-1,%d0
.fh_out:
        rts

| tempo_step(faster): every held track's sample tempo -= faster (BPMx24);
| the first held track's percentage is shown. C ABI: d0/d1/a0/a1 scratch.
tempo_step:
        lea     -16(%sp),%sp
        movem.l %d2-%d4/%a2,(%sp)
        moveq   #0,%d2                  | track
        moveq   #-1,%d4                 | the first held track with a sample
.ts_track:
        moveq   #0,%d0
        move.b  (TRACK_ROW).l,%d0
        btst    %d2,%d0
        beq.s   .ts_next
        move.l  #168,%d0
        mulu.l  %d2,%d0
        lea     (VOICES).l,%a0
        movea.l V_SETTINGS(%a0,%d0.l),%a2
        move.l  %a2,%d0
        beq.s   .ts_next
        tst.l   %d4
        bpl.s   .ts_set
        move.l  %d2,%d4
.ts_set:
        move.l  S_BPM24(%a2),%d0
        sub.l   20(%sp),%d0             | faster = a lower sample tempo
        pea     64
        move.l  %d0,-(%sp)
        move.l  %a2,-(%sp)
        jsr     (SET_TEMPO).l
        lea     12(%sp),%sp
.ts_next:
        addq.l  #1,%d2
        moveq   #8,%d0
        cmp.l   %d2,%d0
        bne.s   .ts_track
        tst.l   %d4
        bmi.s   .ts_out
        move.l  %d4,(show_track).l
        moveq   #SHOW_CALLS,%d0
        move.l  %d0,(show_left).l
        jsr     (0x4004b08c).l          | the readout, through readout
.ts_out:
        movem.l (%sp),%d2-%d4/%a2
        lea     16(%sp),%sp
        rts

| The UI timer, every TICK_PERIOD ticks for good (never removed: a slot
| cancelled from inside its own callback would unlink the queue).
tempo_tick:
        move.l  (show_left).l,%d0
        beq.s   .tt_held
        subq.l  #1,%d0
        move.l  %d0,(show_left).l
        beq.s   .tt_draw                | the percentage ends
.tt_held:
        bsr     first_held
        move.l  (was_held).l,%d1
        move.l  %d0,(was_held).l
        tst.l   %d0
        bpl.s   .tt_draw                | the time left moves while a track is held
        tst.l   %d1
        bmi.s   .tt_out                 | nothing held before or now
.tt_draw:
        jsr     (0x4004b08c).l
.tt_out:
        rts

| 0x400491a0, the main layer's UP/DOWN handler (code, edge): press,
| repeat and release. With a track key held, a press or repeat steps the
| tempo and stock's handler does not run. Displaced: `move.l d2,-(sp);
| movea.l 8(sp),a0; move.l 12(sp),d1`.
tempo_keys:
        tst.l   8(%sp)
        beq.s   .tk_stock               | the release
        bsr     first_held
        tst.l   %d0
        bmi.s   .tk_stock
        moveq   #1,%d0                  | UP: faster
        moveq   #KEY_UP,%d1
        cmp.l   4(%sp),%d1
        beq.s   .tk_go
        moveq   #-1,%d0
.tk_go:
        move.l  %d0,-(%sp)
        bsr     tempo_step
        addq.l  #4,%sp
        rts
.tk_stock:
        move.l  %d2,-(%sp)              | displaced
        movea.l 8(%sp),%a0
        move.l  12(%sp),%d1
        jmp     (0x400491aa).l

| LEVEL with a track held (index, delta): clockwise is faster.
tempo_level:
        move.l  8(%sp),%d0
        tst.l   (LEVEL_PUSHED).l
        beq.s   .tl_go
        moveq   #COARSE,%d1
        muls.l  %d1,%d0
.tl_go:
        move.l  %d0,-(%sp)
        bsr     tempo_step
        addq.l  #4,%sp
        rts

| a1 = the buffer, d0 = a value 0..9999: its decimal digits, a1 past
| them. d0/d1 clobbered.
put_uint:
        move.l  %d2,-(%sp)
        moveq   #10,%d2
        cmp.l   %d2,%d0
        bcs.s   .pu_digit
        move.l  %d0,-(%sp)
        divu.l  %d2,%d0
        bsr     put_uint                | the higher digits first
        move.l  (%sp)+,%d0
        move.l  %d0,%d1
        divu.l  %d2,%d1
        mulu.l  %d2,%d1
        sub.l   %d1,%d0                 | the last digit
.pu_digit:
        addi.l  #'0',%d0
        move.b  %d0,(%a1)+
        move.l  (%sp)+,%d2
        rts

| The fader's percentage for track d0 into text: "+1.9" under 10 %, "+12"
| from there, "0.0" at its own speed; no "%" sign, which would not fit
| (the field is 23 px, the big font's "+1.9%" 26). d0 = 0: no sample.
percent_text:
        lea     -12(%sp),%sp
        movem.l %d2-%d4,(%sp)
        moveq   #10,%d4
        move.l  #168,%d1
        mulu.l  %d0,%d1
        lea     (VOICES).l,%a0
        movea.l V_SETTINGS(%a0,%d1.l),%a0
        move.l  %a0,%d1
        beq.s   .pt_none
        move.l  S_BPM24(%a0),%d2        | the sample's tempo
        beq.s   .pt_none
        move.l  (PROJECT_BPM24).l,%d0
        move.l  #1000,%d1
        mulu.l  %d1,%d0
        move.l  %d2,%d1
        lsr.l   #1,%d1
        add.l   %d1,%d0                 | rounded
        divu.l  %d2,%d0
        subi.l  #1000,%d0               | tenths of a percent, signed
        lea     (text).l,%a1
        tst.l   %d0
        beq.s   .pt_digits
        bpl.s   .pt_plus
        neg.l   %d0
        move.b  #'-',(%a1)+
        bra.s   .pt_digits
.pt_plus:
        move.b  #'+',(%a1)+
.pt_digits:
        move.l  %d0,%d3
        cmpi.l  #100,%d3
        bcc.s   .pt_whole
        divu.l  %d4,%d0
        bsr     put_uint                | the whole percent
        move.b  #'.',(%a1)+
        move.l  %d3,%d0
        move.l  %d3,%d1
        divu.l  %d4,%d1
        mulu.l  %d4,%d1
        sub.l   %d1,%d0
        bsr     put_uint                | the tenth
        bra.s   .pt_sign
.pt_whole:
        addq.l  #5,%d0                  | rounded to a whole percent
        divu.l  %d4,%d0
        bsr     put_uint
.pt_sign:
        clr.b   (%a1)
        moveq   #1,%d0
        bra.s   .pt_out
.pt_none:
        moveq   #0,%d0
.pt_out:
        movem.l (%sp),%d2-%d4
        lea     12(%sp),%sp
        rts

| The time track d0's sample has left to play into text: "-1:42" under
| ten minutes (23 px, the field's width), "-12'" from there, at the speed
| it plays now: a dry track's increment (nudge and fader in it), a
| stretched track's project / sample tempo (the renderer moves its
| position by that ratio, docs/firmware/REPITCH.md, whatever the
| increment). d0 = 0: not playing a STATIC or FLEX sample.
remain_text:
        lea     -12(%sp),%sp
        movem.l %d2-%d4,(%sp)
        move.l  %d0,%d4
        move.l  #168,%d1
        mulu.l  %d0,%d1
        lea     (VOICES).l,%a0
        adda.l  %d1,%a0
        moveq   #1,%d1
        cmp.b   V_MACHINE(%a0),%d1
        bcs.w   .rt_none                | not STATIC or FLEX
        cmp.b   V_STATE(%a0),%d1
        bne.s   .rt_recent
        move.l  (DTCN3).l,%d0           | playing: note when
        lea     (live_at).l,%a1
        move.l  %d0,(%a1,%d4.l*4)
        bra.s   .rt_live
.rt_recent:
        move.l  (DTCN3).l,%d0           | a STATIC voice between its stream's states,
        lea     (live_at).l,%a1         | or one that has stopped
        sub.l   (%a1,%d4.l*4),%d0
        cmpi.l  #LIVE_COUNTS,%d0
        bcc.w   .rt_none
.rt_live:
        move.l  V_END(%a0),%d2
        sub.l   V_POS(%a0),%d2          | source frames left
        bpl.s   .rt_left
        moveq   #0,%d2
.rt_left:
        tst.b   V_TSTR(%a0)
        beq.s   .rt_dry
        movea.l V_SETTINGS(%a0),%a1     | stretched: project / sample tempo
        move.l  %a1,%d1
        beq.w   .rt_none
        move.l  S_BPM24(%a1),%d1
        beq.w   .rt_none
        move.l  (PROJECT_BPM24).l,%d3
        moveq   #12,%d0
        lsl.l   %d0,%d3
        divu.l  %d1,%d3                 | the speed, 4096 = 1.0
        bra.s   .rt_speed
.rt_dry:
        moveq   #40,%d1
        mulu.l  %d4,%d1
        lea     (STATES).l,%a0
        move.l  S_INC(%a0,%d1.l),%d3
        moveq   #14,%d1
        asr.l   %d1,%d3                 | the speed, 4096 = 1.0
.rt_speed:
        tst.l   %d3
        ble.w   .rt_none                | stopped or backwards
        | output samples = frames * 4096 / speed, as q * 4096 + r * 4096 / speed
        move.l  %d2,%d0
        divu.l  %d3,%d0                 | q
        move.l  %d0,%d1
        mulu.l  %d3,%d1
        sub.l   %d1,%d2                 | r < speed < 2^14
        moveq   #12,%d1
        lsl.l   %d1,%d0
        lsl.l   %d1,%d2
        divu.l  %d3,%d2
        add.l   %d2,%d0                 | output samples
        move.l  #SR,%d1
        divu.l  %d1,%d0                 | seconds
        move.l  #5999,%d1
        cmp.l   %d1,%d0
        bls.s   .rt_cap
        move.l  %d1,%d0                 | 99:59
.rt_cap:
        move.l  %d0,%d2
        moveq   #60,%d4                 | the track is not needed past here
        divu.l  %d4,%d0                 | minutes
        move.l  %d0,%d3
        mulu.l  %d4,%d3
        sub.l   %d3,%d2                 | seconds of the minute
        lea     (text).l,%a1
        move.b  #'-',(%a1)+
        moveq   #10,%d1
        cmp.l   %d1,%d0
        bcs.s   .rt_min
        bsr     put_uint                | ten minutes or more: the minutes alone
        move.b  #0x27,(%a1)+            | '
        bra.s   .rt_end
.rt_min:
        bsr     put_uint
        move.b  #':',(%a1)+
        moveq   #10,%d1
        cmp.l   %d1,%d2
        bcc.s   .rt_sec
        move.b  #'0',(%a1)+
.rt_sec:
        move.l  %d2,%d0
        bsr     put_uint
.rt_end:
        clr.b   (%a1)
        moveq   #1,%d0
        bra.s   .rt_out
.rt_none:
        moveq   #0,%d0
.rt_out:
        movem.l (%sp),%d2-%d4
        lea     12(%sp),%sp
        rts

| 0x4004b08c, the BPM field's drawer (no arguments). Displaced: `link.w
| fp,#-32; movem.l d2-d3/a2,(sp)`, which stock resumes after.
readout:
        tst.l   (timer_slot).l
        bpl.s   .ro_mode
        pea     tempo_tick
        pea     TICK_PERIOD
        jsr     (TIMER_ADD).l
        addq.l  #8,%sp
        move.l  %d0,(timer_slot).l      | -1 when the 32 slots are full: tried at the next draw
.ro_mode:
        tst.l   (show_left).l
        beq.s   .ro_held
        move.l  (show_track).l,%d0
        bsr     percent_text
        tst.l   %d0
        bne.s   .ro_draw
.ro_held:
        bsr     first_held
        tst.l   %d0
        bmi.s   .ro_stock
        bsr     remain_text
        tst.l   %d0
        bne.s   .ro_draw
.ro_stock:
        tst.l   (drawn).l
        beq.s   .ro_stock_go
        clr.l   (drawn).l
        bsr     wide_clear              | what ours left right of stock's clear
.ro_stock_go:
        .word   0x4e56,0xffe0           | displaced: link.w %fp,#-32
        movem.l %d2-%d3/%a2,(%sp)       | displaced
        jmp     (0x4004b094).l
.ro_draw:
        bsr     wide_clear
        moveq   #1,%d0
        move.l  %d0,(drawn).l
        pea     (text).l
        pea     -1
        pea     (BIG).l
        jsr     (TEXT_W).l
        lea     12(%sp),%sp
        moveq   #35,%d1
        sub.l   %d0,%d1                 | right-aligned at the field's edge, as stock's "P%d"
        moveq   #13,%d0
        cmp.l   %d0,%d1
        bge.s   .ro_x
        move.l  %d0,%d1                 | never left of what the clear covers
.ro_x:
        pea     (text).l
        pea     -1
        pea     0x33
        move.l  %d1,-(%sp)
        pea     (SURFACE).l
        pea     (BIG).l
        jsr     (TEXT).l
        lea     24(%sp),%sp
        moveq   #1,%d0
        move.l  %d0,(DIRTY).l
        rts

| Clear the field as stock does (x 13, y 51 to x 35, y 59), and four
| columns further right that stock never draws in this field: the big
| font's glyphs run past the widths 0x40012f30 sums (measured under the
| port, 18 Oct 2026: a "-0:01" right-aligned at x 35 left pixels in x 36
| and 37).
wide_clear:
        clr.l   -(%sp)
        pea     0x3b
        pea     0x27
        pea     0x33
        pea     0xd
        pea     (SURFACE).l
        jsr     (CLEAR).l
        lea     24(%sp),%sp
        rts

| The held layer's encoder table: LEVEL only, in the record shape of CUE's.
        .balign 2
tempo_levels:
        .byte   6, 0                    | LEVEL
        .long   tempo_level, -1, 0x100, 0, 0x80
        .byte   0xff, 0

        .data
        .balign 4
show_track: .long 0
show_left:  .long 0                     | timer calls left showing show_track's percentage
was_held:   .long -1                    | the first held track at the last timer call
timer_slot: .long -1
drawn:      .long 0                     | the field holds our text
live_at:    .long 0,0,0,0,0,0,0,0       | DTCN3 when each track's voice last read 1
text:       .space 12
