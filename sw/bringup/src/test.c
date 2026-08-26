volatile int *marker = (int *)0x10100;

int add(int a, int b) {
    return a + b;
}

int main() {
    int result = add(21, 21);
    *marker = result;
    while (1) {}
    return 0;
}