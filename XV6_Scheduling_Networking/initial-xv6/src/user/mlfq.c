#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define NUM_PROCESSES 5

void io_bound(int id) {
    for (int i = 0; i < 100; i++) {
        sleep(1);  // Simulate I/O operation
        //printf("IO-bound process %d: iteration %d\n", id, i);
    }
    exit(0);
}

void cpu_bound(int id) {
    for (int i = 0; i < 10000000000; i++) {
        if (i % 1000000000 == 0) {
            //printf("Loopy Loop 100M process ID %d: iteration %d\n", id, i / 10000000);
        }
    }
    exit(0);
}

void mixed(int id) {
    for (int i = 0; i < 100; i++) {
        if (i % 2 == 0) {
            sleep(1);  // Simulate I/O operation
        } else {
            for (int j = 0; j < 5000000; j++) { asm volatile("nop"); } // Optionally use 'nop' to prevent optimization}  // CPU-intensive work

        }
        //printf("Mixed process %d: iteration %d\n", id, i);
    }
    exit(0);
}

int main(int argc, char *argv[]) {
    int pids[NUM_PROCESSES];

    for (int i = 0; i < NUM_PROCESSES; i++) {
        pids[i] = fork();
        if (pids[i] < 0) {
            printf("Fork failed\n");
            exit(1);
        } else if (pids[i] == 0) {
            // Child process
            switch (i) {
                case 0:
                case 1:
                    io_bound(i);
                    break;
                case 2:
                case 3:
                    cpu_bound(i);
                    break;
                case 4:
                    mixed(i);
                    break;
            }
        }
    }

    // Parent process
    for (int i = 0; i < NUM_PROCESSES; i++) {
        wait(0);
    }

    //printf("All processes completed\n");
    exit(0);
}