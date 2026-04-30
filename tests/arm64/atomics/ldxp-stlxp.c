#include <stdio.h>
#include <stdint.h>
#include <string.h>

static volatile unsigned long long pair_mem[2] = {0,0};

int main(void) {
    unsigned long long old0, old1;
    unsigned int status;
    unsigned long long new0 = 1, new1 = 2;
    int tries = 0;
    do {
        __asm__ volatile(
            "ldxp %0, %1, [%3]\n"
            "stlxp %w2, %4, %5, [%3]\n"
            : "=&r"(old0), "=&r"(old1), "=&r"(status)
            : "r"(pair_mem), "r"(new0), "r"(new1)
            : "memory");
        tries++;
        if (tries > 1000000) {
            printf("loop old0=%llu old1=%llu status=%u mem=%llu,%llu\n", old0, old1, status, pair_mem[0], pair_mem[1]);
            return 2;
        }
    } while (status != 0);
    printf("ok tries=%d old=%llu,%llu mem=%llu,%llu\n", tries, old0, old1, pair_mem[0], pair_mem[1]);
    return 0;
}
