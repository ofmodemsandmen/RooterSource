/******************************************************************************
  @file    ql-tty2tcp.c
  @brief   switch data between tcp socket and ttyUSB port.

  DESCRIPTION
  QLog Tool for USB and PCIE of Quectel wireless cellular modules.

  INITIALIZATION AND SEQUENCING REQUIREMENTS
  None.

  ---------------------------------------------------------------------------
  Copyright (c) 2016 - 2020 Quectel Wireless Solution, Co., Ltd.  All Rights Reserved.
  Quectel Wireless Solution Proprietary and Confidential.
  ---------------------------------------------------------------------------
******************************************************************************/
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <time.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <poll.h>

char *inet_ntoa(struct in_addr in);

static int s_quit = 0;
static uint8_t s_rbuf[16*1024];

static int wait_tcp_client_connect(int tcp_port) {
    int sockfd, n, connfd;
    struct sockaddr_in serveraddr;
    struct sockaddr_in clientaddr;
    int reuse_addr = 1;
    size_t sin_size;

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1)
    {
        printf("Create socket fail!\n");
        return 0;
    }

    memset(&serveraddr, 0, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    serveraddr.sin_addr.s_addr = htonl(INADDR_ANY);
    serveraddr.sin_port = htons(tcp_port);

    printf("Starting the TCP server(%d)...\n", tcp_port);

    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuse_addr,sizeof(reuse_addr));

    n = bind(sockfd, (struct sockaddr *)&serveraddr, sizeof(serveraddr));
    if (n == -1)
    {
        printf("bind fail! errno: %d\n", errno);
        close(sockfd);
        return 0;
    }
    printf("bind OK!\n");

    n = listen(sockfd, 1);
    if (n == -1)
    {
        printf("listen fail! errno: %d\n", errno);
        close(sockfd);
        return 0;
    }
    printf("listen OK!\nWaiting the TCP Client...\n");

    sin_size = sizeof(struct sockaddr_in);
    connfd = accept(sockfd, (struct sockaddr *)&clientaddr, (socklen_t *)&sin_size);
    close(sockfd);
    if (connfd == -1)
    {
        printf("accept fail! errno: %d\n", errno);
        return -1;
    }

    printf("TCP Client %s:%d connect\n", inet_ntoa(clientaddr.sin_addr), clientaddr.sin_port);

    return connfd;
}

static ssize_t tty2tcp_poll_write(int fd, const uint8_t *buf, size_t size, unsigned timeout_msec) {
    ssize_t wc = 0;
    ssize_t nbytes;

    nbytes = write(fd, (uint8_t *)buf+wc, size-wc);

    if (nbytes <= 0) {
        if (errno != EAGAIN) {
            printf("Fail to write fd = %d, errno : %d (%s)\n", fd, errno, strerror(errno));
            goto out;
        }
        else {
            nbytes = 0;
        }
    }

    wc += nbytes;

    while ((size_t)wc < size) {
        int ret;
        struct pollfd pollfds[] = {{fd, POLLOUT, 0}};

        ret = poll(pollfds, 1, timeout_msec);

        if (ret <= 0) {
            printf("poll(%d)=%d errno : %d (%s)\n", fd, ret, errno, strerror(errno));
            break;
        }

        if (pollfds[0].revents & (POLLERR | POLLHUP | POLLNVAL)) {
            printf("poll(%d) revents = %04x\n", fd, pollfds[0].revents);
            break;
        }

        if (pollfds[0].revents & (POLLOUT)) {
            nbytes = write(fd, (uint8_t *)buf+wc, size-wc);

            if (nbytes <= 0) {
                printf("write(%d)=%zd, errno : %d (%s)\n", fd, nbytes, errno, strerror(errno));
                break;
            }
            wc += nbytes;
        }
    }

out:
    if ((size_t)wc != size) {
        printf("WRAN: fd=%d, write %zd/%zd, timeout=%d\n", fd, wc, size, timeout_msec);
    }

    return (wc);
}

static void tty2tcp_sigaction(int signal_num) {
    s_quit = 1;
    printf("recv signal %d\n", signal_num);
}

static void tty2tcp_usage(const char *self, const char *dev) {
    printf("Usage: %s -p <tcp server port> -d <tty port> \n", self);
    printf("Default: %s -p %d -d %s\n", self, 9000, "/dev/ttyUSB0");
}

int main(int argc, char **argv)
{
    int opt;
    char ttyname[32] = "/dev/ttyUSB0";
    int tcp_port = 9000;
    int ttyfd = -1;
    int sockfd = -1;
    struct termios  ios;

    optind = 1; //call by popen(), optind mayby is not 1
    while ( -1 != (opt = getopt(argc, argv, "d:p:h"))) {
        switch (opt) {
            case 'p':
                tcp_port = atoi(optarg);
            break;
            case 'd':
                strcpy(ttyname, optarg);
            break;
            default:
                tty2tcp_usage(argv[0], ttyname);
            return 0;
            break;
        }
    }

    signal(SIGTERM, tty2tcp_sigaction);
    signal(SIGHUP, tty2tcp_sigaction);
    signal(SIGINT, tty2tcp_sigaction);

    ttyfd = open (ttyname, O_RDWR | O_NDELAY | O_NOCTTY);
    printf("open %s ttyfd = %d\n", ttyname, ttyfd);

    if (ttyfd <= 0) {
        printf("Fail to open %s, errno : %d (%s)\n", ttyname, errno, strerror(errno));
        return -1;
    }

    memset(&ios, 0, sizeof(ios));
    tcgetattr( ttyfd, &ios );
    cfmakeraw(&ios);
    cfsetispeed(&ios, B115200);
    cfsetospeed(&ios, B115200);
    tcsetattr( ttyfd, TCSANOW, &ios );

    sockfd = wait_tcp_client_connect(tcp_port);
    printf("open %d sockfd = %d\n", tcp_port, sockfd);

    if (sockfd <= 0) {
        close(ttyfd);
        return -1;
    }

    printf("Press CTRL+C to stop %s\n", argv[0]);

    while (s_quit == 0) {
        ssize_t rc, wc;
        int ret;
        int n;
        struct pollfd pollfds[] = {{ttyfd, POLLIN, 0}, {sockfd, POLLIN, 0}};

        ret = poll(pollfds, 2, -1);

        if (ret <= 0) {
            printf("poll() =%d, errno: %d (%s)\n", ret, errno, strerror(errno));
            break;
        }

        for (n = 0; n < 2; n++) {
            if (pollfds[n].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                printf("poll(%d) revents = %04x\n", pollfds[n].fd, pollfds[0].revents);
                s_quit = 1;
                break;
            }

            if ((pollfds[n].revents & (POLLIN)) == 0)
                continue;

            rc = read(pollfds[n].fd, s_rbuf, sizeof(s_rbuf));

            if(rc > 0) {
                wc = tty2tcp_poll_write(pollfds[1-n].fd, s_rbuf, rc, 200);
                if (wc != rc) {
                }
            }
            else {
                printf("read(%d)=%zd, errno: %d (%s)\n", pollfds[n].fd, rc, errno, strerror(errno));
                s_quit = 1;
                break;
            }
        }
    }

    close(ttyfd);
    close(sockfd);

    return 0;
}
