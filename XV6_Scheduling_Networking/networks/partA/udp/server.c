// tictactoe_server_udp.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ctype.h>

#define BUFFER_SIZE 1024
#define BOARD_SIZE 3

char board[BOARD_SIZE][BOARD_SIZE]; // Tic-Tac-Toe board
int moves = 0;

// Utility function to trim leading and trailing spaces from a string
void trim_whitespace(char *str)
{
    // Trim leading spaces
    char *start = str;
    while (isspace((unsigned char)*start))
    {
        start++;
    }
    // Trim trailing spaces
    char *end = str + strlen(str) - 1;
    while (end > start && isspace((unsigned char)*end))
    {
        end--;
    }
    *(end + 1) = '\0';
    memmove(str, start, end - start + 2);
}

// Utility function to convert a string to lowercase
void str_to_lower(char *str)
{
    for (int i = 0; str[i]; i++)
    {
        str[i] = tolower((unsigned char)str[i]);
    }
}

void initialize_board()
{
    for (int i = 0; i < BOARD_SIZE; i++)
    {
        for (int j = 0; j < BOARD_SIZE; j++)
        {
            board[i][j] = ' ';
        }
    }
    moves = 0;
}

void print_board()
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

int check_winner(char mark)
{
    for (int i = 0; i < BOARD_SIZE; i++)
    {
        // Check rows and columns
        if ((board[i][0] == mark && board[i][1] == mark && board[i][2] == mark) ||
            (board[0][i] == mark && board[1][i] == mark && board[2][i] == mark))
        {
            return 1;
        }
    }
    // Check diagonals
    if ((board[0][0] == mark && board[1][1] == mark && board[2][2] == mark) ||
        (board[0][2] == mark && board[1][1] == mark && board[2][0] == mark))
    {
        return 1;
    }
    return 0;
}

int is_board_full()
{
    for (int i = 0; i < BOARD_SIZE; i++)
    {
        for (int j = 0; j < BOARD_SIZE; j++)
        {
            if (board[i][j] == ' ')
                return 0;
        }
    }
    return 1;
}

void update_board(int row, int col, char mark)
{
    board[row][col] = mark;
}

void send_board(int sockfd, struct sockaddr_in *player1_addr, struct sockaddr_in *player2_addr, socklen_t addr_len)
{
    // Send the updated board to both players
    sendto(sockfd, board, sizeof(board), 0, (struct sockaddr *)player1_addr, addr_len);
    sendto(sockfd, board, sizeof(board), 0, (struct sockaddr *)player2_addr, addr_len);
}

int ask_replay(int sockfd, struct sockaddr_in *player_addr, socklen_t addr_len)
{
    char buffer[BUFFER_SIZE];
    while (1)
    {
        sendto(sockfd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0, (struct sockaddr *)player_addr, addr_len);
        recvfrom(sockfd, buffer, BUFFER_SIZE, 0, (struct sockaddr *)player_addr, &addr_len);

        // Remove trailing newline character
        buffer[strcspn(buffer, "\n")] = 0;
        trim_whitespace(buffer);
        str_to_lower(buffer);

        if (strcmp(buffer, "yes") == 0 || strcmp(buffer, "y") == 0)
        {
            return 1; // Yes response
        }
        else if (strcmp(buffer, "no") == 0 || strcmp(buffer, "n") == 0)
        {
            return 0; // No response
        }
        else
        {
            // Inform the client that the input is invalid
            sendto(sockfd, "Invalid input! Please type 'yes' or 'no'.\n", strlen("Invalid input! Please type 'yes' or 'no'.\n"), 0, (struct sockaddr *)player_addr, addr_len);
        }
    }
}

int main()
{
    int sockfd;
    struct sockaddr_in server_addr, player1_addr, player2_addr, client_addr;
    socklen_t addr_len = sizeof(client_addr);
    char buffer[BUFFER_SIZE] = {0};
    int row, col, game_over = 0;
    int replay_player1 = 1, replay_player2 = 1;
    int player1_set = 0, player2_set = 0;

    // Create a UDP socket
    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) == 0)
    {
        perror("Socket failed");
        exit(EXIT_FAILURE);
    }

    // Set server address structure
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(0); // Use dynamic port

    // Bind the socket to the address
    if (bind(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
    {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }

    // Get the dynamically assigned port
    socklen_t len = sizeof(server_addr);
    if (getsockname(sockfd, (struct sockaddr *)&server_addr, &len) == -1)
    {
        perror("getsockname failed");
        exit(EXIT_FAILURE);
    }

    printf("Server listening on port %d\n", ntohs(server_addr.sin_port));

    // Write the port number to a file
    FILE *port_file = fopen("server_port.txt", "w");
    if (port_file != NULL)
    {
        fprintf(port_file, "%d\n", ntohs(server_addr.sin_port));
        fclose(port_file);
    }
    else
    {
        perror("Could not write port to file");
        exit(EXIT_FAILURE);
    }

    printf("Waiting for players to connect...\n");

    // Wait for the first player to send data
    while (!player1_set || !player2_set)
    {
        recvfrom(sockfd, buffer, BUFFER_SIZE, 0, (struct sockaddr *)&client_addr, &addr_len);
        if (!player1_set)
        {
            player1_addr = client_addr;
            player1_set = 1;
            printf("Player 1 connected\n");
            sendto(sockfd, "X", 1, 0, (struct sockaddr *)&player1_addr, addr_len); // Assign 'X' to Player 1
        }
        else if (!player2_set && memcmp(&client_addr, &player1_addr, sizeof(client_addr)) != 0)
        {
            player2_addr = client_addr;
            player2_set = 1;
            printf("Player 2 connected\n");
            sendto(sockfd, "O", 1, 0, (struct sockaddr *)&player2_addr, addr_len); // Assign 'O' to Player 2
        }
    }

    do
    {
        initialize_board();
        int current_player = 1; // Start with Player 1
        game_over = 0;

        while (!game_over)
        {
            print_board();
            send_board(sockfd, &player1_addr, &player2_addr, addr_len);

            struct sockaddr_in *current_addr = (current_player == 1) ? &player1_addr : &player2_addr;
            struct sockaddr_in *other_addr = (current_player == 1) ? &player2_addr : &player1_addr;
            char current_mark = (current_player == 1) ? 'X' : 'O';

            // Send a "wait" message to the other player
            sendto(sockfd, "Wait for your turn...\n", strlen("Wait for your turn...\n"), 0, (struct sockaddr *)other_addr, addr_len);

            // Request move from the current player
            sendto(sockfd, "Your move: ", strlen("Your move: "), 0, (struct sockaddr *)current_addr, addr_len);
            recvfrom(sockfd, buffer, BUFFER_SIZE, 0, (struct sockaddr *)current_addr, &addr_len);
            sscanf(buffer, "%d %d", &row, &col);

            // Validate the move
            if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE || board[row][col] != ' ')
            {
                sendto(sockfd, "Invalid move! Try again.\n", strlen("Invalid move! Try again.\n"), 0, (struct sockaddr *)current_addr, addr_len);
                continue;
            }

            // Update the board
            update_board(row, col, current_mark);
            moves++;

            // Check for a winner or draw
            if (check_winner(current_mark))
            {
                print_board();
                send_board(sockfd, &player1_addr, &player2_addr, addr_len);

                char win_msg[50];
                sprintf(win_msg, "Player %c Wins!\n", current_mark);
                sendto(sockfd, win_msg, strlen(win_msg), 0, (struct sockaddr *)&player1_addr, addr_len);
                sendto(sockfd, win_msg, strlen(win_msg), 0, (struct sockaddr *)&player2_addr, addr_len);

                game_over = 1;
            }
            else if (is_board_full())
            {
                print_board();
                send_board(sockfd, &player1_addr, &player2_addr, addr_len);
                char draw_msg[] = "It's a Draw!\n";
                sendto(sockfd, draw_msg, strlen(draw_msg), 0, (struct sockaddr *)&player1_addr, addr_len);
                sendto(sockfd, draw_msg, strlen(draw_msg), 0, (struct sockaddr *)&player2_addr, addr_len);

                game_over = 1;
            }

            // Switch players
            current_player = 3 - current_player; // Alternates between 1 and 2
        }

        // Ask both players if they want to play again
        replay_player1 = ask_replay(sockfd, &player1_addr, addr_len);
        replay_player2 = ask_replay(sockfd, &player2_addr, addr_len);

        if (replay_player1 && replay_player2)
        {
            sendto(sockfd, "Both players want to replay. Restarting game...\n", 50, 0, (struct sockaddr *)&player1_addr, addr_len);
            sendto(sockfd, "Both players want to replay. Restarting game...\n", 50, 0, (struct sockaddr *)&player2_addr, addr_len);
            game_over = 0;
        }
        else
        {
            // One or both players don't want to replay
            if (!replay_player1)
            {
                sendto(sockfd, "Player 1 doesn't want to play again. Disconnecting...\n", 52, 0, (struct sockaddr *)&player1_addr, addr_len);
                sendto(sockfd, "Player 1 doesn't want to play again. Disconnecting...\n", 52, 0, (struct sockaddr *)&player2_addr, addr_len);
            }
            else if (!replay_player2)
            {
                sendto(sockfd, "Player 2 doesn't want to play again. Disconnecting...\n", 52, 0, (struct sockaddr *)&player1_addr, addr_len);
                sendto(sockfd, "Player 2 doesn't want to play again. Disconnecting...\n", 52, 0, (struct sockaddr *)&player2_addr, addr_len);
            }
            else
            {
                sendto(sockfd, "Both players don't want to replay. Disconnecting...\n", 50, 0, (struct sockaddr *)&player1_addr, addr_len);
                sendto(sockfd, "Both players don't want to replay. Disconnecting...\n", 50, 0, (struct sockaddr *)&player2_addr, addr_len);
            }
            break; // End the game and disconnect
        }
    }

    while (replay_player1 && replay_player2); // Loop for replaying the game

    close(sockfd);
    return 0;
}
