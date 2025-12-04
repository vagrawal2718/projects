#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/memlayout.h"
//#include "kernel/defs.h"

#define PGSIZE 4096

void readonly_test() {
    printf("Running Read-Only Test\n");

    int pid = fork();
    if (pid < 0) {
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
        // Child process: read from allocated memory without modifying
        char *mem = sbrk(PGSIZE);
        if (mem == (char *)-1) {
            printf("sbrk failed\n");
            return;
        }
        // Read the memory to ensure no COW is triggered
        volatile char value = mem[0];
        printf("Child read value: %d\n", value);
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}

void write_test() {
    printf("Running Write Test\n");

    int pid = fork();
    if (pid < 0) {
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
        // Child process: write to allocated memory to trigger COW
        char *mem = sbrk(PGSIZE);
        if (mem == (char *)-1) {
            printf("sbrk failed\n");
            return;
        }
        // Write to the memory to trigger COW
        mem[0] = 'A';
        printf("Child wrote to memory\n");
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}

int main(void) {
    //total_fault_count = 0;
    //cow_fault_count = 0;
    // Run the read-only test
    readonly_test();

    // Run the write test
    write_test();

    // Retrieve and print the fault counts using the new system call
    get_fault_counts();

    return 0;
}
