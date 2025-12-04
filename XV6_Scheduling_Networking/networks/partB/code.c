#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

#define MAX_CHUNK_SIZE 5
#define TIMEOUT_SEC 0.1
#define MAX_PORT_ATTEMPTS 10
#define MAX_CHUNKS 100
#define MAX_RETRANSMISSIONS 10

typedef struct
{
  int seq_num;
  int total_chunks;
  int chunk_size;
  char data[MAX_CHUNK_SIZE];
} DataChunk;

typedef struct
{
  int seq_num;
} AckPacket;

int create_socket(const char *ip, int *port)
{
  // Create a UDP socket
  int sock = socket(AF_INET, SOCK_DGRAM, 0);
  if (sock < 0)
  {
    perror("Socket creation failed");
    exit(EXIT_FAILURE);
  }

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = inet_addr(ip);

  // Attempt to bind the socket to the given port, incrementing the port if necessary
  for (int attempt = 0; attempt < MAX_PORT_ATTEMPTS; attempt++)
  {
    addr.sin_port = htons(*port);
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0)
    {
      break;
    }
    (*port)++;
  }

  // If we fail to bind after several attempts, exit the program
  if (*port >= *port + MAX_PORT_ATTEMPTS)
  {
    perror("Failed to bind to any port");
    exit(EXIT_FAILURE);
  }

  // Set the socket to non-blocking mode
  int flags = fcntl(sock, F_GETFL, 0);
  fcntl(sock, F_SETFL, flags | O_NONBLOCK);

  return sock; // Return the created socket file descriptor
}

void send_data(int sock, const char *data, const struct sockaddr *dest_addr, socklen_t dest_len, int use_fixed_chunks)
{
  int total_len = strlen(data);
  if (total_len == 0)
  {
    printf("Cannot send empty message\n");
    return;
  }

  int num_chunks, chunk_size;

  if (use_fixed_chunks)
  {
    num_chunks = MAX_CHUNKS;
    chunk_size = (total_len + num_chunks - 1) / num_chunks;
  }
  else
  {
    chunk_size = MAX_CHUNK_SIZE;
    num_chunks = (total_len + chunk_size - 1) / chunk_size;
  }

  DataChunk *chunks = malloc(num_chunks * sizeof(DataChunk));
  if (!chunks)
  {
    perror("Failed to allocate memory for chunks");
    exit(EXIT_FAILURE);
  }

  // Prepare all chunks
  for (int i = 0; i < num_chunks; i++)
  {
    chunks[i].seq_num = i;
    chunks[i].total_chunks = num_chunks;
    chunks[i].chunk_size = (i == num_chunks - 1) ? (total_len - i * chunk_size) : chunk_size;
    memcpy(chunks[i].data, data + i * chunk_size, chunks[i].chunk_size);
    printf("Prepared chunk %d/%d with content: %.*s\n", i + 1, num_chunks, chunks[i].chunk_size, chunks[i].data);
  }

  int *acked = calloc(num_chunks, sizeof(int)); // To track which chunks have been acknowledged
  if (!acked)
  {
    perror("Failed to allocate memory for ACK tracking");
    free(chunks);
    exit(EXIT_FAILURE);
  }

  int retransmission_count[MAX_CHUNKS] = {0}; // Track how many times each chunk has been retransmitted
  struct timeval start, now;
  gettimeofday(&start, NULL);

  fd_set readfds;
  struct timeval tv;

  // Send all chunks once initially
  for (int i = 0; i < num_chunks; i++)
  {
    if (!acked[i])
    {
      printf("Sending chunk %d/%d with content: %.*s\n", i + 1, num_chunks, chunks[i].chunk_size, chunks[i].data);
      ssize_t sent = sendto(sock, &chunks[i], sizeof(DataChunk), 0, dest_addr, dest_len);
      if (sent < 0)
      {
        perror("Sendto failed");
        free(chunks);
        free(acked);
        exit(EXIT_FAILURE);
      }
    }
  }

  // Now wait for ACKs and retransmit if necessary
  while (1)
  {
    // Wait for ACKs
    FD_ZERO(&readfds);
    FD_SET(sock, &readfds);
    tv.tv_sec = 0;
    tv.tv_usec = 100000; // 100ms timeout

    while (select(sock + 1, &readfds, NULL, NULL, &tv) > 0)
    {
      AckPacket ack;
      struct sockaddr_in sender_addr;
      socklen_t sender_len = sizeof(sender_addr);

      ssize_t received = recvfrom(sock, &ack, sizeof(AckPacket), MSG_DONTWAIT, (struct sockaddr *)&sender_addr, &sender_len);

      if (received > 0 && ack.seq_num < num_chunks)
      {
        acked[ack.seq_num] = 1;
        //printf("ACK received for chunk %d with content: %.*s\n", ack.seq_num+1, chunks[ack.seq_num].chunk_size, chunks[ack.seq_num].data);
      }
    }

    // Check if all chunks are acknowledged
    int all_done = 1;
    for (int i = 0; i < num_chunks; i++)
    {
      if (!acked[i] && retransmission_count[i] < MAX_RETRANSMISSIONS)
      {
        all_done = 0;
        break;
      }
    }

    if (all_done)
    {
      printf("All chunks sent successfully or max retransmissions reached.\n");
      break;
    }

    // Timeout occurred: retransmit unacknowledged chunks
    gettimeofday(&now, NULL);
    double elapsed = (now.tv_sec - start.tv_sec) + (now.tv_usec - start.tv_usec) / 1000000.0;

    if (elapsed > TIMEOUT_SEC)
    {
      //printf("Timeout occurred. Retransmitting unacknowledged chunks.\n");
      for (int i = 0; i < num_chunks; i++)
      {
        if (!acked[i])
        {
          //printf("Retransmitting chunk %d/%d with content: %.*s\n", i + 1, num_chunks, chunks[i].chunk_size, chunks[i].data);
          ssize_t sent = sendto(sock, &chunks[i], sizeof(DataChunk), 0, dest_addr, dest_len);
          if (sent < 0)
          {
            perror("Sendto failed");
            free(chunks);
            free(acked);
            exit(EXIT_FAILURE);
          }
          retransmission_count[i]++;
        }
      }
      gettimeofday(&start, NULL); // Reset the timer
    }
  }

  free(chunks);
  free(acked);
}

void receive_data(int sock, struct sockaddr *sender_addr, socklen_t *sender_len)
{
  static char *received_data = NULL;
  static int *received_chunks = NULL;
  static int total_chunks = 0;
  static int chunks_received = 0;

  DataChunk chunk;
  ssize_t received = recvfrom(sock, &chunk, sizeof(DataChunk), 0, sender_addr, sender_len);

  if (received > 0)
  {
    //printf("Received data of size %zd bytes\n", received);

    if (!received_data || total_chunks != chunk.total_chunks)
    {
      free(received_data);
      free(received_chunks);
      total_chunks = chunk.total_chunks;
      received_data = calloc(total_chunks * MAX_CHUNK_SIZE, sizeof(char));
      received_chunks = calloc(total_chunks, sizeof(int));
      chunks_received = 0;

      if (!received_data || !received_chunks)
      {
        perror("Failed to allocate memory for received data");
        exit(EXIT_FAILURE);
      }
      printf("Initialized for new transmission with %d total chunks\n", total_chunks);
    }

    if (chunk.seq_num < total_chunks && !received_chunks[chunk.seq_num])
    {
      //printf("Processing chunk %d/%d with content: %.*s\n", chunk.seq_num + 1, total_chunks, chunk.chunk_size, chunk.data);
      memcpy(received_data + chunk.seq_num * MAX_CHUNK_SIZE, chunk.data, chunk.chunk_size);
      received_chunks[chunk.seq_num] = 1;
      chunks_received++;

      AckPacket ack;
      ack.seq_num = chunk.seq_num;

      if ((chunk.seq_num % 3 == 2) && (rand() % 2 == 0))
      {
        //printf("Simulating ACK loss for chunk %d\n", chunk.seq_num + 1);
        received_chunks[chunk.seq_num] = 0;
        chunks_received--;
      }
      else
      {
        ssize_t sent = sendto(sock, &ack, sizeof(AckPacket), 0, sender_addr, *sender_len);
        if (sent < 0)
        {
          perror("Failed to send ACK");
        }
        else
        {
          //printf("Sent ACK for chunk %d\n", chunk.seq_num + 1);
        }
      }

      if (chunks_received == total_chunks)
      {
        printf("Reassembled message: ");
        for (int i = 0; i < total_chunks; i++)
        {
          printf("%.*s", MAX_CHUNK_SIZE, received_data + i * MAX_CHUNK_SIZE);
        }
        printf("\n");

        free(received_data);
        free(received_chunks);
        received_data = NULL;
        received_chunks = NULL;
        total_chunks = 0;
        chunks_received = 0;
      }
    }
    else
    {
      printf("Discarding invalid or duplicate chunk %d/%d\n", chunk.seq_num + 1, total_chunks);
    }
  }
  else if (received < 0 && errno != EWOULDBLOCK && errno != EAGAIN)
  {
    perror("Error receiving data");
  }
}
int main(int argc, char *argv[])
{
  if (argc != 4)
  {
    fprintf(stderr, "Usage: %s <local_ip> <local_port> <remote_port>\n", argv[0]);
    exit(EXIT_FAILURE);
  }

  const char *local_ip = argv[1];
  int local_port = atoi(argv[2]);
  int remote_port = atoi(argv[3]);

  // Create socket
  int sock = create_socket(local_ip, &local_port);
  printf("Bound to port: %d\n", local_port);

  // Set up remote address
  struct sockaddr_in remote_addr;
  memset(&remote_addr, 0, sizeof(remote_addr));
  remote_addr.sin_family = AF_INET;
  remote_addr.sin_addr.s_addr = inet_addr(local_ip);
  remote_addr.sin_port = htons(remote_port);

  // Variables for select()
  fd_set readfds;
  struct timeval tv;

  while (1)
  {
    FD_ZERO(&readfds);
    FD_SET(STDIN_FILENO, &readfds); // Monitor standard input (keyboard)
    FD_SET(sock, &readfds);         // Monitor socket for incoming messages

    tv.tv_sec = 0;
    tv.tv_usec = 100000; // 100ms timeout

    int activity = select(sock + 1, &readfds, NULL, NULL, &tv);

    if (activity < 0)
    {
      perror("Select error");
      exit(EXIT_FAILURE);
    }
   
    // Check if there is input from the user (STDIN)
    if (FD_ISSET(STDIN_FILENO, &readfds))
    {
      char input[1024];
      printf("Enter message to send (or 'quit' to exit): "); // Prompt user
      if (fgets(input, sizeof(input), stdin) != NULL)
      {
        input[strcspn(input, "\n")] = 0; // Remove newline character

        if (strcmp(input, "quit") == 0)
          break;

        // Only send non-empty messages
        if (strlen(input) > 0)
        {
          // Send the message to the remote peer
          send_data(sock, input, (struct sockaddr *)&remote_addr, sizeof(remote_addr), 0); // 0 for fixed-size chunks
        }
      }
    }

    // Check if there's data coming in from the socket
    if (FD_ISSET(sock, &readfds))
    {
      struct sockaddr_in sender_addr;
      socklen_t sender_len = sizeof(sender_addr);
      receive_data(sock, (struct sockaddr *)&sender_addr, &sender_len);
    }
  }

  close(sock);
  return 0;
}
