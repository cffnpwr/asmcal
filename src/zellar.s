    .text
    .global zellar
    .type zellar, %function

@ zellarの公式を用いて曜日を計算する
@ params
@   r0 = year
@   r1 = month
@   r2 = day
@   r3 = monday starts flag
@ returns
@   r0 = Day of Week
zellar:
    push    {lr}
    cmp     r1, #3      @ if (y < 3)
    sublt   r0, r0, #1  @   y -= 1
    addlt   r1, r1, #12 @   m += 12
    sub     r2, r2, r3  @ r2 = mondayStartsFlag ? r2 - 1 : r2
    mov     r3, r0      @ r3 = y
    bl      div4        @ r0 = div4(y)
    add     r3, r3, r0  @ r3 = y + div4(y)
    push    {r1}
    bl      divmod5     @ r0 = div5(div4(y))
    bl      divmod5     @ r0 = div5(div5(div(y))) = div100(y)
    pop     {r1}
    sub     r3, r3, r0  @ r3 = y + div4(y) - div100(y)
    bl      div4        @ r0 = div4(div100(y)) = div400(y)
    add     r3, r3, r0  @ r3 = y + div4(y) - div100(y) + div400(y)
    mov     r0, #13
    mul     r0, r1, r0  @ r0 = 13 * m
    add     r0, r0, #8  @ r0 = 13 * m + 8
    bl      divmod5     @ r0 = div5(13 * m + 8)
    add     r3, r3, r0  @ r3 = y + div4(y) - div100(y) + div400(y) + div5(13 * m + 8)
    add     r0, r3, r2  @ r0 = y + div4(y) - div100(y) + div400(y) + div5(13 * m + 8) + d
    bl      divmod7     @ r1 = mod7(y + div4(y) - div100(y) + div400(y) + div5(13 * m + 8) + d)
    mov     r0, r1
    pop     {lr}
    bx      lr
