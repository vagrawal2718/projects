#ifndef LOG_H
#define LOG_H

#include "shell.h"
#include "hop.h"
#include "reveal.h"
#include "proclore.h"
#include "seek.h"
#include "sys_command.h"

void parse_log_command(char *any_command_string);
void store_command(char *log_command_string);
void log_purge();
void log_display();
void execute_log_file_command(char *command, int background_check);

#endif 