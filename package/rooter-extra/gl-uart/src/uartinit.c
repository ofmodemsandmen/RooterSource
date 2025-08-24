#include <stdio.h>    
#include <stdlib.h> 
#include <unistd.h>   
#include <sys/types.h>  
#include <sys/stat.h>  
#include <fcntl.h>    
#include <termios.h>  
#include <errno.h>    
#include <string.h>
#include <sys/time.h>

int speed_arr[] ={ B115200,B38400, B19200, B9600, B4800, B2400, B1200, B300, B115200,B38400, B19200, B9600,B4800, B2400, B1200, B300, };
int name_arr[] ={ 115200,38400, 19200, 9600, 4800, 2400, 1200, 300,115200, 38400, 19200, 9600, 4800, 2400,1200, 300, };
int set_parity(int fd,int databits,int stopbits,int parity)
{
	struct termios options;
	if (tcgetattr (fd, &options) != 0){
		perror ("SetupSerial 1");
		return -1;
	}
	options.c_cflag &= ~CSIZE;
	options.c_iflag &= ~(ICRNL | IXON); //fix cannot receive 0x11 0x0d 0x13 bug
	options.c_lflag  &= ~(ICANON | ECHO | ECHOE | ISIG);  /*Input ->changed by kong*/     
	options.c_oflag  &= ~OPOST;   /*Output  ->changed by kong */
	switch (databits)
	{
		case 7:
			options.c_cflag |= CS7;
			break;
		case 8:
			options.c_cflag |= CS8;
			break;
		default:
			fprintf (stderr, "Unsupported data size\n");
			return -1;
	}
	switch(parity)
	{
		case 'n':
		case 'N':
			options.c_cflag &= ~PARENB;   /* Clear parity enable */
			options.c_iflag &= ~INPCK;    /* Enable parity checking */
			break;
		case 'o':
		case 'O':
			options.c_cflag |= (PARODD | PARENB);
			options.c_iflag |= INPCK;     /* Disnable parity checking */
			break;
		case 'e':
		case 'E':
			options.c_cflag |= PARENB;	  /* Enable parity */
			options.c_cflag &= ~PARODD;
			options.c_iflag |= INPCK;     /* Disnable parity checking */
			break;
		case 'S':
		case 's':
			options.c_cflag &= ~PARENB;
			options.c_cflag &= ~CSTOPB;
			break;
		default:
			fprintf (stderr, "Unsupported parity\n");
			return -1;
	}
	switch(stopbits)
	{
		case 1:
			options.c_cflag &= ~CSTOPB;
			break;
		case 2:
			options.c_cflag |= CSTOPB;
			break;
		default:
			fprintf (stderr, "Unsupported stop bits\n");
			return -1;
	}
	/* Set input parity option */
	if (parity != 'n')
		options.c_iflag |= INPCK;
	tcflush (fd, TCIFLUSH);
	options.c_cc[VTIME] = 0;
	options.c_cc[VMIN] = 1;     /* Update the options and do it NOW */
	if (tcsetattr (fd, TCSANOW, &options) != 0) {
		perror ("SetupSerial 3");
		return -1;
	}
	return 0;
}

void set_speed(int fd,int speed)
{
	int i;
	int status;
	struct termios opt;
	tcgetattr(fd,&opt);
	for(i=0;i<sizeof(speed_arr)/sizeof(int);i++)
	{
		if(speed == name_arr[i]) {
			tcflush(fd,TCIOFLUSH);	
			cfsetispeed(&opt,speed_arr[i]);
			cfsetospeed(&opt,speed_arr[i]);
			status = tcsetattr(fd,TCSANOW,&opt);
			if(status != 0) {
				perror("tcsetattr fd failed!");
				return;
			}
			tcflush(fd,TCIOFLUSH);
		}
	}
}

int main(int argc, char *argv[])  
{  
	int fd;  
	int i = 0;
	int a = 0;
	int *fd_uart;
	unsigned char *hex;

	if(argc != 3) {
		printf("please exec ./uart_test 115200 string!\n");
		return -1;
	}
	/*打开串口  */
	fd = open(argv[2], O_RDWR | O_NOCTTY);// | O_NDELAY);
	if(fd < 0 ) {
		fprintf(stderr,"open %s failed !",ttyname(fd));
		exit(1);
	}
	//MCU
	set_speed(fd,atoi(argv[1]));
	if(set_parity(fd,8,1,'N') < 0 ) {
		printf("Set parity error");
		close(fd);
		exit(0);
	}
	close(fd);  

	return 0;  
}  

