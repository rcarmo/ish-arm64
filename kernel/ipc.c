#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "kernel/calls.h"
#include "kernel/memory.h"
#include "kernel/mm.h"
#include "platform/platform.h"
#include "util/sync.h"

#define IPC_PRIVATE_ 0
#define IPC_CREAT_ 01000
#define IPC_EXCL_ 02000
#define IPC_RMID_ 0
#define IPC_SET_ 1
#define IPC_STAT_ 2
#define IPC_NOWAIT_ 04000

#define MSG_NOERROR_ 010000
#define MSG_EXCEPT_ 020000

#define SHM_RDONLY_ 010000
#define SHM_RND_ 020000
#define SHM_REMAP_ 040000

struct shm_segment {
    int id;
    int key;
    size_t size;
    pages_t pages;
    int fd;
    struct shm_segment *next;
};

struct shm_attach {
    struct mm *mm;
    addr_t addr;
    pages_t pages;
    int shmid;
    struct shm_attach *next;
};

struct guest_ipc_perm {
    int32_t key;
    uint32_t uid;
    uint32_t gid;
    uint32_t cuid;
    uint32_t cgid;
    uint32_t mode;
    int32_t seq;
    int64_t pad1;
    int64_t pad2;
};

struct guest_shmid_ds {
    struct guest_ipc_perm shm_perm;
    uint64_t shm_segsz;
    int64_t shm_atime;
    int64_t shm_dtime;
    int64_t shm_ctime;
    int32_t shm_cpid;
    int32_t shm_lpid;
    uint64_t shm_nattch;
    uint64_t pad1;
    uint64_t pad2;
};

struct msg_message {
    int64_t type;
    size_t size;
    char *data;
    struct msg_message *next;
};

struct msg_queue {
    int id;
    int key;
    struct msg_message *messages;
    struct msg_queue *next;
};

static lock_t shm_lock = LOCK_INITIALIZER;
static cond_t msg_cond = COND_INITIALIZER;
static int next_shmid = 1;
static int next_msgid = 1;
static struct shm_segment *shm_segments;
static struct shm_attach *shm_attaches;
static struct msg_queue *msg_queues;

static struct shm_segment *shm_find_id(int shmid) {
    for (struct shm_segment *seg = shm_segments; seg; seg = seg->next)
        if (seg->id == shmid)
            return seg;
    return NULL;
}

static struct shm_segment *shm_find_key(int key) {
    for (struct shm_segment *seg = shm_segments; seg; seg = seg->next)
        if (seg->key == key)
            return seg;
    return NULL;
}

static struct msg_queue *msg_find_id(int msqid) {
    for (struct msg_queue *queue = msg_queues; queue; queue = queue->next)
        if (queue->id == msqid)
            return queue;
    return NULL;
}

static struct msg_queue *msg_find_key(int key) {
    for (struct msg_queue *queue = msg_queues; queue; queue = queue->next)
        if (queue->key == key)
            return queue;
    return NULL;
}

int_t sys_msgget(int_t key, int_t msgflg) {
    STRACE("msgget(%#x, %#x)", key, msgflg);
    lock(&shm_lock);
    struct msg_queue *queue = key == IPC_PRIVATE_ ? NULL : msg_find_key(key);
    if (queue != NULL) {
        if ((msgflg & IPC_CREAT_) && (msgflg & IPC_EXCL_)) {
            unlock(&shm_lock);
            return _EEXIST;
        }
        int id = queue->id;
        unlock(&shm_lock);
        return id;
    }
    if (key != IPC_PRIVATE_ && !(msgflg & IPC_CREAT_)) {
        unlock(&shm_lock);
        return _ENOENT;
    }
    queue = calloc(1, sizeof(*queue));
    if (queue == NULL) {
        unlock(&shm_lock);
        return _ENOMEM;
    }
    queue->id = next_msgid++;
    if (next_msgid <= 0)
        next_msgid = 1;
    queue->key = key;
    queue->next = msg_queues;
    msg_queues = queue;
    int id = queue->id;
    unlock(&shm_lock);
    return id;
}

int_t sys_msgctl(int_t msqid, int_t cmd, addr_t buf_addr) {
    STRACE("msgctl(%d, %d, %#llx)", msqid, cmd, (unsigned long long) buf_addr);
    lock(&shm_lock);
    struct msg_queue **queuep = &msg_queues;
    while (*queuep != NULL && (*queuep)->id != msqid)
        queuep = &(*queuep)->next;
    struct msg_queue *queue = *queuep;
    if (queue == NULL) {
        unlock(&shm_lock);
        return _EINVAL;
    }
    if (cmd == IPC_RMID_) {
        *queuep = queue->next;
        struct msg_message *msg = queue->messages;
        while (msg != NULL) {
            struct msg_message *next = msg->next;
            free(msg->data);
            free(msg);
            msg = next;
        }
        free(queue);
        notify(&msg_cond);
        unlock(&shm_lock);
        return 0;
    }
    unlock(&shm_lock);
    if (cmd == IPC_STAT_ || cmd == IPC_SET_)
        return 0;
    return _EINVAL;
}

int_t sys_msgsnd(int_t msqid, addr_t msgp, size_t msgsz, int_t msgflg) {
    STRACE("msgsnd(%d, %#llx, %#zx, %#x)", msqid, (unsigned long long) msgp, msgsz, msgflg);
    (void) msgflg;
    int64_t type;
    if (user_read(msgp, &type, sizeof(type)) < 0)
        return _EFAULT;
    if (type <= 0)
        return _EINVAL;
    struct msg_message *msg = calloc(1, sizeof(*msg));
    if (msg == NULL)
        return _ENOMEM;
    msg->data = malloc(msgsz ? msgsz : 1);
    if (msg->data == NULL) {
        free(msg);
        return _ENOMEM;
    }
    if (msgsz && user_read(msgp + sizeof(type), msg->data, msgsz) < 0) {
        free(msg->data);
        free(msg);
        return _EFAULT;
    }
    msg->type = type;
    msg->size = msgsz;

    lock(&shm_lock);
    struct msg_queue *queue = msg_find_id(msqid);
    if (queue == NULL) {
        unlock(&shm_lock);
        free(msg->data);
        free(msg);
        return _EINVAL;
    }
    struct msg_message **tail = &queue->messages;
    while (*tail != NULL)
        tail = &(*tail)->next;
    *tail = msg;
    notify(&msg_cond);
    unlock(&shm_lock);
    return 0;
}

static bool msg_matches(int64_t have, int64_t want, int_t flags) {
    if (want == 0)
        return true;
    if (want > 0) {
        if (flags & MSG_EXCEPT_)
            return have != want;
        return have == want;
    }
    return have <= -want;
}

ssize_t sys_msgrcv(int_t msqid, addr_t msgp, size_t msgsz, int64_t msgtyp, int_t msgflg) {
    STRACE("msgrcv(%d, %#llx, %#zx, %lld, %#x)", msqid, (unsigned long long) msgp, msgsz, (long long) msgtyp, msgflg);
    lock(&shm_lock);
    for (;;) {
        struct msg_queue *queue = msg_find_id(msqid);
        if (queue == NULL) {
            unlock(&shm_lock);
            return _EINVAL;
        }
        struct msg_message **msgp_link = &queue->messages;
        struct msg_message **best_link = NULL;
        int64_t best_type = INT64_MAX;
        while (*msgp_link != NULL) {
            struct msg_message *candidate = *msgp_link;
            if (msg_matches(candidate->type, msgtyp, msgflg)) {
                if (msgtyp < 0) {
                    if (candidate->type < best_type) {
                        best_type = candidate->type;
                        best_link = msgp_link;
                    }
                } else {
                    best_link = msgp_link;
                    break;
                }
            }
            msgp_link = &candidate->next;
        }
        if (best_link != NULL) {
            struct msg_message *msg = *best_link;
            if (msg->size > msgsz && !(msgflg & MSG_NOERROR_)) {
                unlock(&shm_lock);
                return _E2BIG;
            }
            *best_link = msg->next;
            size_t copy = msg->size < msgsz ? msg->size : msgsz;
            int64_t type = msg->type;
            char *data = msg->data;
            size_t original_size = msg->size;
            free(msg);
            unlock(&shm_lock);
            int err = user_write(msgp, &type, sizeof(type));
            if (err == 0 && copy)
                err = user_write(msgp + sizeof(type), data, copy);
            free(data);
            if (err < 0)
                return _EFAULT;
            return copy < original_size ? (ssize_t) copy : (ssize_t) original_size;
        }
        if (msgflg & IPC_NOWAIT_) {
            unlock(&shm_lock);
            return _ENODATA;
        }
        current->blocking = true;
        int err = wait_for(&msg_cond, &shm_lock, NULL);
        current->blocking = false;
        if (err < 0) {
            unlock(&shm_lock);
            return err;
        }
    }
}

int_t sys_shmget(int_t key, size_t size, int_t shmflg) {
    STRACE("shmget(%#x, %#zx, %#x)", key, size, shmflg);
    lock(&shm_lock);

    struct shm_segment *seg = key == IPC_PRIVATE_ ? NULL : shm_find_key(key);
    if (seg != NULL) {
        if ((shmflg & IPC_CREAT_) && (shmflg & IPC_EXCL_)) {
            unlock(&shm_lock);
            return _EEXIST;
        }
        if (size > seg->size) {
            unlock(&shm_lock);
            return _EINVAL;
        }
        int id = seg->id;
        unlock(&shm_lock);
        return id;
    }

    if (key != IPC_PRIVATE_ && !(shmflg & IPC_CREAT_)) {
        unlock(&shm_lock);
        return _ENOENT;
    }
    if (size == 0) {
        unlock(&shm_lock);
        return _EINVAL;
    }

    pages_t pages = PAGE_ROUND_UP(size);
    size_t map_size = (size_t) pages << PAGE_BITS;
    int fd = platform_create_shared_memory_fd(map_size);
    if (fd < 0) {
        int err = errno_map();
        unlock(&shm_lock);
        return err;
    }
    fcntl(fd, F_SETFD, FD_CLOEXEC);

    seg = calloc(1, sizeof(*seg));
    if (seg == NULL) {
        close(fd);
        unlock(&shm_lock);
        return _ENOMEM;
    }
    seg->id = next_shmid++;
    if (next_shmid <= 0)
        next_shmid = 1;
    seg->key = key;
    seg->size = size;
    seg->pages = pages;
    seg->fd = fd;
    seg->next = shm_segments;
    shm_segments = seg;

    int id = seg->id;
    unlock(&shm_lock);
    return id;
}

int_t sys_shmctl(int_t shmid, int_t cmd, addr_t buf_addr) {
    STRACE("shmctl(%d, %d, %#llx)", shmid, cmd, (unsigned long long) buf_addr);
    lock(&shm_lock);
    struct shm_segment **segp = &shm_segments;
    while (*segp != NULL && (*segp)->id != shmid)
        segp = &(*segp)->next;
    struct shm_segment *seg = *segp;
    if (seg == NULL) {
        unlock(&shm_lock);
        return _EINVAL;
    }

    if (cmd == IPC_RMID_) {
        *segp = seg->next;
        close(seg->fd);
        free(seg);
        unlock(&shm_lock);
        return 0;
    }

    if (cmd == IPC_STAT_) {
        if (buf_addr == 0) {
            unlock(&shm_lock);
            return _EFAULT;
        }
        uint64_t nattch = 0;
        for (struct shm_attach *attach = shm_attaches; attach; attach = attach->next)
            if (attach->shmid == shmid)
                nattch++;
        struct guest_shmid_ds ds = {
            .shm_perm = {
                .key = seg->key,
                .uid = 0,
                .gid = 0,
                .cuid = 0,
                .cgid = 0,
                .mode = 0666,
                .seq = 0,
            },
            .shm_segsz = seg->size,
            .shm_nattch = nattch,
        };
        unlock(&shm_lock);
        return user_write(buf_addr, &ds, sizeof(ds));
    }

    unlock(&shm_lock);
    if (cmd == IPC_SET_)
        return 0;
    return _EINVAL;
}

addr_t sys_shmat(int_t shmid, addr_t shmaddr, int_t shmflg) {
    STRACE("shmat(%d, %#llx, %#x)", shmid, (unsigned long long) shmaddr, shmflg);
    lock(&shm_lock);
    struct shm_segment *seg = shm_find_id(shmid);
    if (seg == NULL) {
        unlock(&shm_lock);
        return _EINVAL;
    }

    pages_t pages = seg->pages;
    size_t map_size = (size_t) pages << PAGE_BITS;
    int host_prot = PROT_READ;
    unsigned guest_prot = P_READ | P_SHARED;
    if (!(shmflg & SHM_RDONLY_)) {
        host_prot |= PROT_WRITE;
        guest_prot |= P_WRITE;
    }

    void *host_map = mmap(NULL, map_size, host_prot, MAP_SHARED, seg->fd, 0);
    if (host_map == MAP_FAILED) {
        int err = errno_map();
        unlock(&shm_lock);
        return err;
    }

    write_wrlock(&current->mem->lock);
    page_t page;
    if (shmaddr != 0) {
        if (shmflg & SHM_RND_)
            shmaddr = BYTES_ROUND_DOWN(shmaddr);
        if (PGOFFSET(shmaddr) != 0) {
            write_wrunlock(&current->mem->lock);
            munmap(host_map, map_size);
            unlock(&shm_lock);
            return _EINVAL;
        }
        page = PAGE(shmaddr);
        if (!(shmflg & SHM_REMAP_) && !pt_is_hole(current->mem, page, pages)) {
            write_wrunlock(&current->mem->lock);
            munmap(host_map, map_size);
            unlock(&shm_lock);
            return _EINVAL;
        }
    } else {
        page = pt_find_hole(current->mem, pages);
        if (page == BAD_PAGE) {
            write_wrunlock(&current->mem->lock);
            munmap(host_map, map_size);
            unlock(&shm_lock);
            return _ENOMEM;
        }
    }

    int err = pt_map(current->mem, page, pages, host_map, 0, guest_prot);
    write_wrunlock(&current->mem->lock);
    if (err < 0) {
        munmap(host_map, map_size);
        unlock(&shm_lock);
        return err;
    }

    struct shm_attach *attach = calloc(1, sizeof(*attach));
    if (attach == NULL) {
        write_wrlock(&current->mem->lock);
        pt_unmap_always(current->mem, page, pages);
        write_wrunlock(&current->mem->lock);
        unlock(&shm_lock);
        return _ENOMEM;
    }
    attach->mm = current->mm;
    attach->addr = page << PAGE_BITS;
    attach->pages = pages;
    attach->shmid = shmid;
    attach->next = shm_attaches;
    shm_attaches = attach;

    addr_t result = page << PAGE_BITS;
    unlock(&shm_lock);
    return result;
}

int_t sys_shmdt(addr_t shmaddr) {
    STRACE("shmdt(%#llx)", (unsigned long long) shmaddr);
    if (PGOFFSET(shmaddr) != 0)
        return _EINVAL;

    lock(&shm_lock);
    struct shm_attach **attachp = &shm_attaches;
    while (*attachp != NULL && !((*attachp)->mm == current->mm && (*attachp)->addr == shmaddr))
        attachp = &(*attachp)->next;
    struct shm_attach *attach = *attachp;
    if (attach == NULL) {
        unlock(&shm_lock);
        return _EINVAL;
    }
    *attachp = attach->next;
    pages_t pages = attach->pages;
    free(attach);
    unlock(&shm_lock);

    write_wrlock(&current->mem->lock);
    int err = pt_unmap(current->mem, PAGE(shmaddr), pages);
    write_wrunlock(&current->mem->lock);
    return err < 0 ? _EINVAL : 0;
}

int_t sys_ipc(uint_t call, int_t first, int_t second, int_t third, addr_t ptr, int_t fifth) {
    STRACE("ipc(%u, %d, %d, %d, %#x, %d)", call, first, second, third, ptr, fifth);
    return _ENOSYS;
}
