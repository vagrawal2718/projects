#include "activities.h"
#include <sys/wait.h>

process_info *process_list = NULL;

void add_process(pid_t pid, const char *command)
{
  process_info *new_process = (process_info *)malloc(sizeof(process_info));
  if (!new_process)
  {
    perror("ERROR: Failed to allocate memory for process info");
    return;
  }
  new_process->pid = pid;
  strncpy(new_process->command, command, MAX_CMD - 1);
  new_process->command[MAX_CMD - 1] = '\0';

  new_process->status = 1;
  new_process->next = NULL;

  // Sort
  if (!process_list || strcmp(new_process->command, process_list->command) < 0)
  {
    new_process->next = process_list;
    process_list = new_process;
  }
  else
  {
    process_info *current = process_list;
    while (current->next && strcmp(new_process->command, current->next->command) > 0)
    {
      current = current->next;
    }
    new_process->next = current->next;
    current->next = new_process;
  }
}

void update_process_state(pid_t pid, int status)
{
  process_info *current = process_list;
  while (current)
  {
    if (current->pid == pid)
    {
      current->status = status;
      return;
    }
    current = current->next;
  }
}

void update_all_processes_status()
{
  process_info *current = process_list;
  while (current)
  {
    int status;
    pid_t result = waitpid(current->pid, &status, WNOHANG | WUNTRACED | WCONTINUED);

    if (result == 0)
    {
      current->status = 1; // Process is still running
    }
    else if (result == -1)
    {
      // current->status = 0; // Error or process exited, mark as "Stopped"
      if (errno == ECHILD)
      {
        // No such child, likely because it has been reaped
        current->status = 0; // Mark as stopped
      }
      else
      {
        perror("waitpid");
      }
    }
    else
    {
      if (WIFEXITED(status) || WIFSIGNALED(status))
      {
        current->status = 0; // Process has terminated or been killed, mark as "Stopped"
      }
      else if (WIFSTOPPED(status))
      {
        current->status = 0; // Process is stopped
      }
      else if (WIFCONTINUED(status))
      {
        current->status = 1; // Process has resumed, mark as "Running"
      }
    }

    current = current->next;
  }
}

/*void update_all_processes_status()
{
  process_info *current = process_list;
  process_info *prev = NULL;

  // Traverse the process list
  while (current)
  {
    pid_t pid = current->pid;

    // Use kill(pid, 0) to check if the process exists
    if (kill(pid, 0) == -1)
    {
      if (errno == ESRCH)
      {
        // Process does not exist anymore
        // Remove it from the process list
        process_info *to_remove = current;
        if (prev == NULL)
        {
          process_list = current->next;
        }
        else
        {
          prev->next = current->next;
        }
        current = current->next;
        free(to_remove);
        continue; // Skip to the next iteration
      }
      else
      {
        // Some other error
        perror("kill");
      }
    }
    else
    {
      // Process exists
      // Assuming it's running
      current->status = 1;
    }

    prev = current;
    current = current->next;
  }
}*/

void remove_process(pid_t pid)
{
  process_info *current = process_list;
  process_info *prev = NULL;

  while (current)
  {
    if (current->pid == pid)
    {
      if (prev)
      {
        prev->next = current->next;
      }
      else
      {
        process_list = current->next;
      }
      free(current);
      return;
    }
    prev = current;
    current = current->next;
  }
}

void list_activities()
{
  update_all_processes_status(); // Update process statuses

  if (!process_list)
  {
    printf("No activities to display.\n");
    return;
  }

  process_info *current = process_list;
  while (current)
  {
    printf("[%d] : %s - %s\n", current->pid, current->command, current->status ? "Running" : "Stopped");
    current = current->next;
  }
}
void free_process_list()
{
  process_info *current = process_list;
  while (current)
  {
    process_info *temp = current;
    current = current->next;
    free(temp);
  }
  process_list = NULL;
}

int process_exists(pid_t pid)
{
  process_info *current = process_list;
  while (current)
  {
    //printf("Debug: Checking if PID %d matches process list PID: %d\n", pid, current->pid);
    if (current->pid == pid)
    {
      //printf("Debug: Process with PID %d found in the process list\n", pid);
      return 1; // Process exists
    }
    current = current->next;
  }
  //printf("Debug: Process with PID %d not found in the process list\n", pid);
  return 0; // Process not found
}
