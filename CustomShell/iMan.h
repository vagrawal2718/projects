#ifndef IMAN_H
#define IMAN_H

#include "shell.h"
#include "helper.h"
void fetch_man_page(char *command);
void execute_iman(char *command_string);
void strip_html_tags(char *src, char *dest);
#endif
