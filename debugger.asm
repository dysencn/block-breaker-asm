.386
.model flat, stdcall
option casemap:none

include \masm32\include\msvcrt.inc
include \masm32\include\masm32rt.inc

crlf equ <13, 10, 0> ; 手动定义 crlf = 13, 10, 0

.data
    thisnumber dd 24

    msgFmt db "Ball1X=%d, Paddle1X=%d", 0
    msgFmt2 db "line258", 0
    msg3 db "line 284: Ball1Y=%d, edx=%d, ecx=%d", 0
    msgBuf db 64 dup(0)

.code



main proc
    invoke KillTimer, hwnd, TimerID
    invoke wsprintf, addr msgBuf, addr msgFmt
    invoke MessageBox, NULL, addr msgBuf, addr AppName, MB_OK
    invoke SetTimer, hwnd, TimerID, TimerDelay, NULL

    mov eax, thisnumber
    mov ebx, chr$("First number is %d", 13, 10, 0)
    invoke crt_printf, ebx, eax

    invoke crt_printf, chr$("line 18", 13, 10, 0)

    invoke crt_printf, chr$("Second number is %d", 13, 10, 0), thisnumber

    print "line20", crlf

    invoke ExitProcess, 0
main endp
end main