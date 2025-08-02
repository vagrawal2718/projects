#ifndef SEEK_H
#define SEEK_H

#define KBLU "\x1B[34m"
#define KNRM "\x1B[0m"
#define KGRN "\x1B[32m"

#include "shell.h"

typedef struct
{
  char path[MAX_PATH];
  int is_directory;
  int is_file;
  int is_executable;
} file_info;

void parse_seek(char *seek_command);
void print_colored(const char *path, int is_dir);
void search_target(char *target_name, char *current_path, int look_dir, int look_file, int exec_flag, int *match_count);
void execute_or_display_file(file_info *file_info);
#endif