#ifndef NM_H
#define NM_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <ctype.h>
#include <stdbool.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>   
#include <time.h>
#include <sys/sendfile.h>
#include <sys/stat.h>


#define MAX_STORAGE_SERVERS 10
#define MAX_CLIENTS 10
#define BUFFER_SIZE 1024
#define MAX_PATHS 25
#define MAX_PATH_LENGTH 256
#define PORT_NUM 6060
#define CACHE 5
#define MOD 1000000007
#define MAX_FILE_LENGTH 256
#define MAX_REQ_LENGTH 100
#define MAX_TIME_INTERVAL 3

#define RESET "\033[0m"
#define YELLOW "\033[1;33m"
#define PINK "\033[1;35m"
#define WHITE "\033[1;37m"
#define GREEN "\033[1;32m"
#define RED "\033[1;31m"
#define MAX_THREADS 100 // Define a maximum number of threads
//thread args for clients and SS
typedef struct thread_arg{
    int *new_sock_ptr;
    char *ip_address;
    int port;
}thread_arg;


//Storing of SS
typedef struct {
    int sock;
    char ip_address[INET_ADDRSTRLEN]; // IP Address of the Storage Server
    int nm_port;                      // Port for Naming Server communication
    int client_port;                  // Port for client communication
    char accessible_paths[MAX_PATHS][MAX_PATH_LENGTH]; // Array of accessible paths
    int path_count;                   // Number of accessible paths
    char path_backup1[MAX_PATH_LENGTH];               // path to home directory of backup ss
    char path_backup2[MAX_PATH_LENGTH];
} StorageServer;

extern StorageServer storage_servers[MAX_STORAGE_SERVERS];
extern int storage_server_count;

//thread for client and SS
extern pthread_mutex_t storage_mutex[MAX_STORAGE_SERVERS];
extern pthread_mutex_t client_mutex;
extern pthread_mutex_t trie_mutex;

// TRIE IMPLEMETATION
typedef struct trie {     // trie structure
    int storageServerID;
    bool checkFileorDir;  // true if file
    bool endOfWord;
    struct trie* desc[BUFFER_SIZE];
} trie;
extern trie* root; // global trie variable
trie* createtrienode();
void insertintotrie(trie** head, char* path, int serverID);
int search(trie* head, char* path);
void delete(trie** head, char* path);

//LRU implementation
typedef struct LRUCache{
    char path[MAX_PATH_LENGTH];
    int serverID;
    int levelNumber;
} LRUCache;
extern LRUCache LRU[CACHE];


int searchStorageServer(char* path, trie* head, LRUCache* LRU);

//Helper functions
int is_valid_ip(const char *str);
void set_nonblocking(int sock) ;
void set_blocking(int sock);
int count_substring_occurrences(char *str, char *sub);
void split_string_by_ack(const char *input, char **part1, char **part2) ;



//Book-keeping or Log
extern FILE *log_file;
void log_message(const char *ip_address, int port, const char *message);
void initialize_log_file();
void close_log_file();

int check_dir_or_not(char* name);
void traverse_directory(const char *dir_path);


#endif