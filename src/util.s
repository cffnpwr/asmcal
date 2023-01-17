@   いろいろやるための関数たち
    .text
    .global isInt
    .type isInt, %function

@   引数で与えられた文字列が整数か判断する
@   int isInt(char* str)
@ params
@   r0 = string address
@ returns
@   r0 = boolean <=> 1 or 0
isInt:
    push    {r1, lr}
isIntLoop:
    ldrb    r1, [r0], #1
    cmp     r1, #0      @ if (*str == '\0')
    beq     isIntTrue
    cmp     r1, #45     @ if (*str == '-')
    ldreqb  r1, [r0], #1
    cmp     r1, #48     @ if (*str < '0')
    blt     isIntFalse
    cmp     r1, #57     @ if (*str > '9')
    bgt     isIntFalse
    b       isIntLoop
isIntFalse:
    mov     r0, #0
    b       isIntReturn
isIntTrue:
    mov     r0, #1
isIntReturn:
    pop     {r1, lr}
    bx      lr


    .global str2int
    .type str2int, %function

@   引数で与えられた文字列を整数に変換する
@   int str2int(char *str)
@ params
@   r0 = string address
@ returns
@   r0 = integer
str2int:
    push    {r1-r4, lr}
    push    {r0}
    bl      isInt       @ isInt(r0)
    cmp     r0, #0
    moveq   r0, #3      @ exit flag = 3
    beq     errorAndExit@ return 1
    pop     {r0}
    mov     r2, #0      @ is minus flag
    mov     r3, #0      @ return value
    mov     r4, #10
str2intLoop:
    ldrb    r1, [r0], #1
    cmp     r1, #0      @ if (*str == '\0')
    beq     str2intReturn
    cmp     r1, #45     @ if (*str == '-')
    ldreqb  r1, [r0], #1
    moveq   r2, #1
    sub     r1, r1, #48 @ char -> digit
    cmp     r2, #1      @ is minus
    mvneq   r1, r1
    addeq   r1, r1, #1
    mul     r3, r4, r3  @ y_1 = y_0 * 10 + x
    add     r3, r3, r1
    b       str2intLoop
str2intReturn:
    mov     r0, r3
    pop     {r1-r4, lr}
    bx      lr


    .global int2str
    .type int2str, %function

@   引数で与えられた整数を文字列に変換する
@   char *int2str(int num)
@ params
@   r0 = integer
@ returns
@   r0 = string address
int2str:
    push    {r1-r3, lr}
    ldr     r3, =intStr
    push    {r3}
    cmp     r0, #0      @ if (r0 < 0)
    movlt   r2, #45     @ r2 = '-'
    strltb  r2, [r3], #1@ str[0] = '-'
    mvnlt   r0, r0      @ r0 ~= r0
    addlt   r0, r0, #1  @ r0 = ~r0 + 1
int2strLoop:
    bl      divmod10
    push    {r1}
    cmp     r0, #0
    bne     int2strLoop
int2strLoop2:
    pop     {r0}
    cmp     r0, #11
    addlt   r0, r0, #48
    strltb  r0, [r3], #1
    blt     int2strLoop2
    mov     r1, #0
    strb    r1, [r3], #1
    pop     {r1-r3, lr}
    bx      lr


    .global getStrLen
    .type getStrLen, %function

@ 文字列長を取得する
@ int getStrLen(char *str)
@ params
@   r0 = string address
@ returns
@   r0 = string length
getStrLen:
    push    {r1, r2, lr}
    mov     r2, r0
getStrLenLoop:
    ldrb    r1, [r0], #1
    cmp     r1, #0      @ if (*str == '\0')
    bne     getStrLenLoop
    sub     r0, r0, r2  
    sub     r0, r0, #1  @ strLen = r2 - r0 - 1
    pop     {r1, r2, lr}
    bx      lr


    .global storeStr
    .type storeStr, %function

@ r0で与えられたアドレスにr1で与えられたアドレスに格納された文字列を格納する
@ 格納後の先頭アドレスを返す
@ char *storeStr(char *pool, char *str)
@ params
@   r0 = output buffer
@   r1 = string address
@ returns
@   r0 = output buffer
storeStr:
    push    {r1, r2, lr}
storeStrLoop:
    ldrb    r2, [r1], #1
    cmp     r2, #0
    strneb  r2, [r0], #1
    bne     storeStrLoop
    pop     {r1, r2, lr}
    bx      lr


    .global printStr
    .type printStr, %function

@ 文字列出力関数
@ printStr(char *str)
@ params
@   r0 = string address
@ returns
@   null
printStr:
    push    {r0-r2, r7, lr}
    mov     r1, r0
    bl      getStrLen
    mov     r2, r0
    mov     r0, #1
    mov     r7, #4          @ write(1, r1, r2)
    svc     #0
    pop     {r0-r2, r7, lr}
    bx      lr


    .global errorAndExit
    .type errorAndExit, %function

@ エラーを出して終了する
@ params
@   r0 = exit flag
errorAndExit:
    cmp     r0, #1
    ldreq   r0, =noEnoughMsg
    bleq    printStr        @ 引数が足りません
    
    cmp     r0, #2
    ldreq   r0, =tooManyMsg
    bleq    printStr        @ 引数が多すぎ

    cmp     r0, #3
    ldreq   r0, =nonIntMsg
    bleq    printStr        @ 引数が整数じゃない

    cmp     r0, #4
    ldreq   r0, =invalidYearMsg
    bleq    printStr        @ 年が正しくない

    cmp     r0, #5
    ldreq   r0, =invalidMonthMsg
    bleq    printStr        @ 月が正しくない

    cmp     r0, #6
    ldreq   r0, =invalidDayMsg
    bleq    printStr        @ 日が正しくない

    cmp     r0, #7
    ldreq   r0, =unknownOptionMsg
    bleq    printStr        @ 不正なオプション

    bl      calExit         @ return r0


    .global calExit
    .type calExit, %function
calExit:
    mov     r7, #1
    svc     #0              @ return r0


    .global div4
    .type div4, %function

@   r0を4で割る
div4:
    asr     r0, r0, #2
    bx      lr


    .global divmod5
    .type divmod5, %function

@   r0を5で割る
@ r0 = 商
@ r1 = 余り
divmod5:
    push    {r2-r4, lr}
    ldr     r2, div5magic
    smull   r4, r3, r2, r0
    asr     r4, r0, #31
    sub     r2, r3, r4
    mov     r3, #5
    mul     r1, r2, r3
    sub     r1, r0, r1
    cmp     r1, #0
    addlt   r1, r1, #5
    sublt   r0, r2, #1
    movge   r0, r2
    pop     {r2-r4, lr}
    bx      lr


    .global divmod7
    .type divmod7, %function

@   r0を7で割った余り
@ r0 = 商
@ r1 = 余り
divmod7:
    push    {r2, r3, r4, lr}
    ldr     r2, div7magic
    smull   r4, r3, r2, r0
    asr     r4, r0, #31
    sub     r2, r3, r4
    mov     r3, #7
    mul     r1, r2, r3
    sub     r1, r0, r1
    cmp     r1, #0
    addlt   r1, r1, #7
    sublt   r0, r2, #1
    movge   r0, r2
    @ mov     r0, r2
    pop     {r2, r3, r4, lr}
    bx      lr


    .global divmod10
    .type divmod10, %function

@ r0を10で割った余り
@ r0 = 商
@ r1 = 余り
divmod10:
    push    {r2, r3, r4, lr}
    ldr     r2, div10magic
    smull   r4, r3, r2, r0
    asr     r3, r3, #2
    asr     r4, r0, #31
    sub     r2, r3, r4
    mov     r3, #10
    mul     r1, r2, r3
    sub     r1, r0, r1
    cmp     r1, #0
    addlt   r1, r1, #10
    sublt   r0, r2, #1
    movge   r0, r2
    pop     {r2, r3, r4, lr}
    bx      lr

    .global divmod1000000
    .type divmod1000000, %function

@ r0を1000000で割った余り
@ r0 = 商
@ r1 = 余り
divmod1000000:
    push    {r2-r4, lr}
    ldr     r2, div1000000magic
    smull   r4, r3, r2, r0
    asr     r4, r0, #31
    sub     r2, r3, r4
    mov     r3, #16960      @ r3 = 16960
    movt    r3, #15         @ r3 = (15 << 16) + 16960 = 1000000
    mul     r1, r2, r3
    sub     r1, r0, r1
    cmp     r1, #0
    addlt   r1, r1, r3
    sublt   r0, r2, #1
    movge   r0, r2
    pop     {r2-r4, lr}
    bx      lr
    

div5magic:
    .word   0x33333334
div7magic:
    .word   0x24924925
div10magic:
    .word   0x66666667
div1000000magic:
    .word   0x10c7

noEnoughMsg:
    .asciz  "引数が足りません\n"
tooManyMsg:
    .asciz  "引数が多すぎます\n"
nonIntMsg:
    .asciz  "引数が不正です\n"
invalidYearMsg:
    .asciz  "範囲外の年です\n"
invalidMonthMsg:
    .asciz  "存在しない月です\n"
invalidDayMsg:
    .asciz  "存在しない日です\n"
unknownOptionMsg:
    .asciz  "存在しないオプションです\n"

    .comm intStr, 11
