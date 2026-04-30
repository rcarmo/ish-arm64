#include <string.h>
#include <stdatomic.h>
#include "kernel/calls.h"

#define PRCTL_SET_KEEPCAPS_ 8
#define PRCTL_SET_NAME_ 15

int_t sys_prctl(dword_t option, addr_t arg2, addr_t UNUSED(arg3), addr_t UNUSED(arg4), addr_t UNUSED(arg5)) {
    switch (option) {
        case PRCTL_SET_KEEPCAPS_:
            // stub
            return 0;
        case PRCTL_SET_NAME_: {
            char name[16];
            if (user_read_string(arg2, name, sizeof(name) - 1))
                return _EFAULT;
            name[sizeof(name) - 1] = '\0';
            STRACE("prctl(PRCTL_SET_NAME, \"%s\")", name);
            strcpy(current->comm, name);
            return 0;
        }
        default:
            STRACE("prctl(%#x)", option);
            return _EINVAL;
    }
}

int_t sys_arch_prctl(int_t code, addr_t addr) {
    STRACE("arch_prctl(%#x, %#x)", code, addr);
    return _EINVAL;
}

#define MEMBARRIER_CMD_QUERY 0
#define MEMBARRIER_CMD_GLOBAL (1 << 0)
#define MEMBARRIER_CMD_GLOBAL_EXPEDITED (1 << 1)
#define MEMBARRIER_CMD_REGISTER_GLOBAL_EXPEDITED (1 << 2)
#define MEMBARRIER_CMD_PRIVATE_EXPEDITED (1 << 3)
#define MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED (1 << 4)
#define MEMBARRIER_CMD_PRIVATE_EXPEDITED_SYNC_CORE (1 << 5)
#define MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED_SYNC_CORE (1 << 6)
#define MEMBARRIER_CMD_PRIVATE_EXPEDITED_RSEQ (1 << 7)
#define MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED_RSEQ (1 << 8)

#define MEMBARRIER_SUPPORTED_CMDS \
    (MEMBARRIER_CMD_GLOBAL | \
     MEMBARRIER_CMD_GLOBAL_EXPEDITED | \
     MEMBARRIER_CMD_REGISTER_GLOBAL_EXPEDITED | \
     MEMBARRIER_CMD_PRIVATE_EXPEDITED | \
     MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED | \
     MEMBARRIER_CMD_PRIVATE_EXPEDITED_SYNC_CORE | \
     MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED_SYNC_CORE)

int_t sys_membarrier(int_t cmd, dword_t flags, int_t cpu_id) {
    STRACE("membarrier(%#x, %#x, %d)", cmd, flags, cpu_id);
    if (cmd == MEMBARRIER_CMD_QUERY)
        return MEMBARRIER_SUPPORTED_CMDS;
    if (flags != 0)
        return _EINVAL;
    if (!(cmd & MEMBARRIER_SUPPORTED_CMDS) || (cmd & ~MEMBARRIER_SUPPORTED_CMDS))
        return _EINVAL;
    (void)cpu_id;
    atomic_thread_fence(memory_order_seq_cst);
    return 0;
}

#define REBOOT_MAGIC1 0xfee1dead
#define REBOOT_MAGIC2 672274793
#define REBOOT_MAGIC2A 85072278
#define REBOOT_MAGIC2B 369367448
#define REBOOT_MAGIC2C 537993216

#define REBOOT_CMD_CAD_OFF 0
#define REBOOT_CMD_CAD_ON 0x89abcdef

int_t sys_reboot(int_t magic, int_t magic2, int_t cmd) {
    STRACE("reboot(%#x, %d, %d)", magic, magic2, cmd);
    if (!superuser())
        return _EPERM;
    if (magic != (int) REBOOT_MAGIC1 ||
            (magic2 != REBOOT_MAGIC2 &&
             magic2 != REBOOT_MAGIC2A &&
             magic2 != REBOOT_MAGIC2B &&
             magic2 != REBOOT_MAGIC2C))
        return _EINVAL;

    switch (cmd) {
        case REBOOT_CMD_CAD_ON:
        case REBOOT_CMD_CAD_OFF:
            return 0;
        default:
            return _EPERM;
    }
}
