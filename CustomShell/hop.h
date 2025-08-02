#ifndef HOP_H
#define HOP_H

#include "shell.h"

void execute_hop(char *full_command, char **prev_dir);
char* construct_full_path(char *path);

#endif