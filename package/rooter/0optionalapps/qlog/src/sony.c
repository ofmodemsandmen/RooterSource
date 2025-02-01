/******************************************************************************
  @file    sony.c
  @brief   read com data.

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
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#define RX_COM_SIZE (16*1024)

int set_interface_attribs(int fd, int speed)
{
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0) {
        qlog_dbg("Error from tcgetattr: %s\n", strerror(errno));
        return -1;
    }

    cfsetospeed(&tty, (speed_t)speed);
    cfsetispeed(&tty, (speed_t)speed);

    tty.c_cflag |= (CLOCAL | CREAD);    /* ignore modem controls */
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;         /* 8-bit characters */
    tty.c_cflag &= ~PARENB;     /* no parity bit */
    tty.c_cflag &= ~CSTOPB;     /* only need 1 stop bit */
    tty.c_cflag &= ~CRTSCTS;    /* no hardware flowcontrol */

    /* setup for non-canonical mode */
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tty.c_oflag &= ~OPOST;

    /* fetch bytes as they become available */
    tty.c_cc[VMIN] = 1;
    tty.c_cc[VTIME] = 1;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        qlog_dbg("Error from tcsetattr: %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

void set_mincount(int fd, int mcount)
{
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0) {
        qlog_dbg("Error tcgetattr: %s\n", strerror(errno));
        return;
    }

    tty.c_cc[VMIN] = mcount ? 1 : 0;
    tty.c_cc[VTIME] = 5;        /* half second timer */

    if (tcsetattr(fd, TCSANOW, &tty) < 0)
        qlog_dbg("Error tcsetattr: %s\n", strerror(errno));
}


int qlog_com_catch_log(char* ttyDM, char* logdir, int logfile_sz, const char* (*qlog_time_name)(int))
{
    char *portname = ttyDM;
    const char *logfile_suffix = "bin";
    size_t logfile_save_size = 0;
    unsigned s_com_logfile_seq = 0;
    int com_log_fd = -1;
    int fd = -1;
    int nreads = 0;
    int nwrites = 0;
    size_t total_read = 0;
    unsigned now_msec = 0;
    unsigned last_msec = 0;

    fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        qlog_dbg("Error opening %s: %s\n", portname, strerror(errno));
        return -1;
    }
    /*baudrate 921600, 8 bits, no parity, 1 stop bit */
    set_interface_attribs(fd, B921600);
    //set_mincount(fd, 0);                /* set to pure timed read */

    if (access(logdir, F_OK) && errno == ENOENT)
        mkdir(logdir, 0755);

    uint8_t *com_rbuf = NULL;
    com_rbuf = (uint8_t *)malloc(RX_COM_SIZE);
    if (com_rbuf == NULL) {
          qlog_dbg("Fail to malloc, errno: %d (%s)\n",errno, strerror(errno));
          return -1;
    }

    now_msec = last_msec = qlog_msecs();
    while (qlog_exit_requested == 0)
    {
        if (com_log_fd == -1)
        {
            char shortname[100] = {0};
            char filename[256] = {0};
            snprintf(shortname, sizeof(shortname), "%.80s_%04d", qlog_time_name(1), s_com_logfile_seq);
            sprintf(filename, "%s/%s.%s", logdir, shortname, logfile_suffix);
            com_log_fd = qlog_logfile_create_fullname(0, filename, 0, 1);
            if (com_log_fd <= 0) {
                qlog_dbg("Fail to create new logfile! errno : %d (%s)\n", errno, strerror(errno));
            }

            qlog_dbg("%s %s com_log_fd=%d\n", __func__, filename, com_log_fd);
            s_com_logfile_seq++;
        }

        nreads = qlog_poll_read(fd, com_rbuf, RX_COM_SIZE, 12000);
        if (nreads <= 0)
        {
            qlog_dbg("Error from read: %d: %s\n", nreads, strerror(errno));
            break;
        }

        total_read += nreads;
        now_msec = qlog_msecs();
        if ((total_read >= (16*1024*1024)) || (now_msec >= (last_msec + 5000))) {
            now_msec = qlog_msecs();
            qlog_dbg("recv: %zdM %zdK %zdB  in %u msec\n", total_read/(1024*1024),
                total_read/1024%1024,total_read%1024, now_msec-last_msec);
    		last_msec = now_msec;
    		total_read = 0;
        }

        nwrites = qlog_logfile_save(com_log_fd, com_rbuf , nreads);
        if (nreads != nwrites)
        {
            qlog_dbg("nreads:%d  nwrites:%d\n",nreads,nwrites);
            break;
        }

        logfile_save_size += nreads;

        if (logfile_save_size > ((size_t)logfile_sz - RX_COM_SIZE))
        {
            if (com_log_fd > 0)
            {
                close(com_log_fd);
                com_log_fd = -1;
                logfile_save_size = 0;
            }
        }
    }

    if (com_log_fd > 0)
    {
        close(com_log_fd);
        com_log_fd = -1;
    }

    if (com_rbuf)
        free(com_rbuf);

    return 0;
}