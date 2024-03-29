#define MTIMECMP (*((volatile int*)0x02004000))
#define MTIME    (*((volatile int*)0x0200bff8))

void int_allow();
void int_disallow();

void set_timer(int duration) {
    int now = MTIME;
    MTIMECMP = now + duration;
}

void trap_handler(void) {
    set_timer(20);
    int_allow();
}

int main(void) {
    asm("lui a5, 0x20000");
    asm("jalr a5");
    return 0;
}
