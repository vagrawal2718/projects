#ifndef HELPER_H
#define HELPER_H

#include "shell.h"
#include "sys_command.h"
#include "hop.h"
#include "reveal.h"
#include "log.h"
#include "io_redirection.h"
#include "pipe.h"
#include "activities.h"
#include "signals.h"
#include "fg_bg.h"
#include "iMan.h"

#include <signal.h>

void trim(char *token);
void tokenize_input(char *input_buffer, char **commands_list, int *command_count, int *background_check);
int is_not_bash_command(char *command);
int parse_command(char *command, char **args);
void user_command_select(char * command_string);
void concatenate_command(char **clean_args, char *command_string);
void cleanup_all_processes(); //ex
void execute_system_command(char **args); //ex

#endif 