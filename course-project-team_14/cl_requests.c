#include "ss.h"
#include <fcntl.h>
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <errno.h>

#define LIMIT_FOR_ASYNC 10
#define CHUNK_SIZE 50
#define A_SYNC_THHRESHOLD 1000
#define PORT_NUM 6062

// pthread_mutex_t file_mutex[MAX_PATHS];

void send_ack_to_client(int client_sock, const char *status, const char *message)
{
  char ack_message[BUFFER_SIZE];
  snprintf(ack_message, sizeof(ack_message), "ACK: %s %s", status, message);
  send(client_sock, ack_message, strlen(ack_message), 0);
}

// Handle READ request
void handle_read(int client_sock, const char *path)
{
  int j;
  for (j = 0; j < path_count; j++)
  {
    if (strcmp(accessible_paths[j], path) == 0)
    {
      pthread_mutex_lock(&file_mutex[j]);
      break;
    }
  }

  FILE *file = fopen(path, "rb");
  if (!file)
  {
    send_ack_to_client(client_sock, "READ_FAILED", path);
    perror("Failed to open file for reading");
    return;
  }

  char buffer[BUFFER_SIZE];
  size_t bytes_read;

  while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0)
  {
    send(client_sock, buffer, bytes_read, 0);
  }

  fclose(file);
  send_ack_to_client(client_sock, "READ_SUCCESS", path);
  printf(GREEN "File read successfully: %s\n" RESET, path);
  if (j < path_count)
  {
    pthread_mutex_unlock(&file_mutex[j]);
  }
}

// Handle WRITE request
void handle_write(int client_sock, const char *path, const char *data, int is_async)
{
  int j;
  for (j = 0; j < path_count; j++)
  {
    if (strcmp(accessible_paths[j], path) == 0)
    {
      pthread_mutex_lock(&file_mutex[j]);
      break;
    }
  }

  FILE *file = fopen(path, "ab");
  if (!file)
  {
    send_ack_to_client(client_sock, "WRITE_FAILED", path);
    perror("Failed to open file for writing");
    return;
  }

  if (is_async)
  {
    send_ack_to_client(client_sock, "ASYNC_WRITE_ACCEPTED", path);
    printf(GREEN "Asynchronous write initiated: %s\n" RESET, path);

    size_t data_length = strlen(data);
    size_t bytes_written = 0;

    while (bytes_written < data_length)
    {
      size_t remaining = data_length - bytes_written;
      size_t to_write = remaining < CHUNK_SIZE ? remaining : CHUNK_SIZE;
      // Write the chunk
      size_t written = fwrite(data + bytes_written, 1, to_write, file);
      if (written != to_write)
      {
        perror("Error writing to file");
        send_ack_to_nm(naming_sock, "ASYNC_WRITE_FAILED", " ");
        break;
      }

      bytes_written += written;
    }
    fclose(file);
    sleep(50);
    printf(GREEN "Data written to %s in chunks.\n" RESET, path);
    send_ack_to_nm(naming_sock, "ASYNC_WRITE_SUCCESS", " ");
  }
  else
  {
    send_ack_to_client(client_sock, "WRITE_SUCCESS", path);
    fprintf(file, "%s", data);
    fclose(file);
    printf(GREEN "File written successfully: %s\n" RESET, path);
  }
  if (j < path_count)
  {
    pthread_mutex_unlock(&file_mutex[j]);
  }
}

// Handle STREAM request
void handle_stream(int client_sock, const char *path)
{
  // printf("Handling STREAM request for path: %s\n", path);
  if (strstr(path, ".mp3") == NULL)
  {
    send(client_sock, "INVALID_PATH", strlen("INVALID_PATH"), 0);
    printf(RED "Invalid path\n" RESET);
    return;
  }

  int file_fd = open(path, O_RDONLY);
  if (file_fd < 0)
  {
    send(client_sock, "STREAM_FAILED", strlen("STREAM_FAILED"), 0);
    perror("Failed to open file for streaming");
    return;
  }

  struct stat file_stat;
  if (fstat(file_fd, &file_stat) < 0)
  {
    send(client_sock, "STREAM_FAILED", strlen("STREAM_FAILED"), 0);
    perror("Failed to stat file for streaming");
    close(file_fd);
    return;
  }

  size_t file_size = file_stat.st_size;
  printf(GREEN "Streaming file of size: %ld bytes\n" RESET, file_size);

  char buffer[BUFFER_SIZE];
  ssize_t bytes_read;
  int paused = 0;
  off_t file_offset = 0; // Keep track of file position

  while (1)
  {
    // Check for pause/resume/stop commands from the client
    char command[BUFFER_SIZE];
    ssize_t command_received = recv(client_sock, command, sizeof(command) - 1, MSG_DONTWAIT);
    if (command_received > 0)
    {
      command[command_received] = '\0';
      if (strncmp(command, "PAUSE", 5) == 0)
      {
        paused = 1;
        printf(YELLOW "Stream paused by client.\n" RESET);
        continue;
      }
      else if (strncmp(command, "RESUME", 6) == 0)
      {
        paused = 0;
        printf(YELLOW "Stream resumed by client.\n" RESET);
        continue;
      }
      else if (strncmp(command, "STOP", 4) == 0)
      {
        printf(YELLOW "Stream stopped by client.\n" RESET);
        break;
      }
    }
    else if (command_received == 0)
    {
      // Client disconnected
      printf(RED "Client disconnected. Stopping stream.\n" RESET);
      break;
    }
    else if (command_received < 0 && errno != EAGAIN && errno != EWOULDBLOCK)
    {
      perror("Error receiving client command");
      break;
    }

    // If paused, wait before checking commands again
    if (paused)
    {
      usleep(100000); // Sleep for 100ms while paused
      continue;
    }

    // Send file data in chunks
    bytes_read = pread(file_fd, buffer, sizeof(buffer), file_offset);
    if (bytes_read <= 0)
      break;

    if (send(client_sock, buffer, bytes_read, 0) <= 0)
    {
      perror("Failed to send audio data to client");
      break;
    }

    file_offset += bytes_read;
  }

  close(file_fd);
  printf(GREEN "Streaming completed or stopped for file: %s\n" RESET, path);
}

// Handle GET_INFO request
void handle_get_info(int client_sock, const char *path)
{
  struct stat file_stat;
  if (stat(path, &file_stat) < 0)
  {
    send_ack_to_client(client_sock, "GET_INFO_FAILED", path);
    perror("Failed to stat file");
    return;
  }

  char info[2048];
  char formatted_time[BUFFER_SIZE];

  // Format the last modified time
  struct tm *tm_info = localtime(&file_stat.st_mtime); // Convert to local time
  if (tm_info == NULL)
  {
    perror("Failed to convert time");
    send_ack_to_client(client_sock, "GET_INFO_FAILED", path);
    return;
  }

  // Format the time into a human-readable string
  strftime(formatted_time, sizeof(formatted_time), "%Y-%m-%d %H:%M:%S", tm_info);

  // Prepare the information string
  snprintf(info, sizeof(info),
           "File: %s\nSize: %ld bytes\nPermissions: %o\nLast Modified: %s\n",
           path, file_stat.st_size, file_stat.st_mode & 0777, formatted_time);

  // Send the information to the client
  send(client_sock, info, strlen(info), 0);
  // send_ack_to_client(client_sock, "GET_INFO_SUCCESS", path);
  printf("File info sent successfully: %s\n", path);
}

// Check if a path is accessible
int is_accessible_path(const char *path)
{
  for (int i = 0; i < path_count; i++)
  {
    if (strncmp(path, accessible_paths[i], strlen(accessible_paths[i])) == 0)
    {
      return 1; // Path is accessible
    }
  }
  return 0; // Path is not accessible
}

void handle_list_dir(const char *path, int client_sock)
{
  printf(PINK "Handling LIST_DIR request for path: %s\n" RESET, path);

  // Check if the requested path is accessible
  if (!is_accessible_path(path))
  {
    send_ack_to_client(client_sock, "LIST_DIR_FAILED", "Path not accessible");
    printf(RED "LIST_DIR failed: Path not accessible - %s\n" RESET, path);
    return;
  }

  DIR *dir = opendir(path);
  if (!dir)
  {
    send_ack_to_client(client_sock, "LIST_DIR_FAILED", "Failed to open directory");
    perror("Failed to open directory for LIST_DIR");
    return;
  }

  struct dirent *entry;
  char response[BUFFER_SIZE] = "";

  // List files and directories in the specified path
  while ((entry = readdir(dir)) != NULL)
  {
    // Skip special entries
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
    {
      continue;
    }

    char entry_path[MAX_PATH_LENGTH * 2];
    snprintf(entry_path, sizeof(entry_path), "%s/%s", path, entry->d_name);

    // Check if the entry is in the accessible paths
    if (is_accessible_path(entry_path))
    {
      strncat(response, entry_path, sizeof(response) - strlen(response) - 1); // Add absolute path
      strncat(response, "\n", sizeof(response) - strlen(response) - 1);       // Add newline
    }
  }

  closedir(dir);

  if (strlen(response) == 0)
  {
    snprintf(response, sizeof(response), "No accessible files or directories found in %s\n", path);
  }

  send(client_sock, response, strlen(response), 0);
  // send_ack_to_client(client_sock, "LIST_DIR_SUCCESS", path);
  printf(GREEN "LIST_DIR completed for path: %s\n" RESET, path);
}

void handle_copy_file_for_dir(int client_sock, const char *buffer)
{
  printf("Recieved request to copy from %d and %s\n", client_sock, buffer);
  char dest_path[MAX_PATH_LENGTH];
  sscanf(buffer, "COPY_FILE %s", dest_path);

  printf("DEBUG: Handling COPY_FILE for destination path: %s\n", dest_path);

  // open the file for writing received data
  FILE *dest_file = fopen(dest_path, "wb");
  if (!dest_file)
  {
    perror("Failed to create destination file");
    send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
    close(client_sock);
    return;
  }

  printf("File created and will now send signal saying its ready\n");
  // Step 3: Receive the file data and write to the destination file
  char file_buffer[BUFFER_SIZE];
  ssize_t bytes_received;
  ssize_t total_bytes_received = 0;

  // Send a ready signal to the source server
  const char *ready_signal = "READY_TO_RECEIVE";
  send(client_sock, ready_signal, strlen(ready_signal), 0);

  // Add an end-of-transfer marker
  const char *end_marker = "FILE_TRANSFER_END";
  size_t marker_len = strlen(end_marker);

  while ((bytes_received = recv(client_sock, file_buffer, BUFFER_SIZE, 0)) > 0)
  {
    file_buffer[bytes_received] = '\0'; // Null-terminate for safer debug output
    printf("The following content is received in the file buffer: %s\n", file_buffer);

    // Check if this buffer is the end marker
    if (strncmp(file_buffer, end_marker, 17) == 0)
    {
      printf("End-of-transfer marker received. Stopping transfer.\n");
      break;
    }

    // Write the buffer content to the file
    if (fwrite(file_buffer, 1, bytes_received, dest_file) != (size_t)bytes_received)
    {
      perror("Failed to write data to destination file");
      fclose(dest_file);
      send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
      // close(client_sock);
      return;
    }
    total_bytes_received += bytes_received;
  }

  fclose(dest_file);

  if (total_bytes_received > 0)
  {
    send_ack_to_client(client_sock, "COPY_FILE_SUCCESS", dest_path);
    printf("DEBUG: File successfully received and written to %s (Total bytes: %zd)\n",
           dest_path, total_bytes_received);
  }
  else
  {
    perror("No data received");
    send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
  }

  // close(client_sock);
}
void handle_copy_file(int client_sock, const char *buffer)
{
  printf("Recieved request to copy from %d and %s\n", client_sock, buffer);
  char dest_path[MAX_PATH_LENGTH];
  sscanf(buffer, "COPY_FILE %s", dest_path);

  printf("DEBUG: Handling COPY_FILE for destination path: %s\n", dest_path);

  // open the file for writing received data
  FILE *dest_file = fopen(dest_path, "wb");
  if (!dest_file)
  {
    perror("Failed to create destination file");
    send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
    close(client_sock);
    return;
  }

  printf("File create and will now send signal sayinf its ready\n");
  // Step 3: Receive the file data and write to the destination file
  char file_buffer[BUFFER_SIZE];
  ssize_t bytes_received;
  ssize_t total_bytes_received = 0;

  // Send a ready signal to the source server
  const char *ready_signal = "READY_TO_RECEIVE";
  send(client_sock, ready_signal, strlen(ready_signal), 0);

  // Add an end-of-transfer marker
  const char *end_marker = "FILE_TRANSFER_END";
  size_t marker_len = strlen(end_marker);

  while ((bytes_received = recv(client_sock, file_buffer, BUFFER_SIZE, 0)) > 0)
  {
    printf("The following ocntent is recievd in the file buffer %s\n", file_buffer);
    // Check for end marker
    if (bytes_received >= marker_len &&
        memcmp(file_buffer + bytes_received - marker_len, end_marker, marker_len) == 0)
    {
      // Write everything except the marker
      fwrite(file_buffer, 1, bytes_received - marker_len, dest_file);
      break;
    }

    if (fwrite(file_buffer, 1, bytes_received, dest_file) != (size_t)bytes_received)
    {
      perror("Failed to write data to destination file");
      fclose(dest_file);
      send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
      close(client_sock);
      return;
    }
    total_bytes_received += bytes_received;
  }

  fclose(dest_file);

  if (total_bytes_received > 0)
  {
    send_ack_to_client(client_sock, "COPY_FILE_SUCCESS", dest_path);
    // send_ack_to_nm(naming_sock, "COPY_FILE_SUCCESS", dest_path);
    printf("DEBUG: File successfully received and written to %s (Total bytes: %zd)\n",
           dest_path, total_bytes_received);
  }
  else
  {
    perror("No data received");
    send_ack_to_client(client_sock, "COPY_FILE_FAILED", dest_path);
  }

  close(client_sock);
}
void handle_subdirectory(const char *command)
{
  char sub_dir[MAX_PATH_LENGTH] = {0};

  if (sscanf(command, "CREATE_DIR %s", sub_dir) != 1)
  {
    fprintf(stderr, "Invalid CREATE_DIR command format\n");
    return;
  }

  struct stat st;
  if (stat(sub_dir, &st) == 0 && S_ISDIR(st.st_mode))
  {
    printf("DEBUG: Subdirectory already exists: %s\n", sub_dir);
  }
  else if (mkdir(sub_dir, 0755) == -1)
  {
    perror("Failed to create subdirectory");
    return;
  }
  else
  {
    printf("DEBUG: Successfully created subdirectory: %s\n", sub_dir);
  }
}

void process_remaining_commands(int client_sock)
{
  char buffer[BUFFER_SIZE];
  size_t buffer_len = 0;

  while (1)
  {
    // Receive data from the client
    ssize_t bytes_received = recv(client_sock, buffer + buffer_len, sizeof(buffer) - buffer_len - 1, 0);

    if (bytes_received <= 0)
    {
      if (bytes_received == 0)
      {
        printf("DEBUG: Client disconnected\n");
      }
      else
      {
        perror("recv error");
      }
      return;
    }

    buffer_len += bytes_received;
    buffer[buffer_len] = '\0';

    // Process commands from the buffer
    char *cmd_start = buffer;
    char *cmd_end;
    while ((cmd_end = strstr(cmd_start, "\n")) != NULL)
    {
      *cmd_end = '\0'; // Null-terminate the command

      if (strncmp(cmd_start, "CREATE_DIR", 10) == 0)
      {
        handle_subdirectory(cmd_start);
      }
      else if (strncmp(cmd_start, "COPY_FILE", 9) == 0)
      {
        handle_copy_file_for_dir(client_sock, cmd_start);
      }
      else if (strcmp(cmd_start, "DIRECTORY_COMPLETE") == 0)
      {
        printf("DEBUG: Directory transfer complete\n");
        // Send acknowledgment for directory transfer success
        const char *dir_ack = "DIR_TRANSFER_SUCCESS\n";
        send(client_sock, dir_ack, strlen(dir_ack), 0);
        return;
      }
      else
      {
        fprintf(stderr, "Unknown command: %s\n", cmd_start);
      }

      // Move to the next command
      cmd_start = cmd_end + 1;
    }

    // Shift any incomplete command to the start of the buffer
    buffer_len -= (cmd_start - buffer);
    memmove(buffer, cmd_start, buffer_len);
  }
}

void handle_copy_dir(int client_sock, const char *buffer)
{
  char parent_dir[MAX_PATH_LENGTH] = {0};

  // Extract the parent directory path
  if (sscanf(buffer, "CREATE_DIR %s", parent_dir) != 1)
  {
    fprintf(stderr, "Invalid CREATE_DIR command format\n");
    send_ack_to_client(client_sock, "CREATE_DIR_FAILED", "invalid format");
    return;
  }

  // Create the parent directory
  struct stat st;
  if (stat(parent_dir, &st) == 0 && S_ISDIR(st.st_mode))
  {
    printf("DEBUG: Parent directory already exists: %s\n", parent_dir);
  }
  else if (mkdir(parent_dir, 0755) == -1)
  {
    perror("Failed to create parent directory");
    send_ack_to_client(client_sock, "CREATE_DIR_FAILED", parent_dir);
    return;
  }
  else
  {
    printf("DEBUG: Successfully created parent directory: %s\n", parent_dir);
  }

  // Redirect to process_remaining_commands to handle subdirectories and files
  process_remaining_commands(client_sock);
}

// Process client request
void process_client_request(int client_sock, const char *buffer)
{
  char command[16];
  char path[MAX_PATH_LENGTH];
  char data[BUFFER_SIZE];
  int parsed;

  if (strncmp(buffer, "CREATE_DIR", 10) == 0)
  {
    handle_copy_dir(client_sock, buffer);
  }
  else if (strncmp(buffer, "COPY_FILE", 9) == 0)
  {
    handle_copy_file(client_sock, buffer);
  }
  else if (strncmp(buffer, "READ", 4) == 0)
  {
    parsed = sscanf(buffer, "READ %s", path);
    if (parsed == 1)
    {
      handle_read(client_sock, path);
    }
    else
    {
      send_ack_to_client(client_sock, "INVALID_FORMAT", "READ");
    }
  }
  else if (strncmp(buffer, "WRITE", 5) == 0)
  {
    // parsed = sscanf(buffer, "WRITE %s %s", path, data);

    // if (parsed == 2)
    // {
    //   int is_async = 0; // Change this to 1 if asynchronous handling is required
    //   handle_write(client_sock, path, data, is_async);
    // }
    // else
    // {
    //   send_ack_to_client(client_sock, "INVALID_FORMAT", "WRITE");
    // }

    char buffer_dup[BUFFER_SIZE];
    strcpy(buffer_dup, buffer);
    char *token = strtok(buffer_dup, " ");
    if (strcmp(token, "WRITE") == 0)
    {
      token = strtok(NULL, " ");
      if (token == NULL)
      {
        send_ack_to_client(client_sock, "INVALID_FORMAT", "WRITE");
        return;
      }
      strcpy(path, token);
      token = strtok(NULL, " ");
      if (token == NULL)
      {
        send_ack_to_client(client_sock, "INVALID_FORMAT", "WRITE");
        return;
      }
      int is_async = 0; // Change this to 1 if asynchronous handling is required
      if (strstr(token, "--SYNC") != NULL)
      {
        is_async = 1;
        token = strtok(NULL, " ");
      }
      if (token == NULL)
      {
        send_ack_to_client(client_sock, "INVALID_FORMAT", "WRITE");
        return;
      }
      strcpy(data, token);
      token = strtok(NULL, " ");
      while (token != NULL)
      {
        char dupp[BUFFER_SIZE];
        sprintf(dupp, " %s", token);
        strcat(data, dupp);
        token = strtok(NULL, " ");
      }
      printf("%s\n", data);
      if (strlen(data) > A_SYNC_THHRESHOLD)
      {
        is_async = 1;
      }
      handle_write(client_sock, path, data, is_async);
    }
  }
  else if (strncmp(buffer, "STREAM", 6) == 0)
  {
    parsed = sscanf(buffer, "STREAM %s", path);
    if (parsed == 1)
    {
      handle_stream(client_sock, path);
    }
    else
    {
      send_ack_to_client(client_sock, "INVALID_FORMAT", "STREAM");
    }
  }
  else if (strncmp(buffer, "GET_INFO", 8) == 0)
  {
    parsed = sscanf(buffer, "GET_INFO %s", path);
    if (parsed == 1)
    {
      handle_get_info(client_sock, path);
    }
    else
    {
      send_ack_to_client(client_sock, "INVALID_FORMAT", "GET_INFO");
    }
  }
  else if (strncmp(buffer, "LIST_DIR", 8) == 0)
  {
    parsed = sscanf(buffer, "LIST_DIR %s", path);
    if (parsed == 1)
    {
      handle_list_dir(path, client_sock);
    }
    else
    {
      send_ack_to_client(client_sock, "INVALID_FORMAT", "LIST_DIR");
    }
  }
  else
  {
    send_ack_to_client(client_sock, "UNKNOWN_COMMAND", buffer);
  }
}

void *listen_for_client_requests(void *arg)
{
  int client_sock = *((int *)arg);
  char buffer[BUFFER_SIZE];
  int bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);
  printf("Buffer received from source ss is %s\n", buffer);
  if (bytes_received <= 0)
  {
    perror("Failed to receive client request");
    close(client_sock);
  }

  buffer[bytes_received] = '\0';
  process_client_request(client_sock, buffer);

  close(client_sock);

  return NULL;
}
