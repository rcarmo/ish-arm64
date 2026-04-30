#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/fcntl.h>
#include <pthread.h>
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonRandom.h>
#include "platform/platform.h"

struct cpu_usage get_cpu_usage() {
    host_cpu_load_info_data_t load;
    mach_msg_type_number_t fuck = HOST_CPU_LOAD_INFO_COUNT;
    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t) &load, &fuck);
    struct cpu_usage usage;
    usage.user_ticks = load.cpu_ticks[CPU_STATE_USER];
    usage.system_ticks = load.cpu_ticks[CPU_STATE_SYSTEM];
    usage.idle_ticks = load.cpu_ticks[CPU_STATE_IDLE];
    usage.nice_ticks = load.cpu_ticks[CPU_STATE_NICE];
    return usage;
}

struct mem_usage get_mem_usage() {
    host_basic_info_data_t basic = {};
    mach_msg_type_number_t fuck = HOST_BASIC_INFO_COUNT;
    kern_return_t status = host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t) &basic, &fuck);
    assert(status == KERN_SUCCESS);
    vm_statistics64_data_t vm = {};
    fuck = HOST_VM_INFO64_COUNT;
    status = host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info_t) &vm, &fuck);
    assert(status == KERN_SUCCESS);

    struct mem_usage usage;
    usage.total = basic.max_mem;
    usage.free = vm.free_count * vm_page_size;
    usage.active = vm.active_count * vm_page_size;
    usage.inactive = vm.inactive_count * vm_page_size;
    return usage;
}

struct uptime_info get_uptime() {
    uint64_t kern_boottime[2];
    size_t size = sizeof(kern_boottime);
    sysctlbyname("kern.boottime", &kern_boottime, &size, NULL, 0);
    struct timeval now;
    gettimeofday(&now, NULL);

    struct {
        uint32_t ldavg[3];
        long scale;
    } vm_loadavg;
    size = sizeof(vm_loadavg);
    sysctlbyname("vm.loadavg", &vm_loadavg, &size, NULL, 0);

    // linux wants the scale to be 16 bits
    for (int i = 0; i < 3; i++) {
        if (FSHIFT < 16)
            vm_loadavg.ldavg[i] <<= 16 - FSHIFT;
        else
            vm_loadavg.ldavg[i] >>= FSHIFT - 16;
    }

    struct uptime_info uptime = {
        .uptime_ticks = now.tv_sec - kern_boottime[0],
        .load_1m = vm_loadavg.ldavg[0],
        .load_5m = vm_loadavg.ldavg[1],
        .load_15m = vm_loadavg.ldavg[2],
    };
    return uptime;
}

int platform_fd_get_path(int fd, char *out, size_t out_size) {
    (void)out_size;
    return fcntl(fd, F_GETPATH, out);
}

uint64_t platform_stat_atime_sec(const struct stat *st) { return st->st_atimespec.tv_sec; }
uint64_t platform_stat_mtime_sec(const struct stat *st) { return st->st_mtimespec.tv_sec; }
uint64_t platform_stat_ctime_sec(const struct stat *st) { return st->st_ctimespec.tv_sec; }
long platform_stat_atime_nsec(const struct stat *st) { return st->st_atimespec.tv_nsec; }
long platform_stat_mtime_nsec(const struct stat *st) { return st->st_mtimespec.tv_nsec; }
long platform_stat_ctime_nsec(const struct stat *st) { return st->st_ctimespec.tv_nsec; }

int platform_get_random_bytes(char *buf, size_t len) {
    return CCRandomGenerateBytes(buf, len) == kCCSuccess ? 0 : -1;
}

void platform_set_thread_name(const char *name) {
    pthread_setname_np(name);
}
