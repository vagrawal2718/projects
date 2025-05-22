#include "ss.h"

// Send acknowledgment to NM
void send_ack_to_nm(int nm_sock, const char *status, const char *path)
{
    char ack_message[BUFFER_SIZE];
    snprintf(ack_message, sizeof(ack_message), "ACK: %s %s", status, path);
    send(nm_sock, ack_message, strlen(ack_message), 0);
}
void handle_copy_backup (int nm_sock, char *src_path, char *dest_dir, const char *dest_ip, int dest_port) {
    struct stat src_stat, dest_stat;
    char dest_path[MAX_PATH_LENGTH]; 
    char *src_name = strrchr(src_path, '/');
    src_name = src_name ? src_name + 1 : src_path; // Extract the source file's name
    if (snprintf(dest_path, sizeof(dest_path), "%s/%s", dest_dir, src_name) >= sizeof(dest_path))
    {
        send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
        fprintf(stderr, "Error: Destination path too long.\n");
        return;
    }
    if (!S_ISDIR(src_stat.st_mode))
    {
        printf("DEBUG: Performing file-to-file copy: %s -> %s\n", src_path, dest_path);

        if (dest_ip == NULL || dest_port == 0)
        {
            // Local file-to-file copy
            copy_file(src_path, dest_path);
            send_ack_to_nm(nm_sock, "COPY_SUCCESS", dest_path);
        }
        else
        {
            // Cross-server file-to-file copy
            printf("DEBUG: Performing cross-server file-to-file copy to %s:%d.\n", dest_ip, dest_port);
            FILE *src_file = fopen(src_path, "rb");
            if (!src_file)
            {
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                perror("Failed to open source file for cross-server copy");
                return;
            }

            int dest_sock = connect_to_storage_server(dest_ip, dest_port);
            if (dest_sock < 0)
            {
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                fclose(src_file);
                return;
            }

            // Send file data
            char buffer[BUFFER_SIZE];
            size_t bytes_read;
            while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, src_file)) > 0)
            {
                send(dest_sock, buffer, bytes_read, 0);
            }

            fclose(src_file);
            close(dest_sock);
            send_ack_to_nm(nm_sock, "COPY_SUCCESS", dest_path);
        }
    }
    else if (S_ISDIR(src_stat.st_mode))
    {
        // Source is a directory
        printf("DEBUG: Performing directory copy: %s -> %s\n", src_path, dest_path);

        if (dest_ip == NULL || dest_port == 0)
        {
            // Local directory copy
            traverse_and_copy(src_path, dest_path);
            send_ack_to_nm(nm_sock, "COPY_SUCCESS", dest_path);
        }
        else
        {
            // Cross-server directory copy
            printf("DEBUG: Performing cross-server directory copy to %s:%d.\n", dest_ip, dest_port);
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path); // Placeholder
        }
    }
}
// Client-side directory traversal and sending
void traverse_and_send_directory(const char *src_dir, const char *dest_dir, int dest_sock) {
    DIR *dir = opendir(src_dir);
    if (!dir) {
        perror("Failed to open source directory");
        return;
    }

    struct dirent *entry;
    char src_path[MAX_PATH_LENGTH];
    char dest_path[MAX_PATH_LENGTH];

    // Send create directory command with newline delimiter
    char create_dir_cmd[BUFFER_SIZE];
    snprintf(create_dir_cmd, sizeof(create_dir_cmd), "CREATE_DIR %s\n", dest_dir);
    printf("The create_dir_command in traverse and send is %s\n", create_dir_cmd);
    send(dest_sock, create_dir_cmd, strlen(create_dir_cmd), 0);

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        snprintf(src_path, sizeof(src_path), "%s/%s", src_dir, entry->d_name);
        snprintf(dest_path, sizeof(dest_path), "%s/%s", dest_dir, entry->d_name);

        struct stat path_stat;
        if (stat(src_path, &path_stat) == -1) {
            continue;
        }

        if (S_ISDIR(path_stat.st_mode)) {
            traverse_and_send_directory(src_path, dest_path, dest_sock);
        } else if (S_ISREG(path_stat.st_mode)) {
            // Send copy file command with newline delimiter
            char copy_cmd[BUFFER_SIZE];
            snprintf(copy_cmd, sizeof(copy_cmd), "COPY_FILE %s\n", dest_path);
            printf("The copy file command in traverse and send is %s\n", copy_cmd);
            send(dest_sock, copy_cmd, strlen(copy_cmd), 0);

            // Wait for ready signal
            char ready_buffer[BUFFER_SIZE] = {0};
            if (recv(dest_sock, ready_buffer, sizeof(ready_buffer)-1, 0) <= 0 ||
                strstr(ready_buffer, "READY_TO_RECEIVE") == NULL) {
                fprintf(stderr, "Did not receive ready signal for: %s\n", dest_path);
                continue;
            }

            // Send file contents
            FILE *src_file = fopen(src_path, "rb");
            printf("source path in traverse and send dir is %s\n", src_path);
            if (!src_file)
                continue;
            char buffer[BUFFER_SIZE];
            size_t bytes_read;
            while ((bytes_read = fread(buffer, 1, sizeof(buffer), src_file)) > 0) {
                send(dest_sock, buffer, bytes_read, 0);
            }
        //     size_t bytes_read, total_bytes_sent = 0;
        //     while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, src_file)) > 0)
        // {
        //     ssize_t bytes_sent = send(dest_sock, buffer, bytes_read, 0);
        //     if (bytes_sent < 0)
        //     {
        //         perror("Failed to send file data");
        //         fclose(src_file);
        //         close(dest_sock);
        //         send_ack_to_nm(naming_sock, "COPY_FAILED", src_path);
        //         return;
        //     }
        //     total_bytes_sent += bytes_sent;
        // }
            // Send end marker with newline
            const char *end_marker = "FILE_TRANSFER_END\n";
            send(dest_sock, end_marker, strlen(end_marker), 0);

            fclose(src_file);

            // Wait for copy acknowledgment
            char ack_buffer[BUFFER_SIZE] = {0};
            recv(dest_sock, ack_buffer, sizeof(ack_buffer)-1, 0);
        }
    }

    // Send directory complete marker
    const char *complete_marker = "DIRECTORY_COMPLETE\n";
    send(dest_sock, complete_marker, strlen(complete_marker), 0);


    // Wait for acknowledgment of directory transfer
    char dir_ack_buffer[BUFFER_SIZE] = {0};
    if (recv(dest_sock, dir_ack_buffer, sizeof(dir_ack_buffer) - 1, 0) > 0 &&
        strstr(dir_ack_buffer, "DIR_TRANSFER_SUCCESS") != NULL) {
        // Notify Naming Server
        char nm_ack[BUFFER_SIZE];
        snprintf(nm_ack, sizeof(nm_ack), "DIRECTORY_TRANSFER_SUCCESS %s", src_dir);
        send(naming_sock, nm_ack, strlen(nm_ack), 0);
    } else {
        fprintf(stderr, "Did not receive directory transfer acknowledgment.\n");
    }
    closedir(dir);
}

void handle_copy(int nm_sock, const char *src_path, const char *dest_dir_or_file, const char *dest_ip, int dest_port)
{
    // printf("DEBUG: handle_copy called. src_path=%s, dest_dir_or_file=%s, dest_ip=%s, dest_port=%d\n",
    //        src_path, dest_dir_or_file, dest_ip ? dest_ip : "NULL", dest_port);

    struct stat src_stat, dest_stat;

    // Check if the source path is valid
    if (stat(src_path, &src_stat) == -1)
    {
        send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
        perror("Invalid source path");
        return;
    }

    // Construct the full destination path
    char dest_path[MAX_PATH_LENGTH];
    if (stat(dest_dir_or_file, &dest_stat) == 0 && S_ISDIR(dest_stat.st_mode))
    {
        // Destination is a directory; append source file/directory name
        const char *src_name = strrchr(src_path, '/');
        src_name = src_name ? src_name + 1 : src_path; // Extract the source file's name
        if (snprintf(dest_path, sizeof(dest_path), "%s/%s", dest_dir_or_file, src_name) >= sizeof(dest_path))
        {
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
            fprintf(stderr, "Error: Destination path too long.\n");
            return;
        }
    }
    // else if (stat(dest_dir_or_file, &dest_stat) == -1)
    // {
    //     // Destination file does not exist
    //     send_ack_to_nm(nm_sock, "COPY_FAILED", dest_dir_or_file);
    //     fprintf(stderr, "Error: Destination file or directory does not exist.\n");
    //     return;
    // }
    // else
    // {
    //     // Destination is treated as a file
    //     strncpy(dest_path, dest_dir_or_file, sizeof(dest_path) - 1);
    //     dest_path[sizeof(dest_path) - 1] = '\0';
    // }



    if(dest_ip==NULL || dest_port==0){
        //Local copy
        if(!S_ISDIR(src_stat.st_mode)){
            //file-to-file
            copy_file(src_path, dest_path);
            send_ack_to_nm(nm_sock, "COPY_SUCCESS", dest_path);
        }
        else if(S_ISDIR(src_stat.st_mode)){
            //source is a directory
            traverse_and_copy(src_path, dest_path);
            send_ack_to_nm(nm_sock, "COPY_SUCCESS", dest_path);
        }
        else
        {
            // Invalid scenario: Cannot copy directory to a file
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
            fprintf(stderr, "Error: Invalid copy operation: Cannot copy directory to file or mismatched types.\n");
        }
    }
    else{
        //Cross-server
        int dest_sock = connect_to_storage_server(dest_ip, dest_port);
        if (dest_sock < 0)
        {
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
            return;
        }

        if (S_ISDIR(src_stat.st_mode))
        {
            // Directory-to-Directory copy
            char create_dir_command[BUFFER_SIZE];
            char *lastSlash = strrchr(src_path, '/'); // Find the last '/' in the path
                    if (lastSlash == NULL) {
                        // No '/' found, the entire path is the file name
                        return;
                    }
                // strcat(dest_dir_or_file, "/");
            strcat(dest_dir_or_file, lastSlash);
            snprintf(create_dir_command, sizeof(create_dir_command), "CREATE_DIR %s", dest_dir_or_file);
            printf("Buffere sent to destination for creation of parent dir from handle copy is %s\n", create_dir_command);
            /* if (send(dest_sock, create_dir_command, strlen(create_dir_command), 0) < 0)
            {
                perror("Failed to send CREATE_DIR command to destination server");
                close(dest_sock);
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                return;
            }*/
            //printf("DEBUG: Sent CREATE_DIR command for: %s\n", dest_dir_or_file);

            traverse_and_send_directory(src_path, dest_dir_or_file, dest_sock);
        }
        else if (S_ISREG(src_stat.st_mode))
        {
            // File-to-Directory copy
            const char *file_name = strrchr(src_path, '/');
            file_name = file_name ? file_name + 1 : src_path;

            char dest_path[MAX_PATH_LENGTH];
            // Avoid appending an extra slash if dest_dir_or_file already ends with one
            size_t len = strlen(dest_dir_or_file);
            if (len > 0 && dest_dir_or_file[len - 1] == '/')
            {
                snprintf(dest_path, sizeof(dest_path), "%s%s", dest_dir_or_file, file_name);
            }
            else
            {
                snprintf(dest_path, sizeof(dest_path), "%s/%s", dest_dir_or_file, file_name);
            }
            // Send the COPY_FILE command to the destination server
            char copy_request[BUFFER_SIZE];
            snprintf(copy_request, sizeof(copy_request), "COPY_FILE %s", dest_path);
            if (send(dest_sock, copy_request, strlen(copy_request), 0) < 0)
            {
                perror("Failed to send COPY_FILE command to destination server");
                close(dest_sock);
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                return;
            }
            printf("DEBUG: Sent COPY_FILE command for: %s\n", dest_path);

            // Wait for ready signal from the destination server
            char ready_buffer[BUFFER_SIZE];
            if (recv(dest_sock, ready_buffer, sizeof(ready_buffer) - 1, 0) <= 0 ||
                strncmp(ready_buffer, "READY_TO_RECEIVE", 16) != 0)
            {
                perror("Did not receive READY_TO_RECEIVE signal");
                close(dest_sock);
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                return;
            }
            //printf("DEBUG: Received ready signal from destination server\n");

            // Open the source file for reading
            FILE *src_file = fopen(src_path, "rb");
            if (!src_file)
            {
                perror("Failed to open source file");
                close(dest_sock);
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                return;
            }

            // Transfer file contents
            char buffer[BUFFER_SIZE];
            size_t bytes_read, total_bytes_sent = 0;

            while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, src_file)) > 0)
            {
                ssize_t bytes_sent = send(dest_sock, buffer, bytes_read, 0);
                if (bytes_sent < 0)
                {
                    perror("Failed to send file data");
                    fclose(src_file);
                    close(dest_sock);
                    send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                    return;
                }
                total_bytes_sent += bytes_sent;
            }

            // Send end-of-file marker
            const char *end_marker = "FILE_TRANSFER_END";
            if (send(dest_sock, end_marker, strlen(end_marker), 0) < 0)
            {
                perror("Failed to send end marker");
                fclose(src_file);
                close(dest_sock);
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
                return;
            }

            fclose(src_file);
            //printf("DEBUG: File transfer complete. Total bytes sent: %zu\n", total_bytes_sent);
        }
        else
        {
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
            fprintf(stderr, "Source path is neither a directory nor a regular file: %s\n", src_path);
            close(dest_sock);
            return;
        }

        // Wait for acknowledgment from the destination server
        char ack_buffer[BUFFER_SIZE];
        if (recv(dest_sock, ack_buffer, sizeof(ack_buffer) - 1, 0) > 0)
        {
            ack_buffer[BUFFER_SIZE - 1] = '\0';
            //printf("DEBUG: Received acknowledgment: %s\n", ack_buffer);
            if (strstr(ack_buffer, "COPY_FILE_SUCCESS") != NULL)
            {
                send_ack_to_nm(nm_sock, "COPY_FILE_SUCCESS", dest_dir_or_file);
            }
            else
            {
                send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
            }
        }
        else
        {
            perror("No acknowledgment from destination server");
            send_ack_to_nm(nm_sock, "COPY_FAILED", src_path);
        }

        close(dest_sock);
    }
}

void traverse_and_copy(const char *src_dir, const char *dest_dir)
{
  DIR *dir = opendir(src_dir);
  if (!dir)
  {
    perror("Failed to open source directory for copying");
    return;
  }

  // Ensure the destination directory exists
  mkdir(dest_dir, 0755);

  struct dirent *entry;
  char src_path[MAX_PATH_LENGTH], dest_path[MAX_PATH_LENGTH];

  while ((entry = readdir(dir)) != NULL)
  {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
      continue;

    // Use `snprintf` safely and handle truncation
    if (snprintf(src_path, sizeof(src_path), "%s/%s", src_dir, entry->d_name) >= sizeof(src_path))
    {
      fprintf(stderr, "Warning: Source path truncated: %s/%s\n", src_dir, entry->d_name);
      continue;
    }

    if (snprintf(dest_path, sizeof(dest_path), "%s/%s", dest_dir, entry->d_name) >= sizeof(dest_path))
    {
      fprintf(stderr, "Warning: Destination path truncated: %s/%s\n", dest_dir, entry->d_name);
      continue;
    }

    struct stat path_stat;
    if (stat(src_path, &path_stat) == -1)
    {
      perror("Failed to stat source path");
      continue;
    }

    // Recursively copy directories or copy files
    if (S_ISDIR(path_stat.st_mode))
    {
      traverse_and_copy(src_path, dest_path);
    }
    else
    {
      copy_file(src_path, dest_path);
    }
  }

  closedir(dir);
}

void copy_file(const char *src_file, const char *dest_file)
{
    FILE *src = fopen(src_file, "rb");
    if (!src)
    {
        perror("Failed to open source file");
        return;
    }

    FILE *dest = fopen(dest_file, "wb");
    if (!dest)
    {
        perror("Failed to open destination file");
        fclose(src);
        return;
    }

    char buffer[BUFFER_SIZE];
    size_t bytes;
    while ((bytes = fread(buffer, 1, BUFFER_SIZE, src)) > 0)
    {
        fwrite(buffer, 1, bytes, dest);
    }

    fclose(src);
    fclose(dest);
}

int connect_to_storage_server(const char *storage_ip, int storage_port)
{
  printf("Storage ip and port %s %d\n", storage_ip, storage_port);
  int storage_sock;
  struct sockaddr_in storage_server_addr;

  storage_sock = socket(AF_INET, SOCK_STREAM, 0);
  if (storage_sock < 0)
  {
    perror("Failed to create socket for storage server");
    return -1;
  }

  storage_server_addr.sin_family = AF_INET;
  storage_server_addr.sin_port = htons(storage_port);
  if (inet_pton(AF_INET, storage_ip, &storage_server_addr.sin_addr) <= 0)
  {
    perror("Invalid storage server IP");
    close(storage_sock);
    return -1;
  }

  if (connect(storage_sock, (struct sockaddr *)&storage_server_addr, sizeof(storage_server_addr)) < 0)
  {
    perror("Failed to connect to storage server");
    close(storage_sock);
    return -1;
  }

  printf(GREEN " Connecting to storage server %s:%d\n" RESET, storage_ip, storage_port);

  return storage_sock;
}

// Handle CREATE command
void handle_create(int nm_sock, const char *full_path)
{
    // Check if the input path has an extension to determine if it's a file
    const char *ext = strrchr(full_path, '.'); // Find the last dot in the path
    if (ext != NULL) // If an extension exists, treat it as a file
    {
        // Create a file
        FILE *file = fopen(full_path, "wb");
        if (file)
        {
            fclose(file);
            if(path_count<MAX_PATHS){
                strcpy(accessible_paths[path_count],full_path);
                path_count++;
            }
            send_ack_to_nm(nm_sock, "CREATE_FILE_SUCCESS", full_path);
            printf(GREEN "File created successfully: %s\n" RESET, full_path);
        }
        else
        {
            send_ack_to_nm(nm_sock, "CREATE_FILE_FAILED", full_path);
            perror("Failed to create file");
        }
    }
    else
    {
        // Create a directory
        if (mkdir(full_path, 0755) == 0)
        {
            if(path_count<MAX_PATHS){
                strcpy(accessible_paths[path_count],full_path);
                path_count++;
            }
            send_ack_to_nm(nm_sock, "CREATE_DIR_SUCCESS", full_path);
            printf(GREEN "Directory created successfully: %s\n" RESET, full_path);
        }
        else
        {
            send_ack_to_nm(nm_sock, "CREATE_DIR_FAILED", full_path);
            perror("Failed to create directory");
        }
    }
}

// Helper function to recursively delete a directory and its contents
int delete_directory_recursive(const char *dir_path)
{
    DIR *dir = opendir(dir_path);
    if (!dir)
    {
        perror("Failed to open directory");
        return -1;
    }

    struct dirent *entry;
    char entry_path[4*MAX_PATH_LENGTH];

    while ((entry = readdir(dir)) != NULL)
    {
        // Skip "." and ".."
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
        {
            continue;
        }

        snprintf(entry_path, sizeof(entry_path), "%s/%s", dir_path, entry->d_name);

        struct stat entry_stat;
        if (stat(entry_path, &entry_stat) == -1)
        {
            perror("Failed to stat entry");
            closedir(dir);
            return -1;
        }

        if (S_ISDIR(entry_stat.st_mode))
        {
            // Recursively delete subdirectory
            if (delete_directory_recursive(entry_path) == -1)
            {
                closedir(dir);
                return -1;
            }
        }
        else
        {
            // Delete file
            int j;
            for(j=0;j< path_count;j++){
                if(strcmp(accessible_paths[j],entry_path)==0){
                pthread_mutex_lock(&file_mutex[j]);
                break;
                }
            }
            if (remove(entry_path) == -1)
            {
                perror("Failed to delete file");
                closedir(dir);
                return -1;
            }
            if(j<path_count){
                pthread_mutex_unlock(&file_mutex[j]);
            }
        }
    }

    closedir(dir);

    // Finally, delete the empty directory
    int j;
    for(j=0;j< path_count;j++){
        if(strcmp(accessible_paths[j],entry_path)==0){
            pthread_mutex_lock(&file_mutex[j]);
            break;
        }
    }
    if (rmdir(dir_path) == -1)
    {
        perror("Failed to delete directory");
        return -1;
    }
    if(j<path_count){
        pthread_mutex_unlock(&file_mutex[j]);
    }

    return 0;
}

// Handle DELETE command
void handle_delete(int nm_sock, const char *full_path)
{
    struct stat path_stat;

    // Get file/directory information
    if (stat(full_path, &path_stat) == -1)
    {
        send_ack_to_nm(nm_sock, "DELETE_FAILED", full_path);
        perror("Failed to stat path");
        return;
    }

    if (S_ISDIR(path_stat.st_mode))
    {
        // Attempt to delete the directory recursively
        if (delete_directory_recursive(full_path) == 0)
        {
            for(int j=0;j<path_count;j++){
                if(strncmp(accessible_paths[j],full_path,strlen(full_path))==0){
                    strcpy(accessible_paths[j],"Deleted");
                }
            }
            send_ack_to_nm(nm_sock, "DELETE_DIR_SUCCESS", full_path);
            printf(GREEN "Directory and its contents deleted successfully: %s\n" RESET, full_path);
        }
        else
        {
            send_ack_to_nm(nm_sock, "DELETE_DIR_FAILED", full_path);
            fprintf(stderr, "Failed to delete directory and its contents: %s\n", full_path);
        }
    }
    else if (S_ISREG(path_stat.st_mode))
    {
        // Attempt to delete the file
        int j;
        for(j=0;j< path_count;j++){
            if(strcmp(accessible_paths[j],full_path)==0){
                pthread_mutex_lock(&file_mutex[j]);
                break;
            }
        }
        if (remove(full_path) == 0)
        {
            for(int j=0;j<path_count;j++){
                if(strcmp(accessible_paths[j],full_path)==0){
                    strcpy(accessible_paths[j],"Deleted");
                    break;
                }
            }
            send_ack_to_nm(nm_sock, "DELETE_FILE_SUCCESS", full_path);
            printf(GREEN "File deleted successfully: %s\n" RESET, full_path);
        }
        else
        {
            send_ack_to_nm(nm_sock, "DELETE_FILE_FAILED", full_path);
            perror("Failed to delete file");
        }
        if(j<path_count){
            pthread_mutex_unlock(&file_mutex[j]);
        }
    }
    else
    {
        send_ack_to_nm(nm_sock, "DELETE_FAILED_UNKNOWN_TYPE", full_path);
        printf(RED "DELETE_FAILED_UNKNOWN_TYPE" RESET);
        fprintf(stderr, "Unknown type for path: %s\n", full_path);
    }
}

// Process commands from NM
void *process_nm_request(void *arg)
{   
    int nm_sock=naming_sock;
    char *buffer=(char *)arg;
    char command[16];
    char path[MAX_PATH_LENGTH];
    if(strncmp(buffer,"CREATE",6)==0){
        char name[MAX_PATH_LENGTH];
        int parsed = sscanf(buffer, "%s %s %s", command, path, name);

        if (parsed != 3)
        {
            fprintf(stderr, "Invalid command format from NM: %s\n", buffer);
            send_ack_to_nm(nm_sock, "INVALID_FORMAT", "");
            return NULL;
        }

        // Construct the full path
        char full_path[MAX_PATH_LENGTH * 2];
        snprintf(full_path, sizeof(full_path), "%s/%s", path, name);
        send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
        handle_create(nm_sock, full_path);
    }
    else if(strncmp(buffer,"DELETE",6)==0){
        int parsed = sscanf(buffer, "%s %s", command, path);
        if (parsed != 2)
        {
            fprintf(stderr, "Invalid command format from NM: %s\n", buffer);
            send_ack_to_nm(nm_sock, "INVALID_FORMAT", "");
            return NULL;
        }
        send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
        int j;
        for(j=0;j< path_count;j++){
            if(strcmp(accessible_paths[j],path)==0){
            pthread_mutex_lock(&file_mutex[j]);
            break;
            }
        }
        handle_delete(nm_sock, path);
    }
    else if (strncmp(buffer, "BACKUP_COPY",11)==0)
    {

        printf(PINK "entered backup_copy: %s\n" RESET,buffer);
        char src_path[MAX_PATH_LENGTH], dest_path[MAX_PATH_LENGTH];
        char dest_ip[INET_ADDRSTRLEN] = {0};
        int dest_port = 0;

        int parsed = sscanf(buffer, "BACKUP_COPY %s %s %s %d", src_path, dest_path, dest_ip, &dest_port);
        printf("DEBUG: BACKUP_COPY command parsed. src_path=%s, dest_path=%s, dest_ip=%s, dest_port=%d\n",
        src_path, dest_path, dest_ip[0] ? dest_ip : "NULL", dest_port);
        send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
        handle_copy_backup(nm_sock, src_path, dest_path, NULL, 0);
        // if (parsed == 2){
        //     send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
        //     handle_copy(nm_sock, src_path, dest_path, NULL, 0);
        // }
        // else if (parsed == 4)
        // {
        //     send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
        //     handle_copy(nm_sock, src_path, dest_path, dest_ip, dest_port);
        // }
        // else
        // {
        //     send_ack_to_nm(nm_sock, "INVALID_FORMAT", "COPY");
        //     printf("DEBUG: COPY command parsing failed.\n");
        // }
    }
    else if(strncmp(buffer, "COPY",4)==0){
        printf("REQUEST: %s\n",buffer);
        char src_path[MAX_PATH_LENGTH], dest_path[MAX_PATH_LENGTH];
        char dest_ip[INET_ADDRSTRLEN] = {0};
        int dest_port = 0;

        int parsed = sscanf(buffer, "COPY %s %s %s %d", src_path, dest_path, dest_ip, &dest_port);
            // printf("DEBUG: COPY command parsed. src_path=%s, dest_path=%s, dest_ip=%s, dest_port=%d\n",
            // src_path, dest_path, dest_ip[0] ? dest_ip : "NULL", dest_port);

        if (parsed == 2){
            send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
            handle_copy(nm_sock, src_path, dest_path, NULL, 0);
        }
        else if (parsed == 4)
        {
            send_ack_to_nm(nm_sock, "REQUEST ACKNOWLEDGMENT SUCCESS", "");
            handle_copy(nm_sock, src_path, dest_path, dest_ip, dest_port);
        }
        else
        {
            send_ack_to_nm(nm_sock, "INVALID_FORMAT", "COPY");
            printf(RED "INVALID FORMAT FOR COPY\n" RESET);
            //printf("DEBUG: COPY command parsing failed.\n");
        }
    }
    else if (strncmp(buffer, "BACKUP",6)==0)
    {
      char name[MAX_PATH_LENGTH];
      int parsed = sscanf(buffer, "%s %s", command, name);

      if (parsed != 2)
      {
          fprintf(stderr, "Invalid command format from NM: %s\n", buffer);
          send_ack_to_nm(nm_sock, "INVALID_FORMAT", "");
          return NULL;
      }
      char *home_dir = getenv("HOME");

      if (home_dir != NULL) {
        char *home_path = malloc(strlen(home_dir) + 1); // +1 for the null terminator
        if (home_path != NULL) {
            strcpy(home_path, home_dir); // Copy the path to the allocated memory
              char full_path[2*MAX_PATH_LENGTH];
              snprintf(full_path, sizeof(full_path), "%s/%s", home_path, name);
              printf ("%s\n", full_path);
              if (mkdir(full_path, 0755) == 0)
              {
                // printf ("\n%s\n", full_path);
                printf ("successfull creation\n");
                send (nm_sock, full_path, sizeof (full_path), 0);
                // printf("Directory created successfully: %s\n", full_path);
              //   for (int i = 0; i < storage->path_count; i++) {
              //   char *src_path = current_server->accessible_paths[i];

              //   // Backup to the first backup server
              //   char *dest_path_1 = backup_folder_1; // Destination path in backup server 1
              //   handle_copy(src_path, dest_path_1, storage_servers[backup_server_index_1].port);

              //   // Backup to the second backup server
              //   char *dest_path_2 = backup_folder_2; // Destination path in backup server 2
              //   handle_copy(src_path, dest_path_2, storage_servers[backup_server_index_2].port);
              // }
              }
            
        } 
    } 
    }
    else
    {
        int parsed = sscanf(buffer, "%s %s", command, path);
        fprintf(stderr, "Unknown command: %s\n", command);
        printf(RED "%s\n" RESET,command);
        send_ack_to_nm(nm_sock, "UNKNOWN_COMMAND", "");
    }
    return NULL;
}

void *listen_for_nm_requests(void *arg){
    char buffer[BUFFER_SIZE];
    pthread_t nm_threads[MAX_THREADS];
    int nm_thread_count=0;
    while (1)
    {
        if(shutdown_flag<0){
            break;
        }
        int bytes_received = recv(naming_sock, buffer, sizeof(buffer) - 1, 0);
        if (bytes_received>0)
        {
            buffer[bytes_received] = '\0';
            if(nm_thread_count<MAX_THREADS){
                pthread_create(&nm_threads[nm_thread_count],NULL,process_nm_request,buffer);
                nm_thread_count++;
            }
            else{
                printf(RED "MAX thread limit for clients reached. Cannot create more threads\n" RESET);
                break;
            }

        }
    }
    for(int j=0;j<nm_thread_count;j++){
        pthread_join(nm_threads[j],NULL);
    }
    close(naming_sock);
}