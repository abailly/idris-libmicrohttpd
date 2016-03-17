# the compiler: gcc for C program
CC = gcc

# compiler flags:
CFLAGS  = -Wall

# define any libraries to link:
LIBS = -lmicrohttpd

SRCS = lmh.c

all: $(SRCS)
	$(CC) $(CFLAGS) -c $(SRCS) $(LFLAGS) $(LIBS)

clean:
	$(RM) *.o *~  a.out
