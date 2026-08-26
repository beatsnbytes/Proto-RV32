
volatile int *marker = (int *)0x100;
extern unsigned long _telemetry_start;  // declared, not defined - linker provides the address

static inline unsigned long read_mcycle(void) {
    unsigned long val;
    asm volatile ("csrr %0, mcycle" : "=r"(val));
    return val;
}
static inline unsigned long read_minstret(void) {
    unsigned long val;
    asm volatile ("csrr %0, minstret" : "=r"(val));
    return val;
}


int add(int a, int b) {
    return a + b;
}

void evict() {
    // Force eviction of the telemetry line: same cache index, different tag,
    // so the write-back cache flushes the dirty line to main_memory before halt.
    volatile unsigned long *evict_address = (unsigned long *)((unsigned long)&_telemetry_start + 0x400);
    unsigned long dummy = *evict_address;
    (void)dummy;  // suppress unused-variable warning    
    return;
}

int main() {

    unsigned long cycles_start = read_mcycle();
    unsigned long instret_start = read_minstret();    

    int result = add(21, 21);
    *marker = result;

    unsigned long cycles_end = read_mcycle();
    unsigned long instret_end = read_minstret();

    volatile unsigned long *telemetry = (unsigned long *)&_telemetry_start;
    telemetry[0] = cycles_end - cycles_start;  
    telemetry[1] = instret_end - instret_start;
    
    evict();

    while (1) {}
    return 0;
}