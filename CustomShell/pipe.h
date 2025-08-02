#ifndef PIPE_H
#define PIPE_H

#include "io_redirection.h"
#include"helper.h"
#include"shell.h"
#include "activities.h"

void handle_pipeline(char *command, int background_flag);
void execute_user_command_pipe(char **args);
int contains_pipe(char *command);
int tokenize_by_pipe(char *command, char **commands);
void strip_quotes(char *str);

#endif
