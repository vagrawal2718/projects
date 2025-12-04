// tictactoe_client_udp.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/time.h>
#define BOARD_SIZE 3
#define BUFFER_SIZE 1024

void print_board(char board[BOARD_SIZE][BOARD_SIZE])
{
    printf("\nCurrent Board:\n");
    for (int i = 0; i < BOARD_SIZE; i++)
    {
        for (int j = 0; j < BOARD_SIZE; j++)
        {
            printf(" %c ", board[i][j]);
            if (j < BOARD_SIZE - 1)
                printf("|");
        }
        printf("\n");
        if (i < BOARD_SIZE - 1)
            printf("---|---|---\n");
    }
}

// Function to validate the move locally before sending it to the server
int is_valid_move(char board[BOARD_SIZE][BOARD_SIZE], int row, int col)
{
    // Check if the row and column are within bounds
    if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE)
    {
        printf("Invalid move: Row and column should be between 0 and %d.\n", BOARD_SIZE - 1);
        return 0;
    }

    // Check if the position is already occupied
    if (board[row][col] != ' ')
    {
        printf("Invalid move: Cell (%d, %d) is already occupied.\n", row, col);
        return 0;
    }

    return 1; // The move is valid
}

int main()
{
    int sock = 0, port;
    struct sockaddr_in serv_addr;
    socklen_t addr_len = sizeof(serv_addr);
    char buffer[BUFFER_SIZE] = {0};
    char board[BOARD_SIZE][BOARD_SIZE];
    char mark;
    int game_over = 0;

    struct timeval timeout;

    // Read the dynamically assigned port from the server's file
    FILE *port_file = fopen("server_port.txt", "r");
    if (port_file == NULL)
    {
        perror("Could not open port file");
        return -1;
    }
    fscanf(port_file, "%d", &port);
    fclose(port_file);

    // Create a UDP socket
    if ((sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
    {
        printf("\n Socket creation error \n");
        return -1;
    }

    // Set server address structure
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    // Convert IPv4 addresses from text to binary form
    if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0)
    {
        printf("\nInvalid address/ Address not supported \n");
        return -1;
    }

    // Set a timeout of 2 seconds for the initial server connection check
    timeout.tv_sec = 2;
    timeout.tv_usec = 0;
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0)
    {
        perror("Error setting socket timeout");
        return -1;
    }
    // Send an empty message to the server to connect as a player
    sendto(sock, buffer, 1, 0, (const struct sockaddr *)&serv_addr, addr_len);

    // Receive assigned mark (X or O)

    // Try to receive assigned mark (X or O) from the server (check connection)
    if (recvfrom(sock, &mark, 1, 0, (struct sockaddr *)&serv_addr, &addr_len) <= 0)
    {
        // If no response, print connection error and exit
        printf("Connection Failed. Server is not responding.\n");
        close(sock);
        return -1;
    }
    // If successfully connected, remove the timeout for future recvfrom calls
    timeout.tv_sec = 0;
    timeout.tv_usec = 0;
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0)
    {
        perror("Error removing socket timeout");
        return -1;
    }
    printf("You are Player %c\n", mark);

    // Game loop
    while (1)
    {
        game_over = 0;
        memset(board, 0, sizeof(board));

        while (!game_over)
        {
            memset(buffer, 0, sizeof(buffer));

            // Receive the current board from the server
            recvfrom(sock, board, sizeof(board), 0, (struct sockaddr *)&serv_addr, &addr_len);
            print_board(board);

            // Receive a message for your move or game result
            recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr *)&serv_addr, &addr_len);

            // If it's the client's turn to make a move
            if (strstr(buffer, "Your move"))
            {
                printf("%s\n", buffer);
                int row, col;
                while (1)
                {
                    // Get row and column input from the user
                    printf("Enter row and column: ");
                    fgets(buffer, BUFFER_SIZE, stdin);
                    sscanf(buffer, "%d %d", &row, &col);

                    // Validate the move locally before sending it to the server
                    if (is_valid_move(board, row, col))
                    {
                        snprintf(buffer, BUFFER_SIZE, "%d %d", row, col);
                        sendto(sock, buffer, strlen(buffer), 0, (const struct sockaddr *)&serv_addr, addr_len);
                        break; // Exit the loop if a valid move is made
                    }
                    else
                    {
                        printf("Please enter a valid move.\n");
                    }
                }
            }
            // If the message says "Wait for your turn", don't prompt for input
            else if (strstr(buffer, "Wait for your turn"))
            {
                printf("%s\n", buffer);
                continue;
            }
            // If the game has ended with a win or draw
            else if (strstr(buffer, "Wins") || strstr(buffer, "Draw"))
            {
                printf("%s\n", buffer);
                game_over = 1;

                // Ask the user if they want to play again
                memset(buffer, 0, sizeof(buffer));
                recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr *)&serv_addr, &addr_len);
                if (strstr(buffer, "play again"))
                {
                    printf("%s", buffer);
                    char response[10];
                    fgets(response, sizeof(response), stdin);
                    sendto(sock, response, strlen(response), 0, (const struct sockaddr *)&serv_addr, addr_len);

                    // Receive server's response about the replay decision
                    memset(buffer, 0, sizeof(buffer));
                    recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr *)&serv_addr, &addr_len);
                    printf("%s", buffer);

                    if (strstr(buffer, "Disconnecting"))
                    {
                        return 0; // Exit the program if server says disconnect
                    }
                }
                break; // Exit the inner game loop
            }
        }
    }

    close(sock);
    return 0;
}
