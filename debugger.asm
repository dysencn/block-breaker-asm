.386
.model flat, stdcall
option casemap:none

include \masm32\include\msvcrt.inc
include \masm32\include\masm32rt.inc

crlf equ <13, 10, 0> ; 手动定义 crlf = 13, 10, 0

.data
    thisnumber dd 24

.code

; 宏定义
STD_INPUT_HANDLE equ -10 ; 标准输入句柄的常量值

; ... (在 .data 段中，你现在可以移除 ReadBuffer 和 dwBytesRead)

.code

PauseProgram PROC USES ebx 
    ; USES ebx 确保过程结束后 ebx 的值不会改变。
    
    ; 使用 LOCAL 关键字在栈上定义局部变量
    LOCAL hInput:DWORD       ; 用于存储控制台句柄
    LOCAL lpCharsRead:DWORD  ; 用于存储实际读取的字节数
    LOCAL ReadBuffer[1]:BYTE ; 用于存储输入的缓冲区 (只需1个字节)
    
    ; 1. 获取标准输入句柄，并保存到局部变量 hInput
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov hInput, eax 
    
    ; 2. 调用 ReadConsole 等待用户输入
    invoke ReadConsole, \
           hInput, \
           ADDR ReadBuffer, \
           1, \
           ADDR lpCharsRead, \
           NULL

    ; 3. 返回调用者 
    ret 
PauseProgram ENDP

main proc
    mov eax, thisnumber
    mov ebx, chr$("First number is %d", 13, 10, 0)
    invoke crt_printf, ebx, eax

    invoke crt_printf, chr$("line 18", 13, 10, 0)
    invoke PauseProgram

    invoke crt_printf, chr$("Second number is %d", 13, 10, 0), thisnumber

    print "line20", crlf

    invoke ExitProcess, 0
main endp
end main