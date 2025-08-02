#ifndef FG_BG_H
#define FG_BG_H

#include "activities.h"
#include"shell.h"

void fg_command(const char *command_string);
void bg_command(const char *command_string);
process_info *find_process_by_pid(pid_t pid);
pid_t extract_pid(const char *command_string);

#endif
