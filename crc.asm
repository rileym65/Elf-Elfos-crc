; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

.op "PUSH","N","9$1 73 8$1 73"
.op "POP","N","60 72 A$1 F0 B$1"
.op "CALL","W","D4 H1 L1"
.op "RTN","","D5"
.op "MOV","NR","9$2 B$1 8$2 A$1"
.op "MOV","NW","F8 H2 B$1 F8 L2 A$1"

include    ../bios.inc
include    ../kernel.inc

           org     2000h
begin:     br      start
           eever
           db      'Written by Michael H. Riley',0

start:     lda     ra                  ; move past any spaces
           smi     ' '
           bz      start
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; check for -
           smi     '-'
           bnz     start1              ; jump if not
           inc     ra                  ; move past dash
           lda     ra                  ; get following character
           smi     'x'                 ; check for x
           bnz     argerr              ; jump if not
           mov     rf,padding
           ldi     1                   ; signal xmodem padding
           str     rf
           br      start               ; move past any spaces
argerr:    sep     scall               ; display error
           dw      o_inmsg
           db      'Invalid switch',10,13,0
           ldi     09h
           sep     sret                ; return to OS
start1:    ghi     ra                  ; copy argument address to rf
           phi     rf
           glo     ra
           plo     rf
loop1:     lda     rf                  ; look for first less <= space
           smi     33
           bdf     loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldn     rf                  ; get byte from argument
           lbnz    good                ; jump if filename given
           sep     scall               ; otherwise display usage message
           dw      o_inmsg
           db      'Usage: crc [-x] filename',10,13,0
           ldi     0ah
           sep     sret                ; and return to os

good:      ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           bnf     opened              ; jump if file was opened
           ldi     high errmsg         ; get error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           ldi     04
           sep     sret                ; return to the OS
opened:    ldi     0                   ; set initial crc
           plo     r7
           phi     r7
loop:      push    rd                  ; save file descriptor
           push    r7                  ; save crc
           mov     rf,data             ; point to kernel data
           mov     rc,128              ; 128 bytes to read
           sep     scall               ; read file
           dw      o_read
           pop     r7
           pop     rd
           glo     rc
           lbz     done
           lbnf    success             ; jump if read was good
done:      sep     scall               ; close the file
           dw      o_close
           mov     rd,r7               ; move crc
           mov     rf,data             ; point to buffer
           sep     scall               ; convert to ASCII
           dw      f_hexout4
           ldi     0                   ; need a terminator
           str     rf
           mov     rf,data             ; display result
           sep     scall
           dw      o_msg
           sep     scall               ; cr/lf
           dw      o_inmsg
           db      10,13,0
           ldi     0
           sep     sret

success:   glo     rc                  ; get bytes read
           smi     128                 ; were 128 bytes read
           lbz     success2            ; jump if so
           mov     r9,padding          ; need to see if need padding
           ldn     r9
           lbz     success2            ; jump if not
padloop:   ldi     01ah                ; write padding byte
           str     rf                  ; store in buffer
           inc     rf
           inc     rc
           glo     rc
           smi     128
           lbnz    padloop             ; loop until 128 bytes padded
success2:  mov     rf,data             ; point to data
           sep     scall               ; perform crc calculation
           dw      crc
           lbr     loop                ; loop back for more data


; ****************************
; *** CRC calculation      ***
; *** R7 - 16-bit crc      ***
; *** RF - Pointer to data ***
; *** RC - count           ***
; ****   R8.0 - C          ***
; ***    R8.1 - Q          ***
; ****************************
crc:       lda     rf                  ; get next byte
           plo     r8                  ; save it
           str     r2                  ; store for xor
           glo     r7                  ; need to xor crc value with c
           xor
           ani     0fh                 ; keep only low nybble
           phi     r8                  ; keep it
           sep     scall               ; need to shift crc 4 bits
           dw      shift
           sep     scall               ; combine with poly
           dw      poly
           glo     r8                  ; get C
           shr                         ; want only hight nybble in low position
           shr
           shr
           shr
           str     r2                  ; store it
           glo     r7                  ; need low byte of crc
           xor                         ; xor it
           ani     0fh                 ; keep only low nybble
           phi     r8                  ; store in Q
           sep     scall               ; need to shift crc 4 bits
           dw      shift
           sep     scall               ; combine with poly
           dw      poly
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    crc                 ; loop back if not
           ghi     rc                  ; check high byte
           lbnz    crc                 ; loop back if more to do
           sep     sret                ; otherwise return to caller

poly:      ghi     r8                  ; get Q
           str     r2                  ; save a copy
           shr                         ; shift low bit into df
           ldi     0                   ; need 0
           shrc                        ; shift high bit in
           add                         ; then add in q, now have low byte
           str     r2                  ; store for xor
           glo     r7                  ; get low byte of crc
           xor                         ; xor with poly
           plo     r7                  ; and put it back
           ghi     r8                  ; get Q
           shr                         ; keep only high 3 bits 
           str     r2                  ; store for later
           ghi     r8                  ; recover Q
           shl                         ; shift to high nybble
           shl
           shl
           shl
           add                         ; add in first part
           str     r2                  ; store for xor
           ghi     r7                  ; byte from crc
           xor
           phi     r7                  ; put it back
           sep     sret                ; return to caller

shift:     ldi     4                   ; shift crc right 4 bits
           plo     re
crc1:      ghi     r7                  ; shift crc value
           shr
           phi     r7
           glo     r7
           shrc
           plo     r7
           dec     re                  ; decrement count
           glo     re                  ; get count
           lbnz    crc1                ; loop until done
           sep     sret                ; return

padding:   db      0
filename:  db      0,0
errmsg:    db      'File not found',10,13,0
fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

endrom:    equ     $

.suppress

buffer:    ds      20
cbuffer:   ds      80
dta:       ds      512

data:      ds      128

           end     begin

