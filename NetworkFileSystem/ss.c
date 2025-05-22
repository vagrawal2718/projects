#include "ss.h"
#include <ifaddrs.h>
#include <net/if.h> 

// Global Variables
int port_naming;
int port_client;
char accessible_paths[MAX_PATHS][MAX_PATH_LENGTH];
int path_count = 0;
int naming_sock=0;
pthread_mutex_t file_mutex[MAX_PATHS];
char *naming_server_ip;

int server_sock = 0;  // Made global for cleanup
volatile sig_atomic_t shutdown_flag = 0;  // Added for signal handling

void cleanup_resources() {
    // Close the naming server socket
    if (naming_sock > 0) {
        char buffer[BUFFER_SIZE];
        strcpy(buffer, "Server down\0");
        send(naming_sock, buffer, strlen(buffer), 0);
        close(naming_sock);

        int sock;
        struct sockaddr_in server_addr;

        sock = socket(AF_INET, SOCK_STREAM, 0);
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(port_naming);

        if (inet_pton(AF_INET, naming_server_ip, &server_addr.sin_addr) <= 0)
        {
            perror("Invalid Naming Server IP address");
            close(sock);
            exit(EXIT_FAILURE);
        }

        if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
        {
            perror("Connection to Naming Server failed");
            close(sock);
            exit(EXIT_FAILURE);
        }

        int bytes_rev=send(sock, buffer, strlen(buffer), 0);
        printf("%d\n", bytes_rev);
        close(sock);
    }

    // Close the server socket
    if (server_sock > 0) {
        close(server_sock);
    }
}

void sigint_handler(int signum) {
    // Set the shutdown flag
    shutdown_flag = 1;
    
    // Perform cleanup
    cleanup_resources();
    
    // Exit gracefully
    exit(EXIT_SUCCESS);
}

char* get_ip_address() {
    struct ifaddrs *ifaddr, *ifa;
    char *ip_address = NULL;

    // Get the list of network interfaces
    if (getifaddrs(&ifaddr) == -1) {
        perror("getifaddrs");
        return NULL;
    }

    // Loop through the linked list of interfaces
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        // Check if the interface is up and has an address
        if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_INET) { // IPv4
            // Allocate memory for the IP address string
            ip_address = malloc(INET_ADDRSTRLEN);
            if (ip_address == NULL) {
                perror("malloc");
                freeifaddrs(ifaddr);
                return NULL;
            }

            // Convert the address to a string
            if (inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr, ip_address, INET_ADDRSTRLEN) == NULL) {
                perror("inet_ntop");
                free(ip_address);
                freeifaddrs(ifaddr);
                return NULL;
            }

            // Check if the interface is not a loopback interface
            if (ifa->ifa_flags & IFF_LOOPBACK) {
                free(ip_address); // Free if it's a loopback address
                ip_address = NULL;
            } else {
                break; // Found a valid non-loopback IP address
            }
        }
    }

    freeifaddrs(ifaddr); // Free the linked list of interfaces
    return ip_address; // Return the IP address or NULL if not found
}

// Append path to the global list
void append_path(const char *path)
{
    if (path_count >= MAX_PATHS)
    {
        fprintf(stderr, "Error: Exceeded maximum number of accessible paths.\n");
        return;
    }
    strncpy(accessible_paths[path_count], path, MAX_PATH_LENGTH - 1);
    accessible_paths[path_count][MAX_PATH_LENGTH - 1] = '\0'; // Null-terminate
    path_count++;
}

// Recursively traverse directories
void traverse_directory(const char *dir_path)
{
    DIR *dir = opendir(dir_path);
    if (dir == NULL)
    {
        perror("Failed to open directory");
        return;
    }

    struct dirent *entry;
    char full_path[MAX_PATH_LENGTH * 2];

    append_path(dir_path);

    while ((entry = readdir(dir)) != NULL)
    {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
        {
            continue;
        }

        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);

        struct stat path_stat;
        if (lstat(full_path, &path_stat) == -1)
        {
            perror("Failed to stat path");
            continue;
        }

        if (S_ISDIR(path_stat.st_mode))
        {
            traverse_directory(full_path);
        }
        else if (S_ISREG(path_stat.st_mode))
        {
            append_path(full_path);
        }
    }

    closedir(dir);
}

int register_with_naming_server(const char *naming_server_ip)
{
    int sock;
    struct sockaddr_in server_addr;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0)
    {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port_naming);
    if (inet_pton(AF_INET, naming_server_ip, &server_addr.sin_addr) <= 0)
    {
        perror("Invalid Naming Server IP address");
        close(sock);
        exit(EXIT_FAILURE);
    }

    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
    {
        perror("Connection to Naming Server failed");
        close(sock);
        exit(EXIT_FAILURE);
    }

    printf(GREEN "Connection with naming server successfully\n" RESET);

    int n;
    printf("Enter number of accessible paths: ");
    scanf("%d", &n);
    if (n > MAX_PATHS)
    {
        fprintf(stderr, "Error: Exceeded maximum number of paths.\n");
        close(sock);
        exit(EXIT_FAILURE);
    }

    for (int i = 0; i < n; i++)
    {
        char input_path[MAX_PATH_LENGTH];
        printf("Enter path %d: ", i + 1);
        scanf("%s", input_path);
        // char curr_dir_path [4096];
        // if (getcwd(curr_dir_path, 4096) == NULL)
        // {
        //     perror("cwd path not obtained");
        //     return;
        // }
        // char temp[4096]="/";
        // strcat (temp, input_path);
        // strcpy (input_path, curr_dir_path);
        // strcat (input_path, temp);
        struct stat path_stat;
        if (lstat(input_path, &path_stat) == -1)
        {
            perror("Invalid path");
            continue;
        }

        if (S_ISDIR(path_stat.st_mode))
        {
            traverse_directory(input_path);
        }
        else if (S_ISREG(path_stat.st_mode))
        {
            append_path(input_path);
        }
        else
        {
            fprintf(stderr, "Unsupported file type: %s\n", input_path);
        }
    }

    char *ip_address_ss;
    ip_address_ss=get_ip_address();
    //printf("%s\n", ip_address_ss);

    char info[4096];
    snprintf(info, sizeof(info), "%s %d %d", ip_address_ss, port_naming, port_client);

    for (int i = 0; i < path_count; i++)
    {
        strcat(info, " ");
        strcat(info, accessible_paths[i]);
    }

    //printf("%s\n",info);

    if (send(sock, info, strlen(info), 0) < 0)
    {
        fprintf(stderr, "Failed to send data to Naming Server.\n");
        close(sock);
        exit(EXIT_FAILURE);
    }

    printf(GREEN "Registered with Naming Server with given info\n" RESET);

    return sock;
}

int main(int argc, char *argv[])
{
    if (argc != 4)
    {
        fprintf(stderr, "Usage: %s <NamingServerIP> <PortForNaming> <PortForClient>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    // Set up signal handler
    struct sigaction sa;
    sa.sa_handler = sigint_handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);
    
    if (sigaction(SIGINT, &sa, NULL) == -1) {
        perror("sigaction");
        exit(EXIT_FAILURE);
    }

    naming_server_ip = argv[1];
    port_naming = atoi(argv[2]);
    port_client = atoi(argv[3]);

    // Register with Naming Server
    naming_sock=register_with_naming_server(naming_server_ip);

    // Start thread for listening to nm requests
    pthread_t naming_thread;

    // int *nm_sock=(int *)malloc(sizeof(int));
    // *nm_sock=naming_sock;

    // Start the nm listener
    if (pthread_create(&naming_thread, NULL, listen_for_nm_requests,&naming_sock) != 0)
    {
        perror("Failed to create thread for nm requests");
        exit(EXIT_FAILURE);
    }

    // Start thread for listening to client requests
    pthread_t client_thread[MAX_THREADS];
    int client_thread_count=0;

    int server_sock;
    struct sockaddr_in server_addr, client_addr;
    socklen_t addr_size = sizeof(client_addr);

    // Create the socket
    server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock < 0)
    {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    // Bind the socket to port_client
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port_client);
    server_addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(server_sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
    {
        perror("Bind failed");
        close(server_sock);
        exit(EXIT_FAILURE);
    }

    if (listen(server_sock, 10) < 0)
    {
        perror("Listen failed");
        close(server_sock);
        exit(EXIT_FAILURE);
    }

    printf(GREEN "SS is listening for client requests on port %d...\n" RESET, port_client);

    for(int i=0;i< MAX_PATHS;i++){
        pthread_mutex_init(&file_mutex[i],NULL);
    }

    // Accept and process client requests
    while (1)
    {
        int client_sock = accept(server_sock, (struct sockaddr *)&client_addr, &addr_size);
        if (client_sock < 0)
        {
            if(shutdown_flag<0){
                break; //Exit loop if shutdown is required
            }
            perror("Failed to accept connection from client");
            continue;
        }

        int *sock_ptr=(int *)malloc(sizeof(int));
        *sock_ptr=client_sock;
        
        if(client_thread_count<MAX_THREADS){
            pthread_create(&client_thread[client_thread_count], NULL, listen_for_client_requests,sock_ptr);
            client_thread_count++;
        }
        else{
            printf(RED "MAX thread limit for clients reached. Cannot create more threads\n" RESET);
            free(sock_ptr);
            close(client_sock);
            break;
        }
        
    }

    for(int j=0;j<client_thread_count;j++){
        pthread_join(client_thread[j],NULL);
    }

    close(server_sock);

    // Wait for the nm thread to finish (though it'll run indefinitely)
    pthread_join(naming_thread, NULL);

    return 0;
}
