#include "pipe.h"
#include "activities.h"
#include "signals.h"

int tokenize_by_pipe(char *command, char **commands)
{
  int num_commands = 0;
  char *token = strtok(command, "|");

  while (token != NULL && num_commands < MAX_ARGS - 1)
  {
    commands[num_commands++] = token;
    token = strtok(NULL, "|");
  }
  commands[num_commands] = NULL;
  return num_commands;
}

void strip_quotes(char *str)
{
  char *dst = str;
  char *src = str;

  while (*src)
  {
    if (*src != '"')
    {
      *dst++ = *src;
    }
    src++;
  }
  *dst = '\0';
}

int contains_pipe(char *command)
{
  return strchr(command, '|') != NULL;
}

void handle_pipeline(char *command, int background_flag)
{
  char *commands[MAX_ARGS];
  int num_commands = tokenize_by_pipe(command, commands);
  /* for (int i = 0; i < num_commands; i++)
  {
    printf("%s ", commands[i]);
  }
 */
  int pipefds[2];
  int prev_fd = -1;
  pid_t pid;

  for (int i = 0; i < num_commands; ++i)
  {
    pipe(pipefds);
    pid = fork();

    if (pid == 0)
    {
      if (prev_fd != -1)
      {
        dup2(prev_fd, STDIN_FILENO); // Get input from the previous pipe
        close(prev_fd);
      }

      if (i != num_commands - 1)
      {
        dup2(pipefds[1], STDOUT_FILENO); // Send output to the next pipe
      }
      close(pipefds[0]);
      close(pipefds[1]);

      char *args[MAX_ARGS];
      // char *input_file = NULL;
      // char *output_file = NULL;
      // int append_mode = 0;

      int has_redirection = contains_io_redirection(commands[i]);
      if (has_redirection)
      {
        io_redirection_setup(commands[i], args, background_flag);
      }
      else
      {
        parse_command(commands[i], args);
      }

      for (int j = 0; args[j] != NULL; j++)
      {
        strip_quotes(args[j]);
      }

      if (is_not_bash_command(args[0]))
      {
        // execute_user_command_pipe(args);
        char *command_string = malloc(sizeof(char) * MAX_CMD);
        concatenate_command(args, command_string);
        user_command_select(command_string);
      }
      else
      {
        execvp(args[0], args); // System command
        perror("Error executing command");
        exit(EXIT_FAILURE);
      }
    }
    else if (pid > 0)
    {
      wait(NULL);
      close(pipefds[1]);
      prev_fd = pipefds[0]; // Save the read-end for next command
    }
    else
    {
      perror("Fork failed");
    }
  }
}

void execute_user_command_pipe(char **args)
{
  if (strncmp(args[0], "hop", 3) == 0)
  {
    execute_hop(args[0], prev_dir);
  }
  else if (strncmp(args[0], "reveal", 6) == 0)
  {
    reveal_execute(args[0]);
  }
  else if (strncmp(args[0], "log", 3) == 0)
  {
    parse_log_command(args[0]);
  }
  else if (strncmp(args[0], "proclore", 8) == 0)
  {
    execute_proclore(args[0]);
  }
  else if (strncmp(args[0], "seek", 4) == 0)
  {
    parse_seek(args[0]);
  }
  else if (strncmp(args[0], "activities", 10) == 0)
  {
    list_activities();
  }
  else if (strncmp(args[0], "ping", 4) == 0)
  {
    execute_ping(args[0]);
  }
  else
  {
    fprintf(stderr, "ERROR: '%s' is not a recognized user command\n", args[0]);
    return;
  }
}