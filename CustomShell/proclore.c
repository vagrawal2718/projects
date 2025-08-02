#include "proclore.h"
#include "helper.h"
#include "sys_command.h"

int is_background_process(pid_t pid)
{
  for (int i = 0; i < num_bg_process; i++)
  {
    if (bg_processes[i].pid == pid)
    {
      return 1;
    }
  }
  return 0;
}

void execute_proclore(char *command_string)
{
  char *args[MAX_ARGS];
  int num_args = parse_command(command_string, args);
  pid_t pid;
  if (num_args == 2)
  {
    pid = atoi(args[1]);
    //printf("PID from user %d\n", pid);
  }
  if (!pid)
  {
    pid = getpid();
    //printf("PID from getpid %d\n", pid);
  }
  if (pid <= 0)
  {
    fprintf(stderr, "proclore: Invalid PID\n");
    return;
  }

  int background_flag = is_background_process(pid);
  //printf("is bg process %d, pid %d\n", background_flag, pid);
  char proc_status_path[MAX_PATH];
  snprintf(proc_status_path, MAX_PATH, "/proc/%d/status", pid);
  int fd = open(proc_status_path, O_RDONLY);
  if (fd == -1)
  {
    perror("Error opening process status file");
    return;
  }
  close(fd);

  FILE *file = fopen(proc_status_path, "r");
  // char stat_path[64];
  int MAX_LINE = 4096;
  char line[MAX_LINE];
  char exe_path[MAX_PATH];
  char resolved_path[MAX_PATH];
  char status = '\0';
  int virt_mem = 0;
  int pgrp = 0;
  while (fgets(line, sizeof(line), file))
  {
    if (strstr(line, "State:") == line)
    {
      sscanf(line, "State:\t%c", &status);
    }
    else if (strstr(line, "Tgid:") == line)
    {
      sscanf(line, "Tgid:\t%d", &pgrp);
    }
    else if (strstr(line, "VmSize:") == line)
    {
      sscanf(line, "VmSize:\t%d", &virt_mem);
    }
  }

  fclose(file);

  snprintf(exe_path, sizeof(exe_path), "/proc/%d/exe", pid);
  ssize_t len = readlink(exe_path, resolved_path, sizeof(exe_path) - 1);
  if (len != -1)
  {
    exe_path[len] = '\0';
  }
  else
  {
    strcpy(resolved_path, "Permission denied");
  }
  printf("pid : %d\n\n", pid);

  printf("process status : %c", status);
  // printf("background_flag %d\n", background_flag);
  if (!background_flag && (status == 'R' || status == 'S'))
  {
    printf("+");
  }
  else if (background_flag && (status == 'R' || status == 'S'))
  {
    printf(" ");
  }
  printf("\n\n");

  printf("Process Group : %d\n\n", pgrp);
  printf("Virtual memory : %d KB\n\n", virt_mem);
  printf("executable path : %s\n", resolved_path);
}