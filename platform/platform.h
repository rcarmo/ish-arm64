#ifndef PLATFORM_H
#define PLATFORM_H
#include <stddef.h>
#include <sys/stat.h>
#include "misc.h"

// for some reason a tick is always 10ms
struct cpu_usage {
    uint64_t user_ticks;
    uint64_t system_ticks;
    uint64_t idle_ticks;
    uint64_t nice_ticks;
};
struct cpu_usage get_cpu_usage(void);

struct mem_usage {
    uint64_t total;
    uint64_t free;
    uint64_t active;
    uint64_t inactive;
};
struct mem_usage get_mem_usage(void);

struct uptime_info {
    uint64_t uptime_ticks;
    uint64_t load_1m, load_5m, load_15m;
};
struct uptime_info get_uptime(void);

// Guest-visible CPU topology. Keep this deterministic instead of mirroring the
// host CPU count: exposing all host cores makes modern runtimes (Bun/JSC/V8) fan
// out too aggressively for the emulator.
#ifndef PLATFORM_GUEST_CPU_COUNT
#define PLATFORM_GUEST_CPU_COUNT 4
#endif

// Host OS shims. Keep Linux/macOS/iOS API differences behind platform/* so
// emulator/kernel code can include one stable interface.
int platform_fd_get_path(int fd, char *out, size_t out_size);
uint64_t platform_stat_atime_sec(const struct stat *st);
uint64_t platform_stat_mtime_sec(const struct stat *st);
uint64_t platform_stat_ctime_sec(const struct stat *st);
long platform_stat_atime_nsec(const struct stat *st);
long platform_stat_mtime_nsec(const struct stat *st);
long platform_stat_ctime_nsec(const struct stat *st);
int platform_get_random_bytes(char *buf, size_t len);
void platform_set_thread_name(const char *name);

#endif
