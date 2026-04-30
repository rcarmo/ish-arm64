#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

typedef unsigned __int128 u128;
static _Alignas(16) volatile u128 g = 0;

static void print_u128(u128 v){
    unsigned long long lo=(unsigned long long)v;
    unsigned long long hi=(unsigned long long)(v>>64);
    printf("0x%016llx%016llx", hi, lo);
}

int main(void){
    u128 expected = 0;
    u128 desired = ((u128)2<<64) | 1;
    bool ok = __atomic_compare_exchange_n(&g, &expected, desired, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
    printf("ok=%d expected=", ok); print_u128(expected); printf(" g="); print_u128(g); printf("\n");
    return ok ? 0 : 1;
}
