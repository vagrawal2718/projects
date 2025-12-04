#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[])
{
  char *syscall_names[] = {
      "zero", "fork", "exit", "wait", "pipe", "read",
      "kill", "exec", "fstat", "chdir", "dup",
      "getpid", "sbrk", "sleep", "uptime", "open",
      "write", "mknod", "unlink", "link", "mkdir",
      "close", "waitx", "getSysCount"};
  int syscall_num = 0;
  int count = 0;
  if (argc < 3)
  {
    fprintf(2, "Usage: syscount <mask> command [args]\n");
    exit(1);
  }

  int mask = atoi(argv[1]);
  int original_mask = mask;

  int parent_pid = getpid();
  printf("Parent PID is %d\n", parent_pid);

  int pid = fork();

  if (pid < 0)
  {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0)
  {
    // Child process
    printf("Child PID is %d\n", getpid());
    exec(argv[2], &argv[2]);
    fprintf(2, "exec failed\n");
    exit(1);
  }
  else
  {
    // Parent process
    wait(0);

    // Calculate syscall number based on mask
    mask = original_mask;
    while (mask > 1)
    {
      mask >>= 1;
      syscall_num++;
    }

    count = getSysCount(syscall_num, pid);
    int count_parent = getSysCount(syscall_num, parent_pid);
    if(count >= 0) {
      printf("PID %d called %s %d times\n", pid, syscall_names[syscall_num], count);
    } 
    else 
    {
      printf("Failed to get syscall count for PID %d\n", pid);
    }
    if(count_parent >= 0) {
      printf("Parent PID %d called %s %d times\n", parent_pid, syscall_names[syscall_num], count_parent);
    } 
    else 
    {
      printf("Failed to get syscall count for Parent PID %d\n", pid);
    }
  }

  exit(0);
}