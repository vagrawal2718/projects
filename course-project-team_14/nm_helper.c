#include "nm.h"

// Function to check if the input starts with an IP address
int is_valid_ip(const char *str) {
    struct sockaddr_in sa;
    return inet_pton(AF_INET, str, &(sa.sin_addr)) != 0;
}

void set_nonblocking(int sock) {
    int flags = fcntl(sock, F_GETFL, 0);
    if (flags == -1) {
        perror("fcntl F_GETFL");
        return;
    }
    if (fcntl(sock, F_SETFL, flags | O_NONBLOCK) == -1) {
        perror("fcntl F_SETFL");
    }
}

void set_blocking(int sock) {
    int flags = fcntl(sock, F_GETFL, 0);
    if (flags == -1) {
        perror("fcntl F_GETFL");
        return;
    }
    if (fcntl(sock, F_SETFL, flags & ~O_NONBLOCK) == -1) {
        perror("fcntl F_SETFL");
    }
}

int count_substring_occurrences(char *str, char *sub) {
    int count = 0;
    char *temp = str;

    // Search for the substring in the main string
    while ((temp = strstr(temp, sub)) != NULL) {
        count++;
        temp += strlen(sub); // Move past the current substring
    }

    return count;
}

void split_string_by_ack(const char *input, char **part1, char **part2) {
    const char *ack_pos = strstr(input, "ACK:");
    if (!ack_pos) {
        *part1 = NULL;
        *part2 = NULL;
        return;
    }

    const char *second_ack_pos = strstr(ack_pos + 1, "ACK:");
    if (!second_ack_pos) {
        *part1 = strdup(ack_pos);
        *part2 = NULL;
        return;
    }

    size_t part1_length = second_ack_pos - ack_pos;
    *part1 = (char *)malloc(part1_length + 1);
    strncpy(*part1, ack_pos, part1_length);
    (*part1)[part1_length] = '\0';

    *part2 = strdup(second_ack_pos);
}