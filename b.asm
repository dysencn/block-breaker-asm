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
includelib \masm32\lib\masm32.lib

.data
    AppName     db "MASM32 Breakout",0
    ClassName   db "BreakoutClass",0
    
    WindowW     dd 710
    WindowH     dd 640
    TimerID     dd 1
    TimerDelay  dd 16

    ; 玩家生命值
    Life1       dd 3
    Life2       dd 3
    LifeSize    dd 15
    
    ; --- 球数据 ---
    Ball1X      dd 80
    Ball1Y      dd 320
    Vel1X       dd 4
    Vel1Y       dd 4
    Ball1Color  dd 0 
    
    Ball2X      dd 600
    Ball2Y      dd 320
    Vel2X       dd -4
    Vel2Y       dd -4
    Ball2Color  dd 0 
    
    BallSize    dd 24
    
    ; --- 挡板数据 ---
    Paddle1X    dd 15
    Paddle1Y    dd 270
    Paddle2X    dd 680
    Paddle2Y    dd 270
    PaddleW     dd 15
    PaddleH     dd 100
    PaddleSpeed dd 20
    Pad1Color   dd 0 
    Pad2Color   dd 0 
    
    ; --- 砖块配置 ---
    Bricks      db 15 dup(1) 
    BrickColors db 15 dup(0) 
    
    BrickRows   dd 5
    BrickCols   dd 3
    BrickW      dd 30
    BrickH      dd 100
    BrickGap    dd 10
    BrickOffX   dd 300
    BrickOffY   dd 30

    Life1X      dd 40
    LifeY       dd 10
    Life2X      dd 660
    LifeSpace   dd 25

    ; --- 初始位置常量 (用于蒸发/超导) ---
    Ball1InitX  dd 80
    Ball1InitY  dd 320
    Ball2InitX  dd 600
    Ball2InitY  dd 320

    ; --- 反应状态 ---
    FreezeTimer1 dd 0    ; 球1冻结计时器
    FreezeTimer2 dd 0    ; 球2冻结计时器

    ; --- 颜色系统配置 ---
    ColorValues dd 000000FFh ; 0 红色
                dd 00800000h ; 1 深蓝色
                dd 00999900h ; 2 蓝绿
                dd 00800080h ; 3 紫色
                dd 00E6D8ADh ; 4 浅蓝色
    
    PauseCaption db "Game Paused", 0
    PauseMsg     db "Game is paused. Click OK to continue.", 0
    MsgP1Win     db "Player 2 Out of Lives! Player 1 Wins!", 0
    MsgP2Win     db "Player 1 Out of Lives! Player 2 Wins!", 0
    GameOverCap  db "Game Over", 0
    RandSeed     dd 0

    MAX_EFFECTS    equ 10         ; 同时最多显示10个飘字
    EffectActive   db MAX_EFFECTS dup(0) ; 特效是否激活
    EffectX        dd MAX_EFFECTS dup(0)
    EffectY        dd MAX_EFFECTS dup(0)
    EffectLife     dd MAX_EFFECTS dup(0) ; 生命周期（如从255递减到0）
    TxtMinusOne    db "-1", 0

    msgBuf db 64 dup(0)

.data?
    hInstance     HINSTANCE ?
    hColorBrushes dd 5 dup(?) 
    hBrushLife    HBRUSH ?    ; 专门用于固定红色的生命值点
    szNumBuffer   db 4 dup(?) 

.code

WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD

; --- 工具函数 ---
GetRandomIdx proc range:DWORD
    invoke GetTickCount
    add eax, RandSeed      
    imul eax, eax, 1103515245
    add eax, 12345
    mov RandSeed, eax      
    xor edx, edx
    mov ecx, range
    div ecx                
    mov eax, edx
    ret
GetRandomIdx endp

;飘字函数
SpawnEffect proc x:DWORD, y:DWORD
    push eax
    push ecx
    mov ecx, 0
@@:
    .if EffectActive[ecx] == 0
        mov EffectActive[ecx], 1
        mov eax, x
        mov EffectX[ecx*4], eax
        mov eax, y
        mov EffectY[ecx*4], eax
        mov EffectLife[ecx*4], 40    ; 设置20帧的寿命
        jmp @f
    .endif
    inc ecx
    cmp ecx, MAX_EFFECTS
    jl @b
@@:
    pop ecx
    pop eax
    ret
SpawnEffect endp

; --- 重置球的位置 (用于 蒸发) ---
ResetBallPos proc bIdx:DWORD
    .if bIdx == 1
        mov eax, Ball1InitX
        mov Ball1X, eax
        mov eax, Ball1InitY
        mov Ball1Y, eax
        ; 速度重置为初始正向
        mov Vel1X, 4
        mov Vel1Y, 4
    .else
        mov eax, Ball2InitX
        mov Ball2X, eax
        mov eax, Ball2InitY
        mov Ball2Y, eax
        mov Vel2X, -4
        mov Vel2Y, -4
    .endif
    ret
ResetBallPos endp


;扩散反应
HandleSwirl proc bIdx:DWORD, bc:DWORD, tc:DWORD
    local targetColor:DWORD
    ; 确定染色目标
    mov eax, bc
    .if eax == 2
        mov eax, tc ; 球是风，染成砖块色
    .else
        mov eax, bc ; 砖块是风，染成球色
    .endif
    mov targetColor, eax
    
    ; 这里的逻辑较复杂，简化演示：修改对应索引的 BrickColors
    ; 实际应用时需计算上下左右的索引并检查边界
    ret 
HandleSwirl endp

;冻结反应
FreezeBall proc bIdx:DWORD
    .if bIdx == 1
        mov FreezeTimer1, 120 ; 约2秒 (60fps * 2)
    .else
        mov FreezeTimer2, 120
    .endif
    ret
FreezeBall endp

; --- 融化：场上所有 冰(4) 变为 水(1) ---
MeltReaction proc
    mov ecx, 0
@@:
    .if BrickColors[ecx] == 4 ; 冰
        mov BrickColors[ecx], 1 ; 变水
    .endif
    inc ecx
    cmp ecx, 15
    jl @b
    ret
MeltReaction endp

;感电
ElectroCharged proc
    mov ecx, 0
@@:
    mov al, BrickColors[ecx]
    .if al == 1 ; 水元素
        .if Bricks[ecx] > 0
            dec Bricks[ecx]
        .endif
    .endif
    inc ecx
    cmp ecx, 15
    jl @b
    ret
ElectroCharged endp

; --- 超导：传送到对方球的初始位置 ---
SuperConduct proc bIdx:DWORD
    .if bIdx == 1
        mov eax, Ball2InitX
        mov Ball1X, eax
        mov eax, Ball2InitY
        mov Ball1Y, eax
    .else
        mov eax, Ball1InitX
        mov Ball2X, eax
        mov eax, Ball1InitY
        mov Ball2Y, eax
    .endif
    ret
SuperConduct endp

; --- 内部工具：安全扣除砖块血量 ---
DamageBrick proc idx:DWORD
    mov ecx, idx
    .if byte ptr Bricks[ecx] > 0
        dec byte ptr Bricks[ecx]
    .endif
    ret
DamageBrick endp

; --- 超载：附近砖块血量减1 ---
Overloaded proc brickIdx:DWORD
    local row:DWORD
    local col:DWORD

    ; 计算行列 (Index = Row * 3 + Col)
    mov eax, brickIdx
    xor edx, edx
    mov ecx, 3
    div ecx
    mov row, eax
    mov col, edx

    ; 这里的逻辑是简单的：尝试减少周围 4 个方向的血量
    ; 向上 (row-1)
    .if row > 0
        mov eax, brickIdx
        sub eax, 3
        invoke DamageBrick, eax
    .endif
    ; 向下 (row+1)
    .if row < 4
        mov eax, brickIdx
        add eax, 3
        invoke DamageBrick, eax
    .endif
    ; 向左 (col-1)
    .if col > 0
        mov eax, brickIdx
        dec eax
        invoke DamageBrick, eax
    .endif
    ; 向右 (col+1)
    .if col < 2
        mov eax, brickIdx
        inc eax
        invoke DamageBrick, eax
    .endif
    ret
Overloaded endp


; --- 反应核心：输入球索引(1/2), 砖块索引(0-14), 球颜色, 砖块颜色 ---
TriggerReaction proc ballIdx:DWORD, brickIdx:DWORD, bColor:DWORD, tColor:DWORD
    mov eax, bColor
    .if eax == tColor
        ; --- 属性相同：常规减血 ---
        mov esi, offset Bricks
        add esi, brickIdx
        dec byte ptr [esi]
        ret
    .endif

    ; --- 处理【风】元素 (扩散) ---
    .if bColor == 2 || tColor == 2
        invoke HandleSwirl, brickIdx, bColor, tColor
        jmp DoneReaction
    .endif

    ; --- 处理其它组合 (水0, 火1, 雷3, 冰4) ---
    ; 这里使用一种简便算法：将两个颜色编号排序后组合判断
    mov eax, bColor
    mov ebx, tColor
    .if eax > ebx
        xchg eax, ebx ; 确保 eax < ebx
    .endif
    ; 现在 eax 是较小的颜色号，ebx 是较大的

    ; 水(1) + 火(0) -> [0, 1] 蒸发
    .if eax == 0 && ebx == 1
        mov esi, offset Bricks
        add esi, brickIdx
        mov byte ptr [esi], 0 ; 砖块消失
        invoke ResetBallPos, ballIdx
    
    ; 水(1) + 冰(4) -> [1, 4] 冻结
    .elseif eax == 1 && ebx == 4
        invoke FreezeBall, ballIdx

    ; 水(1) + 雷(3) -> [1, 3] 感电
    .elseif eax == 1 && ebx == 3
        invoke ElectroCharged

    ; 火(0) + 冰(4) -> [0, 4] 融化
    .elseif eax == 0 && ebx == 4
        invoke MeltReaction

    ; 火(0) + 雷(3) -> [0, 3] 超载
    .elseif eax == 0 && ebx == 3
        invoke Overloaded, brickIdx

    ; 冰(4) + 雷(3) -> [3, 4] 超导
    .elseif eax == 3 && ebx == 4
        invoke SuperConduct, ballIdx
    .endif

DoneReaction:
    ret
TriggerReaction endp

InitGameData proc
    mov esi, offset Bricks
    mov edi, offset BrickColors
    mov ecx, 15 
InitLoop:
    push ecx
    push edi
    push esi
    invoke GetRandomIdx, 5
    inc eax ; 随机生命 1-5
    pop esi
    mov byte ptr [esi], al
    inc esi
    invoke GetRandomIdx, 5
    pop edi
    mov byte ptr [edi], al
    inc edi
    pop ecx
    dec ecx
    jnz InitLoop

    invoke GetRandomIdx, 5
    mov Ball1Color, eax
    invoke GetRandomIdx, 5
    mov Ball2Color, eax
    invoke GetRandomIdx, 5
    mov Pad1Color, eax
    invoke GetRandomIdx, 5
    mov Pad2Color, eax
    ret
InitGameData endp

CheckKeyboard proc
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

UpdateGame proc hwnd:HWND

    ;生命检测
    .if Life1 == 0
        invoke KillTimer, hwnd, TimerID
        invoke MessageBox, hwnd, addr MsgP2Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
        mov Life1, -1 
        ret
    .elseif Life2 == 0
        invoke KillTimer, hwnd, TimerID
        invoke MessageBox, hwnd, addr MsgP1Win, addr GameOverCap, MB_OK
        invoke PostQuitMessage, 0
        mov Life2, -1 
        ret
    .endif
    .if sdword ptr Life1 < 0 || sdword ptr Life2 < 0
        ret
    .endif

    invoke CheckKeyboard

    .if FreezeTimer1 > 0
        dec FreezeTimer1
        jmp SkipBall1Pos ; 跳过 Ball1 的判断
    .endif

    ;球1的常规位置更新
    mov eax, Ball1X
    add eax, Vel1X
    mov Ball1X, eax
    mov eax, Ball1Y
    add eax, Vel1Y
    mov Ball1Y, eax

    ;球1上下反弹
    mov eax, WindowH
    sub eax, BallSize
    sub eax, BallSize
    .if sdword ptr Ball1Y < 0 || Ball1Y > eax
        neg Vel1Y
    .endif

    ; 球1墙壁反弹
    .if Ball1X > 680
        neg Vel1X
    .endif

    ; P1挡板与自己球
    mov eax, Paddle1X
    add eax, PaddleW
    .if Ball1X < eax
        mov edx, Paddle1Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball1Y >= sdword ptr edx && Ball1Y <= ecx
            neg Vel1X
            mov eax, Paddle1X
            add eax, PaddleW
            mov Ball1X, eax
            mov ecx, Pad1Color
            mov Ball1Color, ecx
            invoke GetRandomIdx, 5
            mov Pad1Color, eax
        .endif
    .endif

    ;P2挡板与对方球
    mov eax, Paddle2X
    sub eax, BallSize
    .if Ball1X > eax 
        mov edx, Paddle1Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball1Y >= sdword ptr edx && Ball1Y <= ecx
            dec Life2
            neg Vel1X
            mov eax, Paddle2X
            sub eax, BallSize
            mov Ball1X, eax
        .endif
    .endif

    ;球1出界判定 (失误)
    .if sdword ptr Ball1X < 0
        dec Life1
        mov Ball1X, 100
        mov Vel1X, 5
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
    cmp byte ptr [esi], 0
    je B1_Skip
    ; AABB
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

    ; 1. 计算砖块索引 (在你的循环中 esi 指向 Bricks 偏移)
    mov edx, esi
    sub edx, offset Bricks ; 现在 edx 就是 brickIdx
    
    ; 2. 调用反应函数
    invoke TriggerReaction, 1, edx, Ball1Color, eax
    
    ; 3. 处理反弹逻辑（如果没被冻结）
    .if FreezeTimer1 == 0
        neg Vel1X
    .endif

    ; --- 新增：触发特效 ---
    push edx    ; edx 是当前砖块的 X
    push ebx    ; ebx 是当前砖块的 Y
    invoke SpawnEffect, edx, ebx
    pop ebx
    pop edx

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

    SkipBall1Pos:

    .if FreezeTimer2 > 0
        dec FreezeTimer2
        jmp SkipBall2Pos ; 跳过 Ball1 的判断
    .endif

    ;球2的常规位置更新
    mov eax, Ball2X
    add eax, Vel2X
    mov Ball2X, eax
    mov eax, Ball2Y
    add eax, Vel2Y
    mov Ball2Y, eax


    ;球2上下反弹
    mov eax, WindowH
    sub eax, BallSize
    sub eax, BallSize
    .if sdword ptr Ball2Y < 0 || Ball2Y > eax
        neg Vel2Y
    .endif


    ; 球2墙壁反弹
    .if sdword ptr Ball2X < 0
        neg Vel2X
    .endif

    ;P1挡板与对方球
    mov eax, Paddle1X
    add eax, PaddleW
    .if Ball2X < eax
        mov edx, Paddle1Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball2Y >= edx && Ball2Y <= ecx
            dec Life1
            neg Vel2X
            mov eax, Paddle1X
            add eax, PaddleW
            mov Ball2X, eax
        .endif
    .endif

    ;P2挡板与自己球
    mov eax, Paddle2X
    sub eax, BallSize
    .if Ball2X > eax 
        mov edx, Paddle2Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball2Y >= sdword ptr edx && Ball2Y <= ecx
            neg Vel2X
            mov eax, Paddle2X
            sub eax, BallSize
            mov Ball2X, eax
            mov ecx, Pad2Color
            mov Ball2Color, ecx
            invoke GetRandomIdx, 5
            mov Pad2Color, eax
        .endif
    .endif




    ;球2出界判定 (失误)
    .if Ball2X > 680
        dec Life2
        mov Ball2X, 580
        mov Vel2X, -5
    .endif



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
    
    ; 1. 计算砖块索引 (在你的循环中 esi 指向 Bricks 偏移)
    mov edx, esi
    sub edx, offset Bricks ; 现在 edx 就是 brickIdx
    
    ; 2. 调用反应函数
    invoke TriggerReaction, 2, edx, Ball1Color, eax
    
    ; 3. 处理反弹逻辑（如果没被冻结）
    .if FreezeTimer1 == 0
        neg Vel2X
    .endif

    ; --- 新增：触发特效 ---
    push edx    ; edx 是当前砖块的 X
    push ebx    ; ebx 是当前砖块的 Y
    invoke SpawnEffect, edx, ebx
    pop ebx
    pop edx

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

SkipBall2Pos:

UpdateDone:

    ; 更新特效位置
    mov ecx, 0
UpdateEffLoop:
    .if EffectActive[ecx] != 0
        sub EffectY[ecx*4], 1       ; 每一帧向上飘2像素
        dec EffectLife[ecx*4]       ; 寿命减1
        .if EffectLife[ecx*4] == 0
            mov EffectActive[ecx], 0 ; 寿命耗尽，注销特效
        .endif
    .endif
    inc ecx
    cmp ecx, MAX_EFFECTS
    jl UpdateEffLoop

    ret
UpdateGame endp

PaintGame proc hdc:HDC, lprect:PTR RECT
    local memDC:HDC
    local hBitmap:HBITMAP
    local hOld:HBITMAP
    local rectClient:RECT
    local currentX:DWORD
    local currentY:DWORD
    local rectBrick:RECT
    local pColorArr:DWORD
    local rectEff:RECT

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

    ; --- 绘制生命值点 (强制固定红色) ---
    invoke SelectObject, memDC, hBrushLife ; 使用 WM_CREATE 中定义的红色画刷
    ; P1 生命
    mov edi, 0
    .while edi < Life1
        mov eax, edi
        imul eax, LifeSpace
        add eax, Life1X
        mov ebx, LifeY
        mov ecx, eax
        add ecx, LifeSize
        mov edx, ebx
        add edx, LifeSize
        push edi
        invoke Ellipse, memDC, eax, ebx, ecx, edx
        pop edi
        inc edi
    .endw
    ; P2 生命
    mov edi, 0
    .while edi < Life2
        mov eax, Life2X
        mov ebx, edi
        imul ebx, LifeSpace
        sub eax, ebx
        mov ebx, LifeY
        mov ecx, eax
        add ecx, LifeSize
        mov edx, ebx
        add edx, LifeSize
        push edi
        invoke Ellipse, memDC, eax, ebx, ecx, edx
        pop edi
        inc edi
    .endw

    ; --- 绘制 P1 挡板 (动态颜色) ---
    mov eax, Pad1Color
    mov ecx, hColorBrushes[eax*4] ; 取数组中的画刷
    invoke SelectObject, memDC, ecx
    mov eax, Paddle1X
    add eax, PaddleW
    mov ecx, Paddle1Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle1X, Paddle1Y, eax, ecx

    ; --- 绘制 P2 挡板 (动态颜色) ---
    mov eax, Pad2Color
    mov ecx, hColorBrushes[eax*4]
    invoke SelectObject, memDC, ecx
    mov eax, Paddle2X
    add eax, PaddleW
    mov ecx, Paddle2Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle2X, Paddle2Y, eax, ecx

    ; --- 绘制球 ---
    mov eax, Ball1Color
    invoke SelectObject, memDC, hColorBrushes[eax*4]
    mov eax, Ball1X
    add eax, BallSize
    mov ecx, Ball1Y
    add ecx, BallSize
    invoke Ellipse, memDC, Ball1X, Ball1Y, eax, ecx
    
    mov eax, Ball2Color
    invoke SelectObject, memDC, hColorBrushes[eax*4]
    mov eax, Ball2X
    add eax, BallSize
    mov ecx, Ball2Y
    add ecx, BallSize
    invoke Ellipse, memDC, Ball2X, Ball2Y, eax, ecx

    ; --- 绘制砖块 ---
    invoke SetTextColor, memDC, 00FFFFFFh 
    invoke SetBkMode, memDC, TRANSPARENT
    mov esi, offset Bricks
    mov eax, offset BrickColors
    mov pColorArr, eax
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
    jge PaintNextRow
    cmp byte ptr [esi], 0
    je SkipDraw
    push ecx
    push edi
    push esi
    mov esi, pColorArr
    xor eax, eax
    mov al, byte ptr [esi]
    invoke SelectObject, memDC, hColorBrushes[eax*4]
    pop esi
    pop edi
    pop ecx
    mov eax, currentX
    add eax, BrickW
    mov ebx, currentY
    add ebx, BrickH
    push ecx
    invoke Rectangle, memDC, currentX, currentY, eax, ebx
    mov eax, currentX
    mov rectBrick.left, eax

    mov eax, currentX
    add eax, BrickW
    mov rectBrick.right, eax

    mov eax, currentY
    mov rectBrick.top, eax

    mov eax, currentY
    add eax, BrickH
    mov rectBrick.bottom, eax
    xor eax, eax
    mov al, byte ptr [esi]
    add al, '0'
    mov szNumBuffer[0], al
    mov szNumBuffer[1], 0
    invoke DrawText, memDC, addr szNumBuffer, -1, addr rectBrick, DT_CENTER or DT_VCENTER or DT_SINGLELINE
    pop ecx
SkipDraw:
    inc esi
    inc pColorArr
    mov eax, currentX
    add eax, BrickW
    add eax, BrickGap
    mov currentX, eax
    inc ecx
    jmp PaintCol
PaintNextRow:
    inc edi
    mov eax, currentY
    add eax, BrickH
    add eax, BrickGap
    mov currentY, eax
    jmp PaintRow

PaintEnd:

    ; --- 绘制飘字特效 ---
    invoke SetBkMode, memDC, TRANSPARENT ; 确保文字背景不会遮挡砖块
    invoke SetTextColor, memDC, 0000FFFFh ; 黄色文字，醒目一点
    mov edi, 0
DrawEffLoop:
    .if EffectActive[edi] != 0
        mov eax, EffectX[edi*4]
        mov rectEff.left, eax
        add eax, 40
        mov rectEff.right, eax
        mov eax, EffectY[edi*4]
        mov rectEff.top, eax
        add eax, 20
        mov rectEff.bottom, eax
        
        invoke DrawText, memDC, addr TxtMinusOne, -1, addr rectEff, DT_CENTER
    .endif
    inc edi
    cmp edi, MAX_EFFECTS
    jl DrawEffLoop

    invoke BitBlt, hdc, 0, 0, 710, 640, memDC, 0, 0, SRCCOPY
    invoke SelectObject, memDC, hOld
    invoke DeleteObject, hBitmap
    invoke DeleteDC, memDC
    ret
PaintGame endp

WndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    local ps:PAINTSTRUCT
    local hdc:HDC
    .if uMsg == WM_CREATE
        mov ecx, 0
    CreateBrushLoop:
        cmp ecx, 5
        jge CreateBrushDone
        push ecx
        invoke CreateSolidBrush, ColorValues[ecx*4]
        pop ecx
        mov hColorBrushes[ecx*4], eax
        inc ecx
        jmp CreateBrushLoop
    CreateBrushDone:

        ; --- 修正：为生命值创建固定的红色画刷 ---
        invoke CreateSolidBrush, 000000FFh ; 纯红色 (RGB: 255, 0, 0)
        mov hBrushLife, eax
        
        invoke GetTickCount
        mov RandSeed, eax
        invoke InitGameData
        invoke SetTimer, hwnd, TimerID, TimerDelay, NULL

    .elseif uMsg == WM_TIMER
        invoke UpdateGame, hwnd
        invoke InvalidateRect, hwnd, NULL, FALSE
    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hwnd, addr ps
        mov hdc, eax
        invoke PaintGame, hdc, addr ps.rcPaint
        invoke EndPaint, hwnd, addr ps
    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_ESCAPE
            invoke KillTimer, hwnd, TimerID
            invoke MessageBox, hwnd, addr PauseMsg, addr PauseCaption, MB_OK
            invoke SetTimer, hwnd, TimerID, TimerDelay, NULL
        .endif
    .elseif uMsg == WM_DESTROY
        mov ecx, 0
    CleanupLoop:
        cmp ecx, 5
        jge CleanupDone
        invoke DeleteObject, hColorBrushes[ecx*4]
        inc ecx
        jmp CleanupLoop
    CleanupDone:
        invoke DeleteObject, hBrushLife ; 清理生命值红色画刷
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
    mov wc.lpszClassName, offset ClassName
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    invoke RegisterClassEx, addr wc
    invoke CreateWindowEx, NULL, addr ClassName, addr AppName,
           WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,
           CW_USEDEFAULT, CW_USEDEFAULT, 710, 640, NULL, NULL, hInst, NULL
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