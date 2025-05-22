#include "nm.h"

#define A_SYNC_THHRESHOLD 1000
char accessible_paths[MAX_PATHS][MAX_PATH_LENGTH];
int path_count = 0;
pthread_mutex_t storage_mutex[MAX_STORAGE_SERVERS];
pthread_mutex_t path_count_mutex=PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t client_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t trie_mutex=PTHREAD_MUTEX_INITIALIZER;
trie *root=NULL; // global trie variable
int storage_server_count=0;
LRUCache LRU[CACHE];
FILE *log_file;

StorageServer storage_servers[MAX_STORAGE_SERVERS];

void create_backup_directory(int server_index, char backup_folder[], char* ans_path) {
    // Create a command to create the backup directory
    char create_backup_cmd[BUFFER_SIZE];
    snprintf(create_backup_cmd, sizeof(create_backup_cmd), "BACKUP %s", backup_folder);
    // Send the command to the specified storage server
    send(storage_servers[server_index].sock, create_backup_cmd, strlen(create_backup_cmd), 0);
    char ack_buffer[BUFFER_SIZE];
    //  printf ("###########\n");
    int bytes_received = read(storage_servers[server_index].sock, ans_path, MAX_PATH_LENGTH-1);
    if (bytes_received > 0) {
        ans_path[bytes_received] = '\0'; // Null-terminate the received string
        // char status[10]; // Adjust size as needed
        // char path[MAX_PATH_LENGTH];
        // if (sscanf(ans_path, "%s", ack_buffer) == 1) {
        //     printf ("%s\n", ack_buffer);
        //     *ans_path= path;
            printf ("\n%s\n", ans_path);
            return;
        // } else {
        //     fprintf(stderr, "Failed to parse acknowledgment message: %s\n", ack_buffer);
        //     return;
        // }
    }
    else 
    printf("No acknowledgment received from server %d\n", server_index);

}

void backup_storage_server(int new_server_index) {
    if (storage_server_count >= 2) {
        // Get the current storage server
        StorageServer *current_server = &storage_servers[new_server_index];

        // Get the indices of the backup servers
        int backup_server_index_1 = new_server_index - 1;
        int backup_server_index_2 = new_server_index - 2;

        // Define backup folder names
        char backup_folder_1[BUFFER_SIZE];
        char backup_folder_2[BUFFER_SIZE];
        snprintf(backup_folder_1, sizeof(backup_folder_1), "backup_%d_%d",new_server_index, backup_server_index_1); // Assuming the first path is the base path
        snprintf(backup_folder_2, sizeof(backup_folder_2), "backup_%d_%d",new_server_index, backup_server_index_2); // Assuming the first path is the base path

        // Create backup directories in the backup servers
        create_backup_directory(backup_server_index_1, backup_folder_1, current_server->path_backup1);
        printf ("path_backup1 %s\n",current_server->path_backup1);
        create_backup_directory(backup_server_index_2, backup_folder_2, current_server->path_backup2);
        printf ("path_backup2 %s\n",current_server->path_backup2);
        // Backup to the previous two storage servers
        for (int i = 0; i < current_server->path_count; i++) {
            for (int j=0; j<=i; j++)
            {
                if (j!=i || i==0)
                {
                    char *src_path1 = current_server->accessible_paths[i];
                    char *src_path2 = current_server->accessible_paths[j];
                    if (strstr (src_path1, src_path2)!=NULL)
                    {
                        char *dest_path_1 = current_server->path_backup1; // Destination path in backup server 1
                        char comm1[MAX_REQ_LENGTH];
                        snprintf(comm1, sizeof(comm1), "BACKUP_COPY %s %s %s %d",
                        src_path1, dest_path_1, storage_servers[backup_server_index_1].ip_address,
                        storage_servers[backup_server_index_1].client_port); // Assuming the first path is the base path
                        
                        printf ("\n%s\n", comm1);
                        send(current_server->sock, comm1, strlen(comm1), 0);

                        // Wait for intial acknowledgment from SS
                        char ack_buffer[BUFFER_SIZE];
                        int bytes_read = read(current_server->sock, ack_buffer, sizeof(ack_buffer) - 1);
                        if (bytes_read > 0)
                        {
                            ack_buffer[bytes_read]='\0';
                            printf("%s\n",ack_buffer);
                            char ack_buffer_2[BUFFER_SIZE];
                            //wait for final acknowledgment from SS
                            int bytes_2=read(current_server->sock,ack_buffer_2,sizeof(ack_buffer_2)-1);
                            if(bytes_2>0){
                                ack_buffer_2[bytes_2]='\0';
                                printf("%s\n",ack_buffer_2);
                            }
                            else{
                                printf("No final acknowledgment received from backup_SS1\n");
                            }
                        }
                        else{
                            printf("No initial acknowledgment received from backup_SS1\n");
                        }

                        char *dest_path_2 = current_server->path_backup2; // Destination path in backup server 1
                        char comm2[MAX_REQ_LENGTH];
                        snprintf(comm2, sizeof(comm2), "BACKUP_COPY %s %s %s %d",
                        src_path1, dest_path_2, storage_servers[backup_server_index_2].ip_address,
                        storage_servers[backup_server_index_2].client_port); // Assuming the first path is the base path
                        
                        printf ("\n%s\n", comm2);
                        send(current_server->sock, comm2, strlen(comm2), 0);

                        // Wait for intial acknowledgment from SS
                        char ack_buffer_3[BUFFER_SIZE];
                        int bytes_read_3 = read(current_server->sock, ack_buffer_3, sizeof(ack_buffer_3) - 1);
                        if (bytes_read_3 > 0)
                        {
                            ack_buffer_3[bytes_read_3]='\0';
                            printf("%s\n",ack_buffer_3);
                            char ack_buffer_4[BUFFER_SIZE];
                            //wait for final acknowledgment from SS
                            int bytes_4=read(current_server->sock,ack_buffer_4,sizeof(ack_buffer_4)-1);
                            if(bytes_4>0){
                                ack_buffer_4[bytes_4]='\0';
                                printf("%s\n",ack_buffer_4);
                            }
                            else{
                                printf("No final acknowledgment received from backup_SS2\n");
                            }
                        }
                        else{
                            printf("No initial acknowledgment received from backup_SS2\n");
                        }
                        // handle_copy(src_path1, dest_path_1, storage_servers[backup_server_index_1].port);
                        // char *dest_path_2 = storage_servers[new_server_index].path_backup2; // Destination path in backup server 2
                        // handle_copy(src_path1, dest_path_2, storage_servers[backup_server_index_2].port);
                    }
                    else
                    break;
                }
            }
        }
    }
}

int check_dir_or_not(char* name){
    DIR *dir=opendir(name);
    if (dir!=NULL) {
        closedir(dir);
        return 0;
    }
    return 1;
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
    pthread_mutex_lock(&path_count_mutex);
    path_count++;
    pthread_mutex_unlock(&path_count_mutex);
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

// searching for the storage server
int searchStorageServer(char* path, trie* head, LRUCache* LRU){
    // long long hashedadd=0;
    // for (int i=0;i<strlen(path);i++){
    //     hashedadd=(hashedadd*23+(path[i]-'a'))%(MOD);
    // }
    for (int i=0;i<CACHE;i++){
        LRU[i].levelNumber+=1;
    }
    int mlevel=-1;
    int mind=-1;
    for (int i=0;i<CACHE;i++){
        if (mlevel<LRU[i].levelNumber){
            mlevel=LRU[i].levelNumber;
            mind=i;
        }
        if (strcmp(LRU[i].path, path)==0){
            LRU[i].levelNumber=0;
            return LRU[i].serverID;
        }
    }
    LRU[mind].serverID=search(root, path);
    if (LRU[mind].serverID==-1){
        LRU[mind].path[0]='\0';
        LRU[mind].levelNumber=1e9;
    }
    else{
        strcpy(LRU[mind].path, path);
        LRU[mind].levelNumber=0;
    }
    //printf("HII\n");
    return LRU[mind].serverID;
}

int ss_ack_handling(int ss_num,int client_sock, char *ip_address,int port,char *req){
    int return_val=1;
    clock_t start_time = clock();
        char ack1[BUFFER_SIZE];
        int bytes_read;
        while((bytes_read=read(storage_servers[ss_num].sock, ack1, BUFFER_SIZE - 1))<0){
            // Check elapsed time
            clock_t current_time = clock();
            double elapsed_time = (double)(current_time - start_time) / CLOCKS_PER_SEC;
            if (elapsed_time > MAX_TIME_INTERVAL) {
                printf(RED "Timeout: No data received within %d seconds.\n" RESET, MAX_TIME_INTERVAL);
                sprintf(ack1," No akn from ss: Timeout\n");
                send(client_sock, ack1, strlen(ack1), 0);
                return -1;
            }
        }
        if (bytes_read > 0) {
            ack1[bytes_read] = '\0';

            int count=count_substring_occurrences(ack1,"ACK:");
            if(count>1){
                char *ack_1;
                char *ack_2;
                split_string_by_ack(ack1,&ack_1,&ack_2);
                printf(GREEN "%s\n" RESET,ack_1);

                //log the initial ack from SS
                char log_msg_2[2*BUFFER_SIZE];
                sprintf(log_msg_2," Initial SS ack for %s => %s",req,ack_1);
                log_message(ip_address,port, log_msg_2);

                printf(GREEN "%s\n" RESET,ack_2);
                //log the final ack from SS
                char log_msg_3[2*BUFFER_SIZE];
                sprintf(log_msg_3," Final SS ack for %s => %s",req,ack_2);
                log_message(ip_address,port, log_msg_3);

                if(strstr(ack_2,"SUCCESS")!=NULL){
                    return_val=0;
                }
                //send  final ack to client
                send(client_sock, ack_2, strlen(ack_2), 0);
                return-1;
            }
            else if(count<=0){
                printf(RED "%s\n" RESET,ack1);
                send(client_sock, ack1, strlen(ack1), 0);
                return -1;
            }

            printf(GREEN "%s\n" RESET,ack1);
            
            //log the initial ack from SS
            char log_msg_2[2*BUFFER_SIZE];
            sprintf(log_msg_2," Initial SS ack for %s => %s",req,ack1);
            log_message(ip_address,port, log_msg_2);

            //set sock to non_blocking mode
            set_nonblocking(storage_servers[ss_num].sock);

            //receive final ack from SS
            char buf[BUFFER_SIZE];
            memset(buf, 0, sizeof(buf));
            int bytes_read2;
            while((bytes_read2=read(storage_servers[ss_num].sock, buf, BUFFER_SIZE - 1))<0){
            }

            if (bytes_read2 > 0) {
                buf[bytes_read2] = '\0';
                if (strstr (buf, "STOP")==0){

                    //log the ack from SS
                    char log_msg_3[2*BUFFER_SIZE];
                    sprintf(log_msg_3," Final SS ack for %s => %s",req, buf);
                    log_message(ip_address,port, log_msg_3);

                    if(strstr(buf,"SUCCESS")!=NULL){
                        return_val=0;
                    }

                    // send acknowledgement to client
                    printf(GREEN "%s\n" RESET ,buf);
                    send(client_sock, buf, strlen(buf), 0);
                }
            }
            else if(bytes_read2==0){
                char msg[]="ACK from SS not received";
                send(client_sock, msg, strlen(msg), 0);
            }
            set_blocking(storage_servers[ss_num].sock);
        } 

    return return_val;
}

void execute_request_client (char* buffer, int client_sock, char *ip_address, int port) {

    //logging the client request
    char log_msg[BUFFER_SIZE];
    sprintf(log_msg," Client request=> %s",buffer);
    log_message(ip_address,port, log_msg);

    //printf ("%s\n", buffer);
    int len = strlen(buffer);
    while (len > 0 && (buffer[len-1]==' ' || buffer[len-1]=='\t') || buffer[len-1]=='\n') 
    {
        len--;
    }
    buffer[len] = '\0';
    if (buffer != NULL)
    {
        while (*buffer == ' ' || *buffer=='\t')
        buffer++;
    }

    char comm[MAX_REQ_LENGTH];
    char dup_buffer[MAX_REQ_LENGTH];
    strcpy (dup_buffer, buffer);
    strcpy (comm, buffer);
    char *token;
    char command [10];
    token = strtok(buffer, " ");
    strcpy (command, token);

    if (strstr (command, "CREATE")!=NULL)
    {
        char path[MAX_PATH_LENGTH];
        char file_name[MAX_FILE_LENGTH];
        token = strtok(NULL, " ");
        if(token==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        strcpy (path, token);
        token = strtok(NULL, " ");
        if(token==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        strcpy (file_name, token);
        int ss_num= searchStorageServer (path, root, LRU);
        if(ss_num==-1){
            char req_ack[]="PATH DOESN'T EXIST";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        //sending intial request acknowledgment
        char req_ack[]="REQUEST ACKNOWLEDGMENT SUCCESS";
        send(client_sock, req_ack, strlen(req_ack),0);

        //sending request to SS
        pthread_mutex_lock(&storage_mutex[ss_num]);
        send(storage_servers[ss_num].sock, comm, strlen(comm), 0);

        int success=ss_ack_handling(ss_num,client_sock,ip_address,port,dup_buffer);
        pthread_mutex_unlock(&storage_mutex[ss_num]);
        if(success==0){
            // store it in the storage server struct
            char newpath[MAX_PATH_LENGTH];
            strcpy(newpath, path);
            strcat(newpath, "/");
            strcat(newpath, file_name);
            if (ss_num!=-1){
                pthread_mutex_lock(&trie_mutex);
                insertintotrie(&root, newpath, ss_num);
                pthread_mutex_unlock(&trie_mutex);

                // insert to backup folder
                char insert_backup1[6*MAX_REQ_LENGTH];
                snprintf(insert_backup1, sizeof(insert_backup1), 
                "BACKUP_COPY %s %s %s %d", path, storage_servers[ss_num].path_backup1,
                storage_servers[ss_num-1].ip_address, storage_servers[ss_num-1].client_port);
                send(storage_servers[ss_num].sock, insert_backup1, strlen(insert_backup1), 0);

                char insert_backup2[6*MAX_REQ_LENGTH];
                snprintf(insert_backup2, sizeof(insert_backup2), 
                "BACKUP_COPY %s %s %s %d", path, storage_servers[ss_num].path_backup2,
                storage_servers[ss_num-2].ip_address, storage_servers[ss_num-2].client_port);
                send(storage_servers[ss_num].sock, insert_backup2, strlen(insert_backup2), 0);

                pthread_mutex_lock(&storage_mutex[ss_num]);
                int index=storage_servers[ss_num].path_count;
                strcpy(storage_servers[ss_num].accessible_paths[index], newpath);
                storage_servers[ss_num].path_count+=1;
                pthread_mutex_unlock(&storage_mutex[ss_num]);
            }
        }
    }
    else if(strstr(command, "DELETE")!=NULL){
        char path[MAX_PATH_LENGTH];
        token = strtok(NULL, " ");
        if(token==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        strcpy (path, token);
        int ss_num= searchStorageServer (path, root, LRU);
        if(ss_num==-1){
            char req_ack[]="PATH DOESN'T EXIST";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        //sending intial request acknowledgment
        char req_ack[]="REQUEST ACKNOWLEDGMENT SUCCESS";
        send(client_sock, req_ack, strlen(req_ack),0);

        //sending request to SS
        pthread_mutex_lock(&storage_mutex[ss_num]);
        send(storage_servers[ss_num].sock, comm, strlen(comm), 0);

        int success=ss_ack_handling(ss_num,client_sock,ip_address,port,dup_buffer);
        pthread_mutex_unlock(&storage_mutex[ss_num]);
        if(success==0){
            // store it in the storage server struct
            char newpath[4096];
            strcpy(newpath, path);
            if (ss_num!=-1){
                int index=storage_servers[ss_num].path_count;
                for (int i=0;i<index;i++){
                    if (strcmp(storage_servers[ss_num].accessible_paths[i], newpath)==0){
                        pthread_mutex_lock(&storage_mutex[ss_num]);
                        delete(&root, storage_servers[ss_num].accessible_paths[i]);
                        storage_servers[ss_num].path_count-=1;
                        strcpy(storage_servers[ss_num].accessible_paths[i],"Deleted\0");
                        pthread_mutex_unlock(&storage_mutex[ss_num]);
                        break;
                    }
                }
                strcat(newpath,"/");
                for (int i=0;i<index;i++){
                    if (strstr(storage_servers[ss_num].accessible_paths[i], newpath)!=NULL){
                        pthread_mutex_lock(&storage_mutex[ss_num]);
                        delete(&root, storage_servers[ss_num].accessible_paths[i]);
                        storage_servers[ss_num].path_count-=1;
                        strcpy(storage_servers[ss_num].accessible_paths[i],"Deleted\0");
                        pthread_mutex_unlock(&storage_mutex[ss_num]);
                    }
                }
            }
        }
    }
    else if(strstr(command, "COPY")!=NULL){
        char src_path[MAX_PATH_LENGTH], dest_path[MAX_PATH_LENGTH];
        token = strtok(NULL, " ");
        if(token==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        strcpy(src_path, token);
        token = strtok(NULL, " ");
        if(token==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        strcpy(dest_path, token);

        int src_ss = searchStorageServer(src_path,root,LRU);
        int dest_ss = searchStorageServer(dest_path,root,LRU);

        if (src_ss == -1 || dest_ss == -1){
            char req_ack[]="PATH DOESN'T EXIST";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }

        // Acknowledge receipt of COPY request
        char initial_ack[] = "REQUEST_ACKNOWLEDGMENT_SUCCESS";
        send(client_sock, initial_ack, strlen(initial_ack), 0);

        if (src_ss == dest_ss){
            // Local Copy
            char request[BUFFER_SIZE];
            snprintf(request, sizeof(request), "COPY %s %s", src_path, dest_path);
            pthread_mutex_lock(&storage_mutex[src_ss]);
            send(storage_servers[src_ss].sock, request, strlen(request), 0);
        }
        else
        {
            // Cross-server Copy
            char request[BUFFER_SIZE];
            snprintf(request, sizeof(request), "COPY %s %s %s %d",
                    src_path,
                    dest_path,
                    storage_servers[dest_ss].ip_address,
                    storage_servers[dest_ss].client_port);

            pthread_mutex_lock(&storage_mutex[src_ss]);
            send(storage_servers[src_ss].sock, request, strlen(request), 0);

        }

        int success=ss_ack_handling(src_ss,client_sock,ip_address,port,dup_buffer);
        pthread_mutex_unlock(&storage_mutex[src_ss]);
        if(success==0){
            if (check_dir_or_not(src_path)==1 && check_dir_or_not(dest_path)==0){
                const char *lastSlash = strrchr(src_path, '/'); // Find the last '/' in the path
                if (lastSlash == NULL) {
                    // No '/' found, the entire path is the file name
                    return;
                }
                //strcat(dest_path, "/");
                strcat(dest_path, lastSlash);
                pthread_mutex_lock(&trie_mutex);
                insertintotrie(&root, dest_path, dest_ss);
                pthread_mutex_unlock(&trie_mutex);
                int indexx=storage_servers[dest_ss].path_count;
                pthread_mutex_lock(&storage_mutex[dest_ss]);
                strcpy(storage_servers[dest_ss].accessible_paths[indexx], dest_path);
                storage_servers[dest_ss].path_count+=1;
                pthread_mutex_unlock(&storage_mutex[dest_ss]);
            }
            else if (check_dir_or_not(src_path)==0 && check_dir_or_not(dest_path)==0){
                const char *lastSlash = strrchr(src_path, '/'); // Find the last '/' in the path
                if (lastSlash == NULL) {
                    // No '/' found, the entire path is the file name
                    return;
                }
                // strcat(dest_path, "/");
                // strcat(dest_path, src_path);
                traverse_directory(src_path);
                int indexx=storage_servers[dest_ss].path_count;
                for (int i=0;i<path_count;i++){
                    char temp[4096];
                    strcpy(temp, accessible_paths[i]);
                    char dummy[4096];
                    strcpy(dummy, dest_path);
                    //strcat(dummy, "/");
                    strcat(dummy, lastSlash);
                    strcat(dummy, temp+strlen(src_path));
                    strcpy(accessible_paths[i], dummy);
                }
                int j=0;
                while(j<path_count){
                    pthread_mutex_lock(&storage_mutex[dest_ss]);
                    strcpy(storage_servers[dest_ss].accessible_paths[indexx], accessible_paths[j]);
                    pthread_mutex_unlock(&storage_mutex[dest_ss]);
                    pthread_mutex_lock(&trie_mutex);
                    insertintotrie(&root, accessible_paths[j], dest_ss);
                    pthread_mutex_unlock(&trie_mutex);
                    accessible_paths[j][0]='\0';
                    j++;
                    indexx++;
                    pthread_mutex_lock(&storage_mutex[dest_ss]);
                    storage_servers[dest_ss].path_count+=1;
                    pthread_mutex_unlock(&storage_mutex[dest_ss]);
                }
            }
            pthread_mutex_lock(&path_count_mutex);
            path_count=0;
            pthread_mutex_unlock(&path_count_mutex);
        }

    }
    else if (strstr (command, "READ")!=NULL 
    ||strstr (command, "WRITE")!=NULL 
    ||strstr (command, "GET_INFO")!=NULL
    ||strstr (command, "STREAM")!=NULL
    ||strstr (command, "LIST_DIR")!=NULL)
    {
        int flag=0;
        if(strstr(command,"WRITE")!=NULL){
            flag=1;
        }
        char* dummy=strtok(comm, " ");
        if(dummy==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        char* path=strtok(NULL, " ");
        if(dummy==NULL){
            char req_ack[]="INAVLID FORMAT";
            printf(RED "%s\n" RESET,req_ack);
            send(client_sock, req_ack, strlen(req_ack),0);
            return;
        }
        if(strstr(command,"STREAM")!=NULL){
            if(strstr(path,".mp3")==NULL){
                char req_ack[]="INAVLID FORMAT";
                printf(RED "%s\n" RESET,req_ack);
                send(client_sock, req_ack, strlen(req_ack),0);
                return;
            }
        }
        int check=searchStorageServer(path, root, LRU);
        //printf("check %d\n",check);
        if (check==-1){
            char req_ack[]="PATH DOESN'T EXIST\n";
            send(client_sock, req_ack, strlen(req_ack),0);
            printf(RED "This path does not exist\n" RESET);
        }
        else{
            //sending intial request acknowledgment
            char req_ack[]="REQUEST ACKNOWLEDGMENT SUCCESS\n";
            send(client_sock, req_ack, strlen(req_ack),0);

            char request[MAX_REQ_LENGTH];
            sprintf(request, "%s %d", storage_servers[check].ip_address, storage_servers[check].client_port);
            
            //sending data
            if(send(client_sock, request, sizeof(request), 0)>0){
                printf(PINK "Sent information about storage server to client\n" RESET);
            }
            else{
                perror("Send error:");
            }
    
            if(flag>0){
                char *text=strtok(NULL," ");
                if(strstr(text,"--SYNC")!=NULL || strlen(text)>A_SYNC_THHRESHOLD){
                    //A_SYNC
                    //set sock to non_blocking mode
                    set_nonblocking(storage_servers[check].sock);

                    char buf[BUFFER_SIZE];
                    memset(buf, 0, sizeof(buf));

                    int bytes_read;
                    while((bytes_read=read(storage_servers[check].sock, buf, BUFFER_SIZE - 1))<=0){
                    }
                    if (bytes_read > 0) {
                        buf[bytes_read] = '\0';
                        if (strstr (buf, "STOP")==0){

                            //log the ack from SS
                            char log_msg_3[2*BUFFER_SIZE];
                            sprintf(log_msg_3,"SS ack for %s => %s",dup_buffer, buf);
                            log_message(ip_address,port, log_msg_3);

                            // send acknowledgement to client
                            printf(YELLOW "%s\n" RESET,buf);
                            send(client_sock, buf, strlen(buf), 0);
                        }
                    }
                    else if(bytes_read==0){
                        char msg[]=" ASYNC ACK from SS not received";
                        send(client_sock, msg, strlen(msg), 0);
                    }
                    set_blocking(storage_servers[check].sock);
                }
            }

            // //receive ack from client
            // char ackn[BUFFER_SIZE];
            // int ackn_bytes=read(client_sock,ackn,BUFFER_SIZE-1);
            // if(ackn_bytes>0){
            //     ackn[ackn_bytes]='\0';
            //     printf("Client: %s\n",ackn);
            // }
            // else{
            //     printf("ack from client not received\n");
            // }

        }
        
    }
    else if (strstr(command, "GET_PATHS")!=NULL){
        //sending intial request acknowledgment
        char req_ack[]="REQUEST ACKNOWLEDGMENT SUCCESS\n";
        send(client_sock, req_ack, strlen(req_ack),0);

        char request[10000]={'\0'};
        for (int i=0;i<MAX_STORAGE_SERVERS;i++){
            if (storage_servers[i].sock==-1) continue;
            else{
                for (int j=0;j<storage_servers[i].path_count;j++){
                    if (strcmp(storage_servers[i].accessible_paths[j], "Deleted")!=0){
                        strcat(request, storage_servers[i].accessible_paths[j]);
                        strcat(request, " ");
                    }
                }
            }
        }

        //sending data
        if(send(client_sock, request, sizeof(request), 0)>0){
            printf(PINK "Sent paths to client\n" RESET);
        }
        else{
            perror("Send error:");
        }
        // //receive ack from client
        // char ackn[BUFFER_SIZE];
        // int ackn_bytes=read(client_sock,ackn,BUFFER_SIZE-1);
        // if(ackn_bytes>0){
        //     ackn[ackn_bytes]='\0';
        //     printf("Client: %s\n",ackn);
        // }
        // else{
        //     printf("ack from client not received\n");
        // }
    }
    else if(strstr(command,"Server")!=NULL){
        //printf("here\n");
        printf(RED "Server down IP:%s Port:%d\n" RESET,ip_address,port);
        int storage_server_no=-1;
        for (int i=0;i<MAX_STORAGE_SERVERS;i++){
            if (storage_servers[i].path_count>0){
                if (strcmp(storage_servers[i].ip_address, ip_address)==0){
                    storage_server_no=i;
                }
            }
        }
        int indexx=storage_servers[storage_server_no].path_count;
        for (int i=0;i<indexx;i++){
            if (strcmp(storage_servers[storage_server_no].accessible_paths[i],"Deleted")!=0){
                delete(&root, storage_servers[storage_server_no].accessible_paths[i]);
            }
        }
        storage_servers[storage_server_no].sock=-1;
    }
    else
    {
        //sending intial request acknowledgment
        char req_ack[]="Invalid request";
        send(client_sock, req_ack, strlen(req_ack),0);
        printf (RED "Invalid request\n" RESET);
    }
    
}

void handle_storage_server(int storage_sock, char *buffer){
    StorageServer new_server;
    memset(&new_server, 0, sizeof(new_server));

    // Parse the received string
    int sscanf_result = sscanf(buffer, "%s %d %d", 
                               new_server.ip_address, 
                               &new_server.nm_port, 
                               &new_server.client_port);

    // Ensure to print the information received
    if (sscanf_result < 3) {
        fprintf(stderr, "Error: Invalid registration format. Received: %s\n", buffer);
        close(storage_sock);
        return;
    }

    char str1[10];
    char str2[10];
    sprintf(str1, "%d", new_server.nm_port);
    sprintf(str2, "%d", new_server.client_port);
    new_server.sock= storage_sock;
    // printf ("%d\n",new_server.port);
    // Get the accessible paths from the same buffer
    char *paths = buffer + strlen(new_server.ip_address) + 1 + // +1 for space
                  strlen(str1) + 1 + // +1 for space
                  strlen(str2); // No +1 needed here

    // Split paths into an array
    new_server.path_count = 0;
    char *token = strtok(paths, " ");
    while (token != NULL && new_server.path_count < MAX_PATHS) {
        strncpy(new_server.accessible_paths[new_server.path_count], token, MAX_PATH_LENGTH - 1);
        new_server.accessible_paths[new_server.path_count][MAX_PATH_LENGTH - 1] = '\0'; // Ensure null-termination
        new_server.path_count++;
        token = strtok(NULL, " ");
    }

    if (storage_server_count < MAX_STORAGE_SERVERS) 
    {
        pthread_mutex_lock(&storage_mutex[storage_server_count]);
        storage_servers[storage_server_count] = new_server;

        printf("Registered Storage Server #%d\n", storage_server_count + 1);
        printf("IP Address: %s\n", new_server.ip_address);
        printf("Naming Port: %d\n", new_server.nm_port);
        printf("Client Port: %d\n", new_server.client_port);
        printf("Accessible Paths:\n");
        for (int i = 0; i < new_server.path_count; i++) 
        {
            printf("  - %s\n", new_server.accessible_paths[i]);
        }
        // insert into the trie
        for (int i = 0; i < new_server.path_count; i++)
        {
            pthread_mutex_lock(&trie_mutex);
            insertintotrie(&root, new_server.accessible_paths[i], storage_server_count);
            pthread_mutex_unlock(&trie_mutex);
        }
        pthread_mutex_unlock(&storage_mutex[storage_server_count]);
        // backup_storage_server(storage_server_count);
        storage_server_count++;
    } 
    else 
    {
        printf(RED "Maximum storage server limit reached.\n" RESET);
    }

    // close(storage_sock);
}

// Function to handle client requests
void handle_client(int client_sock, char *buffer, char *ip_address, int port) {
    if(strstr(buffer,"Server")==NULL){
        printf (YELLOW "Client request: %s" RESET, buffer);
    }
    execute_request_client(buffer, client_sock,ip_address,port);
}

// Thread function to handle both clients and storage servers
void* handle_connection(void* arg) {
    thread_arg *args=(thread_arg *)arg;
    int sock = *(args->new_sock_ptr);

    char buffer[BUFFER_SIZE];
    memset(buffer, 0, sizeof(buffer));

    int bytes_read = read(sock, buffer, BUFFER_SIZE - 1);
    if (bytes_read > 0) {
        buffer[bytes_read] = '\0';
        char first_word[BUFFER_SIZE];
        sscanf(buffer, "%s", first_word);

        if (is_valid_ip(first_word)) 
        {
            //log the storage server connection
            char log_msg[BUFFER_SIZE];
            snprintf(log_msg, sizeof(log_msg), "Accepted connection from Storage Server");
            log_message(args->ip_address,args->port, log_msg);

            handle_storage_server(sock, buffer);
        } 
        else 
        {
            handle_client(sock, buffer,args->ip_address,args->port);
            // close (sock);
        }
    } 
    else 
    {
        perror("Failed to read from connection");
    }

    return NULL;
}

int main() {

    for(int i=0;i< MAX_STORAGE_SERVERS;i++){
        pthread_mutex_init(&storage_mutex[i],NULL);
    }

    initialize_log_file();
    for (int i=0; i<CACHE; i++) {
        LRU[i].levelNumber=1e9;
        LRU[i].serverID=-1;
        LRU[i].path[0]='\0';
    }

    int naming_sock;
    struct sockaddr_in naming_addr, client_addr;
    pthread_t tid;

    // Step 1: Create socket for Naming Server
    naming_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (naming_sock < 0) {
        perror("Socket creation failed");
        exit(1);
    }

    naming_addr.sin_family = AF_INET;
    naming_addr.sin_addr.s_addr = INADDR_ANY; // Accept connections from any address
    naming_addr.sin_port = htons(PORT_NUM);      

    if (bind(naming_sock, (struct sockaddr*)&naming_addr, sizeof(naming_addr)) < 0) {
        perror("Bind failed");
        exit(1);
    }

    if (listen(naming_sock, 10) < 0) {
        perror("Listen failed");
        exit(1);
    }

    printf(GREEN "Naming Server is listening on port %d...\n" RESET, PORT_NUM);
    int thread_count = 0; 
    pthread_t threads[MAX_THREADS]; // Array to hold thread identifiers

    // Main loop to accept connections from both storage servers and clients
    socklen_t addr_size = sizeof(client_addr);
    while (1) {
        int new_sock = accept(naming_sock, (struct sockaddr*)&client_addr, &addr_size);
        if (new_sock < 0) {
            perror("Accept failed");
            continue;
        }

        // Allocate memory for the new socket and create a thread to handle it
        thread_arg *args=(thread_arg *)malloc(sizeof(thread_arg));
        if (args == NULL) {
            perror("Failed to allocate memory for thread_args");
            close(new_sock);
            continue;
        }
        args->ip_address=inet_ntoa(client_addr.sin_addr);
        args->port=ntohs(client_addr.sin_port);
        args->new_sock_ptr = (int *)malloc(sizeof(int));
        if (args->new_sock_ptr == NULL) {
            perror("Failed to allocate memory for new socket");
            close(new_sock);
            continue;
        }
        *(args->new_sock_ptr) = new_sock;
        if (thread_count < MAX_THREADS)
        {
            pthread_create(&threads[thread_count], NULL, handle_connection, args);
            thread_count++;
        } 
        else 
        {
            printf(RED "Maximum thread limit reached. Cannot create more threads.\n" RESET);
            free(args->new_sock_ptr);
            free(args);
            close(new_sock);
            break;
        }
    }
    for(int j=0;j<thread_count;j++){
        pthread_join(threads[j],NULL);
    }
    close_log_file();
    close(naming_sock);
    return 0;
}