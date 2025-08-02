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
  printf("0. num_commands %d\n", num_commands);
  for (int i = 0; i < num_commands; i++)
  {
    printf("Command %d in pipe set is %s\n", i, commands[i]);
  }

  int pipefds[2];
  int prev_fd = -1;
  pid_t pid;

  for (int i = 0; i < num_commands; ++i)
  {
    printf("entered for loop in handle pipeline\n");
    pipe(pipefds);
    pid = fork();
    printf("Process ID after fork in for loop %d\n", pid);

    if (pid == 0)
    {
      if (prev_fd != -1)
      {
        dup2(prev_fd, STDIN_FILENO); // Get input from the previous pipe
        printf("1. I am here pid %d prev_fd %d\n", pid, prev_fd);
        close(prev_fd);
      }
      printf("2. Trying 2: I am here pid %d pipefds[1] %d\n", pid, pipefds[1]);
      if ((i<num_commands-1)&&(i != num_commands - 1))
      {
        dup2(pipefds[1], STDOUT_FILENO); // Send output to the next pipe
        printf("2. I am here pid %d pipefds[1] %d\n", pid, pipefds[1]);
      }
      close(pipefds[0]);
      close(pipefds[1]);

      char *args[MAX_ARGS];
      // char *input_file = NULL;
      // char *output_file = NULL;
      // int append_mode = 0;

      int has_redirection = contains_io_redirection(commands[i]);
      printf("has_redirection %d commands[%d]: %s\n", has_redirection, i, commands[i]);

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
        printf("3. Stripping quotes args[%d] %s\n", j, args[j]);
      }

      char * command_string = malloc(sizeof(char)*MAX_CMD);
      concatenate_command(args, command_string);
      printf("Command String After Pipe %s\n", command_string);

      if (is_not_bash_command(args[0]))
      {
        user_command_select(command_string);
      }
      else
      {
        execute_sys_command(command_string, background_flag);
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

