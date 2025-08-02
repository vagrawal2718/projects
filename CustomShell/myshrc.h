//INCLOMPLETE
#ifndef MYSHRC_H
#define MYSHRC_H

#include "shell.h"

#define MAX_NUM_ALIAS 50
#define MAX_NUM_FUNC 50
#define MAX_CMD_IN_FUNC 10

typedef struct alias
{
  char alias_name[MAX_CMD];
  char *command[MAX_CMD];
} alias_t;

typedef struct func
{
  char func_name[MAX_CMD];
  char **command[MAX_CMD];
} func_t;

extern alias_t aliases[MAX_NUM_ALIAS]; 
extern func_t funcs[MAX_NUM_FUNC];     
extern char* replacement[MAX_CMD];

void load_myshrc(char* home_path);
int is_alias_or_func(char *user_command, char *first_word,  int *is_func);

#endif