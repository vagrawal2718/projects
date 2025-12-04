#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
// #include "kernel/proc.h"

int main(int argc, char *argv[])
{
  char *syscall_names[] = {
      "zero", "fork", "exit", "wait", "pipe", "read",
      "kill", "exec", "fstat", "chdir", "dup",
      "getpid", "sbrk", "sleep", "uptime", "open",
      "write", "mknod", "unlink", "link", "mkdir",
      "close", "waitx", "getSysCount","sigalarm","sigreturn","settickets"};
  int syscall_num = 0;
  int count = 0;
  if (argc < 3)
  {
    fprintf(2, "Usage: syscount <mask> command [args]\n");
    exit(1);
  }

  int mask = atoi(argv[1]);

  // Get the current PID of the process before fork
  int parent_pid = getpid();

  int pid = fork();

  if (pid < 0)
  {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0)
  {
    // This is the child process
    // int child_pid = getpid(); // Get child PID
    // Execute the command
    exec(argv[2], &argv[2]);

    // If exec fails
    fprintf(2, "exec failed\n");
    exit(1);
  }
  else
  {
    // This is the parent process
    // Calculate syscall number based on mask
    while (mask > 1)
    {
      mask >>= 1;
      syscall_num++;
    }

    count = getSysCount(syscall_num, pid);
    // Wait for the child to complete
    wait(0);

    // Calculate syscall number based on mask
    while (mask > 1)
    {
      mask >>= 1;
      syscall_num++;
    }

    count = getSysCount(syscall_num, pid);
    printf("Parent process (PID: %d) reports: SYSID %d (%s) called %d times by child PID %d.\n", parent_pid, syscall_num, syscall_names[syscall_num], count, pid);
  }

  exit(0);
}
