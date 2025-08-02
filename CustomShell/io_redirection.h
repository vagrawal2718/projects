#ifndef IO_REDIRECTION_H
#define IO_REDIRECTION_H

#include "shell.h"
#include "helper.h"
#include "hop.h"
#include "sys_command.h"
#include "reveal.h"
#include "log.h"
#include "proclore.h"
#include "activities.h"

int contains_io_redirection(char *command);
void io_redirection_setup(char *command, char **args_redirection, int background_flag);

#endif