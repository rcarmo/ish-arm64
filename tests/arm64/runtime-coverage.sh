#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

ISH_BIN="${ISH_BIN:-$PROJECT_DIR/build-arm64-linux/ish}"
ROOTFS="${ROOTFS:-$PROJECT_DIR/alpine-arm64-fakefs}"
TIMEOUT_S="${TIMEOUT_S:-120}"
INSTALL_TIMEOUT_S="${INSTALL_TIMEOUT_S:-1200}"
REPORT_DIR="${REPORT_DIR:-/workspace/tmp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/ish-arm64-runtime-coverage-$STAMP.md"
GUEST_WORK="/tmp/runtime-coverage"
HOST_TMP="$(mktemp -d)"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0
REPORT_ROWS=""

cleanup() {
    rm -rf "$HOST_TMP"
}
trap cleanup EXIT

mkdir -p "$REPORT_DIR"

log() {
    printf '>>> %s\n' "$*"
}

guest_capture() {
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin; { $1; }; rc=\$?; printf '\n__ISH_STATUS:%s\n' \"\$rc\""
}

guest_capture_install() {
    timeout "$INSTALL_TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin; { $1; }; rc=\$?; printf '\n__ISH_STATUS:%s\n' \"\$rc\""
}

push_tree() {
    local src="$1"
    local dst="$2"
    tar -C "$src" -cf - . | timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "rm -rf '$dst' && mkdir -p '$dst' && tar -xf - -C '$dst'"
}

append_row() {
    local stage="$1"
    local name="$2"
    local status="$3"
    local detail="$4"
    REPORT_ROWS+="| $stage | $name | $status | ${detail//$'\n'/<br>} |"$'\n'
}

run_test() {
    local stage="$1"
    local name="$2"
    local cmd="$3"
    local out="$HOST_TMP/test.out"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    printf '[%s] %s ... ' "$stage" "$name"
    if guest_capture "$cmd" >"$out" 2>&1 && grep -q '^__ISH_STATUS:0$' "$out"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "PASS"
        append_row "$stage" "$name" "PASS" "$(grep -v '^__ISH_STATUS:' "$out" | sed -n '1,6p' | sed 's/|/\\|/g')"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "FAIL"
        append_row "$stage" "$name" "FAIL" "$(grep -v '^__ISH_STATUS:' "$out" | sed -n '1,20p' | sed 's/|/\\|/g')"
    fi
}

ensure_guest_basics() {
    log "Ensuring fakefs DNS/apk basics"
    local out="$HOST_TMP/install.out"
    guest_capture_install "test -f /etc/resolv.conf || echo 'nameserver 1.1.1.1' > /etc/resolv.conf; sed -i 's|https://|http://|g' /etc/apk/repositories 2>/dev/null || true; mkdir -p '$GUEST_WORK'" >"$out" 2>&1
    grep -q '^__ISH_STATUS:0$' "$out"
}

ensure_tools() {
    local missing=()
    local spec pkg cmd
    for spec in "$@"; do
        pkg="${spec%%:*}"
        cmd="${spec#*:}"
        [ "$cmd" = "$spec" ] && cmd="$pkg"
        local out="$HOST_TMP/ensure-tool.out"
        guest_capture "command -v $cmd >/dev/null 2>&1" >"$out" 2>&1 || true
        if ! grep -q '^__ISH_STATUS:0$' "$out"; then
            missing+=("$pkg")
        fi
    done
    if ((${#missing[@]} > 0)); then
        log "Installing guest packages: ${missing[*]}"
        local out="$HOST_TMP/apk.out"
        guest_capture_install "apk update >/dev/null 2>&1 && apk add --no-cache ${missing[*]}" >"$out" 2>&1
        grep -q '^__ISH_STATUS:0$' "$out"
    fi
}

prepare_c_fixture() {
    local dir="$HOST_TMP/c"
    mkdir -p "$dir"
    cat >"$dir/hello.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>

int main(void) {
    uint64_t sum = 0;
    for (uint64_t i = 0; i < 100000; i++) sum += i;
    printf("c-runtime-ok %llu\n", (unsigned long long)sum);
    return 0;
}
EOF
    cat >"$dir/sysv_ipc.c" <<'EOF'
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <sys/shm.h>
#include <sys/wait.h>
#include <unistd.h>

struct test_msg {
    long mtype;
    char mtext[64];
};

static void die(const char *what) {
    perror(what);
    exit(1);
}

int main(void) {
    int shmid = shmget(IPC_PRIVATE, 4096, IPC_CREAT | 0600);
    if (shmid < 0) die("shmget");
    char *shared = shmat(shmid, NULL, 0);
    if (shared == (void *) -1) die("shmat");
    strcpy(shared, "parent");

    int msgid = msgget(IPC_PRIVATE, IPC_CREAT | 0600);
    if (msgid < 0) die("msgget");

    pid_t pid = fork();
    if (pid < 0) die("fork");
    if (pid == 0) {
        if (strcmp(shared, "parent") != 0) _exit(2);
        strcpy(shared, "child");
        struct test_msg msg = {.mtype = 2};
        strcpy(msg.mtext, "msg-ok");
        if (msgsnd(msgid, &msg, strlen(msg.mtext) + 1, 0) < 0) _exit(3);
        shmdt(shared);
        _exit(0);
    }

    struct test_msg msg;
    if (msgrcv(msgid, &msg, sizeof(msg.mtext), 2, 0) < 0) die("msgrcv");
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) die("waitpid");
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) return 4;
    if (strcmp(shared, "child") != 0) return 5;
    if (strcmp(msg.mtext, "msg-ok") != 0) return 6;

    if (shmdt(shared) < 0) die("shmdt");
    if (shmctl(shmid, IPC_RMID, NULL) < 0) die("shmctl");
    if (msgctl(msgid, IPC_RMID, NULL) < 0) die("msgctl");
    puts("sysv-ipc-ok");
    return 0;
}
EOF
    push_tree "$dir" "$GUEST_WORK/c"
}

prepare_go_fixture() {
    local dir="$HOST_TMP/go"
    mkdir -p "$dir"
    cat >"$dir/go.mod" <<'EOF'
module example.com/runtimecoverage

go 1.22
EOF
    cat >"$dir/main.go" <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "os"
)

func main() {
    payload := map[string]any{"runtime": "go", "ok": true}
    _ = json.NewEncoder(os.Stdout).Encode(payload)
    fmt.Println("go-runtime-ok")
}
EOF
    mkdir -p "$dir/compileonly"
    cat >"$dir/compileonly/compile_only.go" <<'EOF'
package compileonly

func Add(a, b int) int {
    return a + b
}
EOF
    cat >"$dir/main_test.go" <<'EOF'
package main

import "testing"

func TestMath(t *testing.T) {
    if 2+2 != 4 {
        t.Fatal("bad math")
    }
}
EOF
    push_tree "$dir" "$GUEST_WORK/go"
}

prepare_bun_fixture() {
    local dir="$HOST_TMP/bun"
    mkdir -p "$dir/localdep"
    cat >"$dir/package.json" <<'EOF'
{
  "name": "bun-runtime-coverage",
  "private": true,
  "type": "module",
  "dependencies": {
    "localdep": "file:./localdep"
  }
}
EOF
    cat >"$dir/localdep/package.json" <<'EOF'
{
  "name": "localdep",
  "version": "1.0.0",
  "type": "module",
  "exports": "./index.js"
}
EOF
    cat >"$dir/localdep/index.js" <<'EOF'
export const marker = "bun-localdep-ok";
EOF
    cat >"$dir/index.ts" <<'EOF'
import { writeFileSync, readFileSync } from "node:fs";
import { marker } from "localdep";

writeFileSync("/tmp/runtime-coverage/bun/output.txt", marker + "\n");
process.stdout.write(readFileSync("/tmp/runtime-coverage/bun/output.txt", "utf8"));
EOF
    cat >"$dir/sum.test.ts" <<'EOF'
import { expect, test } from "bun:test";
import { marker } from "localdep";

test("bun runtime coverage", () => {
  expect(marker).toBe("bun-localdep-ok");
  expect(1 + 1).toBe(2);
});
EOF
    push_tree "$dir" "$GUEST_WORK/bun"
}

prepare_node_fixture() {
    local dir="$HOST_TMP/node"
    mkdir -p "$dir"
    cat >"$dir/package.json" <<'EOF'
{
  "name": "node-runtime-coverage",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node index.mjs"
  }
}
EOF
    cat >"$dir/index.mjs" <<'EOF'
import { writeFileSync, readFileSync } from "node:fs";

writeFileSync("/tmp/runtime-coverage/node/output.txt", "node-runtime-ok\n");
process.stdout.write(readFileSync("/tmp/runtime-coverage/node/output.txt", "utf8"));
EOF
    push_tree "$dir" "$GUEST_WORK/node"
}

write_report() {
    cat >"$REPORT" <<EOF
# iSH ARM64 Runtime Coverage Report

- Timestamp: $(date -Is)
- ish binary: $ISH_BIN
- rootfs: $ROOTFS
- timeout: ${TIMEOUT_S}s
- install timeout: ${INSTALL_TIMEOUT_S}s

## Summary

- Total: $TOTAL_COUNT
- Passed: $PASS_COUNT
- Failed: $FAIL_COUNT

## Results

| Stage | Test | Status | Detail |
|---|---|---|---|
$REPORT_ROWS
EOF
}

main() {
    [ -x "$ISH_BIN" ] || { echo "missing ish binary: $ISH_BIN" >&2; exit 1; }
    [ -d "$ROOTFS" ] || { echo "missing rootfs: $ROOTFS" >&2; exit 1; }

    ensure_guest_basics

    run_test base "shell" "echo shell-ok | grep -qx shell-ok"
    run_test base "apk" "apk --version >/dev/null 2>&1"
    run_test base "tmp file io" "echo file-ok > '$GUEST_WORK/base.txt' && grep -qx file-ok '$GUEST_WORK/base.txt'"

    ensure_tools build-base:gcc
    prepare_c_fixture
    run_test c "gcc version" "gcc --version | head -1"
    run_test c "compile + run" "cd '$GUEST_WORK/c' && gcc -O0 hello.c -o hello && ./hello | grep -q '^c-runtime-ok '"
    run_test c "sysv shm/msg IPC" "cd '$GUEST_WORK/c' && gcc -O0 sysv_ipc.c -o sysv_ipc && ./sysv_ipc | grep -qx sysv-ipc-ok"

    ensure_tools go
    prepare_go_fixture
    run_test go "version" "go version"
    run_test go "env" "go env GOARCH GOOS GOROOT"
    run_test go "go tool compile" "cd '$GUEST_WORK/go/compileonly' && go tool compile -o compile_only.o compile_only.go"
    run_test go "go run" "cd '$GUEST_WORK/go' && go run . | tail -1 | grep -qx go-runtime-ok"
    run_test go "go build + execute" "cd '$GUEST_WORK/go' && go build -o app . && ./app | tail -1 | grep -qx go-runtime-ok"
    run_test go "go test" "cd '$GUEST_WORK/go' && go test ./..."

    run_test bun "version" "bun --version"
    prepare_bun_fixture
    run_test bun "install local dep" "cd '$GUEST_WORK/bun' && bun install"
    run_test bun "run typescript" "cd '$GUEST_WORK/bun' && bun run index.ts | grep -qx bun-localdep-ok"
    run_test bun "bun test" "cd '$GUEST_WORK/bun' && bun test"
    run_test bun "bun build" "cd '$GUEST_WORK/bun' && bun build ./index.ts --outfile ./dist/index.js >/dev/null && test -s ./dist/index.js"

    ensure_tools nodejs:node npm
    prepare_node_fixture
    run_test node "node version" "node --version"
    run_test node "node eval" "node -e 'console.log(1+1)' | grep -qx 2"
    run_test node "npm version" "npm --version"
    run_test node "node run" "cd '$GUEST_WORK/node' && npm run --silent start | grep -qx node-runtime-ok"

    write_report
    echo "report: $REPORT"

    if ((FAIL_COUNT > 0)); then
        exit 1
    fi
}

main "$@"
