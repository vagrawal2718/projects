#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define NUM_PROCESSES 5

// Function to simulate a CPU-bound process
void cpu_bound(int id) {
    //int pid = getpid();  // Get the current process ID
    for (int i = 0; i < 10000000000; i++) {
        if (i % 1000000000 == 0) {
            //printf("Loopy Loop 100M CPU Bound ID: %d, Name: %d: iteration %d\n", pid, id, i / 10000000);
        }
    }
    exit(0);
}

// Function to create processes and assign tickets
int main(int argc, char *argv[]) {
    int pids[NUM_PROCESSES];
    int tickets[NUM_PROCESSES] = {1, 2, 3, 4, 5}; // Different ticket counts

    for (int i = 0; i < NUM_PROCESSES; i++) {
        pids[i] = fork();
        if (pids[i] < 0) {
            printf("Fork failed\n");
            exit(1);
        } else if (pids[i] == 0) {
            // Child process
            settickets(tickets[i]); // Set the number of tickets for this process
            cpu_bound(i);            // Execute the CPU-bound function
        }
    }

    // Parent process
    for (int i = 0; i < NUM_PROCESSES; i++) {
        wait(0);
    }

    printf("All processes completed\n");
    exit(0);
}
