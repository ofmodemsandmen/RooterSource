/******************************************************************************
  @file    tty2tcp.c
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
#include "qlog.h"
#include <netinet/ip.h>
#include <arpa/inet.h>
#include <sys/types.h>
extern int g_tcp_client_port;
extern char g_tcp_client_ip[16];

unsigned int inet_addr(const char *cp);
char *inet_ntoa(struct in_addr in);

#define CACHE_SIZE (2*1024*1024)
static const size_t cache_step = (256*1024);

#ifdef CACHE_SIZE
#define min(x,y) (((x) < (y)) ? (x) : (y))
struct __kfifo {
    int fd;
    size_t in;
    size_t out;
    size_t size;
    void *data;
};

static int __kfifo_write(struct __kfifo *fifo, const void *buf, size_t size) {
    void *data;
    size_t unused, len;
    ssize_t nbytes;
    int fd = fifo->fd;

    if (fifo->out == fifo->in) {
        nbytes = qlog_poll_write(fd, buf, size, 0);

        if (nbytes > 0) {
            if ((size_t)nbytes == size) {
                return 1;
            } else {
                buf += nbytes;
                size -= nbytes;
            }
        }
        else if (errno == ECONNRESET) {
            qlog_dbg("TODO: ECONNRESET\n");
            return 0;
        }
    }

    unused = fifo->size - fifo->in;
    if (unused < size && size < (unused + fifo->out)) {
        memmove(fifo->data, fifo->data + fifo->out, fifo->in - fifo->out);
        fifo->in -=  fifo->out;
        fifo->out = 0;
    }

    unused = fifo->size - fifo->in;
    if (unused < size && fifo->size < CACHE_SIZE) {
        data = malloc(fifo->size + cache_step);

        if (data) {
            qlog_dbg("cache[fd=%d] size %zd -> %zd KB\n", fd, fifo->size/1024, (fifo->size + cache_step)/1024);
            if (fifo->data) {
                len = fifo->in - fifo->out;
                if (len)
                    memcpy(data, fifo->data + fifo->out, len);
                free(fifo->data);
            }

            fifo->in -=  fifo->out;
            fifo->out = 0;
            fifo->size += cache_step;
            fifo->data = data;
        }
    }

    unused = fifo->size - fifo->in;
    if (unused < size) {
        static size_t drop = 0;
        static unsigned slient_msec = 0;
        unsigned now = qlog_msecs();

        drop += size;
        if ((slient_msec+2000) < now) {
            qlog_dbg("cache[fd=%d] full, total drop %zd\n", fd, drop);
            slient_msec = now;
        }
    }
    else {
        memcpy(fifo->data + fifo->in, buf, size);
        fifo->in += size;
    }

    len = fifo->in - fifo->out;
    if (len) {
        nbytes = qlog_poll_write(fd, fifo->data + fifo->out, len, 0);

        if (nbytes > 0) {
            fifo->out += nbytes;

            if (fifo->out == fifo->in) {
                fifo->in = 0;
                fifo->out = 0;
            }
        }
        else if (errno == ECONNRESET) {
            qlog_dbg("TODO: ECONNRESET\n");
            return 0;
        }
    }

    return 1;
}

#define FIFO_NUM 12
static struct __kfifo kfifo[FIFO_NUM] = {{-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL},
                                        {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL},
                                        {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}, {-1, 0, 0, 0, NULL}};

int kfifo_alloc(int fd) {
    int idx = 0;
    int flags;

    if (fd == -1)
        return fd;

    for (idx = 0; idx < FIFO_NUM; idx++) {
        if (kfifo[idx].fd == -1)
            break;
    }

    if (idx == FIFO_NUM) {
        qlog_dbg("No Free FIFO for fd = %d\n", fd);
        return -1;
    }

    kfifo[idx].fd = fd;
    kfifo[idx].in = kfifo[idx].out = 0;

    flags = fcntl(fd, F_GETFL);
    if (flags != -1)
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    qlog_dbg("%s [%d] = %d\n", __func__, idx, fd);
    return idx;
}

size_t kfifo_write(int idx, const void *buf, size_t size) {
    if (idx < 0 ||  idx >= FIFO_NUM)
        return 0;
    return __kfifo_write(&kfifo[idx], buf, size) ? size : 0;
}

void kfifo_free(int idx) {
    if (idx < 0 || idx >= FIFO_NUM)
        return;
    qlog_dbg("%s [%d] = %d\n", __func__, idx, kfifo[idx].fd);
    kfifo[idx].fd = -1;
    kfifo[idx].in = kfifo[idx].out = 0;
}

int kfifo_idx(int fd) {
    int idx = 0;

    if (fd == -1)
        return fd;

    for (idx = 0; idx < FIFO_NUM; idx++) {
        if (kfifo[idx].fd == fd)
            break;
    }

    if (idx == FIFO_NUM) {
        return -1;
    }

    return idx;
}
#endif

static int wait_tcp_client_connect(int tcp_port) {
    int sockfd, n, connfd;
    struct sockaddr_in serveraddr;
    struct sockaddr_in clientaddr;
    int reuse_addr = 1;
    size_t sin_size;

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1)
    {
        qlog_dbg("Create socket fail!\n");
        return 0;
    }

    memset(&serveraddr, 0, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    serveraddr.sin_addr.s_addr = htonl(INADDR_ANY);
    serveraddr.sin_port = htons(tcp_port);

    qlog_dbg("Starting the TCP server(%d)...\n", tcp_port);

    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuse_addr,sizeof(reuse_addr));

    n = bind(sockfd, (struct sockaddr *)&serveraddr, sizeof(serveraddr));
    if (n == -1)
    {
        qlog_dbg("bind fail! errno: %d\n", errno);
        close(sockfd);
        return 0;
    }
    qlog_dbg("bind OK!\n");

    n = listen(sockfd, 1);
    if (n == -1)
    {
        qlog_dbg("listen fail! errno: %d\n", errno);
        close(sockfd);
        return 0;
    }
    qlog_dbg("listen OK! and Waiting the TCP Client...\n");

    sin_size = sizeof(struct sockaddr_in);
    connfd = accept(sockfd, (struct sockaddr *)&clientaddr, (socklen_t *)&sin_size);
    close(sockfd);
    if (connfd == -1)
    {
        qlog_dbg("accept fail! errno: %d\n", errno);
        return -1;
    }

    fcntl(connfd, F_SETFL, fcntl(connfd, F_GETFL) | O_NONBLOCK);

    qlog_dbg("TCP Client %s:%d connect tcp port %d, connfd = %d\n",
        inet_ntoa(clientaddr.sin_addr), clientaddr.sin_port, tcp_port, connfd);

    kfifo_alloc(connfd);
    return connfd;
}

int tty2tcp_sockfd = -1;
static int tty2tcp_ttyfd = -1;
static int tty2tcp_logfd = -1;
static int tty2tcp_thirdfd = -1;
static int tty2tcp_tcpport = 9000;
#define  tty2tcp_closefd(_fd) do { if (_fd != -1) { int tmp_fd = _fd; _fd = -1; kfifo_free(kfifo_idx(tmp_fd)); close(tmp_fd);}} while (0)

static void *tcp_sock_read_Loop(void *arg) {
    void *rbuf;
    const size_t rbuf_size = (4*1024);

    (void)arg;
    rbuf = malloc(rbuf_size);
    if (rbuf == NULL) {
          qlog_dbg("Fail to malloc rbuf_size=%zd, errno: %d (%s)\n", rbuf_size, errno, strerror(errno));
          return NULL;
    }

    while (qlog_exit_requested == 0) {
        ssize_t rc, wc;
        int ret;
        struct pollfd pollfds[] = {{0, POLLIN, 0}, {0, POLLIN, 0}, {0, POLLIN, 0}};
        int n = 0, i;

        if (tty2tcp_sockfd == -1 && tty2tcp_logfd == -1 && tty2tcp_thirdfd == -1) {
            tty2tcp_sockfd = wait_tcp_client_connect(tty2tcp_tcpport);
            if (tty2tcp_sockfd == -1)
                break;

            if (g_is_unisoc_chip) {
                tty2tcp_logfd = wait_tcp_client_connect(tty2tcp_tcpport+1);
                if (tty2tcp_logfd == -1)
                    break;
            }

            if (g_is_unisoc_exx00u_chip) {
                tty2tcp_logfd = wait_tcp_client_connect(tty2tcp_tcpport+1);
                if (tty2tcp_logfd == -1)
                    break;
            }

            if (g_is_qualcomm_chip)
            {
                if (use_diag_qdss)
                {
                    tty2tcp_logfd = wait_tcp_client_connect(tty2tcp_tcpport+1);
                    if (tty2tcp_logfd == -1)
                        break;
                }

                if (use_diag_dpl)
                {
                    tty2tcp_thirdfd = wait_tcp_client_connect(tty2tcp_tcpport+2);
                    if (tty2tcp_thirdfd == -1)
                        break;
                }
            }

        }

        if (tty2tcp_sockfd != -1)
            pollfds[n++].fd = tty2tcp_sockfd;

        if (tty2tcp_logfd != -1)
            pollfds[n++].fd = tty2tcp_logfd;

        if (tty2tcp_thirdfd != -1)
            pollfds[n++].fd = tty2tcp_thirdfd;

        if (n == 0)
            break;

        do {
            ret = poll(pollfds, n, -1);
        } while (ret == -1 && errno == EINTR && qlog_exit_requested == 0);

        if (ret <= 0) {
            qlog_dbg("poll(ttyfd) =%d, errno: %d (%s)\n", ret, errno, strerror(errno));
            break;
        }

        for (i = 0; i <  n; i++) {
            int fd = pollfds[i].fd;

            if (pollfds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                qlog_dbg("fd = %d revents = %04x\n", fd, pollfds[0].revents);
                if (pollfds[i].fd == tty2tcp_sockfd)
                {
                    tty2tcp_closefd(pollfds[i].fd);
                    pollfds[i].fd = -1;
                    tty2tcp_sockfd = -1;
                }
                else if (pollfds[i].fd == tty2tcp_logfd)
                {
                    tty2tcp_closefd(pollfds[i].fd);
                    pollfds[i].fd = -1;
                    tty2tcp_logfd = -1;
                }
                else if (pollfds[i].fd == tty2tcp_thirdfd)
                {
                    tty2tcp_closefd(pollfds[i].fd);
                    pollfds[i].fd = -1;
                    tty2tcp_thirdfd = -1;
                }

                break;
            }

            if (!(pollfds[i].revents & (POLLIN)))
                continue;

            rc = read(fd, rbuf, rbuf_size);

            if (rc <= 0) {
                qlog_dbg("sockfd = %d recv %zd Bytes. maybe terminae by peer!\n", fd, rc);
                if (fd == tty2tcp_sockfd)
                    tty2tcp_closefd(tty2tcp_sockfd);
                else if (fd == tty2tcp_logfd)
                    tty2tcp_closefd(tty2tcp_logfd);
                else if (fd == tty2tcp_thirdfd)
                    tty2tcp_closefd(tty2tcp_thirdfd);
            }
            else if (fd == tty2tcp_sockfd){

                if (g_is_asr_chip)
                    wc = asr_send_cmd(tty2tcp_ttyfd, rbuf, rc);
                else if (g_is_unisoc_chip)
                    wc = qlog_poll_write(tty2tcp_ttyfd, rbuf, rc, 1000);
                else if (g_is_unisoc_exx00u_chip)
                    wc = qlog_poll_write(tty2tcp_ttyfd, rbuf, rc, 1000);
                else if (g_is_eigen_chip)
                    wc = qlog_poll_write(tty2tcp_ttyfd, rbuf, rc, 1000);
                else
                    wc = mdm_send_cmd(tty2tcp_ttyfd, rbuf, rc, 0);

                if (wc != rc) {
                    //qlog_dbg("ttyfd write fail %zd/%zd, break\n", wc, rc);
                    //break;
                }
            }
            else
            {
                qlog_dbg("recv %zd Bytes from fd = %d\n", rc, fd);
            }
        }
    }

    free(rbuf);
    tty2tcp_closefd(tty2tcp_sockfd);
    tty2tcp_closefd(tty2tcp_logfd);
    tty2tcp_closefd(tty2tcp_thirdfd);
    qlog_dbg("%s exit\n", __func__);

    return NULL;
}

static int tty2tcp_init_filter(int ttyfd, const char *cfg) {
    pthread_t tid;
    pthread_attr_t attr;

    tty2tcp_ttyfd = ttyfd;
    if (cfg)
        tty2tcp_tcpport = atoi(cfg);

    pthread_attr_init (&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&tid, &attr, tcp_sock_read_Loop, NULL);

    return 0;
}

static int tty2tcp_logfile_create(const char *logfile_dir, const char *logfile_suffix, unsigned logfile_seq) {
    (void)logfile_dir;
    (void)logfile_suffix;
    (void)logfile_seq;
    return 1;
}

static size_t tty2tcp_logfile_save(int logfd, const void *buf, size_t size) {
    (void)logfd;
	if (g_is_unisoc_chip)
    {
        if (g_unisoc_log_type == 0) {           // RG500U/RM500U dm
            if (tty2tcp_sockfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_sockfd), buf, size);
        }
        else {                                  // RG500U/RM500U log
            if (tty2tcp_logfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_logfd), buf, size);
        }
    }
    else if (g_is_unisoc_exx00u_chip)
    {
        if (g_unisoc_exx00u_log_type == 0) {           // EXX00U cp log
            if (tty2tcp_sockfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_sockfd), buf, size);
        }
        else {                                  // EXX00U ap log
            if (tty2tcp_logfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_logfd), buf, size);
        }
    }
    else if (g_is_qualcomm_chip)
    {
        if (g_qualcomm_log_type == 0) {           // qualcomm dm
            if (tty2tcp_sockfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_sockfd), buf, size);
        }
        else if (g_qualcomm_log_type == 1) {                                  // qualcomm log
            if (tty2tcp_logfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_logfd), buf, size);
        }
        else {                                  // qualcomm third
            if (tty2tcp_thirdfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_thirdfd), buf, size);
        }
    }
    else
    {
        if (g_unisoc_log_type == 0) {           // other chip
            if (tty2tcp_sockfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_sockfd), buf, size);
        }
        else {                                  // other chip
            if (tty2tcp_logfd == -1) {
                return size;
            }

            return kfifo_write(kfifo_idx(tty2tcp_logfd), buf, size);
        }
    }
}

static int tty2tcp_logfile_close(int logfd) {
    (void)logfd;
    return 0;
}

qlog_ops_t tty2tcp_qlog_ops = {
    .init_filter = tty2tcp_init_filter,
    .logfile_create = tty2tcp_logfile_create,
    .logfile_save = tty2tcp_logfile_save,
    .logfile_close = tty2tcp_logfile_close,
};

static int tcp_client_logfile_create(const char *logfile_dir, const char *logfile_suffix, unsigned logfile_seq)
{
    int ret = -1;
    int logfd = -1;

    (void)logfile_dir;
    (void)logfile_suffix;
    (void)logfile_seq;
    logfd = socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
    if (logfd <0)
    {
        qlog_dbg("qlog_tcp_client_logfile_create : socket : error\n");
        return -1;
    }

    struct sockaddr_in ser;
    memset(&ser,0,sizeof(ser));

    ser.sin_family = AF_INET;
    ser.sin_port = htons(g_tcp_client_port);
    ser.sin_addr.s_addr = inet_addr(g_tcp_client_ip);

    do
    {
        qlog_dbg("Actively connect to the server...\n");
        ret = connect(logfd,(struct sockaddr *)&ser,sizeof(ser));
        if (ret == 0)
        {
            qlog_dbg("TCP connection established ip:%s  port:%d\n",g_tcp_client_ip,g_tcp_client_port);
            break;
        }else
        {
            qlog_dbg("qlog_tcp_client_logfile_create : connect error\n");
            logfd = -1;
            break;
        }
    } while(1);

    kfifo_alloc(logfd);
    return logfd;
}

qlog_ops_t tcp_client_qlog_ops = {
    .logfile_create = tcp_client_logfile_create,
};
