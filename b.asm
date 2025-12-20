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
    AppName     db "MASM32 2P 2Balls - Life Mode",0
    ClassName   db "BreakoutClass",0
    
    WindowW     dd 710
    WindowH     dd 640
    TimerID     dd 1
    TimerDelay  dd 16
    
    ; 玩家生命值
    Life1       dd 3
    Life2       dd 3
    LifeSize    dd 15
    
    ; 球数据
    Ball1X      dd 100
    Ball1Y      dd 320
    Vel1X       dd 5
    Vel1Y       dd 5
    
    Ball2X      dd 580
    Ball2Y      dd 320
    Vel2X       dd -5
    Vel2Y       dd -4
    
    BallSize    dd 24
    
    ; 挡板
    Paddle1X    dd 15
    Paddle1Y    dd 270
    Paddle2X    dd 680
    Paddle2Y    dd 270
    PaddleW     dd 15
    PaddleH     dd 100
    PaddleSpeed dd 20
    
    ; 砖块
    Bricks      db 1,1,1,1,1
                db 1,1,1,1,1
                db 1,1,1,1,1
    BrickRows   dd 5
    BrickCols   dd 3
    BrickW      dd 30
    BrickH      dd 100
    BrickGap    dd 10
    BrickOffX   dd 340
    BrickOffY   dd 60 ; 稍微下移，给生命值留空间

    MsgP1Win    db "Player 2 Out of Lives! Player 1 Wins!", 0
    MsgP2Win    db "Player 1 Out of Lives! Player 2 Wins!", 0
    GameOverCap db "Game Over", 0

.data?
    hInstance   HINSTANCE ?
    hBrushBall  HBRUSH ?
    hBrushPad1  HBRUSH ?
    hBrushPad2  HBRUSH ?
    hBrushBrick HBRUSH ?
    hBrushLife  HBRUSH ?

.code

CheckKeyboard proc
    invoke GetAsyncKeyState, 57h ; W
    .if eax
        sub Paddle1Y, 20
        .if sdword ptr Paddle1Y < 0
            mov Paddle1Y, 0
        .endif
    .endif
    invoke GetAsyncKeyState, 53h ; S
    .if eax
        add Paddle1Y, 20
        .if Paddle1Y > 500
            mov Paddle1Y, 500
        .endif
    .endif
    invoke GetAsyncKeyState, VK_UP
    .if eax
        sub Paddle2Y, 20
        .if sdword ptr Paddle2Y < 0
            mov Paddle2Y, 0
        .endif
    .endif
    invoke GetAsyncKeyState, VK_DOWN
    .if eax
        add Paddle2Y, 20
        .if Paddle2Y > 500
            mov Paddle2Y, 500
        .endif
    .endif
    ret
CheckKeyboard endp

UpdateGame proc uses esi edi ebx hwnd:HWND
    invoke CheckKeyboard

    ; 更新球位置
    mov eax, Vel1X
    add Ball1X, eax
    mov eax, Vel1Y
    add Ball1Y, eax
    
    mov eax, Vel2X
    add Ball2X, eax
    mov eax, Vel2Y
    add Ball2Y, eax

    ; 通用边界：顶底反弹
    .if sdword ptr Ball1Y < 0 || Ball1Y > 580
        neg Vel1Y
    .endif
    .if sdword ptr Ball2Y < 0 || Ball2Y > 580
        neg Vel2Y
    .endif

    ; --- 核心逻辑：失误判定 (碰到自己这边的墙) ---
    ; 球1是P1的球，如果Ball1X < 0，P1失误
    .if sdword ptr Ball1X < 0
        dec Life1
        mov Ball1X, 100
        mov Vel1X, 5
    .endif
    ; 球2是P2的球，如果Ball2X > 680，P2失误
    .if Ball2X > 680
        dec Life2
        mov Ball2X, 580
        mov Vel2X, -5
    .endif

    ; 球1碰到右墙 (正常反弹)
    .if Ball1X > 680
        neg Vel1X
    .endif
    ; 球2碰到左墙 (正常反弹)
    .if sdword ptr Ball2X < 0
        neg Vel2X
    .endif

    ; --- 核心逻辑：挡板碰撞判定 ---
    ; 1. P1 挡板碰撞
    mov eax, Ball1X
    .if eax < 30 ; 自己的球：反弹
        ; (AABB 检测代码省略部分细节以节省空间，逻辑同前)
        mov eax, Ball1Y
        add eax, BallSize
        .if eax >= Paddle1Y
            mov ecx, Paddle1Y
            add ecx, PaddleH
            .if Ball1Y <= ecx
                mov eax, Paddle1X
                add eax, PaddleW
                .if Ball1X <= eax
                    neg Vel1X
                    mov Ball1X, eax
                .endif
            .endif
        .endif
    .endif
    
    mov eax, Ball2X
    .if eax < 30 ; 对方的球：掉生命并反弹
        mov eax, Ball2Y
        add eax, BallSize
        .if eax >= Paddle1Y
            mov ecx, Paddle1Y
            add ecx, PaddleH
            .if Ball2Y <= ecx
                mov eax, Paddle1X
                add eax, PaddleW
                .if Ball2X <= eax
                    dec Life1 ; 被击中！
                    neg Vel2X
                    mov Ball2X, eax
                .endif
            .endif
        .endif
    .endif

    ; 2. P2 挡板碰撞
    mov eax, Ball1X
    .if eax > 650 ; 对方的球：掉生命并反弹
        mov eax, Ball1Y
        add eax, BallSize
        .if eax >= Paddle2Y
            mov ecx, Paddle2Y
            add ecx, PaddleH
            .if Ball1Y <= ecx
                mov eax, Ball1X
                add eax, BallSize
                .if eax >= Paddle2X
                    dec Life2 ; 被击中！
                    neg Vel1X
                    mov eax, Paddle2X
                    sub eax, BallSize
                    mov Ball1X, eax
                .endif
            .endif
        .endif
    .endif

    mov eax, Ball2X
    .if eax > 650 ; 自己的球：反弹
        mov eax, Ball2Y
        add eax, BallSize
        .if eax >= Paddle2Y
            mov ecx, Paddle2Y
            add ecx, PaddleH
            .if Ball2Y <= ecx
                mov eax, Ball2X
                add eax, BallSize
                .if eax >= Paddle2X
                    neg Vel2X
                    mov eax, Paddle2X
                    sub eax, BallSize
                    mov Ball2X, eax
                .endif
            .endif
        .endif
    .endif

    ; 砖块碰撞逻辑 (省略重复代码，逻辑同前，仅负责反弹)

    ; --- 死亡判定 ---
    .if Life1 == 0
        invoke KillTimer, hwnd, TimerID
        invoke MessageBox, hwnd, addr MsgP2Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
    .elseif Life2 == 0
        invoke KillTimer, hwnd, TimerID
        invoke MessageBox, hwnd, addr MsgP1Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
    .endif

    ret
UpdateGame endp

PaintGame proc hdc:HDC, lprect:PTR RECT
    local memDC:HDC
    local hBitmap:HBITMAP
    local hOld:HBITMAP
    local rectClient:RECT

    invoke CreateCompatibleDC, hdc
    mov memDC, eax
    invoke CreateCompatibleBitmap, hdc, 710, 640
    mov hBitmap, eax
    invoke SelectObject, memDC, hBitmap
    mov hOld, eax

    ; 背景
    invoke GetStockObject, BLACK_BRUSH
    mov rectClient.left, 0
    mov rectClient.top, 0
    mov rectClient.right, 710
    mov rectClient.bottom, 640
    invoke FillRect, memDC, addr rectClient, eax

    ; 绘制生命值 (UI)
    invoke SelectObject, memDC, hBrushLife
    ; P1 生命 (左上)
    mov edi, 0
    .while edi < Life1
        mov eax, edi
        imul eax, 25
        add eax, 20 ; X offset
        mov ebx, 10 ; Y offset
        mov ecx, eax
        add ecx, LifeSize
        mov edx, ebx
        add edx, LifeSize
        push edi
        invoke Ellipse, memDC, eax, ebx, ecx, edx
        pop edi
        inc edi
    .endw
    ; P2 生命 (右上)
    mov edi, 0
    .while edi < Life2
        mov eax, 660
        mov ebx, edi
        imul ebx, 25
        sub eax, ebx
        mov ebx, 10
        mov ecx, eax
        add ecx, LifeSize
        mov edx, ebx
        add edx, LifeSize
        push edi
        invoke Ellipse, memDC, eax, ebx, ecx, edx
        pop edi
        inc edi
    .endw

    ; 绘制挡板和球 (逻辑同前)
    invoke SelectObject, memDC, hBrushPad1
    mov eax, Paddle1X
    add eax, PaddleW
    mov ecx, Paddle1Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle1X, Paddle1Y, eax, ecx

    invoke SelectObject, memDC, hBrushPad2
    mov eax, Paddle2X
    add eax, PaddleW
    mov ecx, Paddle2Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle2X, Paddle2Y, eax, ecx

    invoke SelectObject, memDC, hBrushBall
    mov eax, Ball1X
    add eax, BallSize
    mov ecx, Ball1Y
    add ecx, BallSize
    invoke Ellipse, memDC, Ball1X, Ball1Y, eax, ecx
    mov eax, Ball2X
    add eax, BallSize
    mov ecx, Ball2Y
    add ecx, BallSize
    invoke Ellipse, memDC, Ball2X, Ball2Y, eax, ecx

    ; 绘制砖块 (略...)

    invoke BitBlt, hdc, 0, 0, 710, 640, memDC, 0, 0, SRCCOPY
    invoke SelectObject, memDC, hOld
    invoke DeleteObject, hBitmap
    invoke DeleteDC, memDC
    ret
PaintGame endp

; WndProc 和 WinMain 结构保持不变，在 WM_CREATE 中增加 hBrushLife 的初始化
; invoke CreateSolidBrush, 000000FFh ; 红色画刷
; mov hBrushLife, eax

; ... 剩下的代码逻辑参考之前的结构 ...