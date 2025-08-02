#include "fg_bg.h"

pid_t extract_pid(const char *command_string)
{
  char *command_copy = strdup(command_string);
  strtok(command_copy, " ");         // Skip the command (fg or bg)
  char *pid_str = strtok(NULL, " "); 

  pid_t pid = -1;

  if (pid_str)
  {
    pid = (pid_t)atoi(pid_str); 
  }
  else
  {
    printf("Usage: %s <pid>\n", strtok(command_copy, " "));
  }

  free(command_copy); 
  return pid;
}


process_info *find_process_by_pid(pid_t pid)
{
  process_info *current = process_list;
  while (current)
  {
    if (current->pid == pid)
    {
      return current;
    }
    current = current->next;
  }
  return NULL; // Process not found
}

void fg_command(const char *command_string)
{
  pid_t pid = extract_pid(command_string);
  if (pid == -1)
  {
    return; 
  }

  process_info *process = find_process_by_pid(pid);

  if (!process)
  {
    printf("No such process found\n");
    return;
  }

  // Bring the process to foreground
  printf("Bringing [%d] : %s to foreground\n", process->pid, process->command);

  // Give the terminal control to process
  tcsetpgrp(STDIN_FILENO, process->pid);

  // Resume 
  if (process->status == 0)
  {
    kill(process->pid, SIGCONT); // SIGCONT resume process
  }

  int status;
  
  waitpid(process->pid, &status, WUNTRACED); 
  if (WIFSTOPPED(status))
  {
    process->status = 0; // Mark as stopped
  }
  else if (WIFEXITED(status) || WIFSIGNALED(status))
  {
    remove_process(process->pid); 
  }

  tcsetpgrp(STDIN_FILENO, getpid());
}

void bg_command(const char *command_string)
{
  pid_t pid = extract_pid(command_string);
  if (pid == -1)
  {
    return; // Invalid pid, return early
  }

  process_info *process = find_process_by_pid(pid);
  if (!process)
  {
    printf("No such process found\n");
    return;
  }

  // Resume the stopped process in the background
  if (process->status == 0)
  {
    printf("Resuming [%d] : %s in background\n", process->pid, process->command);
    kill(process->pid, SIGCONT); // Send SIGCONT to resume the process
    process->status = 1;         // Mark as running
  }
  else
  {
    printf("Process [%d] is already running\n", process->pid);
  }
}

