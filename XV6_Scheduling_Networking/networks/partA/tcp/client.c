// tictactoe_client_tcp.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

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
  int sock = 0, valread, port;
  struct sockaddr_in serv_addr;
  char buffer[1024] = {0};
  char mark;
  char board[BOARD_SIZE][BOARD_SIZE];
  int game_over = 0;

  // Read the dynamically assigned port from file
  FILE *port_file = fopen("server_port.txt", "r");
  if (port_file == NULL)
  {
    perror("Could not open port file");
    return -1;
  }
  fscanf(port_file, "%d", &port);
  fclose(port_file);

  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
  {
    printf("\n Socket creation error \n");
    return -1;
  }

  serv_addr.sin_family = AF_INET;
  serv_addr.sin_port = htons(port);
  /*serv_addr.sin_port = htons(PORT);
*/

  if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0)
  {
    printf("\nInvalid address/ Address not supported \n");
    return -1;
  }

  if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
  {
    printf("\nConnection Failed \n");
    return -1;
  }

  // Receive assigned mark (X or O)
  valread = read(sock, &mark, 1);
  if (valread <= 0)
  {
    printf("Server disconnected or failed to assign mark.\n");
    close(sock);
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

      valread = read(sock, board, sizeof(board)); // Message containing the current board
      if (valread <= 0)                           // Check if the server has disconnected
      {
        printf("Server has disconnected.\n");
        close(sock);
        return 0; // Exit the client
      }
      buffer[valread] = '\0';
      print_board(board);

      valread = read(sock, buffer, 1024); // Message for your move or result
                                          // printf("Line 106 buffer is %s\n", buffer);
      if (valread <= 0)                   // Check if the server has disconnected
      {
        printf("Server has disconnected.\n");
        close(sock);
        return 0; // Exit the client
      }

      // Only proceed if it's the client's turn to make a move
      if (strstr(buffer, "Your move"))
      {
        printf("%s\n", buffer);
        int row, col;
        while (1)
        {
          // Get row and column input from the user
          printf("Enter row and column: ");
          fgets(buffer, 1024, stdin);
          sscanf(buffer, "%d %d", &row, &col);

          // Validate the move before sending it to the server
          if (is_valid_move(board, row, col))
          {
            // If the move is valid, send it to the server
            snprintf(buffer, 1024, "%d %d", row, col);
            send(sock, buffer, strlen(buffer), 0);
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
        continue; // Keep waiting until it's your turn
      }
      else if (strstr(buffer, "Wins") || strstr(buffer, "Draw"))
      {
        // printf("Line 142 in Wins on Draw\n");
        printf("%s\n", buffer);
        game_over = 1; // Exit the loop when game ends
                       // Clear buffer and wait for replay prompt
        memset(buffer, 0, sizeof(buffer));
        valread = read(sock, buffer, 1024);
        if (valread <= 0) // Check if the server has disconnected
        {
          printf("Server has disconnected.\n");
          close(sock);
          return 0; // Exit the client
        }
        if (strstr(buffer, "play again"))
        {
          printf("%s", buffer);
          char response[10];
          fgets(response, sizeof(response), stdin);
          send(sock, response, strlen(response), 0);

          // Wait for server's decision about replay
          memset(buffer, 0, sizeof(buffer));
          valread = read(sock, buffer, 1024);
          if (valread <= 0) // Check if the server has disconnected
          {
            printf("Server has disconnected.\n");
            close(sock);
            return 0; // Exit the client
          }
          printf("%s", buffer);

          if (strstr(buffer, "Disconnecting"))
          {
            return 0; // Exit the program
          }
        }
        break; // Exit inner game loop
      }
    }
  }

  close(sock);
  return 0;
}
