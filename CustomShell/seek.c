#include "seek.h"
#include "helper.h"
#include "hop.h"

void execute_or_display_file(file_info *file_info)
{
  char *full_path = construct_full_path(file_info->path);
  printf("%s %s\n", full_path, file_info->path);
  fflush(stdout);
  // dprintf(STDOUT_FILENO, "%s %s\n", full_path, file_info->path);
  if (file_info->is_executable)
  {
    pid_t pid = fork();
    if (pid == 0)
    {
      execl(full_path, file_info->path, NULL);
      perror("seek: error in file execution");
      exit(EXIT_FAILURE);
    }
    else if (pid > 0)
    {
      wait(NULL);
    }
    else
    {
      perror("seek: Error in fork");
    }
  }
  else if (file_info->is_file)
  {
    FILE *file = fopen(full_path, "r");
    if (file == NULL)
    {
      printf("Missing permissions for task!\n");
      fflush(stdout);
      // dprintf(STDOUT_FILENO, "Missing permissions for task!\n");
    }
    else
    {
      char c;
      while ((c = fgetc(file)) != EOF)
      {
        putchar(c);
      }
      fclose(file);
    }
  }
  free(full_path);
}

void print_colored(const char *path, int is_dir)
{
  char buffer[MAX_PATH + 10]; 
  int len;

  if (isatty(STDOUT_FILENO))
  {
    if (is_dir)
    {
      len = snprintf(buffer, sizeof(buffer), "%s%s%s\n", KBLU, path, KNRM);
    }
    else
    {
      len = snprintf(buffer, sizeof(buffer), "%s%s%s\n", KGRN, path, KNRM);
    }
  }
  else
  {
    len = snprintf(buffer, sizeof(buffer), "%s\n", path);
  }

  write(STDOUT_FILENO, buffer, len); 
   
}

void search_target(char *target_name, char *current_path, int seek_dir, int seek_file, int exec_flag, int *match_count)
{
  // int found_file;
  // int found_dir;
  // int count = 0;
  char *full_path = malloc(MAX_PATH * (sizeof(char)));

  file_info found_info = {.path = ".", .is_directory = 0, .is_file = 0, .is_executable = 0};
  DIR *dir = opendir(current_path);

  if (!dir)
  {
    perror("seek: Error opening directory");
    return;
  }

  struct dirent *entry;

  while ((entry = readdir(dir)) != NULL)
  {
    struct stat st; // Inbuilt struct in C to get file stats
    snprintf(full_path, MAX_PATH, "%s/%s", current_path, entry->d_name);
    stat(full_path, &st);

    file_info info;
    strcpy(info.path, full_path);
    info.is_directory = S_ISDIR(st.st_mode);
    info.is_file = S_ISREG(st.st_mode);
    info.is_executable = st.st_mode & S_IXUSR;

    if (strncmp(entry->d_name, target_name, strlen(target_name)) == 0)
    {
      if (info.is_directory && seek_dir)
      {
        found_info = info;
        // found_dir = 1;
        //  count++;
        (*match_count)++;
        print_colored(info.path, 1);
      }
      if (info.is_file && seek_file)
      {
        found_info = info;
        // found_file = 1;
        //  count++;
        (*match_count)++;
        print_colored(info.path, 0);
      }
    }
    if (info.is_directory && strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0)
    {
      search_target(target_name, full_path, seek_dir, seek_file, exec_flag, match_count); // Recursive call
    }
  }
  // closedir(dir);
  // printf("I have printed  the name of the file/directory, now I will print  its content in case of a file\n");
  // printf("Exec flag %d Match count %d\n", exec_flag, *match_count);
  if (exec_flag && *match_count == 1)
  {
    // printf("Checking for exec flag in file/dir\n");
    if (found_info.is_file)
    {
      execute_or_display_file(&found_info);
    }
    else if (found_info.is_directory)
    {
      if (chdir(found_info.path) == -1)
      {
        printf("Missing permissions for task!\n");
      }
    }
  }
}

void parse_seek(char *seek_command)
{
  char *seek_args[MAX_ARGS];
  int num_args = parse_command(seek_command, seek_args);
  int seek_dir = 0, seek_file = 0, exec_flag = 0;
  char *current_path = ".";
  char *actual_path = malloc(MAX_PATH * sizeof(char));
  char *target_name = malloc(MAX_FILE_NAME * sizeof(char));
  // This is the name of the file or directory we are searching for;
  int match_count = 0;

  if (strcmp(seek_args[0], "seek") != 0)
  {
    perror("seek : Incorrect command");
  }
  else if (strcmp(seek_args[0], "seek") == 0)
  {
    for (int i = 1; i < num_args; i++)
    {
      char *pot_path = seek_args[i];
      // printf("My potential path is %s %d %d\n", pot_path, i, num_args);
      if (pot_path[0] == '-')
      {
        if ((strchr(pot_path, 'd')) != 0)
        {
          seek_dir = 1;
          // printf("You are seeking a directory\n");
        }

        if ((strchr(pot_path, 'f')) != 0)
        {
          seek_file = 1;
          // printf("You are seeking a file\n");
        }

        if (seek_file && seek_dir)
        {
          // seek_dir = 0;
          // seek_file = 0;
          printf("Invalid flags\n");
          // printf("Since you chose both d and f, we will look for both files and directories. This is a default option and need not be specified.\n");
        }
        else if (!seek_dir && !seek_file)
        {
          seek_dir = 1;
          seek_file = 1;
        }
        if ((strchr(pot_path, 'e')) != 0)
        {
          exec_flag = 1;
        }
      }
      else if (pot_path[0] != '-')
      {
        // printf("I reached here\n");
        strcpy(target_name, seek_args[i]);
      }
    }
    if (target_name[0] == '\0')
    {
      perror("Looks like you are not seeking any file or directory. Please give me a filename or directory name to look for\n");
      return;
    }
    else
    {
      // printf("Before search_target %s %d %s %s %d %d %d %d\n", seek_command, num_args, target_name, current_path, seek_dir, seek_file, exec_flag, match_count);
      search_target(target_name, current_path, seek_dir, seek_file, exec_flag, &match_count);
      // printf("After  search_target %s %d %s %s %d %d %d %d\n", seek_command, num_args, target_name, current_path, seek_dir, seek_file, exec_flag, match_count);
    }
  }
  //printf("inside seek match count %d", match_count);
  if (match_count == 0)
  {
    printf("No matching files or directories found.\n");
    fflush(stdout);
    // dprintf(STDOUT_FILENO, "No matching files or directories found.\n");
  }

  free(target_name);
  free(actual_path);
  return;
}