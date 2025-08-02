#include "iMan.h"
#include <regex.h>

void strip_html_tags(char *src, char *dest) {
    int inside_tag = 0;
    while (*src) {
        if (*src == '<') {
            inside_tag = 1;
        } else if (*src == '>') {
            inside_tag = 0;
        } else if (!inside_tag) {
            *dest++ = *src;
        }
        src++;
    }
    *dest = '\0';
}

void fetch_man_page(char *command) {
    int sockfd;
    struct addrinfo hints, *servinfo, *p;
    int rv;
    char buffer[MAX_BUFFER];

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if ((rv = getaddrinfo(HOST, PORT, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return;
    }

    for (p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            perror("socket");
            continue;
        }

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            perror("connect");
            continue;
        }
        break;
    }

    if (p == NULL) {
        fprintf(stderr, "Failed to connect\n");
        return;
    }

    freeaddrinfo(servinfo);

    char request[MAX_BUFFER];
    snprintf(request, sizeof(request),
             "GET /?topic=%s&section=all HTTP/1.1\r\n"
             "Host: %s\r\n"
             "Connection: close\r\n\r\n",
             command, HOST);

    if (send(sockfd, request, strlen(request), 0) == -1) {
        perror("send");
        close(sockfd);
        return;
    }

    int bytes_received;

    // Print the command name twice with newlines
    printf("%s\n\n\n\n%s\n\n", command, command);

    while ((bytes_received = recv(sockfd, buffer, MAX_BUFFER - 1, 0)) > 0) {
        buffer[bytes_received] = '\0';
        printf("%s", buffer);  // Print the full HTML content as it is
    }

    if (bytes_received == -1) {
        perror("recv");
    }

    close(sockfd);
}

void execute_iman(char *command_string) {
    char *args[MAX_ARGS];
    int arg_count = parse_command(command_string, args);

    if (arg_count < 2) {
        fprintf(stderr, "Usage: iMan <command_name>\n");
        return;
    }

    fetch_man_page(args[1]);
}