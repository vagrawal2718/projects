#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/memlayout.h"

#define PGSIZE 4096
#define NUM_PAGES 10

void readonly_test() {
    printf("Running Read-Only Test\n");

    int pid = fork();
    if (pid < 0) {
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
        // Child process: read from multiple pages of allocated memory without modifying
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
                printf("sbrk failed\n");
                return;
            }
            // Read the memory to ensure no COW is triggered
            volatile char value = mem[0];
            printf("Child read value from page %d: %d\n", i, value);
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
            printf("Failed to get fault counts\n");
        }
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
        // Child process: write to multiple pages of allocated memory to trigger COW
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
                printf("sbrk failed\n");
                return;
            }
            // Write to the memory to trigger COW
            mem[0] = 'A' + i;
            printf("Child wrote to memory on page %d\n", i);
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
            printf("Failed to get fault counts\n");
        }
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}

void mixed_test() {
    printf("Running Mixed Read/Write Test\n");

    int pid = fork();
    if (pid < 0) {
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
        // Child process: alternate between reading and writing to pages
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = sbrk(PGSIZE);
            if (mem == (char *)-1) {
                printf("sbrk failed\n");
                return;
            }
            if (i % 2 == 0) {
                // Read from the page
                volatile char value = mem[0];
                printf("Child read value from page %d: %d\n", i, value);
            } else {
                // Write to the page
                mem[0] = 'A' + i;
                printf("Child wrote to memory on page %d\n", i);
            }
        }
        // Retrieve and print the fault counts for this process
        if (get_fault_counts() < 0) {
            printf("Failed to get fault counts\n");
        }
        return;
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}

int main(void) {
    // Run the read-only test
    readonly_test();

    // Run the write test
    write_test();

    // Run the mixed read/write test
    mixed_test();

    return 0;
}
