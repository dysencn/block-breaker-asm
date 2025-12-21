.386
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\masm32.inc 

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\masm32.lib ; 引入masm32库用于字符串转换

.data
    AppName     db "MASM32 Breakout - Multi-Life Bricks",0
    ClassName   db "BreakoutClass",0
    
    WindowW     dd 710
    WindowH     dd 640
    TimerID     dd 1
    TimerDelay  dd 16

    ; 玩家生命值
    Life1       dd 3
    Life2       dd 3
    LifeSize    dd 15
    
    ; 球 1
    Ball1X      dd 80
    Ball1Y      dd 320
    Vel1X       dd 4
    Vel1Y       dd 4
    
    ; 球 2
    Ball2X      dd 600
    Ball2Y      dd 320
    Vel2X       dd -4
    Vel2Y       dd -5
    
    BallSize    dd 24
    
    ; 挡板
    Paddle1X    dd 15
    Paddle1Y    dd 270
    Paddle2X    dd 680
    Paddle2Y    dd 270
    PaddleW     dd 15
    PaddleH     dd 100
    PaddleSpeed dd 20
    
    ; 砖块配置
    ; 注意：这里分配了空间，但数值将在 InitBricks 中被随机覆盖
    Bricks      db 15 dup(1) 
    BrickRows   dd 5
    BrickCols   dd 3
    BrickW      dd 30
    BrickH      dd 100
    BrickGap    dd 10
    BrickOffX   dd 340
    BrickOffY   dd 60
    
    PauseCaption db "Game Paused", 0
    PauseMsg     db "Game is paused. Click OK to continue.", 0

    MsgP1Win     db "Player 2 Out of Lives! Player 1 Wins!", 0
    MsgP2Win     db "Player 1 Out of Lives! Player 2 Wins!", 0
    GameOverCap  db "Game Over", 0

    ; 随机数种子
    RandSeed     dd 0

.data?
    hInstance   HINSTANCE ?
    hBrushBall  HBRUSH ?
    hBrushPad1  HBRUSH ?
    hBrushPad2  HBRUSH ?
    hBrushBrick HBRUSH ?
    hBrushLife  HBRUSH ?
    
    ; 用于显示数字的临时缓冲区
    szNumBuffer db 4 dup(?) 

.code

WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD

; --- 简单的随机数生成器 ---
; 输入: 范围上限 (例如 5)
; 输出: eax = 1 到 Range 之间的随机数
GetRandomRange proc range:DWORD
    invoke GetTickCount
    add eax, RandSeed      ; 混入之前的种子
    imul eax, eax, 1103515245
    add eax, 12345
    mov RandSeed, eax      ; 更新种子
    xor edx, edx
    mov ecx, range
    div ecx                ; edx = eax % range
    mov eax, edx
    inc eax                ; 结果 + 1 (变为 1-5)
    ret
GetRandomRange endp

; --- 初始化砖块生命值 ---
InitBricks proc
    mov esi, offset Bricks
    mov ecx, 15 ; 总共15块砖 (5行 * 3列)
InitLoop:
    push ecx
    push esi
    invoke GetRandomRange, 5 ; 生成 1-5
    pop esi
    mov byte ptr [esi], al   ; 存入砖块数组
    inc esi
    pop ecx
    dec ecx
    jnz InitLoop
    ret
InitBricks endp

CheckKeyboard proc
    ; --- P1 控制 (W/S) ---
    invoke GetAsyncKeyState, 57h ; W
    .if eax != 0
        mov eax, Paddle1Y
        sub eax, PaddleSpeed
        .if sdword ptr eax < 0
            mov eax, 0
        .endif
        mov Paddle1Y, eax
    .endif

    invoke GetAsyncKeyState, 53h ; S
    .if eax != 0
        mov eax, Paddle1Y
        add eax, PaddleSpeed
        mov ecx, WindowH
        sub ecx, PaddleH
        sub ecx, 40
        .if eax > ecx
            mov eax, ecx
        .endif
        mov Paddle1Y, eax
    .endif

    ; --- P2 控制 (UP/DOWN) ---
    invoke GetAsyncKeyState, VK_UP
    .if eax != 0
        mov eax, Paddle2Y
        sub eax, PaddleSpeed
        .if sdword ptr eax < 0
            mov eax, 0
        .endif
        mov Paddle2Y, eax
    .endif

    invoke GetAsyncKeyState, VK_DOWN
    .if eax != 0
        mov eax, Paddle2Y
        add eax, PaddleSpeed
        mov ecx, WindowH
        sub ecx, PaddleH
        sub ecx, 40
        .if eax > ecx
            mov eax, ecx
        .endif
        mov Paddle2Y, eax
    .endif
    ret
CheckKeyboard endp

UpdateGame proc hWin:HWND
    ; 检查生命值
    .if Life1 == 0
        invoke KillTimer, hWin, TimerID
        invoke MessageBox, hWin, addr MsgP2Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
        mov Life1, -1 
        ret
    .elseif Life2 == 0
        invoke KillTimer, hWin, TimerID
        invoke MessageBox, hWin, addr MsgP1Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
        mov Life2, -1 
        ret
    .endif

    .if sdword ptr Life1 < 0 || sdword ptr Life2 < 0
        ret
    .endif

    invoke CheckKeyboard

    ; 更新球位置
    mov eax, Ball1X
    add eax, Vel1X
    mov Ball1X, eax
    mov eax, Ball1Y
    add eax, Vel1Y
    mov Ball1Y, eax

    mov eax, Ball2X
    add eax, Vel2X
    mov Ball2X, eax
    mov eax, Ball2Y
    add eax, Vel2Y
    mov Ball2Y, eax

    ; 边界反弹
    .if sdword ptr Ball1Y < 0 || Ball1Y > 580
        neg Vel1Y
    .endif
    .if sdword ptr Ball2Y < 0 || Ball2Y > 580
        neg Vel2Y
    .endif

    ; 左右出界判定 (失误)
    .if sdword ptr Ball1X < 0
        dec Life1
        mov Ball1X, 100
        mov Vel1X, 5
    .endif
    .if Ball2X > 680
        dec Life2
        mov Ball2X, 580
        mov Vel2X, -5
    .endif

    ; 墙壁反弹
    .if Ball1X > 680
        neg Vel1X
    .endif
    .if sdword ptr Ball2X < 0
        neg Vel2X
    .endif

    ; --- 挡板碰撞判定 (P1) ---
    mov eax, Paddle1X
    add eax, PaddleW
    .if Ball1X < eax
        mov edx, Paddle1Y
        mov ecx, edx
        add ecx, PaddleH

        .if Ball1Y >= edx && Ball1Y <= ecx
            neg Vel1X
            mov eax, Paddle1X
            add eax, PaddleW
            mov Ball1X, eax
        .endif
    .endif
    
    mov eax, Ball2X
    .if eax < 30 
        mov eax, Ball2Y
        add eax, BallSize
        .if eax >= Paddle1Y
            mov ecx, Paddle1Y
            add ecx, PaddleH
            .if Ball2Y <= ecx
                mov eax, Paddle1X
                add eax, PaddleW
                .if Ball2X <= eax
                    dec Life1 
                    neg Vel2X
                    mov Ball2X, eax
                .endif
            .endif
        .endif
    .endif

    ; --- 挡板碰撞判定 (P2) ---
    mov eax, Ball1X
    .if eax > 650 
        mov eax, Ball1Y
        add eax, BallSize
        .if eax >= Paddle2Y
            mov ecx, Paddle2Y
            add ecx, PaddleH
            .if Ball1Y <= ecx
                mov eax, Ball1X
                add eax, BallSize
                .if eax >= Paddle2X
                    dec Life2 
                    neg Vel1X
                    mov eax, Paddle2X
                    sub eax, BallSize
                    mov Ball1X, eax
                .endif
            .endif
        .endif
    .endif

    mov eax, Ball2X
    .if eax > 650 
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

    ; --- 砖块碰撞检测 (球1) ---
    mov esi, offset Bricks
    mov edi, 0
    mov ebx, BrickOffY
B1_Row:
    cmp edi, BrickRows
    jge B2_Check
    mov ecx, 0
    mov edx, BrickOffX
B1_Col:
    cmp ecx, BrickCols
    jge B1_NextRow
    
    ; [修改1] 只要生命值 > 0 就算存在
    cmp byte ptr [esi], 0
    je B1_Skip

    ; AABB检测
    mov eax, Ball1X
    add eax, BallSize
    cmp eax, edx
    jle B1_Skip
    mov eax, edx
    add eax, BrickW
    cmp Ball1X, eax
    jge B1_Skip
    mov eax, Ball1Y
    add eax, BallSize
    cmp eax, ebx
    jle B1_Skip
    mov eax, ebx
    add eax, BrickH
    cmp Ball1Y, eax
    jge B1_Skip
    
    ; [修改2] 撞到了，生命值减1，而不是直接清零
    dec byte ptr [esi]
    neg Vel1X
    jmp B2_Check 
B1_Skip:
    inc esi
    inc ecx
    add edx, BrickW
    add edx, BrickGap
    jmp B1_Col
B1_NextRow:
    inc edi
    add ebx, BrickH
    add ebx, BrickGap
    jmp B1_Row

B2_Check:
    ; --- 砖块碰撞检测 (球2) ---
    mov esi, offset Bricks
    mov edi, 0
    mov ebx, BrickOffY
B2_Row:
    cmp edi, BrickRows
    jge UpdateDone
    mov ecx, 0
    mov edx, BrickOffX
B2_Col:
    cmp ecx, BrickCols
    jge B2_NextRow
    
    ; [修改1] 检测生命值 > 0
    cmp byte ptr [esi], 0
    je B2_Skip

    ; AABB检测
    mov eax, Ball2X
    add eax, BallSize
    cmp eax, edx
    jle B2_Skip
    mov eax, edx
    add eax, BrickW
    cmp Ball2X, eax
    jge B2_Skip
    mov eax, Ball2Y
    add eax, BallSize
    cmp eax, ebx
    jle B2_Skip
    mov eax, ebx
    add eax, BrickH
    cmp Ball2Y, eax
    jge B2_Skip
    
    ; [修改2] 撞到了，生命值减1
    dec byte ptr [esi]
    neg Vel2X
    jmp UpdateDone
B2_Skip:
    inc esi
    inc ecx
    add edx, BrickW
    add edx, BrickGap
    jmp B2_Col
B2_NextRow:
    inc edi
    add ebx, BrickH
    add ebx, BrickGap
    jmp B2_Row

UpdateDone:
    ret
UpdateGame endp

PaintGame proc hdc:HDC, lprect:PTR RECT
    local memDC:HDC
    local hBitmap:HBITMAP
    local hOld:HBITMAP
    local rectClient:RECT
    local currentX:DWORD
    local currentY:DWORD
    local rectBrick:RECT ; 用于绘制文字的矩形区域

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
    ; P1
    mov edi, 0
    .while edi < Life1
        mov eax, edi
        imul eax, 25
        add eax, 20
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
    ; P2
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

    ; 绘制挡板
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

    ; 绘制球
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

    ; --- 绘制砖块及文字 ---
    invoke SelectObject, memDC, hBrushBrick
    
    ; 设置文字属性：白色，背景透明
    invoke SetTextColor, memDC, 00FFFFFFh 
    invoke SetBkMode, memDC, TRANSPARENT

    mov esi, offset Bricks
    mov edi, 0
    mov eax, BrickOffY
    mov currentY, eax
PaintRow:
    cmp edi, BrickRows
    jge PaintEnd
    mov ecx, 0
    mov eax, BrickOffX
    mov currentX, eax
PaintCol:
    cmp ecx, BrickCols
    jge PaintNext
    
    ; [修改3] 只要生命值 > 0 就绘制
    cmp byte ptr [esi], 0
    je SkipP

    ; 1. 绘制矩形
    mov eax, currentX
    add eax, BrickW
    mov ebx, currentY
    add ebx, BrickH
    push ecx
    invoke Rectangle, memDC, currentX, currentY, eax, ebx
    
    ; 2. 绘制生命值数字
    ; 设置绘制区域 rectBrick
    mov eax, currentX
    mov rectBrick.left, eax
    add eax, BrickW
    mov rectBrick.right, eax
    
    mov eax, currentY
    mov rectBrick.top, eax
    add eax, BrickH
    mov rectBrick.bottom, eax

    ; 将数字转为字符串
    xor eax, eax
    mov al, byte ptr [esi] ; 获取当前生命值
    add al, '0'            ; 转换为ASCII字符 (例如 3 -> '3')
    mov szNumBuffer[0], al
    mov szNumBuffer[1], 0  ; 字符串结尾

    ; 绘制文字于矩形中心
    invoke DrawText, memDC, addr szNumBuffer, -1, addr rectBrick, DT_CENTER or DT_VCENTER or DT_SINGLELINE

    pop ecx
SkipP:
    inc esi
    inc ecx
    mov eax, currentX
    add eax, BrickW
    add eax, BrickGap
    mov currentX, eax
    jmp PaintCol
PaintNext:
    inc edi
    mov eax, currentY
    add eax, BrickH
    add eax, BrickGap
    mov currentY, eax
    jmp PaintRow

PaintEnd:
    invoke BitBlt, hdc, 0, 0, 710, 640, memDC, 0, 0, SRCCOPY
    invoke SelectObject, memDC, hOld
    invoke DeleteObject, hBitmap
    invoke DeleteDC, memDC
    ret
PaintGame endp

WndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    local ps:PAINTSTRUCT
    .if uMsg == WM_CREATE
        ; 初始化资源
        invoke CreateSolidBrush, 000000FFh ; 红球
        mov hBrushBall, eax
        invoke CreateSolidBrush, 00FF0000h ; 蓝板
        mov hBrushPad1, eax
        invoke CreateSolidBrush, 0000FFFFh ; 黄板
        mov hBrushPad2, eax
        invoke CreateSolidBrush, 00008000h ; 绿砖
        mov hBrushBrick, eax
        invoke CreateSolidBrush, 000000FFh ; 生命指示
        mov hBrushLife, eax
        
        ; [新增] 初始化随机砖块生命值
        invoke GetTickCount
        mov RandSeed, eax ; 初始化随机种子
        invoke InitBricks

        invoke SetTimer, hwnd, TimerID, TimerDelay, NULL
    .elseif uMsg == WM_TIMER
        invoke UpdateGame, hwnd
        invoke InvalidateRect, hwnd, NULL, FALSE
    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hwnd, addr ps
        push eax
        lea ecx, ps.rcPaint
        pop eax
        invoke PaintGame, eax, ecx 
        invoke EndPaint, hwnd, addr ps
    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_ESCAPE
            invoke KillTimer, hwnd, TimerID
            invoke MessageBox, hwnd, addr PauseMsg, addr PauseCaption, MB_OK
            invoke SetTimer, hwnd, TimerID, TimerDelay, NULL
        .endif
    .elseif uMsg == WM_DESTROY
        invoke DeleteObject, hBrushBall
        invoke DeleteObject, hBrushPad1
        invoke DeleteObject, hBrushPad2
        invoke DeleteObject, hBrushBrick
        invoke PostQuitMessage, NULL
    .else
        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret
    .endif
    xor eax, eax
    ret
WndProc endp

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
    mov wc.hbrBackground, COLOR_WINDOWTEXT+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset ClassName
    mov wc.hIcon, NULL
    mov wc.hIconSm, NULL
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    invoke RegisterClassEx, addr wc
    invoke CreateWindowEx, NULL, addr ClassName, addr AppName,
           WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,
           CW_USEDEFAULT, CW_USEDEFAULT, WindowW, WindowH,
           NULL, NULL, hInst, NULL
    mov hwnd, eax
    invoke ShowWindow, hwnd, CmdShow
    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw
    ret
WinMain endp

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax
end start