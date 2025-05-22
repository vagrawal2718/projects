#include "nm.h"

// Function to log messages to the log file
void log_message(const char *ip_address, int port, const char *message)
{
    if (log_file)
    {
        fprintf(log_file, "IP: %s, Port: %d, Message: %s\n", ip_address, port, message);
        fflush(log_file); // Ensure the message is written immediately
    }
}

// Function to initialize the log file
void initialize_log_file()
{
    log_file = fopen("naming_server.log", "a"); // Open log file in append mode
    if (log_file == NULL)
    {
        perror("Failed to open log file");
        exit(EXIT_FAILURE);
    }
}

// Function to close the log file
void close_log_file()
{
    if (log_file)
    {
        fclose(log_file);
    }
}