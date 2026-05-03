#define _GNU_SOURCE
#include <sys/sysinfo.h>
#include <sys/syscall.h>
#include <linux/random.h>
#include <pthread.h>
#include <unistd.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "platform/platform.h"
#include "debug.h"

static void read_proc_line(const char *file, const char *name, char *buf) {
    FILE *f = fopen(file, "r");
    if (f == NULL) ERRNO_DIE(file);
    do {
        fgets(buf, 1234, f);
        if (feof(f))
            die("could not find proc line %s", name);
    } while (!(strncmp(name, buf, strlen(name)) == 0 && buf[strlen(name)] == ' '));
    fclose(f);
}

struct cpu_usage get_cpu_usage() {
    struct cpu_usage usage = {};
    char buf[1234];
    read_proc_line("/proc/stat", "cpu", buf);
    sscanf(buf, "cpu %"SCNu64" %"SCNu64" %"SCNu64" %"SCNu64"\n", &usage.user_ticks, &usage.system_ticks, &usage.idle_ticks, &usage.nice_ticks);
    return usage;
}

struct mem_usage get_mem_usage() {
    struct mem_usage usage;
    char buf[1234];

    read_proc_line("/proc/meminfo", "MemTotal:", buf);
    sscanf(buf, "MemTotal: %"PRIu64" kB\n", &usage.total);
    read_proc_line("/proc/meminfo", "MemFree:", buf);
    sscanf(buf, "MemFree: %"PRIu64" kB\n", &usage.free);
    read_proc_line("/proc/meminfo", "Active:", buf);
    sscanf(buf, "Active: %"PRIu64" kB\n", &usage.active);
    read_proc_line("/proc/meminfo", "Inactive:", buf);
    sscanf(buf, "Inactive: %"PRIu64" kB\n", &usage.inactive);

    return usage;
}

struct uptime_info get_uptime() {
    struct sysinfo info;
    sysinfo(&info);
    struct uptime_info uptime = {
        .uptime_ticks = info.uptime,
        .load_1m = info.loads[0],
        .load_5m = info.loads[1],
        .load_15m = info.loads[2],
    };
    return uptime;
}

int platform_fd_get_path(int fd, char *out, size_t out_size) {
    if (out_size == 0)
        return -1;
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(proc_path, out, out_size - 1);
    if (n < 0)
        return -1;
    out[n] = '\0';
    return 0;
}

uint64_t platform_stat_atime_sec(const struct stat *st) { return st->st_atim.tv_sec; }
uint64_t platform_stat_mtime_sec(const struct stat *st) { return st->st_mtim.tv_sec; }
uint64_t platform_stat_ctime_sec(const struct stat *st) { return st->st_ctim.tv_sec; }
long platform_stat_atime_nsec(const struct stat *st) { return st->st_atim.tv_nsec; }
long platform_stat_mtime_nsec(const struct stat *st) { return st->st_mtim.tv_nsec; }
long platform_stat_ctime_nsec(const struct stat *st) { return st->st_ctim.tv_nsec; }

int platform_get_random_bytes(char *buf, size_t len) {
    return syscall(SYS_getrandom, buf, len, 0) < 0 ? -1 : 0;
}

int platform_create_shared_memory_fd(size_t size) {
    char path[] = "/tmp/ish-shm-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0)
        return -1;
    unlink(path);
    if (ftruncate(fd, (off_t) size) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

void platform_set_thread_name(const char *name) {
    char short_name[16];
    snprintf(short_name, sizeof(short_name), "%s", name);
    pthread_setname_np(pthread_self(), short_name);
}
