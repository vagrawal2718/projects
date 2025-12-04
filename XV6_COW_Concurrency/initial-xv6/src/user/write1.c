// writetest.c
#include "kernel/types.h"
#include "user/user.h"

int main()
{
    int sz = 4096 * 10;  // Allocate 10 pages
    char *p = sbrk(sz);  // Expand the heap by 10 pages

    if (p == (char *)-1) {
        printf("sbrk failed\n");
        exit(1);
    }

    // Initial write to each page to ensure allocation in the parent
    for (int i = 0; i < sz; i += 4096) {
        p[i] = i % 256;
    }

    int pid = fork();
    if (pid == 0) {
        // Child process writes to each page, causing COW page faults
        for (int i = 0; i < sz; i += 4096) {
            p[i] = (i + 1) % 256;  // Modify each page to trigger COW
        }
        // Print COW fault count for the child, expected to be 10
        printf("Child process COW faults: %d\n", get_cow_faults());
        exit(0);
    } else {
        // Parent waits for the child to finish
        wait(0);
        // Print COW fault count for the parent, expected to be minimal or 0
        printf("Parent process COW faults: %d\n", get_cow_faults());
    }

    exit(0);
}
