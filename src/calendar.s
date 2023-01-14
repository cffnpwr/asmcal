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
    push    {r0-r6, lr}

    @ ユーザの入力値を取得・検証
    bl      parseArgs       @ r0 = year, r1 = month, r2 = day, r3 = mondayStartsFlag

    @ その月が何日まであるか計算
    push    {r0, r3}
    bl      getDays
    mov     r4, r0          @ r4 = Number of Days in a Month
    pop     {r0}
    mov     r3, r4
    bl      validateYMD
    pop     {r3}            @ r0 = year, r1 = month, r2 = day, r3 = mondayStartsFlag, r4 = Number of Days in a Month

    mov     r5, r2          @ r5 = r2 = day
    @ ツェラーの公式でその月の初日の曜日を計算
    push    {r0}
    mov     r2, #1          @ day = 1
    bl      zellar          @ r0 = Day of Week (0: Sun ~ 6: Sat) or (0: Mon ~ 6: Sun)
    mov     r2, r0          @ r2 = Day of Week
    pop     {r0}            @ r0 = year, r1 = month, r2 = Start Day of Week, r3 = mondayStartsFlag, r4 = Number of Days in a Month, r5 = day


    @ 祝日のリストをセットする
    bl      setHoliday

    @ カレンダーの上2行を出力
    mov     r6, r2
    ldr     r2, =outputBuf
    push    {r2}            @ stack = [outputBuffer]
    bl      appendMonthWithYear
    mov     r1, r3          @ r1 = mondayStartsFlag
    push    {r1}            @ stack = [mondayStartsFlag, outputBuffer]
    bl      appendDayOfWeekIndex
    push    {r6}            @ stack = [startDayOfWeek, mondayStartsFlag, outputBuffer]

    @ カレンダーの日付のスタート位置をずらす
calendarSpacingLoop:
    ldr     r1, =spacing
    cmp     r6, #0
    beq     calendarSpacingLoopEnd
    bl      storeStr
    sub     r6, r6, #1
    b       calendarSpacingLoop
calendarSpacingLoopEnd:

    mov     r1, r4          @ r1 = Number of Days in a Month
    pop     {r3}            @ r3 = Day of Week Offset   # stack = [mondayStartsFlag, outputBuffer]
    mov     r2, r5          @ r2 = day
    pop     {r4}            @ r4 = mondayStartFlag      # stack = [outputBuffer]
    bl      insertCalendarDay
    pop     {r0}            @ r0 = outputBuffer
    bl      printStr
    pop     {r0-r6, lr}
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

    mov     r4, #0xd8f1
    movt    r4, #0xffff     @ r4 = -9999
    cmp     r0, r4
    movge   r4, #9999
    cmpge   r4, r0          @ if(-9999 > r1 || r1 > 9999)
    movlt   r3, #4          @   exit flag = 4
    blt     errorAndExit

    mov     r4, #12
    cmp     r1, #1
    cmpge   r4, r1          @ if(0 > r1 || r1 > 12)
    movlt   r3, #5          @   exit flag = 5
    blt     errorAndExit

    cmp     r2, #0
    cmpge   r3, r2          @ if(0 > r2 || r2 < NoDiaM)
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
    push    {r1-r5, lr}
    mov     r5, r1          @ r5 = number of days in a month
    mov     r1, #1          @ r1 = current day = 1
calendarDayLoop:
    bl      highlightDay

    push    {r2}
    cmp     r3, #6          @ if(r6 == 6) <=> 土曜日
    moveq   r2, #10         @ 土曜日なら改行
    moveq   r3, #0
    movne   r2, #32         @ 土曜日以外全部ならスペース
    addne   r3, r3, #1
    strb    r2, [r0], #1
    pop     {r2}
    cmp     r1, r5          @ if(NoDiM == current day)
    addne   r1, r1, #1
    bne     calendarDayLoop

    mov     r2, #10
    strb    r2, [r0], #1
    strb    r2, [r0]
    cmpeq   r6, #0
    strneb  r2, [r0, #1]
    pop     {r1-r5, lr}
    bx      lr


@ 日付にハイライトをつける
@ params
@   r0 = output buffer
@   r1 = current day
@   r2 = day
@   r3 = day offset (week pos count)
@   r4 = starts monday flag
highlightDay:
    push    {r1-r6, lr}

    push    {r0}
    mov     r0, r1
    bl      int2str         @ r0 = current day string
    mov     r5, r0          @ r5 = current day string
    bl      getStrLen       @ r0 = current day string length
    mov     r6, r0          @ r6 = current day string length
    pop     {r0}

    cmp     r1, r2          @ if(d == current day)
    mov     r2, #0          @ r2 = 0 <=> highlight off
    pusheq  {r1}
    moveq   r2, #1          @   r2 = 1 <=> highlight off
    ldreq   r1, =highlightStart
    bleq    storeStr        @   append "\x1b[7m" -> Highlight On
    popeq   {r1}

    push    {r4}
    cmp     r4, #1          @ if(r4 == 1)
    mov     r4, #6          @ r4 = 6
    moveq   r4, #5          @   r4 = 5
    cmp     r3, r4          @ if(r3 == r4) <=> 土曜日
    pusheq  {r1}
    moveq   r2, #1          @   r2 = 1 <=> highlight on
    ldreq   r1, =highlightSat
    bleq    storeStr        @   append "\x1b[96m" -> Highlight Cyan
    popeq   {r1}
    pop     {r4}

    push    {r4-r6}
    cmp     r4, #1          @ if(r4 == 1)
    mov     r4, #0          @ r7 = 0
    moveq   r4, #6          @   r7 = 6
    cmp     r3, r4          @ if(r3 == r4) <=> 日曜日
    beq     holidayHighlight

    ldrne   r5, =holidays
holidaysLoop:
    ldrneb  r6, [r5], #1    @ foreach holiday
    cmpne   r6, #0          @ if(holiday == null)
    beq     holidaysLoopEnd
    cmpne   r1, r6          @ if(r1 == r6) <=> current day == holiday
    bne     holidaysLoop

holidayHighlight:
    pusheq  {r1}
    moveq   r2, #1          @   r2 = 1 <=> highlight on
    ldreq   r1, =highlightSun
    bleq    storeStr        @   append "\x1b[91m" -> Highlight Red
    popeq   {r1}
holidaysLoopEnd:
    pop     {r4-r6}

    cmp     r6, #1
    moveq   r6, #32
    streqb  r6, [r0], #1    @ 日付が1桁ならスペースを入れる
    push    {r1}
    mov     r1, r5
    bl      storeStr        @ 日付を入れる
    pop     {r1}

    cmp     r2, #1          @ if(holiday flag)
    ldreq   r1, =highlightEnd
    bleq    storeStr        @   append "\x1b[0m" -> Highlight Off

    pop     {r1-r6, lr}
    bx      lr


@ 1ヶ月が何日まであるかを返す
@ params
@   r0 = year
@   r1 = month
@ returns
@   r0 = Number of Days in a Month
getDays:
    push    {r1, r2, lr}
    and     r2, r1, #1
    cmp     r1, #7
    cmple   r2, #1          @ if(r2 < 8) -> if(r2 == 1)
    cmpgt   r2, #0          @ if(r2 > 7) -> if(r2 == 0)
    mov     r2, #30         @ 31日ではない
    moveq   r2, #31         @ 31日
    cmp     r1, #2          @ if(r0 != 2) <=> 2月かどうか
    movne   r0, r2          @   2月じゃなかったら30 or 31を返す
    bleq    isLeap          @ 2月だったら閏年に応じた日付を返す
    pop     {r1, r2, lr}
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


@ 年月に応じた祝日のリストをバッファに格納する
@ params
@   r0 = year
@   r1 = month
@   r2 = Start Day of Week
@ returns
@   null
setHoliday:
    push    {r0-r3, lr}
    ldr     r3, =holidays   @ 祝日バッファ


    @ 月ごとに分岐
    @ 正直、cmpを10個並べるのは気持ち悪いのでなんとかしたい
    cmp     r1, #1
    beq     jan
    cmp     r1, #2
    beq     feb
    cmp     r1, #3
    beq     mar
    cmp     r1, #4
    beq     apr
    cmp     r1, #5
    beq     may
    cmp     r1, #7
    beq     jul
    cmp     r1, #8
    beq     aug
    cmp     r1, #9
    beq     sep
    cmp     r1, #10
    beq     oct
    cmp     r1, #11
    beq     nov

    b       setHolidayEnd

jan:
    @ お正月 1日
    mov     r1, #1
    strb    r1, [r3], #1
    cmp     r2, #0          @ if(日曜日)
    moveq   r1, #2          @   次の日
    streqb  r1, [r3], #1

    @ 成人の日 第二月曜日
    cmp     r2, #2          @ if(r2 >= 2)
    rsbge   r1, r2, #16     @   r1 = 16 - r2
    rsblt   r1, r2, #9      @ else r1 = 9 - r2
    strb    r1, [r3], #1

    b       setHolidayEnd
    
feb:
    @ 建国記念の日 11日
    mov     r1, #11
    strb    r1, [r3], #1
    cmp     r2, #4          @ if(日曜日) <=> 1日目が木曜
    moveq   r1, #12         @   次の日
    streqb  r1, [r3], #1

    @ 天皇誕生日 23日
    mov     r1, #23
    strb    r1, [r3], #1
    cmp     r2, #6          @ if(日曜日) <=> 1日目が土曜
    moveq   r1, #24         @   次の日
    streqb  r1, [r3], #1

    b       setHolidayEnd

mar:
    @ 春分の日 天文学的計算をする
    push    {r2}
    sub     r0, r0, #2000   @ r0 = year - 2000
    mov     r2, #45586      @ r2 = 45586
    movt    r2, #3          @ r2 = (3 << 16) + 45586 = 242194
    mul     r2, r0, r2      @ r2 *= r0 = (year - 2000) * 242194

    bl      div4            @ r0 /= 4 = (year - 2000) / 4
    mov     r1, r0          @ r1 = (year - 2000) / 4
    push    {r1}
    bl      divmod5
    bl      divmod5
    pop     {r1}
    sub     r1, r1, r0      @ r1 = (year - 2000) / 4 - (year - 2000) / 100
    bl      div4            @ r0 /= 4 = (year - 2000) / 400
    add     r1, r1, r0      @ r1 = (year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400
    mov     r0, #16960      @ r0 = 16960
    movt    r0, #15         @ r0 = (15 << 16) + 16960 = 1000000
    mul     r1, r0, r1      @ r1 *= 1000000
    sub     r1, r2, r1      @ r1 = r2 - r1 = (year - 2000) * 242194 - ((year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400) * 1000000
    mov     r2, #35790      @ r2 = 35790
    movt    r2, #10         @ r2 = (10 << 16) + 35790 = 691150
    add     r0, r2, r1      @ r0 = 691150 + (year - 2000) * 242194 - ((year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400) * 1000000
    bl      divmod1000000
    add     r1, r0, #20
    strb    r1, [r3], #1
    pop     {r2}

    add     r2, r2, r1      @ r2 = [春分の日] - [月の開始日の曜日]
    sub     r2, r2, #1      @ r2 = [春分の日] - [月の開始日の曜日] - 1
    mov     r0, r2
    push    {r1}
    bl      divmod7
    cmp     r1, #0          @ if(日曜日)
    pop     {r1}
    addeq   r1, r1, #1      @   次の日
    streqb  r1, [r3], #1

    b       setHolidayEnd

apr:
    @ 昭和の日 29日
    mov     r1, #29
    strb    r1, [r3], #1
    cmp     r2, #0          @ if(日曜日) <=> 1日目が日曜
    moveq   r1, #30         @   次の日
    streqb  r1, [r3], #1

    b       setHolidayEnd

may:
    @ 憲法記念日 3日
    mov     r1, #3
    strb    r1, [r3], #1

    @ みどりの日 4日
    mov     r1, #4
    strb    r1, [r3], #1

    @ こどもの日 5日
    mov     r1, #5
    strb    r1, [r3], #1

    mov     r1, #5
    cmp     r2, #3          @ if(日曜日) <=> 1日目が水曜〜金曜 <=> if(r2 >= 3 && r2 <= 5)
    cmpge   r1, r2
    movge   r1, #6          @   6日
    strgeb  r1, [r3], #1

    b       setHolidayEnd

jul:
    @ 海の日 第三月曜日
    cmp     r2, #2          @ if(r2 >= 2)
    rsbge   r1, r2, #23     @   r1 = 23 - r2
    rsblt   r1, r2, #16     @ else r1 = 16 - r2
    strb    r1, [r3], #1

    b       setHolidayEnd

aug:
    @ 山の日 11日
    mov     r1, #11
    strb    r1, [r3], #1
    cmp     r2, #4          @ if(日曜日) <=> 1日目が木曜
    moveq   r1, #12         @   次の日
    streqb  r1, [r3], #1

    b       setHolidayEnd

sep:
    @ 敬老の日 第三月曜日
    cmp     r2, #2          @ if(r2 >= 2)
    rsbge   r1, r2, #23     @   r1 = 23 - r2
    rsblt   r1, r2, #16     @ else r1 = 16 - r2
    strb    r1, [r3], #1

    @ 秋分の日 天文学的計算をする
    push    {r2}
    sub     r0, r0, #2000   @ r0 = year - 2000
    mov     r2, #45586      @ r2 = 45586
    movt    r2, #3          @ r2 = (3 << 16) + 45586 = 242194
    mul     r2, r0, r2      @ r2 *= r0 = (year - 2000) * 242194

    bl      div4            @ r0 /= 4 = (year - 2000) / 4
    mov     r1, r0          @ r1 = (year - 2000) / 4
    push    {r1}
    bl      divmod5
    bl      divmod5
    pop     {r1}
    sub     r1, r1, r0      @ r1 = (year - 2000) / 4 - (year - 2000) / 100
    bl      div4            @ r0 /= 4 = (year - 2000) / 400
    add     r1, r1, r0      @ r1 = (year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400
    mov     r0, #16960      @ r0 = 16960
    movt    r0, #15         @ r0 = (15 << 16) + 16960 = 1000000
    mul     r1, r0, r1      @ r1 *= 1000000
    sub     r1, r2, r1      @ r1 = r2 - r1 = (year - 2000) * 242194 - ((year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400) * 1000000
    mov     r2, #37064      @ r2 = 37064
    movt    r2, #1          @ r2 = (1 << 16) + 35790 = 102600
    add     r0, r2, r1      @ r0 = 102600 + (year - 2000) * 242194 - ((year - 2000) / 4 - (year - 2000) / 100 + (year - 2000) / 400) * 1000000
    bl      divmod1000000
    add     r1, r0, #23
    strb    r1, [r3], #1
    pop     {r2}

    add     r2, r2, r1      @ r2 = [春分の日] - [月の開始日の曜日]
    sub     r2, r2, #1      @ r2 = [春分の日] - [月の開始日の曜日] - 1
    mov     r0, r2
    push    {r1}
    bl      divmod7
    cmp     r1, #0          @ if(日曜日)
    pop     {r1}
    addeq   r1, r1, #1      @   次の日
    streqb  r1, [r3], #1


    b       setHolidayEnd

oct:
    @ スポーツの日 第二月曜日
    cmp     r2, #2          @ if(r2 >= 2)
    rsbge   r1, r2, #16     @   r1 = 16 - r2
    rsblt   r1, r2, #9      @ else r1 = 9 - r2
    strb    r1, [r3], #1

    b       setHolidayEnd

nov:
    @ 文化の日 3日
    mov     r1, #3
    strb    r1, [r3], #1
    cmp     r2, #6          @ if(日曜日) <=> 1日目が金曜
    moveq   r1, #4         @   次の日
    streqb  r1, [r3], #1

    @ 勤労感謝の日 23日
    mov     r1, #23
    strb    r1, [r3], #1
    cmp     r2, #6          @ if(日曜日) <=> 1日目が土曜
    moveq   r1, #24         @   次の日
    streqb  r1, [r3], #1

    b       setHolidayEnd

setHolidayEnd:
    mov     r1, #0
    strb    r1, [r3]

    pop     {r0-r3, lr}
    bx      lr


@ 月と年を末尾に追加
@ params
@   r0 = year
@   r1 = month
@   r2 = output buffer address
@ returns
@   r0 = Address of end of string
appendMonthWithYear:
    push    {r1-r6, lr}
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
    pop     {r1-r6, lr}
    bx      lr


@ 曜日のインデックスを挿入
@ params
@   r0 = output buffer address
@   r1 = mondayStartsFlag
@ returns
@   r0 = Address of end of string
appendDayOfWeekIndex:
    push    {r1, r2, lr}
    mov     r2, r1                  @ r2 = mondayStartsFlag
    ldr     r1, =DayOfWeekIndex     @ r1 = DayOfWeekIndexMon
    cmp     r2, #1                  @ if(r2 == 1)
    ldreq   r1, =DayOfWeekIndexMon  @   r1 = DayOfWeekIndexMon
    bl      storeStr
    pop     {r1, r2, lr}
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
holidays:
    .space  5
