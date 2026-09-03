extern unsigned long _telemetry_start;

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

void evict() {
    volatile unsigned long *evict_address = (unsigned long *)((unsigned long)&_telemetry_start + 0x400);
    unsigned long dummy = *evict_address;
    (void)dummy;
    return;
}

typedef struct node {
    int value;
    struct node *next;
} node_t;

int multiply(int a, int b) {
    return a * b;
}

int compute_element(int base, int i) {
    return multiply(base, i) + i;
}

int array_transform_sum(int *arr, int n, int base) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        arr[i] = compute_element(base, i);
        sum += arr[i];
    }
    return sum;
}

int list_sum(node_t *head) {
    int sum = 0;
    node_t *cur = head;
    while (cur != 0) {
        sum += cur->value;
        cur = cur->next;
    }
    return sum;
}

static inline void cache_flush_addr(unsigned long addr) {
    register unsigned long rs1 asm("a0") = addr;
    asm volatile (
        ".word 0x0005200B"
        :
        : "r"(rs1)
        : "memory"
    );
}

// Flush whole cache (funct3=011, opcode=0001011)
static inline void cache_flush_all(void) {
    asm volatile (".word 0x0000300B" : : : "memory"); 
}


int main() {

    unsigned long cycles_start = read_mcycle();
    unsigned long instret_start = read_minstret();

    static int data[100];
    int array_result = array_transform_sum(data, 100, 3);

    static node_t nodes[100];
    for (int i = 0; i < 100; i++) {
        nodes[i].value = data[i];  // reuse array_transform_sum's output as list values
        nodes[i].next = (i < 99) ? &nodes[i + 1] : (node_t *)0;
    }
    int list_result = list_sum(&nodes[0]);

    int result = array_result + list_result;  // combine both, doubles as a cross-check

    unsigned long cycles_end = read_mcycle();
    unsigned long instret_end = read_minstret();

    volatile unsigned long *telemetry = (unsigned long *)&_telemetry_start;
    telemetry[0] = result;
    telemetry[1] = instret_end - instret_start;
    telemetry[2] = cycles_end - cycles_start;
    // evict();
    // cache_flush_addr((unsigned long)&_telemetry_start);
    cache_flush_all();

    while (1) {}
    return 0;
}