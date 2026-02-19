export fn _init() void {
    asm volatile (
        \\ push {r3, r4, r5, r6, r7, lr}
        \\ nop
        \\ pop {r3, r4, r5, r6, r7}
        \\ pop {r3}
        \\ mov lr, r3
        \\ bx lr
    );
}

export fn _fini() void {
    asm volatile (
        \\ push {r3, r4, r5, r6, r7, lr}
        \\ nop
        \\ pop {r3, r4, r5, r6, r7}
        \\ pop {r3}
        \\ mov lr, r3
        \\ bx lr
    );
}

