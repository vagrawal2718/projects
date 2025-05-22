#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/select.h>
#include <errno.h>   
#include <time.h>
#include <pthread.h>
#include <fcntl.h>   // For open()
#include <sys/stat.h> // For struct stat
#include <sys/types.h>
#include <sys/socket.h>
#include <signal.h>
#include <sys/wait.h> // For waitpid

#define BUFFER_SIZE 4096
#define MAX_TIME_INTERVAL 5

#define RESET "\033[0m"
#define YELLOW "\033[1;33m"
#define PINK "\033[1;35m"
#define WHITE "\033[1;37m"
#define GREEN "\033[1;32m"
#define RED "\033[1;31m"

void handle_list_dir(const char *path, int client_sock);
int receive_acknowledgment(int client_sock);
void receive_data(int storage_sock);
int connect_to_storage_server(const char *storage_ip, int storage_port, const char *request);
void handle_read(const char *path, int client_sock);
void handle_write(const char *request, int client_sock);
void handle_delete(const char *path, int client_sock);
void handle_create(const char *path, const char *file_name, int client_sock);
void handle_copy(const char *source, const char *destination, int client_sock);
void handle_stream(const char *path, int client_sock);
void handle_get_info(const char *path, int client_sock);
void handle_get_paths(int client_sock);
void handle_exit();

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <NM_IP_ADDRESS> <NM_PORT>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *naming_server_ip = argv[1];
    int naming_server_port = atoi(argv[2]);

    int client_sock;
    struct sockaddr_in naming_server_addr;
    char buffer[BUFFER_SIZE];

    //create socket
    client_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (client_sock < 0) {
        perror("Socket creation failed");
        exit(1);
    }

    //initialising naming server info
    naming_server_addr.sin_family = AF_INET;
    naming_server_addr.sin_port = htons(naming_server_port);
    naming_server_addr.sin_addr.s_addr = inet_addr(naming_server_ip);

    // Connect to the Naming Server
    if (connect(client_sock, (struct sockaddr*)&naming_server_addr, sizeof(naming_server_addr)) < 0) {
        perror("Connection to Naming Server failed");
        close(client_sock);
        exit(1);
    }

    printf(GREEN "Connected to NM\n" RESET);

    // while (1) {
        char request[BUFFER_SIZE];
        printf(YELLOW"Enter your request: " RESET);
        fgets(request, BUFFER_SIZE, stdin);

        if (send(client_sock, request, sizeof(request), 0) < 0) {
            perror("Error sending request to server\n");
            close(client_sock);
            exit(EXIT_FAILURE);
        }

        printf(GREEN"Sent the client request to NM\n" RESET);

        char request_dup[BUFFER_SIZE];
        strcpy(request_dup,request);

        // Parse the request and process based on the command
        char *command = strtok(request, " ");
        // if (command == NULL) continue;

        if (strcmp(command, "READ") == 0) {
            char *path = strtok(NULL, " ");
            if (path) handle_read(path, client_sock);
            else printf( RED "Error: Path required for READ\n" RESET);
        } else if (strcmp(command, "WRITE") == 0) {
            char *path = strtok(NULL, " ");
            char *text = strtok(NULL, " ");
            if (path && text) handle_write(request_dup, client_sock);
            else printf( RED "Error: Path and text required for WRITE\n" RESET);
        } else if (strcmp(command, "DELETE") == 0) {
            char *path = strtok(NULL, " ");
            if (path) handle_delete(path,client_sock);
            else printf( RED "Error: Path required for DELETE\n" RESET);
        } else if (strcmp(command, "CREATE") == 0) {
            char *path = strtok(NULL, " ");
            char *file_name = strtok(NULL, " ");
            if (path && file_name) handle_create(path, file_name,client_sock);
            else printf( RED "Error: Path and file name required for CREATE\n" RESET);
        } else if (strcmp(command, "COPY") == 0) {
            char *source = strtok(NULL, " ");
            char *destination = strtok(NULL, " ");
            if (source && destination) handle_copy(source, destination, client_sock);
            else printf(RED "Error: Source and destination paths required for COPY\n" RESET);
        } else if (strcmp(command, "STREAM") == 0) {
            char *path = strtok(NULL, " ");
            if (path) handle_stream(path, client_sock);
            else printf(RED "Error: Path required for STREAM\n" RESET);
        } else if (strcmp(command, "GET_INFO") == 0) {
            char *path = strtok(NULL, " ");
            if (path) handle_get_info(path, client_sock);
            else printf(RED "Error: Path required for GET_INFO\n" RESET);
        } else if (strcmp(command, "GET_PATHS") == 0) {
            handle_get_paths(client_sock);
        } 
        else if (strcmp(command, "LIST_DIR") == 0){
            char *path = strtok(NULL, " ");
            if (path)
                handle_list_dir(path, client_sock);
            else
                printf(RED "Error: Path required for LIST_DIR\n" RESET);
        }
        else if (strcmp(command, "EXIT") == 0) {
            handle_exit();
            //break;
        } else {
            printf( RED "Unknown command: %s\n" RESET, command);
        }
    // }

    // close(client_sock);
    // return 0;
}

int receive_acknowledgment(int client_sock) {
    //if received anything, acknowledged.
    char ack_buffer[BUFFER_SIZE];
    int bytes_received = recv(client_sock, ack_buffer, sizeof(ack_buffer) - 1, 0);
    if (bytes_received > 0) {
        ack_buffer[bytes_received] = '\0';
        printf(YELLOW "Server acknowledgment: %s\n" RESET, ack_buffer);
        if(strstr(ack_buffer,"SUCCESS")!=NULL){
            return 0;
        }
        else{
            return -1;
        }
    } else {
        printf(RED "No acknowledgment received from server or error occurred\n" RESET);
        return -1;
    }
}

void send_ack(int sock, char *msg){
    char ack_message[BUFFER_SIZE];
    snprintf(ack_message, sizeof(ack_message), "ACK: %s",msg);
    //printf("%s\n",ack_message);
    if(send(sock, ack_message, sizeof(ack_message), 0)<0){
        perror("error sending ackto nm");
    }
}

void check_and_split(const char *input, char **first_half, char **second_half) {
    const char *success_marker = "SUCCESS\n";
    size_t success_len = strlen(success_marker);

    size_t input_len = strlen(input);
    // Check if the string ends with "SUCCESS\n"
    if (input_len >= success_len && 
        strcmp(input + input_len - success_len, success_marker) == 0) {
        *first_half = strdup(input); // The whole string is valid
        *second_half = NULL;         // No need for a second half
        return;
    }

    // Find the last occurrence of "SUCCESS\n" in the input
    const char *last_success = NULL;
    const char *current_pos = strstr(input, success_marker);
    while (current_pos != NULL) {
        last_success = current_pos; // Update the last occurrence
        current_pos = strstr(current_pos + 1, success_marker);
    }

    if (last_success == NULL) {
        // If no "SUCCESS\n" is found, return the input as second half
        *first_half = NULL;
        *second_half = strdup(input);
        return;
    }

    // Split the string into two halves
    size_t first_half_len = last_success + success_len - input;
    *first_half = (char *)malloc(first_half_len + 1);
    strncpy(*first_half, input, first_half_len);
    (*first_half)[first_half_len] = '\0';

    *second_half = strdup(last_success + success_len);
}

void receive_data(int storage_sock) {
    char data_buffer[BUFFER_SIZE];
    int bytes_received;

    // int flag=0;
    // while((bytes_received=recv(storage_sock, data_buffer, sizeof(data_buffer) - 1, 0))>0){
    //     data_buffer[bytes_received] = '\0';

    //     char dup_data[BUFFER_SIZE];
    //     strcpy(dup_data,data_buffer);
    //     char *pos=strstr(dup_data,"STOP");
    //     if(pos){
    //         *pos='\0';
    //         printf("%s", dup_data);
    //         flag=1;
    //     }
    //     else{
    //         printf("%s", data_buffer);
    //     }
    // }
    // if(flag==0){
    //     printf("No data received from server or error occurred\n");
    // }

    bytes_received=recv(storage_sock, data_buffer, sizeof(data_buffer) - 1, 0);
    if (bytes_received > 0) {
        data_buffer[bytes_received] = '\0';
        printf("%s\n", data_buffer);
    } else {
        printf(RED "No data received from server or error occurred\n" RESET);
    }
}

int connect_to_storage_server(const char *storage_ip, int storage_port, const char *request) {
    //printf("%s %d\n",storage_ip,storage_port);
    int storage_sock;
    struct sockaddr_in storage_server_addr;

    storage_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (storage_sock < 0) {
        perror("Storage server socket creation failed");
        return -1;
    }

    storage_server_addr.sin_family = AF_INET;
    storage_server_addr.sin_port = htons(storage_port);
    storage_server_addr.sin_addr.s_addr = inet_addr(storage_ip);

    if (connect(storage_sock, (struct sockaddr*)&storage_server_addr, sizeof(storage_server_addr)) < 0) {
        perror("Connection to storage server failed");
        close(storage_sock);
        return -1;
    }

    printf(GREEN "Connected to storage server\n" RESET);

    if (send(storage_sock, request, strlen(request), 0) < 0) {
        perror("Error sending request to storage server");
        close(storage_sock);
        return -1;
    }

    printf(GREEN "Request sent to storage server\n" RESET);

    return storage_sock;
}

void handle_read(const char *path, int client_sock) {
    //receive_acknowledgment(client_sock);
    printf(PINK "Handling READ request for path: %s\n" RESET, path);
    // Prepare the read request
    char request[BUFFER_SIZE];
    snprintf(request, sizeof(request), "READ %s", path);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }

        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf( RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        char *ack;
        char *server_info;
        check_and_split(buffer,&ack,&server_info);
        if(server_info==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                server_info = strdup(buffer_2);  // Allocate memory and copy
                if (server_info == NULL) {
                    perror("Failed to allocate memory for server_info");
                    return;
                }
            }
            else{
                printf( RED "Failed to receive info about SS from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,server_info);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET,ack);
        }
        char *storage_ip = strtok(server_info, " ");
        char *port_str=strtok(NULL," ");
        if (storage_ip == NULL || port_str == NULL) {
            printf(RED "Invalid server info format: %s\n" RESET, server_info);
            //send_ack(client_sock,"INVALID FORMAT\n");
            free(server_info);
            return;
        }

        //send_ack(client_sock,"INFO RECEIVED\n");
        int storage_port = atoi(port_str);

        // Send the READ request to the storage server
        int storage_sock=connect_to_storage_server(storage_ip, storage_port, request);
        if(storage_sock>=0){
            receive_data(storage_sock);
        }

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf( RED "Failed to receive storage server information\n" RESET);
    }
}

void handle_write(const char *request, int client_sock) {
    //receive_acknowledgment(client_sock);
    printf(PINK "Handling request: %s" RESET,request);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }

        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf(RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        char *ack;
        char *server_info;
        check_and_split(buffer,&ack,&server_info);
        if(server_info==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                server_info = strdup(buffer_2);  // Allocate memory and copy
                if (server_info == NULL) {
                    perror("Failed to allocate memory for server_info");
                    return;
                }
            }
            else{
                printf(RED "Failed to receive info about SS from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,server_info);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET,ack);
        }
        char *storage_ip = strtok(server_info, " ");
        char *port_str=strtok(NULL," ");
        if (storage_ip == NULL || port_str == NULL) {
            printf(RED "Invalid server info format: %s\n" RESET, server_info);
            //send_ack(client_sock,"INVALID FORMAT\n");
            free(server_info);
            return;
        }

        //send_ack(client_sock,"INFO RECEIVED\n");
        int storage_port = atoi(port_str);

        // Send the READ request to the storage server
        int storage_sock=connect_to_storage_server(storage_ip, storage_port, request);

        if(storage_sock>0){
            char ack_buffer[BUFFER_SIZE];
            int bytes_received_3= recv(storage_sock, ack_buffer, sizeof(ack_buffer) - 1, 0);
            if (bytes_received_3> 0) {
                ack_buffer[bytes_received_3] = '\0';
                printf(GREEN "Server acknowledgment: %s\n" RESET, ack_buffer);
                if(strstr(ack_buffer,"ASYNC")!=NULL){
                    //printf("I'm here\n");
                    char buffer_4[BUFFER_SIZE];
                    int bytes_received_4 = -1;
                    // Loop to receive data 
                    while (1) {
                        bytes_received_4= recv(client_sock, buffer_4, sizeof(buffer_4) - 1, 0);
                        //printf("%d\n", bytes_received_4);
                        if (bytes_received_4 > 0) {
                            buffer_4[bytes_received_4] = '\0'; // Null-terminate the string
                            break;
                        }
                    }

                    if(bytes_received_4>0){
                        printf(YELLOW "%s\n" RESET,buffer_4);
                    }

                }

            } else {
                printf(RED "No acknowledgment received from server or error occurred\n" RESET);
            }
        }

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf(RED "Failed to receive storage server information\n" RESET);
    }
}

void handle_delete(const char *path, int client_sock) {
    if(receive_acknowledgment(client_sock)==0){
        printf(PINK "Handling DELETE request for path: %s\n" RESET, path);
        receive_acknowledgment(client_sock);
    }
}

void handle_create(const char *path, const char *file_name, int client_sock) {
    if(receive_acknowledgment(client_sock)==0){
        printf(PINK "Handling CREATE request for path: %s with file name: %s\n" RESET, path, file_name);
        receive_acknowledgment(client_sock);
    }
}

void handle_copy(const char *source, const char *destination, int client_sock) {
    if(receive_acknowledgment(client_sock)==0){
        printf( PINK "Handling COPY request from source: %s to destination: %s\n" RESET, source, destination);
        receive_acknowledgment(client_sock);
    }
}

static int stream_active = 1; // Global flag to control streaming thread
pthread_mutex_t stream_mutex = PTHREAD_MUTEX_INITIALIZER;

// Global variable to store mpv PID
pid_t mpv_pid = -1;
void *receive_and_play_audio(void *arg)
{
    int storage_sock = *(int *)arg;

    // Create a pipe to communicate with mpv
    int pipe_fds[2];
    if (pipe(pipe_fds) == -1)
    {
        perror("Failed to create pipe");
        close(storage_sock);
        return NULL;
    }

    // Fork a child process to run mpv
    mpv_pid = fork();
    if (mpv_pid == -1)
    {
        perror("Failed to fork");
        close(storage_sock);
        close(pipe_fds[0]);
        close(pipe_fds[1]);
        return NULL;
    }
    else if (mpv_pid == 0)
    {
        // Child process: Run mpv
        // Close write end of the pipe
        close(pipe_fds[1]);

        // Redirect stdin to read end of the pipe
        dup2(pipe_fds[0], STDIN_FILENO);
        close(pipe_fds[0]);

        // Execute mpv
        execlp("mpv", "mpv", "--no-terminal", "--no-video", "--volume=100", "--keep-open=yes", "--idle=yes", "-", NULL);


        // If execlp returns, an error occurred
        perror("Failed to exec mpv");
        exit(EXIT_FAILURE);
    }
    else
    {
        // Parent process
        // Close read end of the pipe
        close(pipe_fds[0]);

        // Now, you can write to mpv via pipe_fds[1]

        char buffer[BUFFER_SIZE];
        ssize_t bytes_received;

        while (1)
        {
            pthread_mutex_lock(&stream_mutex);
            if (!stream_active)
            {
                pthread_mutex_unlock(&stream_mutex);
                break;
            }
            pthread_mutex_unlock(&stream_mutex);

            bytes_received = recv(storage_sock, buffer, sizeof(buffer), 0);
            if (bytes_received > 0)
            {
                ssize_t bytes_written = write(pipe_fds[1], buffer, bytes_received);
                if (bytes_written < 0)
                {
                    perror("Failed to write to mpv pipe");
                    break;
                }
            }
            else if (bytes_received == 0)
            {
                // Server stopped streaming
                printf("Server has stopped streaming.\n");
                break;
            }
            else
            {
                perror("Failed to receive audio data");
                break;
            }
        }

        // Close write end of the pipe
        close(pipe_fds[1]);

        // Wait for mpv to exit
        waitpid(mpv_pid, NULL, 0);

        // Clean up
        close(storage_sock);
        return NULL;
    }
}

void handle_stream(const char *path, int client_sock) {
    //receive_acknowledgment(client_sock);
    printf(PINK "Handling STREAM request for path: %s\n" RESET, path);
    // Prepare the stream request
    char request[BUFFER_SIZE];
    snprintf(request, sizeof(request), "STREAM %s", path);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }
        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf( RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        if(strstr(buffer,"INVALID")!=NULL){
            printf(RED "%s\n" RESET, buffer);
            return;
        }
        char *ack;
        char *server_info;
        check_and_split(buffer,&ack,&server_info);
        if(server_info==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                server_info = strdup(buffer_2);  // Allocate memory and copy
                if (server_info == NULL) {
                    perror("Failed to allocate memory for server_info");
                    return;
                }
            }
            else{
                printf(RED "Failed to receive info about SS from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,server_info);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET,ack);
        }
        char *storage_ip = strtok(server_info, " ");
        char *port_str=strtok(NULL," ");
        if (storage_ip == NULL || port_str == NULL) {
            printf(RED "Invalid server info format: %s\n" RESET, server_info);
            //send_ack(client_sock,"INVALID FORMAT\n");
            free(server_info);
            return;
        }

        //send_ack(client_sock,"INFO RECEIVED\n");
        int storage_port = atoi(port_str);

        // Send the READ request to the storage server
        int storage_sock=connect_to_storage_server(storage_ip, storage_port, request);
        if(storage_sock<0){
            fprintf(stderr,"Failed to connect to storage server\n");
            return;
        }

        pthread_t audio_thread;
        stream_active = 1;

        // Start the streaming thread
        pthread_create(&audio_thread, NULL, receive_and_play_audio, &storage_sock);

        // Handle user commands for pause, resume, and stop
        char command[BUFFER_SIZE];
        while (1)
        {
            printf("Enter command (PAUSE/RESUME/STOP): ");
            fgets(command, sizeof(command), stdin);
            command[strcspn(command, "\n")] = '\0'; // Remove newline character

            if (strcmp(command, "PAUSE") == 0)
            {
                // Send SIGSTOP to mpv to pause it
                if (kill(mpv_pid, SIGSTOP) == 0)
                {
                    printf("mpv paused via SIGSTOP.\n");
                }
                else
                {
                    perror("Failed to send SIGSTOP to mpv");
                }

                // Send pause command to server to pause streaming
                send(storage_sock, "PAUSE", 5, 0);
            }
            else if (strcmp(command, "RESUME") == 0)
            {
                // Send SIGCONT to mpv to resume it
                if (kill(mpv_pid, SIGCONT) == 0)
                {
                    printf("mpv resumed via SIGCONT.\n");
                }
                else
                {
                    perror("Failed to send SIGCONT to mpv");
                }

                // Send resume command to server to resume streaming
                send(storage_sock, "RESUME", 6, 0);
            }
            else if (strcmp(command, "STOP") == 0)
            {
                // Send SIGTERM to mpv to stop it gracefully
                if (kill(mpv_pid, SIGTERM) == 0)
                {
                    printf("mpv stopped via SIGTERM.\n");
                }
                else
                {
                    perror("Failed to send SIGTERM to mpv");
                }

                // Optionally, if mpv doesn't terminate, send SIGKILL
                sleep(1); // Wait for a moment
                if (kill(mpv_pid, 0) == 0) // Check if mpv is still running
                {
                    kill(mpv_pid, SIGKILL);
                }

                // Send stop command to server to stop streaming
                send(storage_sock, "STOP", 4, 0);

                // Set stream_active to 0 to signal the streaming thread to exit
                pthread_mutex_lock(&stream_mutex);
                stream_active = 0;
                pthread_mutex_unlock(&stream_mutex);
                break;
            }
            else
            {
                printf("Unknown command. Use PAUSE, RESUME, or STOP.\n");
            }
        }

        // Wait for the streaming thread to finish
        pthread_join(audio_thread, NULL);

        printf(GREEN "Streaming completed.\n" RESET);

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf(RED "Failed to receive storage server information\n" RESET);
    }
}

void handle_get_info(const char *path, int client_sock) {

    //receive_acknowledgment(client_sock);
    printf(PINK "Handling GET_INFO request for path: %s\n" RESET, path);
    // Prepare the GET_INFO request
    char request[BUFFER_SIZE];
    snprintf(request, sizeof(request), "GET_INFO %s", path);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }

        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf(RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        char *ack;
        char *server_info;
        check_and_split(buffer,&ack,&server_info);
        if(server_info==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                server_info = strdup(buffer_2);  // Allocate memory and copy
                if (server_info == NULL) {
                    perror("Failed to allocate memory for server_info");
                    return;
                }
            }
            else{
                printf(RED "Failed to receive info about SS from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,server_info);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET,ack);
        }
        char *storage_ip = strtok(server_info, " ");
        char *port_str=strtok(NULL," ");
        if (storage_ip == NULL || port_str == NULL) {
            printf(RED "Invalid server info format: %s\n" RESET, server_info);
            //send_ack(client_sock,"INVALID FORMAT\n");
            free(server_info);
            return;
        }

        //send_ack(client_sock,"INFO RECEIVED\n");
        int storage_port = atoi(port_str);

        // Send the READ request to the storage server
        int storage_sock=connect_to_storage_server(storage_ip, storage_port, request);
        if(storage_sock>=0){
            receive_data(storage_sock);
        }

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf(RED "Failed to receive storage server information\n" RESET);
    }

}

void handle_get_paths(int client_sock) {
    //receive_acknowledgment(client_sock);
    printf(PINK "Handling GET_PATHS request\n" RESET);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }

        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf(RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        char *ack;
        char *paths_list;
        check_and_split(buffer,&ack,&paths_list);
        if(paths_list==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                paths_list = strdup(buffer_2);  // Allocate memory and copy
                if (paths_list == NULL) {
                    perror("Failed to allocate memory for paths");
                    return;
                }
            }
            else{
                printf(RED "Failed to receive paths list from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,paths_list);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET ,ack);
        }

        printf("Received paths from the Naming Server:\n");
        char *path_token = strtok(paths_list, " ");  // Assuming each path is separated by a space
        while (path_token != NULL) {
            printf("%s\n", path_token);  // Print each path
            path_token = strtok(NULL, " ");  // Move to the next path
        }

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf(RED "Failed to receive paths from the Naming server\n" RESET);
    }
}

void handle_list_dir(const char *path, int client_sock)
{
    //receive_acknowledgment(client_sock);
    printf(PINK "Handling LIST_DIR request for path: %s\n" RESET, path);
    // Prepare the LIST_DIR request
    char request[BUFFER_SIZE];
    snprintf(request, sizeof(request), "LIST_DIR %s", path);

    // Timer variables
    clock_t start_time = clock();
    char buffer[BUFFER_SIZE];
    int bytes_received = -1;

    // Loop to receive data with a timeout
    while (1) {
        bytes_received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);

        if (bytes_received > 0) {
            buffer[bytes_received] = '\0'; // Null-terminate the string
            break;
        }

        // Check elapsed time
        clock_t current_time = clock();
        double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
        if (elapsed_time > MAX_TIME_INTERVAL) {
            printf(RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
            break;
        }
    }
    
    // Handle the data
    if (bytes_received > 0) {
        //printf("%s\n",buffer);
        char *ack;
        char *server_info;
        check_and_split(buffer,&ack,&server_info);
        if(server_info==NULL){
            char buffer_2[BUFFER_SIZE];
            int bytes_received_2=recv(client_sock, buffer_2, sizeof(buffer_2)-1,0);
            if(bytes_received_2>0){
                buffer_2[bytes_received_2]='\0';
                server_info = strdup(buffer_2);  // Allocate memory and copy
                if (server_info == NULL) {
                    perror("Failed to allocate memory for server_info");
                    return;
                }
            }
            else{
                printf(RED "Failed to receive info about SS from NM\n" RESET);
                return;
            }
        }
        else if(ack==NULL){
            printf(RED "%s\n" RESET,server_info);
            return;
        }
        else{
            printf(GREEN "%s\n" RESET,ack);
        }
        char *storage_ip = strtok(server_info, " ");
        char *port_str=strtok(NULL," ");
        if (storage_ip == NULL || port_str == NULL) {
            printf(RED "Invalid server info format: %s\n" RESET, server_info);
            //send_ack(client_sock,"INVALID FORMAT\n");
            free(server_info);
            return;
        }

        //send_ack(client_sock,"INFO RECEIVED\n");
        int storage_port = atoi(port_str);

        // Send the READ request to the storage server
        int storage_sock=connect_to_storage_server(storage_ip, storage_port, request);
        if(storage_sock>=0){
            receive_data(storage_sock);
        }

    } else {
        //send_ack(client_sock,"INFO NOT RECEIVED\n");
        printf(RED "Failed to receive storage server information\n" RESET);
    }
}

void handle_exit() {
    printf(PINK "Handling EXIT request\n" RESET);
    exit(1);
}