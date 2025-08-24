#LDFLAGS += -ljson-c 

SRC=$(wildcard *.c)
OBJS=$(patsubst %.c,%.o,$(wildcard *.c))

all : gl_uart uartinit 
	@echo "compile done"

%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@ 

uartinit: uartinit.o 
	$(CC) $^ -o $@ $(LDFLAGS) 

gl_uart: gl_uart.o 
	$(CC) $^ -o $@ $(LDFLAGS) 

clean:
	rm -fr $(PROC) $(OBJS)
