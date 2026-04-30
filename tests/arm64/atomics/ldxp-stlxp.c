#include <stdio.h>
#include <stdint.h>

static volatile unsigned long long pair64_mem[2] = {0, 0};
static volatile unsigned int pair32_mem[2] = {0, 0};

static int test64(void) {
    unsigned long long old0, old1;
    unsigned int status;
    unsigned long long new0 = 1, new1 = 2;
    int tries = 0;
    do {
        __asm__ volatile(
            "ldxp %0, %1, [%3]\n"
            "stlxp %w2, %4, %5, [%3]\n"
            : "=&r"(old0), "=&r"(old1), "=&r"(status)
            : "r"(pair64_mem), "r"(new0), "r"(new1)
            : "memory");
        tries++;
        if (tries > 1000000) {
            printf("loop64 old0=%llu old1=%llu status=%u mem=%llu,%llu\n",
                   old0, old1, status, pair64_mem[0], pair64_mem[1]);
            return 2;
        }
    } while (status != 0);
    printf("ok64 tries=%d old=%llu,%llu mem=%llu,%llu\n",
           tries, old0, old1, pair64_mem[0], pair64_mem[1]);
    return (old0 == 0 && old1 == 0 && pair64_mem[0] == 1 && pair64_mem[1] == 2) ? 0 : 3;
}

static int test32(void) {
    unsigned int old0, old1;
    unsigned int status;
    unsigned int new0 = 3, new1 = 4;
    int tries = 0;
    do {
        __asm__ volatile(
            "ldxp %w0, %w1, [%3]\n"
            "stlxp %w2, %w4, %w5, [%3]\n"
            : "=&r"(old0), "=&r"(old1), "=&r"(status)
            : "r"(pair32_mem), "r"(new0), "r"(new1)
            : "memory");
        tries++;
        if (tries > 1000000) {
            printf("loop32 old0=%u old1=%u status=%u mem=%u,%u\n",
                   old0, old1, status, pair32_mem[0], pair32_mem[1]);
            return 4;
        }
    } while (status != 0);
    printf("ok32 tries=%d old=%u,%u mem=%u,%u\n",
           tries, old0, old1, pair32_mem[0], pair32_mem[1]);
    return (old0 == 0 && old1 == 0 && pair32_mem[0] == 3 && pair32_mem[1] == 4) ? 0 : 5;
}

int main(void) {
    int rc = test64();
    if (rc != 0)
        return rc;
    return test32();
}
