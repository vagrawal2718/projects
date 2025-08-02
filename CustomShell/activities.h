#ifndef ACTIVITIES_H
#define ACTIVITIES_H

#include "shell.h"

typedef struct process_info
{
  pid_t pid;
  char command[MAX_CMD];
  int status; // 1 for running, 0 for stopped
  struct process_info *next;
} process_info;

extern process_info *process_list;

void add_process(pid_t pid, const char *command);
void update_process_state(pid_t pid, int status);
void update_all_processes_status();
void remove_process(pid_t pid);
void list_activities();
void free_process_list();
int process_exists(pid_t pid);
process_info *find_process_by_pid(pid_t pid);

#endif
