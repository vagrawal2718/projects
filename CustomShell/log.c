#include "log.h"
#include "helper.h"

void log_display()
{
  FILE *file = fopen("log_file.txt", "r");
  if (!file)
  {
    printf("Log file not found\n");
    return;
  }
  char buffer[MAX_BUFFER];
  int i = 1;
  while (fgets(buffer, sizeof(buffer), file) != NULL)
  {
    trim(buffer);
    if (strlen(buffer) > 0)
    {
      printf("%d %s\n", i, buffer);
      i++;
    }
  }
  fclose(file);
}

void execute_log_file_command(char *command, int background_check)
{
  execute_wrapper(command, background_check);
}

// Execute command as per index in command
void log_execute(int index)
{
  char *file_line_buffer;
  file_line_buffer = malloc(MAX_CMD * sizeof(char));
  if (!file_line_buffer)
  {
    printf("Memory allocation failed\n");
    return;
  }

  FILE *file = fopen("log_file.txt", "r");
  if (!file)
  {
    return;
  }
  int num_cmd_in_file = 0;
  while (fgets(file_line_buffer, MAX_CMD, file) != NULL)
  {
    num_cmd_in_file++;
  }
  //printf("Total commands in log file: %d\n", num_cmd_in_file);

  if (index < 1 || index > num_cmd_in_file)
  {
    printf("log: Invalid log index\n");
    fclose(file);
    free(file_line_buffer);
    return;
  }

  int curr_line_num = 0;
  int target_line_num = num_cmd_in_file - index + 1;
  //printf("Target line number to execute: %d\n", target_line_num);

  // fseek(file, 0, SEEK_SET);
  rewind(file);

  while (fgets(file_line_buffer, MAX_CMD, file) != NULL)
  {
    //printf("Reading cmd # %d i.e. %s need cmd # %d\n", curr_line_num + 1, file_line_buffer, target_line_num);

    // int index_of_recent_cmd = 0;
    if (curr_line_num + 1 == target_line_num)
    {
      //printf("I am here because current line number matches target line\n");
      file_line_buffer[strcspn(file_line_buffer, "\n")] = '\0';
      trim(file_line_buffer);

      char **commands_list = malloc(MAX_CNT_CMD * sizeof(char *));
      for (int i = 0; i < MAX_CNT_CMD; i++)
      {
        commands_list[i] = malloc(MAX_CMD * sizeof(char));
      } // memory allocation only for commands list in one line

      int command_count = 0;
      int background_check[MAX_CNT_CMD] = {0};
      tokenize_input(file_line_buffer, commands_list, &command_count, background_check);
      //printf("Command count from tokenization is %d\n", command_count);

      for (int i = 0; i < command_count; i++)
      {
        //printf("This is the command matched from the file %s\n", commands_list[i]);
      }

      //printf("# of commands in one line of the file %d\n", command_count);
      for (int i = 0; i < command_count; i++)
      {
        execute_log_file_command(commands_list[i], background_check[i]);
      }
      fclose(file);
      return;
    }
    curr_line_num++;
  }
}

void parse_log_command(char *any_command_string)
{
  char *log_args[MAX_ARGS];
  int num_args = 0;
  // printf("Any Command String %s\n", any_command_string);
  if (any_command_string != NULL)
  {
    num_args = parse_command(any_command_string, log_args);
  }

  // printf("Number of arguments in log command %d\n", num_args);

  if ((strcmp(log_args[0], "log") == 0))
  {
    if (num_args == 1)
    {
      log_display();
    }
    else if (num_args == 2 && strcmp(log_args[1], "purge") == 0)
    {
      log_purge();
    }
    else if (num_args == 3 && strcmp(log_args[1], "execute") == 0)
    {
      int index = atoi(log_args[2]);

      if (index > 0)
      {
        log_execute(index);
      }
      else
      {
        fprintf(stderr, "log: Invalid log index\n");
      }
    }
    else
    {
      fprintf(stderr, "log: Invalid log argument\n");
    }
  }
  else
  {
    store_command(any_command_string);
  }
}

void store_command(char *user_input_string)
{
  // printf("user_input_string %s\n", user_input_string);
  if (strstr(user_input_string, "log") != NULL)
  {
    return;
  }
  int fd = open("log_file.txt", O_RDWR | O_CREAT, 0644);
  if (fd == -1)
  {
    printf("log: Error creating/opening log file % d\n", errno);
    return;
  }
  close(fd);

  char **buffer = malloc(MAX_FILE_CAP * sizeof(char *));
  for (int i = 0; i < MAX_FILE_CAP; i++)
  {
    buffer[i] = malloc(MAX_CMD * sizeof(char));
  }

  FILE *file;
  if ((file = fopen("log_file.txt", "r")) == NULL)
  {
    printf("log: Error reading log file % d\n", errno);
    return;
  }

  int num_lines = 0;
  while (num_lines <= MAX_FILE_CAP && fgets(buffer[num_lines], MAX_CMD, file) != NULL)
  {
    trim(buffer[num_lines]);
    num_lines++;
  }
  fclose(file);
  if (num_lines > 0 && strcmp(buffer[num_lines - 1], user_input_string) == 0)
  {
    for (int i = 0; i < MAX_FILE_CAP; i++)
    {
      free(buffer[i]);
    }
    free(buffer);
    return;
  }

  if (strlen(user_input_string) > 0) // We will only add commands which have something in them, we will skip empty strings
  {
    trim(user_input_string);
    if (num_lines == MAX_FILE_CAP)
    {
      for (int i = 1; i < MAX_FILE_CAP; i++)
      {
        strcpy(buffer[i - 1], buffer[i]);
      }
      strcpy(buffer[MAX_FILE_CAP - 1], user_input_string);
    }
    else
    {
      strcpy(buffer[num_lines], user_input_string);
      num_lines++;
    }
  }

  if ((file = fopen("log_file.txt", "w")) == NULL)
  {
    printf("log: Error opening log file for writing %d\n", errno);
    return;
  }
  for (int i = 0; i < num_lines; i++)
  {
    fprintf(file, "%s\n", buffer[i]);
  }

  fclose(file);
  for (int i = 0; i < MAX_FILE_CAP; i++)
  {
    free(buffer[i]);
  }
  free(buffer);
}

void log_purge()
{
  int fd = open("log_file.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd == -1)
  {
    printf("log: Error creating/opening log file % d\n", errno);
    return;
  }
  close(fd);
}
