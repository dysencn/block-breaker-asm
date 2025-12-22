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
    AppName     db "Breakout",0
    ClassName   db "BreakoutClass",0
    
    WindowW     dd 710
    WindowH     dd 640
    TimerID     dd 1
    TimerDelay  dd 16

    Life1       dd 3
    Life2       dd 3
    LifeSize    dd 15
    
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
    BallHalfSize  dd 12
    
    Paddle1X    dd 15
    Paddle1Y    dd 270
    Paddle2X    dd 680
    Paddle2Y    dd 270
    PaddleW     dd 15
    PaddleH     dd 100
    PaddleSpeed dd 20
    Pad1Color   dd 0 
    Pad2Color   dd 0 
    
    Bricks      db 15 dup(1) 
    BrickColors db 15 dup(0) 
    
    BrickRows   dd 5
    BrickCols   dd 3
    BrickW      dd 30
    BrickH      dd 100
    BrickGap    dd 10
    BrickOffX   dd 300
    BrickOffY   dd 30

    CurrentBrickRow dd 0
    CurrentBrickCol dd 0

    CalcBrickX  dd 0
    CalcBrickY  dd 0

    Life1X      dd 40
    LifeY       dd 10
    Life2X      dd 660
    LifeSpace   dd 25

    Ball1InitX  dd 80
    Ball1InitY  dd 320
    Ball2InitX  dd 600
    Ball2InitY  dd 320

    FreezeTimer1 dd 0 
    FreezeTimer2 dd 0 

    ColorValues dd 000000FFh
                dd 00C00000h
                dd 00999900h
                dd 00800080h
                dd 00E6D8ADh
    

    StartCaption db "Game Ready", 0
    StartMsg     db "Press OK to Start", 0
    PauseCaption db "Game Paused", 0
    PauseMsg     db "Game is paused. Click OK to continue.", 0
    MsgP1Win     db "Player 2 Out of Lives! Player 1 Wins!", 0
    MsgP2Win     db "Player 1 Out of Lives! Player 2 Wins!", 0
    GameOverCap  db "Game Over", 0
    RandSeed     dd 0

    MAX_EFFECTS    equ 20
    EffectActive   db MAX_EFFECTS dup(0)
    EffectX        dd MAX_EFFECTS dup(0)
    EffectY        dd MAX_EFFECTS dup(0)
    EffectLife     dd MAX_EFFECTS dup(0)

    EffectStrings  dd MAX_EFFECTS dup(0)
    EffectColors   dd MAX_EFFECTS dup(0)

    ColorYellow    dd 0000FFFFh
    ColorRed       dd 000000FFh

    P1_EffectX     dd 40 
    P1_EffectY     dd 50     
    
    P2_EffectX     dd 640 
    P2_EffectY     dd 50

    TxtMinusOne    db "-1", 0
    TxtSwirl           db "扩散", 0
    TxtEvaporate       db "蒸发", 0
    TxtFreeze          db "冻结", 0
    TxtElectroCharged  db "感电", 0
    TxtMelt            db "融化", 0
    TxtOverloaded      db "超载", 0
    TxtSuperConduct    db "超导", 0

    msgBuf db 64 dup(0)

.data?
    hInstance     HINSTANCE ?
    hColorBrushes dd 5 dup(?) 
    hBrushLife    HBRUSH ?
    szNumBuffer   db 4 dup(?)

    hFontEffect    dd ?

.code

WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD

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

SpawnEffect proc x:DWORD, y:DWORD, lpString:DWORD, textColor:DWORD
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
        mov EffectLife[ecx*4], 40

        mov eax, lpString
        mov EffectStrings[ecx*4], eax
        mov eax, textColor
        mov EffectColors[ecx*4], eax

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

DamageAndEffect proc row:DWORD, col:DWORD
    local brickIdx:DWORD

    mov eax, row
    imul eax, BrickCols
    add eax, col
    mov brickIdx, eax

    mov esi, offset Bricks
    add esi, brickIdx
    cmp byte ptr [esi], 0
    je @f

    dec byte ptr [esi]

    ; X = BrickOffX + col * (BrickW + BrickGap)
    mov eax, col
    mov ecx, BrickW
    add ecx, BrickGap
    imul eax, ecx
    add eax, BrickOffX
    mov CalcBrickX, eax

    ; Y = BrickOffY + row * (BrickH + BrickGap)
    mov eax, row
    mov ecx, BrickH
    add ecx, BrickGap
    imul eax, ecx
    add eax, BrickOffY
    mov CalcBrickY, eax

    mov eax, CalcBrickY
    sub eax, 10
    invoke SpawnEffect, CalcBrickX, eax, addr TxtMinusOne, ColorYellow

@@:
    ret
DamageAndEffect endp

ResetBallPos proc bIdx:DWORD
    .if bIdx == 1
        mov eax, Ball1InitX
        mov Ball1X, eax
        mov eax, Ball1InitY
        mov Ball1Y, eax
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

HandleSwirl proc cRow:DWORD, cCol:DWORD, newColor:DWORD
    
    mov eax, newColor
    mov cl, al

    mov eax, cRow
    .if eax > 0
        dec eax
        imul eax, BrickCols
        add eax, cCol
        mov byte ptr BrickColors[eax], cl
    .endif

    mov eax, cRow
    .if eax < 4
        inc eax             ; row + 1
        imul eax, BrickCols
        add eax, cCol
        mov byte ptr BrickColors[eax], cl
    .endif

    mov eax, cCol
    .if eax > 0 
        dec eax
        push eax          
        mov eax, cRow
        imul eax, BrickCols
        pop edx     
        add eax, edx
        mov byte ptr BrickColors[eax], cl
    .endif

    mov eax, cCol
    .if eax < 2 
        inc eax     
        push eax            
        mov eax, cRow
        imul eax, BrickCols
        pop edx             
        add eax, edx
        mov byte ptr BrickColors[eax], cl
    .endif

    ret
HandleSwirl endp

FreezeBall proc bIdx:DWORD
    .if bIdx == 1
        mov FreezeTimer1, 120 ; 约2秒 (60fps * 2)
    .else
        mov FreezeTimer2, 120
    .endif
    ret
FreezeBall endp

MeltReaction proc
    mov ecx, 0
    @@:
    .if BrickColors[ecx] == 4
        mov BrickColors[ecx], 1
    .endif
    inc ecx
    cmp ecx, 15
    jl @b
    ret
MeltReaction endp

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

Overloaded proc cRow:DWORD, cCol:DWORD

    mov eax, cRow
    .if eax > 0
        dec eax
        invoke DamageAndEffect, eax, cCol
    .endif

    mov eax, cRow
    .if eax < 4
        inc eax
        invoke DamageAndEffect, eax, cCol
    .endif

    mov eax, cCol
    .if eax > 0
        dec eax
        invoke DamageAndEffect, cRow, eax
    .endif

    mov eax, cCol
    .if eax < 2
        inc eax
        invoke DamageAndEffect, cRow, eax
    .endif
    ret
Overloaded endp

ElectroCharged proc
    local row:DWORD
    local col:DWORD
    local idx:DWORD

    mov idx, 0
    .while idx < 15
        mov esi, offset BrickColors
        add esi, idx
        movzx eax, byte ptr [esi]
        
        .if eax == 1
            ; Row = idx / 3, Col = idx % 3
            mov eax, idx
            xor edx, edx
            mov ecx, 3
            div ecx
            
            mov row, eax
            mov col, edx
            
            invoke DamageAndEffect, row, col
        .endif
        
        inc idx
    .endw
    ret
ElectroCharged endp


TriggerReaction proc ballIdx:DWORD
    local brickIdx:DWORD
    local bColor:DWORD
    local tColor:DWORD
    local row:DWORD
    local col:DWORD
    local ballX:DWORD
    local ballY:DWORD
    local realBallColor:DWORD

    push ebx
    push esi
    push edi

    mov eax, CurrentBrickRow
    mov row, eax
    mov eax, CurrentBrickCol
    mov col, eax

    mov eax, row
    imul eax, BrickCols
    add eax, col
    mov brickIdx, eax

    mov esi, offset BrickColors
    add esi, brickIdx
    movzx ebx, byte ptr [esi]
    mov tColor, ebx

    .if ballIdx == 1
        mov eax, Ball1Color
        mov bColor, eax
        mov eax, Ball1X
        mov ballX, eax
        mov eax, Ball1Y
        mov ballY, eax
    .else
        mov eax, Ball2Color
        mov bColor, eax
        mov eax, Ball2X
        mov ballX, eax
        mov eax, Ball2Y
        mov ballY, eax
    .endif

    mov eax, bColor
    mov eax, ColorValues[eax*4]
    mov realBallColor, eax

    invoke DamageAndEffect, row, col

    mov eax, bColor
    .if eax == tColor
        jmp DoneReaction
    .endif

    .if bColor == 2 || tColor == 2
        invoke SpawnEffect, ballX, ballY, addr TxtSwirl, realBallColor
        .if bColor == 2
            invoke HandleSwirl, row, col, tColor
        .else
            invoke HandleSwirl, row, col, bColor
        .endif
        jmp DoneReaction
    .endif

    mov eax, bColor
    mov ebx, tColor
    .if eax > ebx
        xchg eax, ebx 
    .endif
    
    .if eax == 0 && ebx == 1
        invoke SpawnEffect, ballX, ballY, addr TxtEvaporate, realBallColor
        mov esi, offset Bricks
        add esi, brickIdx
        mov byte ptr [esi], 0 
        
        invoke ResetBallPos, ballIdx
    
    .elseif eax == 1 && ebx == 4
        invoke SpawnEffect, ballX, ballY, addr TxtFreeze, realBallColor
        invoke FreezeBall, ballIdx

    .elseif eax == 1 && ebx == 3
        invoke SpawnEffect, ballX, ballY, addr TxtElectroCharged, realBallColor
        invoke ElectroCharged

    .elseif eax == 0 && ebx == 4
        invoke SpawnEffect, ballX, ballY, addr TxtMelt, realBallColor
        invoke MeltReaction

    .elseif eax == 0 && ebx == 3
        invoke SpawnEffect, ballX, ballY, addr TxtOverloaded, realBallColor
        invoke Overloaded, row, col

    .elseif eax == 3 && ebx == 4
        invoke SpawnEffect, ballX, ballY, addr TxtSuperConduct, realBallColor
        invoke SuperConduct, ballIdx
    .endif

DoneReaction:
    pop edi
    pop esi
    pop ebx
    ret
TriggerReaction endp


DecreaseLifeWithEffect proc playerNum:DWORD
    .if playerNum == 1
        .if Life1 > 0
            dec Life1
            invoke SpawnEffect, P1_EffectX, P1_EffectY, addr TxtMinusOne, ColorRed
        .endif
        
    .elseif playerNum == 2
        .if Life2 > 0
            dec Life2
            invoke SpawnEffect, P2_EffectX, P2_EffectY, addr TxtMinusOne, ColorRed
        .endif
    .endif
    ret
DecreaseLifeWithEffect endp

InitGameData proc
    mov esi, offset Bricks
    mov edi, offset BrickColors
    mov ecx, 15 
    InitLoop:
        push ecx
        push edi
        push esi
        invoke GetRandomIdx, 5
        inc eax
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
        jmp SkipBall1Pos
    .endif

    mov eax, Ball1X
    add eax, Vel1X
    mov Ball1X, eax
    mov eax, Ball1Y
    add eax, Vel1Y
    mov Ball1Y, eax

    mov eax, WindowH
    sub eax, BallSize
    sub eax, BallSize
    .if sdword ptr Ball1Y < 0 || Ball1Y > eax
        neg Vel1Y
    .endif

    .if Ball1X > 680
        neg Vel1X
    .endif

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
        mov edx, Paddle2Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball1Y >= sdword ptr edx && Ball1Y <= ecx
            invoke DecreaseLifeWithEffect, 2
            neg Vel1X
            mov eax, Paddle2X
            sub eax, BallSize
            mov Ball1X, eax
        .endif
    .endif

    .if sdword ptr Ball1X < 0
        invoke DecreaseLifeWithEffect, 1
        mov Ball1X, 100
        mov Vel1X, 5
    .endif

    mov esi, offset Bricks
    mov edi, 0
    mov ebx, BrickOffY
    B1_Row:
        cmp edi, BrickRows
        jge SkipBall1Pos
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

    mov CurrentBrickRow, edi
    mov CurrentBrickCol, ecx

    mov eax, Ball1X
    add eax, BallHalfSize

    .if eax >= edx
        push eax                
        mov eax, edx
        add eax, BrickW 
        pop ecx 
        
        .if ecx <= eax 
            neg Vel1Y 
            jmp @f
        .endif
    .endif

    neg Vel1X
    @@:

    invoke TriggerReaction, 1

    jmp SkipBall1Pos
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
        jmp SkipBall2Pos
    .endif

    mov eax, Ball2X
    add eax, Vel2X
    mov Ball2X, eax
    mov eax, Ball2Y
    add eax, Vel2Y
    mov Ball2Y, eax


    mov eax, WindowH
    sub eax, BallSize
    sub eax, BallSize
    .if sdword ptr Ball2Y < 0 || Ball2Y > eax
        neg Vel2Y
    .endif


    .if sdword ptr Ball2X < 0
        neg Vel2X
    .endif

    mov eax, Paddle1X
    add eax, PaddleW
    .if Ball2X < eax
        mov edx, Paddle1Y
        mov ecx, edx
        add ecx, PaddleH
        .if Ball2Y >= edx && Ball2Y <= ecx
            invoke DecreaseLifeWithEffect, 1
            neg Vel2X
            mov eax, Paddle1X
            add eax, PaddleW
            mov Ball2X, eax
        .endif
    .endif

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


    .if sdword ptr Ball2X > 680
        invoke DecreaseLifeWithEffect, 2
        mov Ball2X, 580
        mov Vel2X, -5
    .endif

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
        
        cmp byte ptr [esi], 0
        je B2_Skip

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

    mov CurrentBrickRow, edi 
    mov CurrentBrickCol, ecx 

    mov eax, Ball2X
    add eax, BallHalfSize

    .if eax >= edx
        push eax                
        mov eax, edx
        add eax, BrickW
        pop ecx
        
        .if ecx <= eax
            neg Vel2Y
            jmp @f
        .endif
    .endif


    neg Vel2X
    @@:

    invoke TriggerReaction, 2

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

    mov ecx, 0
UpdateEffLoop:
    .if EffectActive[ecx] != 0
        sub EffectY[ecx*4], 1 
        dec EffectLife[ecx*4] 
        .if EffectLife[ecx*4] == 0
            mov EffectActive[ecx], 0
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
    local hOldFont:HFONT
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

    invoke SelectObject, memDC, hFontEffect
    mov hOldFont, eax

    invoke GetStockObject, BLACK_BRUSH
    mov rectClient.left, 0
    mov rectClient.top, 0
    mov rectClient.right, 710
    mov rectClient.bottom, 640
    invoke FillRect, memDC, addr rectClient, eax

    invoke SelectObject, memDC, hBrushLife
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

    mov eax, Pad1Color
    mov ecx, hColorBrushes[eax*4]
    invoke SelectObject, memDC, ecx
    mov eax, Paddle1X
    add eax, PaddleW
    mov ecx, Paddle1Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle1X, Paddle1Y, eax, ecx

    mov eax, Pad2Color
    mov ecx, hColorBrushes[eax*4]
    invoke SelectObject, memDC, ecx
    mov eax, Paddle2X
    add eax, PaddleW
    mov ecx, Paddle2Y
    add ecx, PaddleH
    invoke Rectangle, memDC, Paddle2X, Paddle2Y, eax, ecx

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

    invoke SetBkMode, memDC, TRANSPARENT

    mov edi, 0
    DrawEffLoop:
        .if EffectActive[edi] != 0

            mov eax, EffectColors[edi*4]
            invoke SetTextColor, memDC, eax
        
            mov eax, EffectX[edi*4]
            mov rectEff.left, eax
            add eax, 50
            mov rectEff.right, eax
            mov eax, EffectY[edi*4]
            mov rectEff.top, eax
            add eax, 30
            mov rectEff.bottom, eax

            mov edx, EffectStrings[edi*4]
            invoke DrawText, memDC, edx, -1, addr rectEff, DT_CENTER or DT_NOCLIP
            
        .endif
        inc edi
        cmp edi, MAX_EFFECTS
    jl DrawEffLoop

    invoke BitBlt, hdc, 0, 0, 710, 640, memDC, 0, 0, SRCCOPY
    invoke SelectObject, memDC, hOldFont
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

        invoke CreateSolidBrush, 000000FFh
        mov hBrushLife, eax
        
        invoke GetTickCount
        mov RandSeed, eax
        invoke InitGameData

        invoke CreateFont, 40, 0, 0, 0, FW_BOLD, \
                           0, 0, 0, DEFAULT_CHARSET, \
                           0, 0, 0, 0, NULL
        mov hFontEffect, eax

        invoke ShowWindow, hwnd, SW_SHOWNORMAL 
        invoke UpdateWindow, hwnd
        invoke MessageBox, hwnd, addr StartMsg, addr StartCaption, MB_OK or MB_ICONINFORMATION
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
        invoke DeleteObject, hBrushLife
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
           CW_USEDEFAULT, CW_USEDEFAULT, WindowW, WindowH, NULL, NULL, hInst, NULL
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