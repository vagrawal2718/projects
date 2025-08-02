#include "reveal.h"
#include "helper.h"
#include "grp.h"
#include "hop.h"

#define KBLU "\x1B[34m" // Blue
#define KNRM "\x1B[0m"
#define KWHT "\x1B[37m"
#define KGRN "\x1B[32m"

char *get_filename(char *filepath)
{
  char *copy = strdup(filepath); // Create a copy to avoid modifying the original
  char *filename = basename(copy);
  free(copy);
  return filename;
}

char *get_dirname(char *dirpath)
{
  char *copy = strdup(dirpath);
  char *dir_name = dirname(copy);
  free(copy);
  return dir_name;
}
int compare(const void *a, const void *b)
{
  return strcmp(*(const char **)a, *(const char **)b);
}
void reveal_execute(char *command)
{
  char *args_list[MAX_ARGS];
  memset(args_list, 0, MAX_ARGS * sizeof(char *));
  char *path = ".";
  char *absolute_path = construct_full_path(path); // This is default path i.e. current directory
  int display_all_files = 0, display_all_file_info = 0;
  int arg_num = 0, i = 0;
  arg_num = parse_command(command, args_list);
  //printf("# of args %d\n", arg_num);
  for (i = 1; (args_list[i] != NULL && i < arg_num); i++)
  {
    //printf("i, arg[i] %d,%s\n", i, args_list[i]);
    char *pot_path = args_list[i];
    if (pot_path[0] == '-')
    {
      if ((strchr(pot_path, 'a')) && (strcmp(pot_path, "-") != 0))
        display_all_files = 1;
      if ((strchr(pot_path, 'l')) && (strcmp(pot_path, "-") != 0))
        display_all_file_info = 1;
    }
    else if ((strcmp(pot_path, "-") == 0) || (pot_path[0] == '/') || (pot_path[0] == '.') || strncmp(pot_path, "..", 2) == 0 || (pot_path[0] == '~'))
      absolute_path = construct_full_path(pot_path);
    else if ((pot_path[0] != '-') && (strcmp(pot_path, "-") != 0) && (pot_path[0] == '/') && (pot_path[0] == '.') && strncmp(pot_path, "..", 2) == 0 && (pot_path[0] == '~'))
      absolute_path = construct_full_path(pot_path);
  }
  //printf("Command: %s, Argument 1: %s, Path: %s", command, args_list[1], absolute_path);
  //printf("Command: %s, Argument 1: %s, Path: %s", command, args_list[1], absolute_path);
  DIR *dir = opendir(absolute_path);
  if (dir == NULL)
  {
    if (errno == ENOTDIR)
    {
      char *filename = get_filename(absolute_path);
      if (display_all_file_info)
        display_file_details(absolute_path, filename);
      else
        show_color(filename, 0);
    }
    else
    {
      perror("Error opening directory");
      return;
    }
  }

  struct dirent *dir_entry;
  char *entries[MAX_DIR_ENTRIES] = {0};
  int num_entries = 0;
  int num_blocks = 0;
  while ((dir_entry = readdir(dir)) != NULL && num_entries < MAX_DIR_ENTRIES)
  {
    if (display_all_files || dir_entry->d_name[0] != '.')
    {
      entries[num_entries++] = strdup(dir_entry->d_name);
      if (display_all_file_info)
      {
        struct stat entry_st;
        char complete_path[MAX_PATH];
        snprintf(complete_path, MAX_PATH, "%s/%s", absolute_path, dir_entry->d_name);
        if (stat(complete_path, &entry_st) == 0)
        {
          num_blocks += entry_st.st_blocks;
        }
      }
    }
  }
  closedir(dir);

  qsort(entries, num_entries, sizeof(char *), compare);
  for (int i = 0; i < num_entries; i++)
  {
    char full_entry_path[MAX_PATH];
    snprintf(full_entry_path, MAX_PATH, "%s/%s", absolute_path, entries[i]);

    if (display_all_file_info)
    {
      display_file_details(full_entry_path, entries[i]);
    }
    else
    {
      show_color(entries[i], 0);
    }

    free(entries[i]);
  }
  free(absolute_path);
}

void show_color(char *filename, mode_t mode)
{
  if (S_ISDIR(mode))
  {
    printf(KBLU "%s\n" KNRM, filename);
  }
  else if ((mode & S_IXUSR) || (mode & S_IXGRP) || (mode & S_IXOTH))
  {
    printf(KGRN "%s\n" KNRM, filename);
  }
  else
  {
    printf(KWHT "%s\n" KNRM, filename);
  }
}
void display_file_details(char *filepath, char *filename)
{
  struct stat file_info;
  int stat_flag = stat(filepath, &file_info);
  if (stat_flag != 0)
  {
    perror("Error obtaining file information");
    return;
  }
  else
  {
    struct passwd *user = getpwuid(file_info.st_uid);
    struct group *group = getgrgid(file_info.st_gid);

    printf("%s%s%s%s%s%s%s%s%s%s %lu %s %s %lld",
           S_ISDIR(file_info.st_mode) ? "d" : "-",
           (file_info.st_mode & S_IRUSR) ? "r" : "-",
           (file_info.st_mode & S_IWUSR) ? "w" : "-",
           (file_info.st_mode & S_IXUSR) ? "x" : "-",
           (file_info.st_mode & S_IRGRP) ? "r" : "-",
           (file_info.st_mode & S_IWGRP) ? "w" : "-",
           (file_info.st_mode & S_IXGRP) ? "x" : "-",
           (file_info.st_mode & S_IROTH) ? "r" : "-",
           (file_info.st_mode & S_IWOTH) ? "w" : "-",
           (file_info.st_mode & S_IXOTH) ? "x" : "-",
           (unsigned long)file_info.st_nlink,
           user->pw_name,
           group->gr_name,
           (long long)file_info.st_size);

    char time_str[50];
    time_t mtime = file_info.st_mtime;
    strftime(time_str, 50, "%b %d %H:%M", localtime(&mtime));
    printf("%s ", time_str);

    show_color(filename, file_info.st_mode);
  };
}
