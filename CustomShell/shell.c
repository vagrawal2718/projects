#include "shell.h"
#include "helper.h"
#include "sys_command.h"
#include "hop.h"
#include "reveal.h"
#include "log.h"
#include "io_redirection.h"
#include "pipe.h"
#include "activities.h"
#include "signals.h"
#include "iMan.h"
#include <signal.h>

// pid_t fg_pid = -1;

char home_dir[MAX_PATH] = {0};
char **prev_dir = NULL;
bg_info bg_processes[MAX_BG_PROCESSES];
int num_bg_process = 0;
char *my_commands[MAX_COMMANDS] =
    {
        "hop", "reveal", "log", "proclore", "seek", "cd", "ping", "activities", "fg", "bg", "iMan"};
int num_commands = 11;

void display_prompt(char *username, char *system_name, char *home_dir)
{
  char curr_dir[MAX_PATH];
  getcwd(curr_dir, MAX_PATH);
  if (getcwd(curr_dir, MAX_PATH) == NULL)
  {
    perror("Error getting current directory");
    return;
  }

  char result_dir[MAX_PATH];
  for (int i = 0; i < MAX_PATH; i++)
  {
    result_dir[i] = '\0';
  }

  int home_len = strlen(home_dir);

  if (strncmp(curr_dir, home_dir, home_len) == 0)
  {
    if (curr_dir[home_len] == '\0')
    {
      strcpy(result_dir, "~");
    }
    else if (curr_dir[home_len] == '/')
    {
      result_dir[0] = '~';
      strcat(result_dir + 1, curr_dir + home_len);
    }
  }
  else
  {
    strcpy(result_dir, curr_dir);
  }
  printf("<%s@%s:%s> ", username, system_name, result_dir);
}

void execute_wrapper(char *command_string, int background_flag)
{
  trim(command_string);
  // printf("%s Background flag is %d in exe wrapper\n",command_string,background_flag );
  if (command_string == NULL)
  {
    return;
  }

  /* char first_word[MAX_CMD];
  sscanf(command_string, "%s", first_word); // Extract the first word
  int is_func = 0;

  //Perform necessary replacement regardless of wheter it is func or alias
  if (is_alias_or_func(command_string, first_word, &is_func))
  {
    replace_command(command_string, first_word, replacement, is_func);
    //AFTER this execution can either  be carries out in the other file or here
  }
  // ADD MORE STUFF TO ACTUALL INITIALTE EXECUTION */

  // SPEC 10 FOR PIPES, DECLARE POINTER TO ARRAY OF STRINGS
  if (contains_pipe(command_string))
  {
    handle_pipeline(command_string, background_flag);
    return;
  }

  char *args_redirection[MAX_ARGS];
  if (contains_io_redirection(command_string))
  {
    io_redirection_setup(command_string, args_redirection, background_flag); // Set up redirection
    // exit(1);
    return;
  }

  int is_not_bash_cmd = is_not_bash_command(command_string);
  // printf("Is Not Bash Command: %d\n", is_not_bash_cmd);
  // printf("Debug: Command string: %s\n", command_string);
  // printf("Debug: is_not_bash_cmd: %d\n", is_not_bash_cmd);

  if (is_not_bash_cmd)
  {
    // printf("Before user command select the command string is **%s**\n", command_string);
    user_command_select(command_string);
  }
  else
  {
    // printf("Before execute sys command the command string is **%s**\n", command_string);
    execute_sys_command(command_string, background_flag);
  }
}
int main()
{
  setup_signal_handlers();
  char *c = getcwd(home_dir, MAX_PATH);
  if (c == NULL)
  {
    perror("Error in obtaining sysname\n");
    return 1;
  }
  home_dir[MAX_PATH - 1] = '\0';

  // load_myshrc(home_dir);

  char *username;
  char system_name[MAX_PATH] = {0};
  prev_dir = malloc(sizeof(char *));
  *prev_dir = NULL;

  username = getlogin();
  if (username == NULL)
  {
    perror("Error in obtaining username");
    return 1;
  }

  int h = gethostname(system_name, MAX_PATH);
  if (h < 0)
  {
    perror("Error in obtaining sysname\n");
    return 1;
  }

  while (1)
  {
    display_prompt(username, system_name, home_dir);

    char *input_buffer;
    input_buffer = malloc(sizeof(char) * MAX_BUFFER);
    memset(input_buffer, 0, MAX_BUFFER * sizeof(char));
    if (fgets(input_buffer, MAX_BUFFER, stdin) == NULL)
    {
      printf("\n");
      free(input_buffer);
      break;
    }

    /*  if (fgets(input_buffer, MAX_BUFFER, stdin) == NULL)
     {
       printf("\nExiting shell...\n");
       cleanup_all_processes(); // Kill all background processes before exiting
       free(input_buffer);
       break;
     } */
    input_buffer[strcspn(input_buffer, "\n")] = '\0';

    store_command(input_buffer); // We use this to log anything the user enters on command line.

    // printf("Input Buffer: %s\n", input_buffer);
    char **commands_list = malloc(MAX_CNT_CMD * sizeof(char *));
    for (int i = 0; i < MAX_CNT_CMD; i++)
    {
      commands_list[i] = malloc(MAX_CMD * sizeof(char));
    }
    int command_count = 0;
    int background_check[MAX_CNT_CMD] = {0};

    tokenize_input(input_buffer, commands_list, &command_count, background_check);

    /* for (int i = 0; i < command_count; i++)
    {
      printf("Command # %d: %s (Background: %d)\n", i, commands_list[i], background_check[i]);
    } */
    for (int i = 0; i < command_count; i++)
    {
      // printf("Command Before Execute: %s\n", commands_list[i]);
      execute_wrapper(commands_list[i], background_check[i]);
    }
    for (int i = 0; i < command_count; i++)
    {
      memset(commands_list[i], 0, MAX_CMD);
      free(commands_list[i]);
    }
    free(commands_list);
    free(input_buffer);
    // memset(background_check, 0, sizeof(background_check));
  }
  process_info *current = process_list;
  while (current)
  {
    kill(current->pid, SIGKILL);
    current = current->next;
  }

  // cleanup_all_processes();
  free_process_list();
  free(prev_dir);

  check_bg_stat();
  return 0;
}