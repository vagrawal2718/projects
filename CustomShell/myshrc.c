//INCOMPLETE
#include "myshrc.h"
#include "helper.h"

void load_myshrc(char *home_path)
{
  char path[MAX_PATH];
  snprintf(path, sizeof(path), "%s/.myshrc", home_path);

  FILE *file = fopen(path, "r");
  if (!file)
  {
    return;
  }

  char file_line[MAX_BUFFER];
  int func_count = 0;
  int alias_count = 0;
  int in_func = 0;
  int func_command_index = 0;

  while (fgets(file_line, MAX_BUFFER, file))
  {
    trim(file_line);
    if (strncmp(file_line, "alias", 5) == 0)
    {
      char alias_name[MAX_CMD];
      char alias_command[MAX_CMD];
      sscanf(file_line, "alias %s = %[^\n]", alias_name, alias_command);

      trim(alias_name);
      trim(alias_command);

      if (alias_count < MAX_NUM_ALIAS)
      {
        strncpy(aliases[alias_count].alias_name, alias_name, MAX_CMD);
        aliases[alias_count].command[0] = strdup(alias_command);
        alias_count++;
      }
    }
    else if (strchr(file_line, '(') && strchr(file_line, ')'))
    {
      char func_name[MAX_CMD];
      sscanf(file_line, "%s", func_name);
      trim(func_name);

      in_func = 1;
      func_command_index = 0;

      if (func_count < MAX_NUM_FUNC)
      {
        strncpy(funcs[func_count].func_name, func_name, MAX_CMD);
      }
    }
    else if (in_func)
    {
      if (strchr(file_line, '{'))
      {
        continue;
      }
      else if (strchr(file_line, '}'))
      {
        in_func = 0;
        funcs[func_count].command[func_command_index] = NULL;
        func_count++;
      }
      else
      {
        if (func_command_index < MAX_CMD_IN_FUNC)
        {
          funcs[func_count].command[func_command_index] = strdup(file_line);
          func_command_index++;
        }
      }
    }
  }
}

int is_alias_or_func(char *user_command, char *first_word, int *is_func)
{
  for (int i = 0; i < MAX_NUM_ALIAS; i++)
  {
    if (strcmp(first_word, aliases[i].alias_name) == 0)
    {
      *is_func = 0;
      return 1;
    }
  }
  for (int i = 0; i < MAX_NUM_FUNC; i++)
  {
    if (strcmp(first_word, funcs[i].func_name) == 0)
    {
      *is_func = 1; // It is a function
      return 1;
    }
  }

  return 0;
}
void replace_command(char *command, char *first_word, char *replacement, int is_func)
{
  replacement[0] = '\0';
  if (is_func)
  {
    char *args[MAX_CMD];
    int arg_count = 0;
    arg_count = parse_command(command, args);

    for (int i = 0; i < MAX_NUM_FUNC; i++)
    {
      if (strcmp(first_word, funcs[i].func_name) == 0)
      {
        
      }
    }
  }
  else if (!is_func)
  {
  }
}