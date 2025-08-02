#include "hop.h"
#include "helper.h"
char *construct_full_path(char *path)
{
  char *full_path = malloc(sizeof(char) * MAX_PATH);
  if (path[0] == '~')
  {
    strcpy(full_path, home_dir);
    strcat(full_path, path + 1);
  }
  else if (path[0] == '/')
  {
    strcpy(full_path, path);
  }
  else
  { //.. . or anything else
    getcwd(full_path, MAX_PATH);
    strcat(full_path, "/");
    strcat(full_path, path);
  }
  return full_path;
}

void execute_hop(char *full_command, char **prev_dir)
{
  char *args[MAX_ARGS];
  int arg_num = 0, i = 0;
  arg_num = parse_command(full_command, args);
  //printf("Let us parse the command %s with %d args\n", full_command,arg_num);

  /* for (int i = 0; i < arg_num; i++)
  {
    printf("%dth argument is %s\n", i, args[i]);
  } */
  if (arg_num == 0)
  {
    int home = chdir(home_dir);
    if (home != 0)
    {
      perror("hop: failed to change to home directory");
      return;
    }
    printf("%s\n", home_dir);
    if (*prev_dir != NULL)
    {
      free(*prev_dir);
    }
    *prev_dir = strdup(home_dir);
  }

  for (i = 1; i < arg_num; i++)
  {

    if (strcmp(args[i], "-") == 0)
    {
      if (*prev_dir == NULL)
      {
        perror("OLDPWD not set\n");
      }
      else
      {
        if (chdir(*prev_dir) != 0)
        {
          perror("hop: failed to change to previous directory");
          continue;
        }
        printf("%s\n", *prev_dir);
      }
    }
    else
    {
      char *absolute_path = construct_full_path(args[i]);
      int changed = chdir(absolute_path);
      if (changed == 0)
      {
        char* current_path = malloc(sizeof(char)* MAX_PATH);
        getcwd(current_path, MAX_PATH);
        printf("%s\n",current_path);
        if (*prev_dir != NULL)
        {
          free(*prev_dir);
        }
        *prev_dir = strdup(absolute_path);
      }
      else
      {
        fprintf(stderr, "hop: %s: No such file or directory\n", args[i]);
      }
      free(absolute_path);
    }
  }
}
