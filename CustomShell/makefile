CC = gcc

CFLAGS = -Wall -Wextra -I.

TARGET = a.out

SRCS = helper.c hop.c log.c proclore.c reveal.c seek.c shell.c sys_command.c io_redirection.c pipe.c activities.c signals.c fg_bg.c iMan.c

OBJS = $(SRCS:.c=.o)
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

# Rule to compile source files into object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@


clean:
	rm -f $(TARGET) $(OBJS)


.PHONY: all clean
