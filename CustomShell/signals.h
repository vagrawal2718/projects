#ifndef SIGNALS_H
#define SIGNALS_H

#include "shell.h"

extern pid_t foreground_pid;

void setup_signal_handlers();
void signal_handler(int sig);
void send_signal(pid_t pid, int sig);
void execute_ping(char *command_string);

#endif 
