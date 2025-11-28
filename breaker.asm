.386
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib

;==============================================================================
; 数据段
;==============================================================================
.data
    AppName     db "MASM32 Breakout",0
    ClassName   db "BreakoutClass",0
    
    ; 游戏参数
    WindowW     dd 640
    WindowH     dd 480
    TimerID     dd 1
    TimerDelay  dd 16   ; ~60 FPS
    
    ; 球
    BallX       dd 320
    BallY       dd 400
    BallSize    dd 12
    VelX        dd 4
    VelY        dd -4
    
    ; 挡板
    PaddleX     dd 270
    PaddleY     dd 440
    PaddleW     dd 100
    PaddleH     dd 15
    PaddleSpeed dd 20
    
    ; 砖块 (1=存在, 0=破碎)
    ;简单的字节数组模拟
    Bricks      db 1,1,1,1,1
                db 1,1,1,1,1
                db 1,1,1,1,1
    BrickRows   dd 3
    BrickCols   dd 5
    BrickW      dd 100
    BrickH      dd 30
    BrickGap    dd 10
    BrickOffX   dd 45
    BrickOffY   dd 50

.data?
    hInstance   HINSTANCE ?
    hBrushBall  HBRUSH ?
    hBrushPad   HBRUSH ?
    hBrushBrick HBRUSH ?
    rect        RECT <>

.code

; 前置声明，解决 A2006 错误
WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD


start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    local wc:WNDCLASSEX
    local msg:MSG
    local hwnd:HWND

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL
    push hInst
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_WINDOW+1 ; 白色背景
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset ClassName
    mov wc.hIcon, NULL
    mov wc.hIconSm, NULL
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, addr wc

    ; 创建固定大小的窗口
    invoke CreateWindowEx, NULL, addr ClassName, addr AppName,
           WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,
           CW_USEDEFAULT, CW_USEDEFAULT, WindowW, WindowH,
           NULL, NULL, hInst, NULL
    mov hwnd, eax

    invoke ShowWindow, hwnd, CmdShow
    invoke UpdateWindow, hwnd

    ; 消息循环
    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw

    mov eax, msg.wParam
    ret
WinMain endp

;------------------------------------------------------------------------------
; 游戏逻辑更新
;------------------------------------------------------------------------------
UpdateGame proc
    ; --- 1. 更新球位置 ---
    mov eax, BallX
    add eax, VelX
    mov BallX, eax
    
    mov eax, BallY
    add eax, VelY
    mov BallY, eax

    ; --- 2. 墙壁碰撞 ---
    ; 左墙
    cmp BallX, 0
    jge @F
    neg VelX
@@:
    ; 右墙
    mov eax, WindowW
    sub eax, BallSize
    sub eax, 20      
    cmp BallX, eax
    jle @F
    neg VelX
@@:
    ; 顶墙
    cmp BallY, 0
    jge @F
    neg VelY
@@:
    ; 底墙 (掉落重置)
    mov eax, WindowH
    sub eax, 50
    cmp BallY, eax
    jle @F
    mov BallX, 320
    mov BallY, 300
    mov VelY, -4
@@:

    ; --- 3. 挡板碰撞 (AABB) ---
    mov eax, BallY
    add eax, BallSize
    cmp eax, PaddleY
    jl NoPaddleHit      ; 球底 < 挡板顶
    
    mov eax, BallY
    mov ecx, PaddleY
    add ecx, PaddleH
    cmp eax, ecx
    jg NoPaddleHit      ; 球顶 > 挡板底

    mov eax, BallX
    add eax, BallSize
    cmp eax, PaddleX
    jl NoPaddleHit      ; 球右 < 挡板左

    mov eax, BallX
    mov ecx, PaddleX
    add ecx, PaddleW
    cmp eax, ecx
    jg NoPaddleHit      ; 球左 > 挡板右

    ; 命中挡板
    neg VelY
    mov eax, PaddleY    ; 修正位置防止粘连
    sub eax, BallSize
    mov BallY, eax
NoPaddleHit:

    ; --- 4. 砖块碰撞检测 (修复版) ---
    ; 使用寄存器：ESI=数组指针, EDI=当前行, EBX=当前砖块Y坐标, EDX=当前砖块X坐标
    
    mov esi, offset Bricks
    mov edi, 0              ; Row index
    mov ebx, BrickOffY      ; Current Row Y

RowLoop:
    cmp edi, BrickRows
    jge EndBrickChecks

    mov ecx, 0              ; Col index
    push ebx                ; 保存当前行的Y坐标
    mov edx, BrickOffX      ; Current Col X

ColLoop:
    cmp ecx, BrickCols
    jge NextRow

    ; 检查砖块是否存在
    mov al, byte ptr [esi]
    cmp al, 0
    je SkipBrickCheck

    ; --- AABB 碰撞检测逻辑 ---
    ; EDX = Brick Left, EBX = Brick Top
    
    ; 1. BallRight > BrickLeft ? (BallX + Size > EDX)
    mov eax, BallX
    add eax, BallSize
    cmp eax, edx
    jle SkipBrickCheck

    ; 2. BallLeft < BrickRight ? (BallX < EDX + Width)
    mov eax, edx
    add eax, BrickW
    cmp BallX, eax
    jge SkipBrickCheck

    ; 3. BallBottom > BrickTop ? (BallY + Size > EBX)
    mov eax, BallY
    add eax, BallSize
    cmp eax, ebx
    jle SkipBrickCheck

    ; 4. BallTop < BrickBottom ? (BallY < EBX + Height)
    mov eax, ebx
    add eax, BrickH
    cmp BallY, eax
    jge SkipBrickCheck

    ; === 命中砖块 ===
    mov byte ptr [esi], 0   ; 设为0 (销毁)
    neg VelY                ; 反弹
    
    pop ebx                 ; 恢复堆栈平衡 (因为我们在NextRow之前退出了)
    ret                     ; 这一帧处理完立刻返回，防止一次穿透多块

SkipBrickCheck:
    inc esi                 ; 数组指针+1
    inc ecx                 ; Col+1
    add edx, BrickW         ; X += Width
    add edx, BrickGap       ; X += Gap
    jmp ColLoop

NextRow:
    pop ebx                 ; 恢复行的Y坐标
    inc edi                 ; Row+1
    add ebx, BrickH         ; Y += Height
    add ebx, BrickGap       ; Y += Gap
    jmp RowLoop

EndBrickChecks:
    ret
UpdateGame endp

;------------------------------------------------------------------------------
; 窗口过程
;------------------------------------------------------------------------------
WndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    local ps:PAINTSTRUCT
    local hdc:HDC
    local hOldBrush:HBRUSH
    ; 定义局部变量用于绘图循环
    local currentX:DWORD
    local currentY:DWORD
    
    .if uMsg == WM_CREATE
        invoke CreateSolidBrush, 000000FFh ; 红球
        mov hBrushBall, eax
        invoke CreateSolidBrush, 00FF0000h ; 蓝板
        mov hBrushPad, eax
        invoke CreateSolidBrush, 00008000h ; 绿砖
        mov hBrushBrick, eax
        invoke SetTimer, hwnd, TimerID, TimerDelay, NULL

    .elseif uMsg == WM_DESTROY
        invoke DeleteObject, hBrushBall
        invoke DeleteObject, hBrushPad
        invoke DeleteObject, hBrushBrick
        invoke KillTimer, hwnd, TimerID
        invoke PostQuitMessage, NULL

    .elseif uMsg == WM_KEYDOWN
        .if wParam == 41h ; A
            mov eax, PaddleX
            sub eax, PaddleSpeed
            cmp eax, 0
            jge @F
            mov eax, 0
        @@:
            mov PaddleX, eax
        .elseif wParam == 44h ; D
            mov eax, PaddleX
            add eax, PaddleSpeed
            mov ecx, WindowW
            sub ecx, PaddleW
            sub ecx, 20
            cmp eax, ecx
            jle @F
            mov eax, ecx
        @@:
            mov PaddleX, eax
        .endif

    .elseif uMsg == WM_TIMER
        invoke UpdateGame
        invoke InvalidateRect, hwnd, NULL, TRUE 

    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hwnd, addr ps
        mov hdc, eax

        ; 1. 绘制挡板
        invoke SelectObject, hdc, hBrushPad
        mov hOldBrush, eax
        
        ; 计算挡板右下角坐标
        mov eax, PaddleX
        add eax, PaddleW    ; EAX = Paddle Right X
        mov ecx, PaddleY
        add ecx, PaddleH    ; ECX = Paddle Bottom Y
        
        ; 调用 Rectangle API: (HDC, Left, Top, Right, Bottom)
        invoke Rectangle, hdc, PaddleX, PaddleY, eax, ecx

        ; 2. 绘制球
        invoke SelectObject, hdc, hBrushBall
        mov eax, BallX
        add eax, BallSize
        mov ecx, BallY
        add ecx, BallSize
        invoke Ellipse, hdc, BallX, BallY, eax, ecx

        ; 3. 绘制砖块 (修复版: 循环绘制)
        invoke SelectObject, hdc, hBrushBrick
        
        ; 保存寄存器 (Windows回调约定)
        push ebx
        push esi
        push edi

        mov esi, offset Bricks
        mov edi, 0              ; Row Loop
        
        mov eax, BrickOffY
        mov currentY, eax

PaintRowLoop:
        cmp edi, BrickRows
        jge PaintEnd

        mov ecx, 0              ; Col Loop
        mov eax, BrickOffX
        mov currentX, eax

PaintColLoop:
        cmp ecx, BrickCols
        jge PaintNextRow

        ; 检查是否存活
        xor eax, eax
        mov al, byte ptr [esi]
        cmp al, 0
        je PaintSkip

        ; 绘制矩形 (currentX, currentY, currentX+W, currentY+H)
        mov eax, currentX
        add eax, BrickW
        mov ebx, currentY
        add ebx, BrickH
        
        ; 保存循环计数器 ECX，因为Invoke可能会修改它
        push ecx 
        invoke Rectangle, hdc, currentX, currentY, eax, ebx
        pop ecx

PaintSkip:
        inc esi                 ; 数组+1
        inc ecx                 ; Col+1
        
        ; Update X
        mov eax, currentX
        add eax, BrickW
        add eax, BrickGap
        mov currentX, eax
        jmp PaintColLoop

PaintNextRow:
        inc edi                 ; Row+1
        ; Update Y
        mov eax, currentY
        add eax, BrickH
        add eax, BrickGap
        mov currentY, eax
        jmp PaintRowLoop

PaintEnd:
        pop edi
        pop esi
        pop ebx

        invoke SelectObject, hdc, hOldBrush
        invoke EndPaint, hwnd, addr ps

    .else
        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret
    .endif

    xor eax, eax
    ret
WndProc endp

end start