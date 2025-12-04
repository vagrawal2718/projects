#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/memlayout.h"
#include <stdint.h>

#define PGSIZE 4096
#define NUM_PAGES 10

/*void readonly_test() {
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
        //return;
        exit(0);
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}*/

void readonly_test() {
    printf("Running Read-Only Test\n");

    // Allocate and initialize all pages in the parent
    for (int i = 0; i < NUM_PAGES; i++) {
        char *mem = sbrk(PGSIZE);
        if (mem == (char *)-1) {
            printf("sbrk failed\n");
            return;
        }
        mem[0] = 0; // Initialize memory to ensure it's fully mapped
    }

    int pid = fork();
    if (pid < 0) {
        printf("Fork failed\n");
        return;
    } else if (pid == 0) {
        // Child process: read from multiple pages of allocated memory without modifying
        for (int i = 0; i < NUM_PAGES; i++) {
            char *mem = (char *)((uintptr_t)sbrk(0) - PGSIZE * (NUM_PAGES - i)); // Access previously allocated memory
            volatile char value = mem[0]; // Read the memory to ensure no COW is triggered
            printf("Child read value from page %d: %d\n", i, value);
        }
        exit(0);
    } else {
        wait((int *)0); // Parent process waits for child completion
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
            printf("Child wrote to memory on page %d mem[0] %d\n", i, mem[0]);
        }
        //return;
        exit(0);
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
        //return;
        exit(0);
    } else {
        // Parent process: wait for the child to complete
        wait((int *)0);
    }
}

int main(void) {
    int cow_fault_count_initial = 0;
    int cow_fault_count_read = 0;
    int cow_fault_count_write = 0;
    int cow_fault_count_mixed = 0;

    int total_fault_count_initial = 0;
    int total_fault_count_read = 0;
    int total_fault_count_write = 0;
    int total_fault_count_mixed = 0;

    cow_fault_count_initial = get_fault_counts();
    total_fault_count_initial = get_total_fault_counts();
  
    printf("Before: Cow Fault Count for Initial: %d Read: %d; Write: %d, Mixed: %d\n", cow_fault_count_initial, cow_fault_count_read, cow_fault_count_write, cow_fault_count_mixed);
    printf("Before: Total Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", total_fault_count_initial, total_fault_count_read, total_fault_count_write, total_fault_count_mixed);

    // Run the read-only test
    readonly_test();
    // Retrieve and print the fault counts using the new system call
    cow_fault_count_read = get_fault_counts()-cow_fault_count_initial;
    total_fault_count_read = get_total_fault_counts()-total_fault_count_initial;
    if (cow_fault_count_read < 0) {
        printf("Failed to get fault counts\n");
    }
    // Run the write test
    write_test();
    // Retrieve and print the fault counts using the new system call
    cow_fault_count_write = get_fault_counts()-cow_fault_count_read-cow_fault_count_initial;
    total_fault_count_write = get_total_fault_counts()-total_fault_count_read-total_fault_count_initial;
    if (cow_fault_count_write < 0) {
        printf("Failed to get fault counts\n");
    }

    // Run the mixed read/write test
    mixed_test();
    cow_fault_count_mixed = get_fault_counts()-cow_fault_count_read-cow_fault_count_write-cow_fault_count_initial;
    total_fault_count_mixed = get_total_fault_counts()-total_fault_count_write-total_fault_count_read-total_fault_count_initial;
    // Retrieve and print the fault counts using the new system call
    if (cow_fault_count_mixed < 0) {
        printf("Failed to get fault counts\n");
    }

    printf("After: Cow Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", cow_fault_count_initial, cow_fault_count_read, cow_fault_count_write, cow_fault_count_mixed);
    printf("After: Total Fault Count for Initial %d, Read: %d; Write: %d, Mixed: %d\n", total_fault_count_initial, total_fault_count_read, total_fault_count_write, total_fault_count_mixed);

    return 0;
}
