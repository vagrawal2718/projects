#include "helper.h"

void trim(char *token)
{
  char *first_char = token;
  while (*first_char && isspace((unsigned char)*first_char))
  {
    first_char++;
  }
  char *last_char_pos = token + strlen(token) - 1;
  while (last_char_pos > token && (isspace((unsigned char)*last_char_pos)))
  {
    last_char_pos--;
  }
  *(last_char_pos + 1) = '\0';
  if (first_char != token)
  {
    memmove(token, first_char, last_char_pos - token + 2); // +2 to include the null terminator
  }
}

void tokenize_input(char *input_buffer, char **commands_list, int *command_count, int *background_check)
{
  char *token = strtok(input_buffer, ";");
  *command_count = 0;
  while (token != NULL && *command_count < MAX_CNT_CMD)
  {
    char *token_copy = strdup(token);
    trim(token_copy);
    char *pos = strchr(token_copy, '&');
    // printf("%s\n", token_copy);
    if (pos != NULL && strcmp(pos, &token_copy[strlen(token_copy) - 1]) == 0)
    {
      *pos = '\0';
      background_check[*command_count] = 1;
    }
    else
    {
      background_check[*command_count] = 0;
    }
    strncpy(commands_list[*command_count], token_copy, MAX_CMD - 1);
    commands_list[*command_count][MAX_CMD - 1] = '\0';
    // printf("Command %d: %s\n", *command_count, commands_list[*command_count]);
    // printf("Background Check %d: %d\n", *command_count, background_check[*command_count]);
    (*command_count)++;
    token = strtok(NULL, ";");
  }
}

int is_not_bash_command(char *command)
{
  trim(command);
  int cmd_length = strcspn(command, " ");

  for (int i = 0; i < num_commands; i++)
  {
    if (strncmp(command, my_commands[i], cmd_length) == 0)
    {
      return 1;
    }
  }
  return 0;
}

int parse_command(char *command, char **args)
{
  int arg_num = 0;
  char *token = strtok(command, " ");

  while (token != NULL && arg_num < MAX_ARGS - 1)
  {
    trim(token);
    args[arg_num] = token;
    token = strtok(NULL, " ");
    arg_num++;
  }
  args[arg_num] = NULL;
  return arg_num;
}

void execute_system_command(char **args)
{
  if (execvp(args[0], args) == -1)
  {
    perror("Error executing command");
  }
} //extra

void user_command_select(char *command_string) // This function takes the parsed args from a command parse
{
  trim(command_string);
  // printf("user_command_select trimmed command: $$%s$$\n", command_string);
  if ((strncmp(command_string, "fg", 2) == 0) || (strncmp(command_string, "bg", 2) == 0))
  {
    // printf("Why am I here even though the command is: $$%s$$\n", command_string);
  }
  // printf("Command on Execute Inside user command select function: $$ %s $$\n", command_string);
  if ((strncmp(command_string, "hop", 3) == 0) || (strncmp(command_string, "cd", 2) == 0))
  {
    // printf("Command on Execute: %s\n", command_string);
    execute_hop(command_string, prev_dir);
  }
  else if (strncmp(command_string, "reveal", 6) == 0)
  {
    reveal_execute(command_string);
  }
  else if (strncmp(command_string, "log", 3) == 0)
  {
    parse_log_command(command_string);
  }
  else if (strncmp(command_string, "proclore", 8) == 0)
  {
    execute_proclore(command_string);
  }
  else if (strncmp(command_string, "seek", 4) == 0)
  {
    parse_seek(command_string);
  }
  else if (strncmp(command_string, "activities", 10) == 0)
  {
    list_activities();
  }
  else if (strncmp(command_string, "ping", 4) == 0)
  {
    execute_ping(command_string);
  }
  else if (strncmp(command_string, "fg", 2) == 0)
  {
    fg_command(command_string);
    return;
  }
  else if (strncmp(command_string, "bg", 2) == 0)
  {
    bg_command(command_string);
    return;
  }
  else if (strncmp(command_string, "iMan", 4) == 0)
  {
    execute_iman(command_string);
    return;
  }
  else
  {
    fprintf(stderr, "ERROR: '%s' is not a valid command\n", command_string);
    return;
  }
}

void concatenate_command(char **clean_args, char *command_string)
{
  command_string[0] = '\0';
  for (int i = 0; clean_args[i] != NULL; i++)
  {
    strcat(command_string, clean_args[i]);
    if (clean_args[i + 1] != NULL)
    {
      strcat(command_string, " ");
    }
  }
}

void cleanup_all_processes()
{
  process_info *current = process_list;
  while (current)
  {
    printf("Killing background process with PID %d\n", current->pid);
    kill(current->pid, SIGKILL);
    current = current->next;
  }

  free_process_list();
}
//extra