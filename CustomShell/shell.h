#ifndef SHELL_H
#define SHELL_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <pwd.h>
#include <sys/types.h>
#include <errno.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <termios.h>
#include <time.h>
#include <stdbool.h>
#include <signal.h>
#include <ctype.h>
#include <dirent.h>
#include <libgen.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <netdb.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <regex.h>

#define MAX_BUFFER 102400     // INput buffer that reads the complete line
#define MAX_PATH 4096         // Max len of file path
#define MAX_CNT_CMD 100       // Maximum number of commands in a single line separated by ;
#define MAX_CMD 1024          // Length of single command
#define MAX_ARGS 100          // Maximum number of args/options you can have in a command
#define MAX_DIR_ENTRIES 1000  // Max #
#define MAX_FILE_NAME 256     // Maximum lenght of file name
#define MAX_FILE_CAP 15       // Maximum number of lines in the file
#define MAX_BG_PROCESSES 4096 // Maximum number off background processes theat can be stored in thhe array
#define MAX_COMMANDS 20       //Max # of user defined commands 
#define HOST "man.he.net"
#define PORT "80"
extern char *my_commands[MAX_COMMANDS];
extern int num_commands;

typedef struct
{
  pid_t pid;
  char command[MAX_CMD];
} bg_info;

// Global
extern char home_dir[MAX_PATH];
extern char **prev_dir;
extern bg_info bg_processes[MAX_BG_PROCESSES];
extern int num_bg_process;
extern pid_t fg_pid;

void sigint_handler(int signum);
void sigtstp_handler(int signum);
void setup_signal_handlers();
void display_prompt(char *username, char *system_name, char *home_dir);
void tokenize_input(char *input_buffer, char **commands_list, int *command_count, int *background_check);
void execute_wrapper(char *command, int background_flag);
int is_not_bash_command(char *command);

#endif