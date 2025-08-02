#ifndef REVEAL_H
#define REVEAL_H

#include "shell.h"
#include "hop.h"

char* get_filename(char* filepath);
char* get_dirname(char* dirpath);
int compare(const void *a, const void *b);
void reveal_execute(char *command);
void show_color(char *filename, mode_t mode);
void display_file_details(char *filepath,  char *filename);


#endif 
