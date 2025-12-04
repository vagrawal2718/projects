// readonly_test.c
#include "kernel/types.h"
#include "user/user.h"

/* int main()
{
    int sz = 4096 * 10;  // Allocate 10 pages
    char *p = sbrk(sz);  // Expand the heap by 10 pages

    if (p == (char *)-1) {
        printf("sbrk failed\n");
        exit(1);
    }

    // Read from each page without modifying it
    for (int i = 0; i < sz; i += 4096) {
        volatile char temp = p[i];  // Read-only access
        (void)temp;  // Suppress unused variable warning
    }

    // Print COW fault count, expected to be 0
    //printf("Read-only process COW faults: %d\n", get_cow_faults());

    exit(0);
} */

int main()
{
    printf("Before sbrk\n");
    int sz = 4096 * 10;
    char *p = sbrk(sz);
    printf("After sbrk\n");

    if (p == (char *)-1) {
        printf("sbrk failed\n");
        exit(1);
    }

    // Read from each page without modifying it
    for (int i = 0; i < sz; i += 4096) {
        printf("Reading from page %d\n", i/4096);
        volatile char temp = p[i];
        (void)temp;
    }

    exit(0);
}