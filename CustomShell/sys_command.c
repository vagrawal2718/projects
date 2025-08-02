#include "sys_command.h"
#include "helper.h"
#include "activities.h"
#include "signals.h"

void execute_sys_command(char *singleton_command, int background_flag)
{
  trim(singleton_command);
  //printf("Within execute sys command the command string is **%s**\n", singleton_command);
  if (singleton_command == NULL)
  {
    return;
  }
  struct timeval start_time, end_time;
  gettimeofday(&start_time, NULL);

  char *args[MAX_ARGS];
  parse_command(singleton_command, args);

  //printf("2. Singleton Command %s args[1] %s args[2]%s\n", args[0], args[1], args[2]);

  pid_t pid = fork();

  if (pid < 0)
  {
    perror("Error in fork pid\n");
  }
  else if (pid == 0) // Execute command regardless of flag
  {
    // printf("2. pid %d\n", pid);
    //printf("3. Singleton Command %s args[1] %s args[2]%s\n", args[0], args[1], args[2]);

    struct sigaction sa_default;
    sa_default.sa_handler = SIG_DFL;
    sigemptyset(&sa_default.sa_mask);
    sa_default.sa_flags = 0;

    sigaction(SIGINT, &sa_default, NULL);
    sigaction(SIGTSTP, &sa_default, NULL);
    //printf("4. Singleton Command %s args[1] %s args[2]%s\n", args[0], args[1], args[2]);
    execvp(args[0], args);
    // perror("Error in executing system command\n");
    printf("ERROR : '%s' is not a valid command\n", args[0]);
    exit(1); // Trying to ensure that the child process exits if there is failure
  }
  else if (pid > 0) // Parent Process
  {
    add_process(pid, singleton_command);
    if (background_flag == 1) // Parent process updated child's or background process' data based on flag
    {
      if (num_bg_process < MAX_BG_PROCESSES)
      {
        bg_processes[num_bg_process].pid = pid;
        strncpy(bg_processes[num_bg_process].command, singleton_command, MAX_CMD - 1);
        bg_processes[num_bg_process].command[MAX_CMD - 1] = '\0';
        num_bg_process++;
      }
      else
      {
        fprintf(stderr, "Cannot store information about more bg_processes\n");
      }

      printf("[%d] %d\n", num_bg_process, pid);
    }
    else // This is for my foreground process, not for background
    {
      int status = 0;
      foreground_pid = pid;
      waitpid(pid, &status, WUNTRACED);
      foreground_pid  = -1;

      gettimeofday(&end_time, NULL);
      int long long seconds = end_time.tv_sec - start_time.tv_sec;
      if (seconds > 2)
      {
        printf("%s : %llds>\n", args[0], seconds);
      }
      // update_all_process_status(pid, 0);
      if (WIFEXITED(status) || WIFSIGNALED(status))
      {
        update_process_state(pid, 0); // Process terminated
      }
      else if (WIFSTOPPED(status))
      {
        update_process_state(pid, 0); // Process stopped
      }
      // remove_process(pid);
    }
  }
}

void check_bg_stat()
{
  pid_t pid = 0;
  int status;
  waitpid(pid, &status, WNOHANG);
  while (status > 0)
  {
    for (int i = 0; i < num_bg_process; i++)
    {
      if (bg_processes[i].pid == pid)
      {
        if (WIFEXITED(status))
        {
          printf("%s exited normally(%d)\n", bg_processes[i].command, pid);
        }
        else
        {
          printf("%s exited abnormally(%d)\n", bg_processes[i].command, pid);
        }

        // Removing process from array
        for (int j = i; j < num_bg_process - 1; j++)
        {
          bg_processes[j] = bg_processes[j + 1];
        }
        num_bg_process--;

        break;
      }
    }
    pid = waitpid(-1, &status, WNOHANG); // Check for other background processes
  }
}