# Compiler
CC = gcc

# Flags
CFLAGS = -pthread

# Executables
SS_EXEC = ss
NM_EXEC = nm
CL_EXEC = cl

# Source files
SS_SRC = ss.c nm_requests.c cl_requests.c
NM_SRC = nm.c log_nm.c nm_helper.c trie.c
CL_SRC = cl.c

# Object files (Optional, for modular compilation)
SS_OBJ = $(SS_SRC:.c=.o)
NM_OBJ = $(NM_SRC:.c=.o)
CL_OBJ = $(CL_SRC:.c=.o)

# Default target
all: $(SS_EXEC) $(NM_EXEC) $(CL_EXEC)

# Compile the storage server
$(SS_EXEC): $(SS_SRC) ss.h
	$(CC) -o $@ $^ $(CFLAGS)

# Compile the naming server
$(NM_EXEC): $(NM_SRC) nm.h
	$(CC) -o $@ $^ $(CFLAGS)

# Compile the client
$(CL_EXEC): $(CL_SRC)
	$(CC) -o $@ $^ $(CFLAGS)

# Clean up generated files
clean:
	rm -f $(SS_EXEC) $(NM_EXEC) $(CL_EXEC) *.o
