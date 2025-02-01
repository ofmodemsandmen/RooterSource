/******************************************************************************
  @file    mtk.c
  @brief   mtk log tool.

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

static int mtk_send_connect_cmd(int fd) {
    uint8_t lpBuf[48] = {0xac, 0xca, 0xef, 0x10, 0x18, 0x00, 0x00, 0x00, 0x10, 0xa0, 0x00, 0x00, 0xa4, 0x6a, 0xef, 0x10, 0x17, 0x08, 0x00, 0x00,
                        0xac, 0xdb, 0xcf, 0xe5, 0x16, 0x10, 0x00, 0x00, 0x00, 0x2e, 0x00, 0x2e, 0x00, 0x02, 0x00, 0x00, 0xBD, 0xDB, 0x5E, 0x00};

    return qlog_poll_write(fd, lpBuf, 40, 0);
}

static int mtk_send_disconnect_cmd(int fd) {
    uint8_t lpBuf[48] = {0xac, 0xca, 0xef, 0x10, 0x18, 0x00, 0x00, 0x00, 0x10, 0xa0, 0x00, 0x00, 0xa4, 0x6a, 0xef, 0x10, 0x17, 0x08, 0x00, 0x00,
                       0xac, 0xdb, 0xcf, 0xe5, 0x16, 0x10, 0x00, 0x00, 0x00, 0x2f, 0x00, 0x2f, 0x05, 0x00, 0x00, 0x00, 0xBD, 0xDB, 0x63, 0x00};

    return qlog_poll_write(fd, lpBuf, 40, 0);
}

int get_file_size(const char* filename)
{
    struct stat statbuf;
    stat(filename, &statbuf);
    int size = statbuf.st_size;

    return size;
}

static int mtk_send_filter_cfg(int fd, const char *cfg)
{
    if (!cfg)
        return -1;

    int read_count = 10;
    int rbuf_size = 0;
    ssize_t cfg_size = 0;
    ssize_t cfg_size_total = 0;
    unsigned char *rbuf = NULL;

    rbuf_size = get_file_size(cfg);
    rbuf = (unsigned char *)malloc(rbuf_size + 1);
    if (rbuf == NULL) {
        qlog_dbg("Fail to malloc rbuf_size=%d, errno: %d (%s)\n", rbuf_size, errno, strerror(errno));
        goto error_return;
    }

    int cfgfd = open(cfg, O_RDONLY);
    if (cfgfd < 0) {
        qlog_dbg("Fail to open %s, errno : %d (%s)\n", cfg, errno, strerror(errno));
        goto error_return;
    }
    else 
    {
        cfg_size = read(cfgfd, rbuf + cfg_size_total, rbuf_size);
        if (cfg_size == -1)
            goto error_return;
        cfg_size_total += cfg_size;
    }

    while (cfg_size_total < rbuf_size && cfgfd > 0 && read_count--) {
       cfg_size = read(cfgfd, rbuf + cfg_size_total, rbuf_size);
       cfg_size_total += cfg_size;
    }

    if (cfg_size_total == rbuf_size)
    {
        if (qlog_poll_write(fd, rbuf, (size_t)cfg_size_total, 0) <= 0)
        {
            qlog_dbg("%s qlog_poll_write error, errno : %d (%s)\n", __func__, errno, strerror(errno));
            goto error_return;
        }
    }
    else
        goto error_return;

    if (rbuf)
        free(rbuf);

    return 1;

error_return:
    if (rbuf)
        free(rbuf);

    return -1;
}

static int mtk_init_filter(int fd, const char *cfg) {

    mtk_send_connect_cmd(fd);
    mtk_send_filter_cfg(fd, cfg);
    return 0;
}

static int mtk_clean_filter(int fd) {

    mtk_send_disconnect_cmd(fd);
    return 0;
}

static int mtk_logfile_init(int logfd, unsigned logfile_seq) {

    (void)logfd;
    (void)logfile_seq;
    return 0;
}

static size_t mtk_logfile_save(int logfd, const void *buf, size_t size) {
    if (size <= 0 || NULL == buf || logfd <= 0)
        return size;

    return qlog_logfile_save(logfd, buf, size);
}

qlog_ops_t mtk_qlog_ops = {
    .init_filter = mtk_init_filter,
    .clean_filter = mtk_clean_filter,
    .logfile_init = mtk_logfile_init,
    .logfile_save = mtk_logfile_save,
};
