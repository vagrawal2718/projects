#include "signals.h"
#include "activities.h"
#include "helper.h"

pid_t foreground_pid = -1;

void sigint_handler(int signum)
{
  if (foreground_pid > 0)
  {
    kill(foreground_pid, SIGINT);
  }
}

void sigtstp_handler(int signum)
{
  if (foreground_pid > 0)
  {
    kill(foreground_pid, SIGTSTP);
    update_process_state(foreground_pid, 0);
    foreground_pid = -1;
  }
}

// Ctrl-C, Ctrl-Z, and SIGCHLD
void setup_signal_handlers()
{
  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_handler = signal_handler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;

  // Ctrl-C
  if (sigaction(SIGINT, &sa, NULL) == -1)
  {
    perror("Error setting up SIGINT handler");
    exit(1);
  }

  // Ctrl-Z
  if (sigaction(SIGTSTP, &sa, NULL) == -1)
  {
    perror("Error setting up SIGTSTP handler");
    exit(1);
  }

  // SIGCHLD
  if (sigaction(SIGCHLD, &sa, NULL) == -1)
  {
    perror("Error setting up SIGCHLD handler");
    exit(1);
  }
}

void signal_handler(int sig)
{
  if (sig == SIGINT)
  {
    if (foreground_pid > 0)
    {
      kill(foreground_pid, SIGINT);
    }
  }
  else if (sig == SIGTSTP)
  {
    if (foreground_pid > 0)
    {
      kill(foreground_pid, SIGTSTP);
      update_process_state(foreground_pid, 0); // stopped
      foreground_pid = -1;
    }
  }
  else if (sig == SIGCHLD)
  {
    int status;
    pid_t pid;
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0)
    {
      if (WIFEXITED(status) || WIFSIGNALED(status))
      {
        update_process_state(pid, 0);
      }
      else if (WIFSTOPPED(status))
      {
        update_process_state(pid, 0);
      }
      else if (WIFCONTINUED(status))
      {
        update_process_state(pid, 1); // Mark the process as 'Running
      }
    }
  }
}

// ping
void send_signal(pid_t pid, int sig)
{
  // printf("Debug: Sending signal %d to process with pid %d\n", sig, pid);
  sig %= 32;

  if (kill(pid, sig) == 0)
  {
    printf("Sent signal %d to process with pid %d\n", sig, pid);
  }
  else
  {
    perror("ERROR: No such process found");
  }
}

// execute ping
void execute_ping(char *command_string)
{
  // printf("Debug: execute_ping called with command_string: %s\n", command_string);
  char *tokens[MAX_ARGS];
  int token_count = 0;

  char *token = strtok(command_string, " ");
  while (token != NULL && token_count < MAX_ARGS)
  {
    tokens[token_count++] = token;
    token = strtok(NULL, " ");
  }

  if (token_count != 3)
  {
    fprintf(stderr, "Usage: ping <pid> <signal_number>\n");
    return;
  }

  pid_t pid = atoi(tokens[1]);

  int signal_number = atoi(tokens[2]) % 32;

  // printf("Debug: Parsed PID: %d, Signal Number: %d\n", pid, signal_number);

  if (!process_exists(pid))
  {
    fprintf(stderr, "No such process found\n");
    return;
  }
  // printf("Debug: Process with PID %d exists. Sending signal\n", pid);
  send_signal(pid, signal_number);
}