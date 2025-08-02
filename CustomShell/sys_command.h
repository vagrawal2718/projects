#ifndef SYS_COMMAND_H
#define SYS_COMMAND_H

#include "shell.h"

void execute_sys_command(char* tokenized_command, int background_flag);
void check_bg_stat();
#endif 
