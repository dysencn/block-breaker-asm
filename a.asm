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

.data
    AppName     db "MASM32 Breakout 2P",0
    ClassName   db "BreakoutClass",0
    
    ; 游戏参数
    WindowW     dd 710          ; 窗口宽度增加，以容纳第二个玩家
    WindowH     dd 640          ; 保持窗口高度
    TimerID     dd 1
    TimerDelay  dd 16           ; ~60 FPS
    
    ; 球
    BallX       dd 80
    BallY       dd 320
    BallSize    dd 24
    VelX        dd 4
    VelY        dd 4
    
    ; 挡板 1 (左侧 - W/S 控制)
    Paddle1X    dd 15           ; X 位置靠近左侧
    Paddle1Y    dd 270          ; Y 初始位置
    PaddleW     dd 15
    PaddleH     dd 100
    PaddleSpeed dd 20
    
    ; 挡板 2 (右侧 - 上下方向键控制)
    Paddle2X    dd 690          ; X 位置靠近右侧 (WindowW - PaddleW - 15)
    Paddle2Y    dd 270          ; Y 初始位置
    
    ; 砖块 (1=存在, 0=破碎)
    Bricks      db 1,1,1,1,1
                db 1,1,1,1,1
                db 1,1,1,1,1
    BrickRows   dd 5            ; 仍然是 5 行
    BrickCols   dd 3            ; 仍然是 3 列
    BrickW      dd 30
    BrickH      dd 100
    BrickGap    dd 10
    BrickOffX   dd 300          ; 砖块组的新 X 偏移 (位于窗口中心附近)
    BrickOffY   dd 45
    
    PauseCaption db "Game Paused", 0
    PauseMsg db "Game is paused. Click OK to continue.", 0

.data?
    hInstance   HINSTANCE ?
    hBrushBall  HBRUSH ?
    hBrushPad1  HBRUSH ?        ; Player 1 画刷
    hBrushPad2  HBRUSH ?        ; Player 2 画刷
    hBrushBrick HBRUSH ?
    rect        RECT <>

    hMemDC      HDC ?
    hMemBitmap  HBITMAP ?
    hOldBitmap  HBITMAP ?

.code

WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD



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
    mov wc.hbrBackground, COLOR_WINDOWTEXT+1 ; 黑色背景
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
; 游戏逻辑更新 (Player 1 & Player 2)
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
    ; 顶墙
    cmp BallY, 0
    jge @F
    neg VelY
    @@:
        ; 底墙
        mov eax, WindowH
        sub eax, BallSize
        sub eax, 30      
        cmp BallY, eax
        jle @F
        neg VelY
    @@:
        ; 右墙 (Player 2 目标区 - 丢球重置)
        mov eax, WindowW
        sub eax, BallSize
        sub eax, 15      
        cmp BallX, eax
        jle @F
        ; Player 1 得分，球重置
        mov BallX, 80
        mov BallY, 320
        mov VelX, 4
        jmp EndChecks ; 跳过后续所有检查
    @@:
        ; 左墙 (Player 1 目标区 - 丢球重置)
        cmp BallX, 0
        jge @F
        ; Player 2 得分，球重置
        mov BallX, 500 ; 靠近 Player 2 一侧重置
        mov BallY, 320
        mov VelX, -4
        jmp EndChecks
    @@:

    ; --- 3. 挡板 1 (左侧) 碰撞 (AABB) ---
    ; PaddleX 是 Paddle1X
    mov eax, BallY
    add eax, BallSize
    cmp eax, Paddle1Y
    jl NoPaddle1Hit
    
    mov eax, BallY
    mov ecx, Paddle1Y
    add ecx, PaddleH
    cmp eax, ecx
    jg NoPaddle1Hit

    mov eax, BallX
    add eax, BallSize
    cmp eax, Paddle1X
    jl NoPaddle1Hit

    mov eax, BallX
    mov ecx, Paddle1X
    add ecx, PaddleW
    cmp eax, ecx
    jg NoPaddle1Hit

    ; 命中 Player 1 挡板
    neg VelX
    mov eax, Paddle1X 
    add eax, PaddleW
    mov BallX, eax ; 修正位置防止粘连
    
    NoPaddle1Hit:

        ; --- 3. 挡板 2 (右侧) 碰撞 (AABB) ---
        mov eax, BallY
        add eax, BallSize
        cmp eax, Paddle2Y
        jl NoPaddle2Hit
        
        mov eax, BallY
        mov ecx, Paddle2Y
        add ecx, PaddleH
        cmp eax, ecx
        jg NoPaddle2Hit

        mov eax, BallX
        add eax, BallSize
        cmp eax, Paddle2X
        jl NoPaddle2Hit

        mov eax, BallX
        mov ecx, Paddle2X
        add ecx, PaddleW
        cmp eax, ecx
        jg NoPaddle2Hit

        ; 命中 Player 2 挡板
        neg VelX
        mov eax, Paddle2X
        sub eax, BallSize
        mov BallX, eax ; 修正位置防止粘连
    NoPaddle2Hit:

        ; --- 4. 砖块碰撞检测 (现在反弹 X 方向) ---
        mov esi, offset Bricks
        mov edi, 0              ; Row index
        mov ebx, BrickOffY      ; Current Row Y

    BrickRowLoop:
        cmp edi, BrickRows
        jge EndChecks

        mov ecx, 0              ; Col index
        push ebx                ; 保存当前行的Y坐标
        mov edx, BrickOffX      ; Current Col X

    ColLoop:
        cmp ecx, BrickCols
        jge NextRow

        ; 检查砖块是否存在
        mov al, byte ptr [esi]
        cmp al, 0
        jle SkipBrickCheck

        ; --- AABB 碰撞检测逻辑 ---
        ; (逻辑保持不变，但现在是垂直游戏，主要反弹 VelX)
        ; EDX = Brick Left, EBX = Brick Top
        
        ; 1. BallRight > BrickLeft ?
        mov eax, BallX
        add eax, BallSize
        cmp eax, edx
        jle SkipBrickCheck

        ; 2. BallLeft < BrickRight ?
        mov eax, edx
        add eax, BrickW
        cmp BallX, eax
        jge SkipBrickCheck

        ; 3. BallBottom > BrickTop ?
        mov eax, BallY
        add eax, BallSize
        cmp eax, ebx
        jle SkipBrickCheck

        ; 4. BallTop < BrickBottom ?
        mov eax, ebx
        add eax, BrickH
        cmp BallY, eax
        jge SkipBrickCheck

        ; === 命中砖块 ===
        mov byte ptr [esi], 0   ; 设为0 (销毁)
        
        ; 简单的垂直游戏反弹：主要反弹 X 速度
        neg VelX                
        
        pop ebx
        jmp EndChecks ; 发现碰撞后立刻跳出所有循环并结束更新

    SkipBrickCheck:
        inc esi
        inc ecx
        add edx, BrickW
        add edx, BrickGap
        jmp ColLoop

    NextRow:
        pop ebx
        inc edi
        add ebx, BrickH
        add ebx, BrickGap
        jmp BrickRowLoop

    EndChecks: ; 统一的结束点
    ret
UpdateGame endp

;------------------------------------------------------------------------------
; 窗口过程
;------------------------------------------------------------------------------
WndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    local ps:PAINTSTRUCT
    local hdc:HDC
    local memDC:HDC
    local hBitmap:HBITMAP
    local hOldBrush:HBRUSH
    local hOld:HBITMAP
    local rectClient:RECT
    local currentX:DWORD
    local currentY:DWORD
    
    .if uMsg == WM_CREATE
        invoke CreateSolidBrush, 000000FFh ; 红球
        mov hBrushBall, eax
        invoke CreateSolidBrush, 00FF0000h ; 蓝板 (P1)
        mov hBrushPad1, eax
        invoke CreateSolidBrush, 0000FFFFh ; 黄板 (P2)
        mov hBrushPad2, eax
        invoke CreateSolidBrush, 00008000h ; 绿砖
        mov hBrushBrick, eax
        invoke SetTimer, hwnd, TimerID, TimerDelay, NULL

        .elseif uMsg == WM_DESTROY
            invoke DeleteObject, hBrushBall
            invoke DeleteObject, hBrushPad1
            invoke DeleteObject, hBrushPad2
            invoke DeleteObject, hBrushBrick
            invoke KillTimer, hwnd, TimerID
            invoke PostQuitMessage, NULL

        .elseif uMsg == WM_KEYDOWN
            ; --- P1 键盘控制 (W/S) ---
            .if wParam == 57h ; W
                mov eax, Paddle1Y
                sub eax, PaddleSpeed
                cmp eax, 0
                jge @F
                mov eax, 0
                @@:
                mov Paddle1Y, eax
                .elseif wParam == 53h ; S
                    mov eax, Paddle1Y
                    add eax, PaddleSpeed
                    mov ecx, WindowH
                    sub ecx, PaddleH
                    sub ecx, 20
                    cmp eax, ecx
                    jle @F
                    mov eax, ecx
                @@:
                    mov Paddle1Y, eax

                ; --- P2 键盘控制 (上下方向键) ---
                .elseif wParam == VK_UP
                    mov eax, Paddle2Y
                    sub eax, PaddleSpeed
                    cmp eax, 0
                    jge @F
                    mov eax, 0
                @@:
                    mov Paddle2Y, eax
                .elseif wParam == VK_DOWN
                    mov eax, Paddle2Y
                    add eax, PaddleSpeed
                    mov ecx, WindowH
                    sub ecx, PaddleH
                    sub ecx, 20
                    cmp eax, ecx
                    jle @F
                    mov eax, ecx
                    @@:
                    mov Paddle2Y, eax

                .elseif wParam == VK_ESCAPE
                    invoke KillTimer, hwnd, TimerID
                    invoke MessageBox, hwnd, ADDR PauseMsg, ADDR PauseCaption, MB_OK
                    invoke SetTimer, hwnd, TimerID, TimerDelay, NULL
            .endif

        .elseif uMsg == WM_TIMER
            invoke UpdateGame
            invoke InvalidateRect, hwnd, NULL, FALSE
            
        .elseif uMsg == WM_PAINT
            invoke BeginPaint, hwnd, addr ps
            mov hdc, eax

            ; 获取客户区大小
            invoke GetClientRect, hwnd, addr rectClient

            ; 创建内存DC和兼容位图
            invoke CreateCompatibleDC, hdc
            mov memDC, eax
            invoke CreateCompatibleBitmap, hdc, rectClient.right, rectClient.bottom
            mov hBitmap, eax
            invoke SelectObject, memDC, hBitmap
            mov hOld, eax

            ; 用黑色填充背景
            invoke GetStockObject, BLACK_BRUSH
            invoke FillRect, memDC, addr rectClient, eax

            ; 1. 绘制 P1 挡板 (蓝色)
            invoke SelectObject, memDC, hBrushPad1
            mov eax, Paddle1X
            add eax, PaddleW
            mov ecx, Paddle1Y
            add ecx, PaddleH
            invoke Rectangle, memDC, Paddle1X, Paddle1Y, eax, ecx

            ; 2. 绘制 P2 挡板 (黄色)
            invoke SelectObject, memDC, hBrushPad2
            mov eax, Paddle2X
            add eax, PaddleW
            mov ecx, Paddle2Y
            add ecx, PaddleH
            invoke Rectangle, memDC, Paddle2X, Paddle2Y, eax, ecx

            ; 3. 绘制球 (红色)
            invoke SelectObject, memDC, hBrushBall
            mov eax, BallX
            add eax, BallSize
            mov ecx, BallY
            add ecx, BallSize
            invoke Ellipse, memDC, BallX, BallY, eax, ecx

            ; 4. 绘制砖块 (绿色)
            invoke SelectObject, memDC, hBrushBrick
            
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

                ; 绘制矩形
                mov eax, currentX
                add eax, BrickW
                mov ebx, currentY
                add ebx, BrickH
                
                push ecx
                invoke Rectangle, memDC, currentX, currentY, eax, ebx
                pop ecx

            PaintSkip:
                inc esi
                inc ecx
                
                mov eax, currentX
                add eax, BrickW
                add eax, BrickGap
                mov currentX, eax
                jmp PaintColLoop

            PaintNextRow:
                inc edi
                
                mov eax, currentY
                add eax, BrickH
                add eax, BrickGap
                mov currentY, eax
                jmp PaintRowLoop

            PaintEnd:
                pop edi
                pop esi
                pop ebx

                ; ========== 绘制完成，复制到屏幕 ==========
                invoke BitBlt, hdc, 0, 0, rectClient.right, rectClient.bottom, memDC, 0, 0, SRCCOPY

                ; 清理资源
                invoke SelectObject, memDC, hOld
                invoke DeleteObject, hBitmap
                invoke DeleteDC, memDC

                invoke EndPaint, hwnd, addr ps

        .else
            invoke DefWindowProc, hwnd, uMsg, wParam, lParam
            ret
    .endif

    xor eax, eax
    ret
WndProc endp

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax
end start