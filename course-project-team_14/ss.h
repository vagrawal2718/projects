#ifndef SS_H
#define SS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/sendfile.h>
#include <libgen.h>
#include <netdb.h>
#include <signal.h>

// Constants
#define BUFFER_SIZE 1024
#define MAX_PATHS 1024
#define MAX_PATH_LENGTH 512
#define MAX_THREADS 20

//Colours
#define RESET "\033[0m"
#define YELLOW "\033[1;33m"
#define PINK "\033[1;35m"
#define WHITE "\033[1;37m"
#define GREEN "\033[1;32m"
#define RED "\033[1;31m"

// Global Variables
extern int port_naming;
extern int port_client;
extern char accessible_paths[MAX_PATHS][MAX_PATH_LENGTH];
extern int path_count;
extern int naming_sock;
extern volatile sig_atomic_t shutdown_flag; 
extern char *naming_server_ip;

extern pthread_mutex_t file_mutex[MAX_PATHS];

// Accessible path functions
void append_path(const char *path);
void traverse_directory(const char *dir_path);
int register_with_naming_server(const char *naming_server_ip);

// NM request handling
void send_ack_to_nm(int nm_sock, const char *status, const char *path);
void handle_create(int nm_sock, const char *full_path);
void handle_delete(int nm_sock, const char *full_path);
void *process_nm_request(void *arg);
void *listen_for_nm_requests(void *arg);

// Client request handling
void send_ack_to_client(int client_sock, const char *status, const char *message);
void handle_read(int client_sock, const char *path);
void handle_write(int client_sock, const char *path, const char *data, int is_async);
void handle_stream(int client_sock, const char *path);
void handle_get_info(int client_sock, const char *path);
void process_client_request(int client_sock, const char *buffer);
void *listen_for_client_requests(void *arg);

//copy
void handle_copy(int nm_sock, const char *src_path, const char *dest_path, const char *dest_ip, int dest_port);
void traverse_and_copy(const char *src_dir, const char *dest_dir);
void copy_file(const char *src_file, const char *dest_file);
int connect_to_storage_server(const char *storage_ip, int storage_port);


#endif // SS_H
