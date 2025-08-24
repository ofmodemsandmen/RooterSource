#include <stdio.h>  
#include <stdlib.h> 
#include <unistd.h>   
#include <sys/types.h>  
#include <sys/stat.h>  
#include <fcntl.h>  
#include <termios.h>  
#include <errno.h>  
#include <string.h>
#include <pthread.h>
#include <sys/time.h>
#include <signal.h>

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

unsigned char char_to_hex(unsigned char bHex){ 
	if((bHex>='0')&&(bHex<='9')) 
		bHex -= 0x30; 
	else if((bHex>='a')&&(bHex<='f'))//小写字母 
		bHex -= 0x57;
	else if((bHex>='A')&&(bHex<='F'))
		bHex -= 0x37;
	else bHex = 0x00; 
	return bHex; 
} 
void func(int fd)
{
	printf("Fail\n");
	system("killall -9 gl_uart");
}
float my_pow(char i)
{
	float c=1;
	while(i--)
		c*= 0.5;
	return c;
}
int temp_hex_to_float(unsigned char high, unsigned char low, double *result)
{
	char a,i;
	double b = 0;
	a = (high << 4) + (low >> 4); 
	for(i=0; i<4; i++) 
	{
		if(low & (1 << (3-i)))
			b += my_pow(i+1);
	}
	*result = a+b;
	//printf("%.4f\n",*result);
	return 0;
}

int data_analysis(unsigned char *buf)
{
	//printf("hex[2]=%2x\n", hex[2]);
	double result = 0;
	char type = 0;
	char rw = 0;
	char ctl = 0;
	char response = 0;
	char week[][8] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
	type = (buf[2] >> 4) & 0x0f;
	rw = (buf[2] >> 3) & 0x01;
	ctl = buf[2] & 0x07;

	//printf("type=%d rw=%d ctl=%d \n", type, rw, ctl);
	switch(type)	
	{
		case 1:
			printf("LED Data %02x\n", buf[4]);
			response = 6;
			break;
		case 2:
			printf("Power Data %02x\n", buf[4]);
			response = 6;
			break;
		case 3:
			temp_hex_to_float(buf[5], buf[4], &result);
			printf("Temp Data %.4f\n", result);
			response = 7;
			break;
		case 4:
			response = 26;
			break;
		case 5:
			printf("RTC 20%02x-%02x-%02x %s %02x:%02x:%02x\n",
					buf[10], buf[9], buf[8], week[buf[7]], buf[6] & 0x3f, buf[5], buf[4]);
			response = 12;	
			break;
		case 6:
            printf("Sim Select:%02x\n",buf[4]);
            response = 6;
            break;          
		default:
			response = 1;
			break;
	}

	return 0;
}
int get_uart_dev_name(char *dev_name,int len)
{
	FILE *fp = popen("find /sys/devices/platform/ahb/1b000000.usb/usb1/1-1/1-1.3/1-1.3:1.0/ -name ttyUSB* | head -n1 | cut -f10 -d/","r");

	if(fp != NULL){
		fgets(dev_name,len,fp);
		pclose(fp);
		if(strlen(dev_name))
			dev_name[strlen(dev_name) - 1] = '\0';
	}
	return 0;
}
int main(int argc, char *argv[])  
{  
	int fd;  
	int i = 0;
	int a = 0;
	int *fd_uart;
	unsigned char *hex;

	if(argc > 3 || argc < 2){
		printf("Version:3.0.6\t\n");

		return -1;
	}
	char dev_name[32] = {0};
	char dname[64] = {0};

	//get_uart_dev_name(dev_name,sizeof(dev_name));
	//if(strlen(dev_name) == 0)
		strcpy(dname,"/dev/ttyUSB1");
	//else
		//sprintf(dname,"/dev/%s",dev_name);
	
	/*打开串口  */
	fd = open(dname, O_RDWR | O_NOCTTY);// | O_NDELAY);
	if(fd < 0 ) {
		fprintf(stderr,"open %s failed !",ttyname(fd));
		exit(1);
	}
	if(argc == 3) {
		hex = argv[2];
		a = strlen(argv[2]);
		set_speed(fd,atoi(argv[1]));
		if(set_parity(fd,8,1,'N') < 0 ) {
			printf("Set parity error");
			close(fd);
			exit(0);
		}
	} else {
		hex = argv[1];
		a = strlen(argv[1]);
	}
	unsigned char checksum = 0;
	for(i=0 ; i< a; i+=2) {
		hex[i/2] = char_to_hex(hex[i])*16;
		hex[i/2] += char_to_hex(hex[i+1]);
		if(i > 3)
			checksum += hex[i/2];
	}
	hex[a/2] = checksum;

	char type = 0;
	char rw = 0;
	char ctl = 0;
	char response = 0;
	type = (hex[2] >> 4) & 0x0f;
	rw = (hex[2] >> 3) & 0x01;
	ctl = hex[2] & 0x07;

	//printf("type=%d rw=%d ctl=%d \n", type, rw, ctl);
	switch(type)	
	{
		case 1:
			response = 6;
			break;
		case 2:
			response = 6;
			break;
		case 3:
			response = 7;
			break;
		case 4:
			response = 26;
			break;
		case 5:
			response = 12;	
			break;
		case 6:
			response = 6;
			break;
		default:
			response = 0;
			break;
	}
	int count = write(fd,hex,a/2+1);  
	unsigned char buf[128] = {0};
	int flag = 0;
	i = 0;
	signal(SIGALRM, func); //time out 
	alarm(10); 
	while(1)
	{
		read(fd,&buf[i],1);
		i++;
		if(i == response){
			flag = 1;
			break;
		}
	}
	// checksum 
	checksum = 0;
	for(i = 0; i < buf[3] + 2; i++)
		checksum += buf[2+i];

	if(type == 4) {
		printf("%s",buf);
	} else {
		if(buf[response - 1] == checksum) {
			for(i = 4; i < response - 1; i++)
				printf("%02x", buf[i]);
			printf("\n");

			data_analysis(buf);
		}
	}
	close(fd);  

	return 0;  
}  
