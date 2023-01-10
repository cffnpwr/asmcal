    .text
    .global _start
_start:
    ldr     r0, [sp]        @ r0 = argc
    add     r1, sp, #4      @ r1 = argv
    bl      calendar
    mov     r0, #0
    mov     r7, #1
    svc     #0


    .global calendar
    .type calendar, %function


@ calendarとして表示される文字列を返す
@ calendar(int argc, char *argv[])
@ r0 = argc
@ r1 = argv
calendar:
    push    {r2-r6, lr}
    bl      parseArgs       @ r0 = year, r1 = month, r2 = day, r3 = mondayStartsFlag
    mov     r5, r3          @ r5 = mondayStartsFlag

    push    {r0, r1}
    bl      getDays
    mov     r3, r0          @ r3 = Number of Days in a Month
    pop     {r0, r1}        @ r0 = year, r1 = month

    mov     r6, r2          @ r6 = day
    bl      validateYMD

    push    {r0, r1, r3}
    mov     r2, #1          @ day = 1
    mov     r3, r5          @ r3 = r5 = mondayStartsFlag
    bl      zellar          @ r0 = Day of Week (0: Sun ~ 6: Sat) or (0: Mon ~ 6: Sun)
    mov     r4, r0          @ r4 = Day of Week
    pop     {r0, r1, r3}    @ r0 = y, r1 = m, r3 = Number of Days in a Month

    ldr     r2, =outputBuf
    push    {r2}
    bl      appendMonthWithYear
    mov     r1, r5          @ r1 = mondayStartsFlag
    push    {r5}
    bl      appendDayOfWeekIndex
    push    {r4}
calendarSpacingLoop:
    ldr     r1, =spacing
    cmp     r4, #0
    beq     calendarSpacingLoopEnd
    bl      storeStr
    sub     r4, r4, #1
    b       calendarSpacingLoop
calendarSpacingLoopEnd:
    mov     r1, r3          @ r1 = Number of Days in a Month
    pop     {r3}            @ r3 = Day of Week Offset
    mov     r2, r6          @ r2 = day
    pop     {r4}
    bl      insertCalendarDay
    pop     {r2}
    mov     r0, r2
    bl      printStr
    pop     {r2-r6, lr}
    bx      lr


@ コマンドライン引数を渡すとyear, month, day, mondayStartsFlagを返す
@ params
@   r0 = arg count
@   r1 = arg value array
@ returns
@   r0 = year
@   r1 = month
@   r2 = day
@   r3 = monday starts flag
parseArgs:
    push    {r0, lr}
    cmp     r0, #2          @ if(argc < 2)
    movlt   r3, #1          @   error flag = 1
    blt     errorAndExit    @   jump errorAndExit

    ldr     r0, [r1, #4]    @ r0 = argv[1]
    ldrb    r3, [r0]        @ r3 = argv[1][0]
    cmp     r3, #109        @ if(r3 == 'm')
    mov     r3, #0          @ r3 = 0
    moveq   r3, #1          @   r3 = 1
    addeq   r1 ,r1, #4      @   r1 += 4

    pop     {r0}
    push    {r3}
    sub     r0, r0, r3      @ r0 = mondayStartsFlag ? r0 - 1 : r0

    cmp     r0, #2          @ if(argc < 2)
    movlt   r3, #1          @   error flag = 1
    blt     errorAndExit    @   jump errorAndExit

    cmp     r0, #4          @ if(argc > 4)
    movgt   r3, #2          @   error flag = 2
    bgt     errorAndExit    @   jump errorAndExit

    mov     r2, #0          @ r2 = 0
    mov     r3, r0          @ r3 = r0
parseArgLoop:
    add     r2, r2, #1      @ r2++
    cmp     r3, r2          @ if(r3 > r2)
    mov     r0, #0          @ r0 = 0
    ldrgt   r0, [r1, #4]!   @   r0 = argv[r3]
    blgt    str2int         @   r0 = str2int(argv[r3])
    push    {r0}            @ stack = [day, month, year, mondayStartsFlag]

    cmp     r2, #3          @ if(r2 < 3)
    blt     parseArgLoop    @   jump parseArgLoop

    pop     {r2}            @ r2 = day
    pop     {r1}            @ r1 = month
    pop     {r0}            @ r0 = year
    pop     {r3}            @ r3 = mondayStartsFlag
    pop     {lr}
    bx      lr


@ year month dayが正しい値か検証する
@ params
@   r0 = year
@   r1 = month
@   r2 = day
@   r3 = Number of Days in a Month
@ returns
@   ok => return
@   ng => exit
validateYMD:
    push    {r0-r4, lr}
    mov     r4, #0xbdc1
    movt    r4, #0xfff0     @ r4 = -10000
    cmp     r0, r4          @ if(r0 <= -10000)
    movle   r3, #4          @   exit flag = 4
    ble     errorAndExit
    mov     r4, #12
    cmp     r1, #0
    cmpge   r4, r1          @ if(0 > r1 || r1 > 12)
    movlt   r3, #5          @   exit flag = 5
    blt     errorAndExit
    cmp     r2, #0
    cmpge   r3, r2          @ if(0 > r2 || r2 > NoDiaM)
    movlt   r3, #6          @   exit flag = 6
    blt     errorAndExit
    pop     {r0-r4, lr}
    bx      lr


@ 日付を挿入する
@ params
@   r0 = output buffer address
@   r1 = number of days in a month
@   r2 = day
@   r3 = day offset
@   r4 = monday starts flag
@ returns
@   r0 = address of end of string
insertCalendarDay:
    push    {r5-r7, lr}
    mov     r7, r4          @ r7 = monday starts flag
    mov     r6, r3          @ r6 = day offset (week pos count)
    mov     r5, r2          @ r5 = day
    mov     r4, r1          @ r4 = number of days in a month
    mov     r3, #1          @ r3 = current day = 1
calendarDayLoop:
    push    {r0}
    mov     r0, r3          @ r0 = current day
    bl      int2str         @ r0 = current day string
    mov     r1, r0          @ r1 = current day string
    bl      getStrLen       @ r0 = current day string length
    mov     r2, r0          @ r2 = current day string length
    pop     {r0}

    cmp     r5, r3          @ if(d == current day)
    pusheq  {r1}
    ldreq   r1, =highlightStart
    bleq    storeStr        @   append "\x1b[7m" -> Highlight On
    popeq   {r1}

    push    {r7}
    cmp     r7, #1          @ if(r7 == 1)
    mov     r7, #0          @ r7 = 0
    moveq   r7, #6          @   r7 = 6
    cmp     r6, r7          @ if(r6 == r7) <=> 日曜日
    pusheq  {r1}
    ldreq   r1, =highlightSun
    bleq    storeStr        @   append "\x1b[91m" -> Highlight Red
    popeq   {r1}
    pop     {r7}

    push    {r7}
    cmp     r7, #1          @ if(r7 == 1)
    mov     r7, #6          @ r7 = 6
    moveq   r7, #5          @   r7 = 5
    cmp     r6, r7          @ if(r6 == r7) <=> 土曜日
    pusheq  {r1}
    ldreq   r1, =highlightSat
    bleq    storeStr        @   append "\x1b[96m" -> Highlight Cyan
    popeq   {r1}
    pop     {r7}

    cmp     r2, #1
    moveq   r2, #32
    streqb  r2, [r0], #1    @ 日付が1桁ならスペースを入れる
    bl      storeStr        @ 日付を入れる

    cmp     r5, r3          @ if(d == current day)
    cmpne   r6, #0          @ else if(r6 == 0) <=> 日曜日
    cmpne   r6, #6          @ else if(r6 == 6) <=> 土曜日
    ldreq   r1, =highlightEnd
    bleq    storeStr        @   append "\x1b[0m" -> Highlight Off

    cmp     r6, #6          @ if(r6 == 6) <=> 土曜日
    moveq   r2, #10         @ 土曜日なら改行
    moveq   r6, #0
    movne   r2, #32         @ 土曜日以外全部ならスペース
    addne   r6, r6, #1
    strb    r2, [r0], #1
    cmp     r4, r3          @ if(NoDiM == current day)
    addne   r3, r3, #1
    bne     calendarDayLoop
    mov     r2, #10
    strb    r2, [r0]
    cmpeq   r6, #0
    strneb  r2, [r0, #1]
    pop     {r5-r7, lr}
    bx      lr


@ 1ヶ月が何日まであるかを返す
@ params
@   r0 = year
@   r1 = month
@ returns
@   r0 = Number of Days in a Month
getDays:
    push    {r2, lr}
    and     r2, r1, #1
    cmp     r1, #7
    cmple   r2, #1          @ if(r2 < 8) -> if(r2 == 1)
    cmpgt   r2, #0          @ if(r2 > 7) -> if(r2 == 0)
    mov     r2, #30         @ 31日ではない
    moveq   r2, #31         @ 31日
    cmp     r1, #2
    movne   r0, r2          @ 2月じゃなかったら30 or 31を返す
    bne     getDaysReturn
    bleq    isLeap          @ 2月だったら閏年に応じた日付を返す
getDaysReturn:
    pop     {r2, lr}
    bx      lr

@ 閏年ならば29、そうでなければ28を返す
@ params
@   r0 = year
@ returns
@   r0 = 28 or 29
isLeap:
    push    {r1-r4, lr}
    mov     r2, #0
    mov     r3, #0
    mov     r4, #0
    and     r1, r0, #3      @ yの下位2ビット
    cmp     r1, #0
    moveq   r2, #1          @ f1 = if(mod4(y) == 0)
    and     r1, r1, #15     @ (y / 4)の下位2ビット
    cmp     r1, #0
    moveq   r2, #1          @ f2 = if(mod16(y) == 0)
    bl      divmod5         @ y = 5 * r0 + r1
    cmp     r1, #0
    bleq    divmod5         @ y = 25 * r0 + r1
    cmpeq   r1, #0
    moveq   r4, #1          @ f3 = if(mod25(y) == 0)
    and     r3, r3, r4      @ r3 = if(f2 && f3)
    cmp     r3, #1
    moveq   r0, #29         @ 閏年である
    beq     isLeapReturn
    and     r4, r2, r4      @ r4 = if(f1 && f3)
    cmp     r4, #1
    moveq   r0, #28         @ 閏年でない
    beq     isLeapReturn
    cmp     r2, #1
    moveq   r0, #29         @ 閏年である
    movne   r0, #28         @ 閏年でない
isLeapReturn:
    pop     {r1-r4, lr}
    bx      lr

@ 月と年を末尾に追加
@ params
@   r0 = year
@   r1 = month
@   r2 = output buffer address
@ returns
@   r0 = Address of end of string
appendMonthWithYear:
    push    {r3-r6, lr}
    mov     r4, #10
    mov     r5, #0          @ r5 = B.C. flag = 0
    sub     r1, r1, #1
    ldr     r3, =monthCodeBook
    mul     r1, r4, r1
    add     r1, r3, r1      @ r1 = month string !
    cmp     r0, #0          @ if(y <= 0) <=> Before Christ
    movle   r5, #1          @   r5 = B.C. flag = 1
    mvnle   r0, r0          @   r0 ~= r0
    addle   r0, r0, #2      @   r0 += 2
    bl      int2str         @ r0 = year string
    mov     r3, r0          @ r3 = year string !
    bl      getStrLen       @ r0 = year string length
    mov     r4, r0          @ r4 = year string length
    mov     r0, r1
    bl      getStrLen       @ r0 = month string length
    add     r4, r4, r0      @ r4 = year strlen + month strlen
    add     r4, r4, #1      @ r4 = year strlen + month strlen + 1
    cmp     r5, #0          @ if(r5 != 0) <=> Before Christ
    addne   r4, r4, #4      @   r4 = year strlen + month strlen + 5
    mov     r6, #20
    sub     r4, r6, r4      @ r4 = 20 - year strlen + month strlen + 1
    asr     r4, r4, #1      @ r4 = [月と年の表示のオフセット] !
    mov     r0, r2          @ r0 = output buffer address
offsetLoop:
    mov     r6, #32
    cmp     r4, #0
    strneb  r6, [r0], #1
    sub     r4, r4, #1
    bne     offsetLoop
    bl      storeStr
    strb    r6, [r0], #1
    cmp     r5, #0          @ if(r5 != 0) <=> Before Christ
    ldrne   r1, =BCStr
    blne    storeStr        @   append "B.C."
    mov     r1, r3
    bl      storeStr
    mov     r6, #10
    strb    r6, [r0], #1
    pop     {r3-r6, lr}
    bx      lr


@ 曜日のインデックスを挿入
@ params
@   r0 = output buffer address
@   r1 = mondayStartsFlag
@ returns
@   r0 = Address of end of string
appendDayOfWeekIndex:
    push    {r2, lr}
    mov     r2, r1                  @ r2 = mondayStartsFlag
    ldr     r1, =DayOfWeekIndex     @ r1 = DayOfWeekIndexMon
    cmp     r2, #1                  @ if(r2 == 1)
    ldreq   r1, =DayOfWeekIndexMon  @   r1 = DayOfWeekIndexMon
    bl      storeStr
    pop     {r2, lr}
    bx      lr


monthCodeBook:
    .asciz  "January\0--February\0-March\0----April\0----May\0------June\0-----July\0-----August\0---September\0October\0--November\0-December"
DayOfWeekIndex:
    .asciz  "\x1b[91mSu\x1b[0m Mo Tu We Th Fr \x1b[96mSa\x1b[0m\n"
DayOfWeekIndexMon:
    .asciz  "Mo Tu We Th Fr \x1b[96mSa\x1b[0m \x1b[91mSu\x1b[0m\n"
spacing:
    .asciz  "   "
BCStr:
    .asciz  "B.C."
highlightStart:
    .asciz  "\x1b[7m"
highlightEnd:
    .asciz  "\x1b[0m"
highlightSun:
    .asciz  "\x1b[91m"
highlightSat:
    .asciz  "\x1b[96m"

    .data
outputBuf:
    .space  320
