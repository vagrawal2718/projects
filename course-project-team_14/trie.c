#include "nm.h"

// TRIE IMPLEMETATION STARTS HERE

// create a trie node
trie* createtrienode(){

    trie* newnode=(trie*)malloc(sizeof(trie));

    newnode->storageServerID=-1;
    newnode->checkFileorDir=false;
    newnode->endOfWord=false;
    for (int i=0;i<BUFFER_SIZE;i++){
        newnode->desc[i]=NULL;
    }
    
    return newnode;
}

// insert into the trie
void insertintotrie(trie** head, char* path, int serverID){
    if (*head==NULL) {
        (*head)=createtrienode();
    }
    trie* current=(*head);
    for (int i=0;i<sizeof(path);i++){
        if (current->desc[path[i]]==NULL){
            current->desc[path[i]]=createtrienode();
        }
        current=current->desc[path[i]];
        // if (path[i]=='/'){
        //     current->checkFileorDir=false;
        //     current->storageServerID=serverID;
        //     current->endOfWord=true;
        // }
    }
    // if (path[strlen(path)-1]!='/'){
        current->checkFileorDir=true;
        current->storageServerID=serverID;
        current->endOfWord=true;
    // }
    return;
}

// search in the trie
int search(trie* head, char* path){
    if (head==NULL){
        return -1;
    }
    trie* current=head;
    for (int i=0;i<sizeof(path);i++){
        if (current->desc[path[i]]==NULL){
            return -1;
        }
        current=current->desc[path[i]];
        if (current->endOfWord==true && current->storageServerID==-1){
            return -1;
        }
    }
    if (current->endOfWord==true){
        // for (int i=0;i<CACHE;i++){
        //     if (strcmp(LRU[i].path, path)==0){
        //         LRU[i].serverID=current->storageServerID;
        //         break;
        //     }
        // }
        return current->storageServerID;
    }
    else{
        return -1;
    }
}

void delete(trie** head, char* path){
    if ((*head)==NULL){
        return;
    }
    if (search((*head), path)==-1){
        return;
    }
    trie* current=(*head);
    for (int i=0;i<sizeof(path);i++){
        if (current->desc[path[i]]==NULL){
            return;
        }
        current=current->desc[path[i]];
    }
    
    // long long hashedadd=0;
    // for (int i=0;i<strlen(path);i++){
    //     hashedadd=(hashedadd*23+(path[i]-'a'))%(MOD);
    // }
    // LRU[hashedadd].serverID=-1;
    for (int i=0;i<CACHE;i++){
        if (LRU[i].serverID==current->storageServerID && strcmp(LRU[i].path,path)==0){
            LRU[i].levelNumber=1e9;
            LRU[i].serverID=-1;
            LRU[i].path[0]='\0';
            break;
        }
    }
    current->storageServerID=-1;
    return;
}

// TRIE IMPLEMENTATION ENDS HERE
