// tictactoe_server_tcp.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>

#define BUFFER_SIZE 1024

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

  // Write new null terminator at the end
  *(end + 1) = '\0';

  // Move trimmed string back to the original pointer
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

// #define PORT 8080 //Not fixing port any more
#define BOARD_SIZE 3

char board[BOARD_SIZE][BOARD_SIZE]; // Tic-Tac-Toe board

void initialize_board()
{
  for (int i = 0; i < BOARD_SIZE; i++)
  {
    for (int j = 0; j < BOARD_SIZE; j++)
    {
      board[i][j] = ' ';
     // board[i][j] = '%';
    }
  }
}

void print_board()
{
  printf("\nCurrent Board:\n");
  for (int i = 0; i < BOARD_SIZE; i++)
  {
    for (int j = 0; j < BOARD_SIZE; j++)
    {
      if (board[i][j]=='%')
        printf("   ");
      else 
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
  // Check rows, columns, and diagonals for a win
  for (int i = 0; i < BOARD_SIZE; i++)
  {
    if ((board[i][0] == mark && board[i][1] == mark && board[i][2] == mark) ||
        (board[0][i] == mark && board[1][i] == mark && board[2][i] == mark))
    {
      return 1;
    }
  }
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

void broadcast_board(int player1_fd, int player2_fd)
{
  // Send the updated board to both players
  send(player1_fd, board, sizeof(board), 0);
  send(player2_fd, board, sizeof(board), 0);
}

int ask_replay(int player_fd)
{
  char buffer[1024];
  while (1)
  { // Loop until valid input is received
    send(player_fd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0);
    //printf("Line 129 message sent to player %d for replay\n", player_fd);
    recv(player_fd, buffer, 1024, 0);
    printf("Line 131 message received from player %d for replay %s\n", player_fd, buffer);

    // Remove trailing newline character from fgets if any
    buffer[strcspn(buffer, "\n")] = 0;

    // Trim whitespace from the input
    trim_whitespace(buffer);

    // Convert the input to lowercase
    str_to_lower(buffer);

    // Check if input is "yes" or "no"
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
      send(player_fd, "Invalid input! Please type 'yes' or 'no'.\n", strlen("Invalid input! Please type 'yes' or 'no'.\n"), 0);
    }
  }
}

int main()
{
  int server_fd, player1_fd, player2_fd;
  struct sockaddr_in address;
  int addrlen = sizeof(address);
  char buffer[1024] = {0};
  int row, col, game_over = 0;
  int replay_player1 = 1, replay_player2 = 1;

  if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0)
  {
    perror("Socket failed");
    exit(EXIT_FAILURE);
  }

  // Set SO_REUSEADDR option to avoid "Address already in use" error
  int opt = 1;
  if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
  {
    perror("setsockopt failed");
    exit(EXIT_FAILURE);
  }

  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  // address.sin_port = htons(PORT);
  /*#define PORT 12345
address.sin_port = htons(PORT);*/
  address.sin_port = htons(0); // Bind to a dynamic port

  if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0)
  {
    perror("Bind failed");
    exit(EXIT_FAILURE);
  }

  // Retrieve and print the dynamically assigned port
  socklen_t len = sizeof(address);
  if (getsockname(server_fd, (struct sockaddr *)&address, &len) == -1)
  {
    perror("getsockname failed");
    exit(EXIT_FAILURE);
  }
  printf("Server listening on port %d\n", ntohs(address.sin_port));
  // Write the port number to a file
  FILE *port_file = fopen("server_port.txt", "w");
  if (port_file != NULL)
  {
    fprintf(port_file, "%d\n", ntohs(address.sin_port));
    fclose(port_file);
  }
  else
  {
    perror("Could not write port to file");
    exit(EXIT_FAILURE);
  }

  if (listen(server_fd, 2) < 0)
  {
    perror("Listen failed");
    exit(EXIT_FAILURE);
  }

  printf("Waiting for players to connect...\n");

  // Accept two players
  if ((player1_fd = accept(server_fd, (struct sockaddr *)&address, (socklen_t *)&addrlen)) < 0)
  {
    perror("Player 1 accept failed");
    exit(EXIT_FAILURE);
  }
  printf("Player 1 connected. %d\n", player1_fd);

  if ((player2_fd = accept(server_fd, (struct sockaddr *)&address, (socklen_t *)&addrlen)) < 0)
  {
    perror("Player 2 accept failed");
    exit(EXIT_FAILURE);
  }
  printf("Player 2 connected. %d\n", player2_fd);

  do
  {
    initialize_board();
    send(player1_fd, "X", 1, 0); // Assign 'X' to Player 1
    send(player2_fd, "O", 1, 0); // Assign 'O' to Player 2

    int current_player_fd = player1_fd;
    char current_mark = 'X';
    game_over = 0;

    while (!game_over)
    {
      print_board();
      broadcast_board(player1_fd, player2_fd);

      // Send a "wait" message to the non-current player
      if (current_player_fd == player1_fd)
      {
        send(player2_fd, "Wait for your turn...\n", strlen("Wait for your turn...\n"), 0);
      }
      else
      {
        send(player1_fd, "Wait for your turn...\n", strlen("Wait for your turn...\n"), 0);
      }
      // Request move from the current player
      send(current_player_fd, "Your move: ", strlen("Your move: "), 0);
      recv(current_player_fd, buffer, 1024, 0);
      sscanf(buffer, "%d %d", &row, &col);

      // Validate the move
      if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE || board[row][col] != ' ')
      {
        send(current_player_fd, "Invalid move! Try again.\n", strlen("Invalid move! Try again.\n"), 0);
        continue;
      }

      // Update the board with the move
      update_board(row, col, current_mark);

      // Check for a winner or draw
      if (check_winner(current_mark))
      {
        print_board();
        broadcast_board(player1_fd, player2_fd);

        char win_msg[50];
        sprintf(win_msg, "Player %c Wins! $", current_mark);
        send(player1_fd, win_msg, strlen(win_msg), 0);
        send(player2_fd, win_msg, strlen(win_msg), 0);
         // Add a small delay to ensure messages are received separately
            usleep(100000);  // 100ms delay

        game_over = 1;

        // added

        // Ask both players if they want to play again, in a separate send call
        //send(player1_fd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0);
        //send(player2_fd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0);
      }
      else if (is_board_full()) // && !check_winner(current_mark))
      {
        print_board();
        broadcast_board(player1_fd, player2_fd);
        char draw_msg[] = "It's a Draw!\n";
        send(player1_fd, draw_msg, strlen(draw_msg), 0);
        send(player2_fd, draw_msg, strlen(draw_msg), 0);


            // Add a small delay
            usleep(100000);  // 100ms delay
        game_over = 1;

        // added
        //send(player1_fd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0);
        //send(player2_fd, "Would you like to play again? (yes/no): ", strlen("Would you like to play again? (yes/no): "), 0);
      }

      // Switch players
      current_player_fd = (current_player_fd == player1_fd) ? player2_fd : player1_fd;
      current_mark = (current_mark == 'X') ? 'O' : 'X';
    }

    // Ask both players if they want to play again
    replay_player1 = ask_replay(player1_fd);
    printf("Player 1 wants to replay: %d\n", replay_player1); // DEBUG

    replay_player2 = ask_replay(player2_fd);
    printf("Player 2 wants to replay: %d\n", replay_player2); // DEBUG

    if (replay_player1 && replay_player2)
    {
      // Both players want to replay
      send(player1_fd, "Both players want to replay. Restarting game...\n", 50, 0);
      send(player2_fd, "Both players want to replay. Restarting game...\n", 50, 0);
      game_over = 0;      // Reset game state to allow replay
      initialize_board(); // Reset the board for the new game
    }
    else
    {
      // At least one player doesn't want to replay
      if (!replay_player1 && replay_player2)
      {
        send(player2_fd, "Disconnecting. Player 1 doesn't want to play again.\n", 50, 0);
        send(player1_fd, "Disconnecting...\n", 50, 0);
      }
      else if (replay_player1 && !replay_player2)
      {
        send(player1_fd, "Disconnecting. Player 2 doesn't want to play again.\n", 50, 0);
        send(player2_fd, "Disconnecting...\n", 50, 0);
      }
      else
      {
        // Neither player wants to replay
        send(player1_fd, "Both players don't want to replay. Disconnecting.\n", 50, 0);
        send(player2_fd, "Both players don't want to replay. Disconnecting.\n", 50, 0);
      }

      // Close connections for both players and end the game
      close(player1_fd);
      close(player2_fd);
      break; // Exit the replay loop
    }
  } while (replay_player1 && replay_player2); // Loop for replaying the game

  close(server_fd);
  return 0;
}
