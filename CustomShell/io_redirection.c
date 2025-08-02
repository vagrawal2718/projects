#include "io_redirection.h"
#include "signals.h"

int contains_io_redirection(char *command)
{
  if (strstr(command, "<") != NULL || strstr(command, ">") != NULL || strstr(command, ">>") != NULL)
  {
    return 1;
  }
  return 0;
}

void io_redirection_setup(char *command, char **args_redirection, int background_flag)
{
  trim(command);
  int arg_count = parse_command(command, args_redirection);

  char *input_file = NULL;
  char *output_file = NULL;
  int append_mode = 0;
  int saved_stdin = -1, saved_stdout = -1;
  // int saved_stdin, saved_stdout;

  char *clean_args[MAX_ARGS];
  int clean_arg_count = 0;
  // fprintf(stderr, "This is begin of while loop with arg_count = %d\n", arg_count);
  // fflush(stderr);
  int i = 0;

  for (i = 0; i < arg_count; i++)
  {
    // printf("%s, ", args_redirection[i]);
    // fflush(stdout);
  }
  // printf("\n");
  // fflush(stdout);

  // Parse through the args and handle the redirection symbols
  for (int i = 0; i < arg_count; i++)
  {
    // printf("This is the begin of while loop with i = %d %s %d\n", i, args_redirection[i], arg_count);
    // fflush(stdout);
    if (strcmp(args_redirection[i], "<") == 0 && (i + 1) < arg_count)
    {
      // printf("Input Redirect %d %s %s\n", i, args_redirection[i], args_redirection[i + 1]);
      // fflush(stdout);
      input_file = args_redirection[i + 1];
      // printf("input file %s\n", input_file);
      // fflush(stdout);
      i++;
    }
    else if (strcmp(args_redirection[i], ">>") == 0 && (i + 1) < arg_count)
    {
      // printf("Append Output Redirect %d %s %s\n", i, args_redirection[i], args_redirection[i + 1]);
      // fflush(stdout);
      output_file = args_redirection[i + 1];
      // printf("output file %s\n", output_file);
      // fflush(stdout);
      append_mode = 1;
      i++;
    }
    else if (strcmp(args_redirection[i], ">") == 0 && (i + 1) < arg_count)
    {
      // printf("Trunc Output Redirect %d %s %s\n", i, args_redirection[i], args_redirection[i + 1]);
      // fflush(stdout);
      output_file = args_redirection[i + 1];
      // printf("output file %s\n", output_file);
      // fflush(stdout);
      append_mode = 0;
      i++; // Skip next token (filename)
    }
    else if (args_redirection[i][0] == '"') // Handle quoted arguments
    {
      char *quoted_arg = malloc(strlen(args_redirection[i]) + 1);
      strcpy(quoted_arg, args_redirection[i]);

      // Remove opening quote
      memmove(quoted_arg, quoted_arg + 1, strlen(quoted_arg));

      // Check if the closing quote is in the same argument
      char *end_quote = strrchr(quoted_arg, '"');
      if (end_quote != NULL)
      {
        *end_quote = '\0'; // Remove the closing quote
      }
      else
      {
        // If no closing quote in this argument, continue to next arguments
        while ((i + 1) < arg_count && (end_quote = strrchr(args_redirection[i + 1], '"')) == NULL)
        {
          quoted_arg = realloc(quoted_arg, strlen(quoted_arg) + strlen(args_redirection[i + 1]) + 2);
          strcat(quoted_arg, " ");
          strcat(quoted_arg, args_redirection[++i]);
        }

        // Handle the last part with closing quote
        if ((i + 1) < arg_count)
        {
          i++; // Move to the argument with closing quote
          char *last_part = args_redirection[i];
          end_quote = strrchr(last_part, '"');
          if (end_quote != NULL)
          {
            *end_quote = '\0'; // Remove the closing quote
            quoted_arg = realloc(quoted_arg, strlen(quoted_arg) + strlen(last_part) + 2);
            strcat(quoted_arg, " ");
            strcat(quoted_arg, last_part);
          }
          else
          {
            printf("Mismatched quotes!\n");
            free(quoted_arg);
            return;
          }
        }
        else
        {
          printf("Mismatched quotes!\n");
          free(quoted_arg);
          return;
        }
      }

      clean_args[clean_arg_count++] = quoted_arg;
    }
    else
    {
      clean_args[clean_arg_count] = args_redirection[i];
      clean_arg_count++;
      // printf("Regular Command and Its Options %d %s\n", i, args_redirection[i]);
      // fflush(stdout);
      //  i++;
      //   Command that can be passed to execvp without redirection symbols and corresponding file names, which we need to address ourselves.
    }
    if (i < arg_count)
    {
      // printf("Good This is the end of while loop with i = %d %s %d\n", i, args_redirection[i], clean_arg_count);
      // fflush(stdout);
    }
    else
    {
      // printf("Bad This is the end of while loop with i = %d we are outside array %d\n", i, clean_arg_count);
      // fflush(stdout);
    }
  }

  // printf("I am out of the while loop\n");
  // fflush(stdout);

  clean_args[clean_arg_count] = NULL;
  for (int i = 0; i < clean_arg_count; i++)
  {
    //printf("%s\n", clean_args[i]);
    // fflush(stdout);
  }

  // printf("I will try to open a file for reading %s %s", input_file, output_file);
  // fflush(stdout);
  //  exit(0);
  if (input_file != NULL)
  {
    // printf("I will try to open a file for reading %s", input_file);
    // fflush(stdout);
    char *full_input_path = construct_full_path(input_file);
    // printf("I will try to open a file for reading %s", full_input_path);
    // fflush(stdout);

    int fdi = open(full_input_path, O_RDONLY);
    // free(full_input_path);
    if (fdi < 0)
    {
      perror("No such input file found!");
      return;
      // exit(0);
    }
    saved_stdin = dup(STDIN_FILENO);
    // printf("stdin where redirecting\n");
    if (dup2(fdi, STDIN_FILENO) < 0)
    {
      perror("Failed to redirect input");
      close(fdi);
      return;
    }
    close(fdi);
    /// printf("I was able to open a file for reading\n");
  }

  if (output_file != NULL)
  {
    // printf("I will try to open a file for writing %s\n", output_file);
    // fflush(stdout);
    char *full_output_path = construct_full_path(output_file);
    // printf("I will try to open a file for writing %s\n", full_output_path);
    /// fflush(stdout);
    int fdo;
    if (append_mode == 0)
    {
      fdo = open(full_output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    }
    else
    {
      fdo = open(full_output_path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    }
    // free(full_output_path);

    if (fdo < 0)
    {
      perror("Failed to open output file");
      return;
    }
    saved_stdout = dup(STDOUT_FILENO);
    // printf("stdout where redirecting\n");
    if (dup2(fdo, STDOUT_FILENO) < 0)
    {
      perror("Failed to redirect output");
      close(fdo);
      return;
    }
    close(fdo);
    // printf("I was able to open a file for writing\n");
    // fflush(stdout);
  }

  int is_not_bash_cmd = is_not_bash_command(clean_args[0]);
  char * command_string = malloc(sizeof(char)*MAX_CMD);
  concatenate_command(clean_args, command_string);
  //printf("After concat cleaned command string in redirect: %s\n", command_string);


  if (is_not_bash_cmd)
  {
    user_command_select(command_string);
  }
  else
  {
    execute_sys_command(command_string, background_flag);
    /*
    pid_t pid = fork();

    if (pid < 0)
    {
      perror("Error in fork");
      return;
    }
    else if (pid == 0)
    {

      execvp(clean_args[0], clean_args);
      perror("Error executing system command");
      exit(1);
    }
    else if (pid > 0)
    {
      if (background_flag == 0)
      {
        waitpid(pid, NULL, 0);
      }
      else
      {
        // Background process: Print info and do not wait
        printf("[Background] Process running with PID %d\n", pid);
      }
    }
    */
  }

  if (saved_stdin != -1)
  {
    dup2(saved_stdin, STDIN_FILENO);
    close(saved_stdin);
    saved_stdin = -1;
    // printf("stdin at end\n");
  }
  if (saved_stdout != -1)
  {
    dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdout);
    saved_stdout = -1;
    // printf("stdout at end\n");
  }

  // fprintf(stderr, "Command execution completed\n");
  return;
}

void execute_ioredirection()
{
  
}