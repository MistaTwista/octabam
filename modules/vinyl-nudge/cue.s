| VINYL NUDGE, the cue: [TRACK] + REC adds a slice to the held track's
| sample from where it plays now to the end of its trim, so the track can
| be started there later from the SLICES trig mode (with SLIC on), and
| from the top as before with [TRACK] + PLAY.
|
| The write is the audio editor's own ADD SLICE (0x40073124): under a
| masked SR, a twelve-byte record {start, end, loop -1} after the last of
| the settings' slices (+312, the count at +1092), the count raised, the
| table sorted by start with stock's 0x40070c28(+312, count); refused past
| 63 slices with stock's "TOO MANY SLICES!", confirmed with its "ADDED
| SLICE!" (0x4005a2b8(text, 0x30)). Only the slot's settings change: the
| voice playing it keeps its position.
|
| Input: REC's main-layer handler (0x40048774, (code, edge) on press and
| release) is entered here first. With a track key held, the press adds
| the cue and stock's handler does not run (stock's REC with a track held
| is REC alone: grid recording on, measured under the port 18 Oct 2026),
| nor does the release that follows it.
        .text

        .global rec_cue

        .equ    VOICES, 0x800049d8      | per-track voices, 168 B
        .equ    V_SETTINGS, 8
        .equ    V_MACHINE, 20           | 0 STATIC, 1 FLEX
        .equ    V_POS, 68               | the play position, frames
        .equ    S_TRIM_START, 300
        .equ    S_TRIM_END, 304
        .equ    S_SLICES, 312           | 12 B each: start, end, loop (-1 = none)
        .equ    S_SLICE_COUNT, 1092
        .equ    SLICE_SORT, 0x40070c28  | (slices, count)
        .equ    POPUP, 0x4005a2b8       | (text, 0x30)
        .equ    TXT_ADDED, 0x400b6b93   | "ADDED SLICE!"
        .equ    TXT_FULL, 0x400b6ba0    | "TOO MANY SLICES!"
        .equ    TRACK_ROW, 0x46100b1a   | the panel's key row 2: bit t = track key t held (tempo.s)

| cue_add(track): a slice from the voice's position to the trim end.
| d0 = the message to show (0: none). C ABI: d0/d1/a0/a1 scratch.
cue_add:
        lea     -16(%sp),%sp
        movem.l %d2-%d4/%a2,(%sp)
        move.l  20(%sp),%d0
        move.l  #168,%d1
        mulu.l  %d0,%d1
        lea     (VOICES).l,%a0
        adda.l  %d1,%a0
        moveq   #0,%d0
        moveq   #1,%d1
        cmp.b   V_MACHINE(%a0),%d1
        bcs.w   .ca_out                 | not STATIC or FLEX
        movea.l V_SETTINGS(%a0),%a2
        move.l  %a2,%d1
        beq.w   .ca_out
        move.l  V_POS(%a0),%d2          | the cue
        cmp.l   S_TRIM_START(%a2),%d2
        blt.w   .ca_out
        cmp.l   S_TRIM_END(%a2),%d2
        bge.w   .ca_out
        move.l  #TXT_FULL,%d0
        move.l  S_SLICE_COUNT(%a2),%d3
        moveq   #62,%d1
        cmp.l   %d1,%d3
        bgt.w   .ca_out                 | stock's own limit (0x40073130)
        move.w  %sr,%d4
        move.w  #0x2700,%sr
        moveq   #12,%d1
        mulu.l  %d3,%d1
        lea     S_SLICES(%a2),%a0
        adda.l  %d1,%a0
        move.l  %d2,(%a0)               | start
        move.l  S_TRIM_END(%a2),4(%a0)  | end
        moveq   #-1,%d1
        move.l  %d1,8(%a0)              | no loop, as ADD SLICE writes
        addq.l  #1,%d3
        move.l  %d3,S_SLICE_COUNT(%a2)
        move.l  %d3,-(%sp)
        pea     S_SLICES(%a2)
        jsr     (SLICE_SORT).l
        addq.l  #8,%sp
        move.w  %d4,%sr
        move.l  #TXT_ADDED,%d0
.ca_out:
        movem.l (%sp),%d2-%d4/%a2
        lea     16(%sp),%sp
        rts

| 0x40048774, REC's handler (code, edge). Displaced: `tst.l 8(sp);
| beq.w 0x4004883a`, so stock resumes at 0x4004877c on a press.
rec_cue:
        tst.l   8(%sp)
        beq.w   .rc_release
        move.l  %d2,-(%sp)
        tst.b   (TRACK_ROW).l
        beq.s   .rc_stock_press         | no track key held
        moveq   #1,%d0
        move.l  %d0,(rec_swallow).l
        moveq   #0,%d2
.rc_track:
        moveq   #0,%d0
        move.b  (TRACK_ROW).l,%d0
        btst    %d2,%d0
        beq.s   .rc_next
        move.l  %d2,-(%sp)
        bsr     cue_add
        addq.l  #4,%sp
        tst.l   %d0
        beq.s   .rc_next
        move.l  %d0,(rec_msg).l
.rc_next:
        addq.l  #1,%d2
        moveq   #8,%d0
        cmp.l   %d2,%d0
        bne.s   .rc_track
        move.l  (rec_msg).l,%d0
        beq.s   .rc_done
        clr.l   (rec_msg).l
        pea     0x30
        move.l  %d0,-(%sp)
        jsr     (POPUP).l
        addq.l  #8,%sp
.rc_done:
        move.l  (%sp)+,%d2
        rts
.rc_stock_press:
        move.l  (%sp)+,%d2
        jmp     (0x4004877c).l
.rc_release:
        tst.l   (rec_swallow).l
        beq.s   .rc_stock_release
        clr.l   (rec_swallow).l         | the release of a cue press
        rts
.rc_stock_release:
        jmp     (0x4004883a).l

        .data
        .balign 4
rec_swallow: .long 0                    | the next REC release belongs to a cue
rec_msg:     .long 0
