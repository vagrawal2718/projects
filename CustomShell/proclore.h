#ifndef PROCLORE_H
#define PROCLORE_H

#include "shell.h"

void execute_proclore(char * command_string);
int is_background_process(pid_t pid);
#endif
