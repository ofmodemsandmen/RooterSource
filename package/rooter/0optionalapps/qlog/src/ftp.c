/******************************************************************************
  @file    ftp.c
  @brief   upload Log and dump.

  DESCRIPTION
  QLog Tool for USB and PCIE of Quectel wireless cellular modules.

  INITIALIZATION AND SEQUENCING REQUIREMENTS
  None.

  ---------------------------------------------------------------------------
  Copyright (c) 2016 - 2021 Quectel Wireless Solution, Co., Ltd.  All Rights Reserved.
  Quectel Wireless Solution Proprietary and Confidential.
  ---------------------------------------------------------------------------
******************************************************************************/

#include "qlog.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <errno.h>
#include <poll.h>
#include <assert.h>
#include <fcntl.h>
#include <ctype.h>
#include <netinet/ip.h>

extern unsigned qlog_msecs(void);
#define dbg(fmt, arg... ) do { unsigned msec = qlog_msecs();  printf("[%03d.%03d]" fmt,  msec/1000, msec%1000, ## arg);} while (0)
#define errno_dbg(fmt, ...) do {dbg(fmt ", errno: %d (%s) at File: %s, Line: %d\n", ##__VA_ARGS__, errno, strerror(errno), __func__, __LINE__);} while (0)
#define FTP_MAX_RETRY  5

struct q_ftp_tag {
    int server_fd;
    char login[4];
};

struct q_ftp_tag_combination {
    struct q_ftp_tag q_ftp_t[3];
};

struct q_ftp_tag_combination q_ftp_tag_comb;

static char buf[1024];
ssize_t ret_ftp_write = 0;
extern const char *g_ftp_server_ip;

static int connet_tcp_server(const char *server, int port)
{
    int ret = -1;
    int sockfd = -1;
    struct sockaddr_in ser;

    sockfd = socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
    if (sockfd <0)
    {
        dbg("qlog_tcp_client_logfile_create : socket : error\n");
        return -1;
    }

    memset(&ser,0,sizeof(ser));
    ser.sin_family = AF_INET;
    ser.sin_port = htons(port);
    ser.sin_addr.s_addr = inet_addr(server);

    dbg("connect to the server %s ...\n", server);
    ret = connect(sockfd,(struct sockaddr *)&ser,sizeof(ser));
    if (ret) {
        close(sockfd);
        sockfd = -1;
    }
    dbg("connect %s\n", sockfd == -1 ? "fail" : "successful");

    return sockfd;
}

void ftp_die(const char *msg)
{
    char *cp = buf; /* buf holds peer's response */

    /* Guard against garbage from remote server */
    while (*cp >= ' ' && *cp < '\x7f')
        cp++;
    *cp = '\0';
    dbg("unexpected server response%s%s: %s\n",(msg ? " to " : ""), (msg ? msg : ""), buf);
    //exit(-1); //debugging
}

int ftpcmd(const char *s1, const char *s2, int server_fd)
{
    unsigned n;

    dbg("cmd > %s %s\n", s1, s2);

    if (s1) {
        snprintf(buf, sizeof(buf), (s2 ? "%s %s\r\n" : "%s %s\r\n"+3),s1, s2);
        ret_ftp_write = write(server_fd, buf, strlen(buf));
    }

    do {
        int len;
        strcpy(buf, "EOF"); /* for ftp_die */
        len = read(server_fd, buf, sizeof(buf) - 2);
        if (len <= 0) {  //ftp connect error or timeout
            ftp_die(NULL);
            return 0;
        }
        else {
            buf[len] = 0;
        }
    } while (!isdigit(buf[0]) || (buf[3] != ' ' &&  buf[3] != '-'));

    buf[3] = '\0';
    dbg("cmd < %s %s\n", buf, buf+4);
    n = atoi(buf);
    buf[3] = ' ';
    return n;
}

void ftp_quit(void)
{
    int i;
    for(i=0;i<3;i++)
    {
        if (strncasecmp(q_ftp_tag_comb.q_ftp_t[i].login, "on", 2))
            continue;

        if (ftpcmd(NULL, NULL, q_ftp_tag_comb.q_ftp_t[i].server_fd) != 226) {
            ftp_die(NULL);
        }

        if (ftpcmd("QUIT", NULL, q_ftp_tag_comb.q_ftp_t[i].server_fd) != 221) {
            ftp_die("QUIT");
        }

        if (q_ftp_tag_comb.q_ftp_t[i].server_fd != -1)
            close(q_ftp_tag_comb.q_ftp_t[i].server_fd);
    }
}

static int ftp_login(const char *ftp_server, const char *user, const char *password)
{
    /* Connect to the command socket */
    int server_fd = connet_tcp_server(ftp_server, 21);
    if (server_fd == -1) {
        return -1;
    }

    if (ftpcmd(NULL, NULL, server_fd) != 220) {
        ftp_die(NULL);
    }

    /*  Login to the server */
    switch (ftpcmd("USER", user, server_fd)) {
    case 230:
        break;
        case 331:
        if (ftpcmd("PASS", password, server_fd) != 230) {
            ftp_die("PASS");
        }
        break;
    default:
        ftp_die("USER");
    }

    if (ftpcmd("TYPE I", NULL , server_fd) != 200) {
        ftp_die("TYPE I");
    }

    return server_fd;
}

static int  parse_pasv_epsv(char *buff)
{
    char *ptr;
    int port;

    if (buff[2] == '7' /* "227" */) {
        /* Response is "227 garbageN1,N2,N3,N4,P1,P2[)garbage]"
         * Server's IP is N1.N2.N3.N4 (we ignore it)
         * Server's port for data connection is P1*256+P2 */
        ptr = strrchr(buff, ')');
        if (ptr) *ptr = '\0';

        ptr = strrchr(buff, ',');
        if (!ptr) return -1;
        *ptr = '\0';
        port = atoi(ptr + 1);

        ptr = strrchr(buff, ',');
        if (!ptr) return -1;
        *ptr = '\0';
        port += atoi(ptr + 1) * 256;
    } else {
        /* Response is "229 garbage(|||P1|)"
         * Server's port for data connection is P1 */
        ptr = strrchr(buff, '|');
        if (!ptr) return -1;
        *ptr = '\0';

        ptr = strrchr(buff, '|');
        if (!ptr) return -1;
        *ptr = '\0';
        port = atoi(ptr + 1);
    }

    return port;
}

static int ftp_send(const char *ftp_server, const char *filename, int server_fd) {
    int port_num;
    int sockfd = -1;
    int response;

    if (ftpcmd("PASV", NULL, server_fd) != 227) {
        ftp_die("PASV");
    }

    port_num = parse_pasv_epsv(buf);
    if (port_num < 0)
        ftp_die("PASV");

    sockfd = connet_tcp_server(ftp_server, port_num);
    if (sockfd < 0)
        ftp_die("PASV");

    response = ftpcmd("STOR", filename, server_fd);
    switch (response) {
    case 125:
    case 150:
        break;
    default:    
        ftp_die("STOR");
    }

    return sockfd;
}

int ftp_write_request(int index, const char *ftp_server, const char *user, const char *pass, const char *filename)
{
    if (strncasecmp(q_ftp_tag_comb.q_ftp_t[index].login, "on", 2))
    {
        q_ftp_tag_comb.q_ftp_t[index].server_fd = ftp_login(ftp_server, user, pass);
        if (q_ftp_tag_comb.q_ftp_t[index].server_fd == -1)
        {	return -1;}
    }else
    {
        if (ftpcmd(NULL, NULL, q_ftp_tag_comb.q_ftp_t[index].server_fd) != 226) {
            ftp_die(NULL);
        }
    }

    strcpy(q_ftp_tag_comb.q_ftp_t[index].login, "on");

    int sockfd = ftp_send(ftp_server, filename, q_ftp_tag_comb.q_ftp_t[index].server_fd);
    return sockfd;
}
