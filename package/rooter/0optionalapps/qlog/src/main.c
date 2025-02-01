/******************************************************************************
  @file    ql-tty2tcp.c
  @brief   enter point.

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
#include "getopt.h"
#include <sys/statfs.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <stdbool.h>
#include <pthread.h>

#define QLOG_VERSION "1.5.18"  //when release, rename to V1.X

#define LOGFILE_SIZE_MIN (2*1024*1024)
#define LOGFILE_SIZE_MAX (512*1024*1024)
#define LOGFILE_SIZE_DEFAULT (256*1024*1024)
#define AP_LOG_SIZE (10*1024*1024)
#define LOGFILE_NUM 512
static char s_logfile_List[LOGFILE_NUM][32];
static unsigned s_logfile_num = 0;
static unsigned s_logfile_seq;
static unsigned s_logfile_idx;
unsigned qlog_exit_requested = 0;
static unsigned exit_after_usb_disconnet = 0;
int use_qmdl2_v2 = 0;
int use_diag_qdss = 0;
int use_diag_dpl = 0;
int disk_file_fd = -1;
unsigned g_rx_log_count = 0;
int g_is_asr_chip = 0;
int g_is_unisoc_chip = 0;
int g_is_qualcomm_chip = 0;
int g_is_unisoc_exx00u_chip = 0;
int g_is_mtk_chip = 0;
int g_is_eigen_chip = 0;
int g_unisoc_log_type = 0; // 0 ~ DIAG, 1 ~ LOG
int g_unisoc_exx00u_log_type = 0; // 0 ~ CP LOG, 1 ~ AP LOG
int g_is_usb_disconnect = 0;
int g_donot_split_logfile = 0;
int g_tcp_server_port = 0;
int g_tcp_client_port = 0;
char g_tcp_client_ip[16] = {0};
const char *g_tftp_server_ip = NULL;
const char *g_ftp_server_ip = NULL;
const char *g_ftp_server_usr = NULL;
const char *g_ftp_server_pass = NULL;
char g_platform_choice[16] = {0};
static int second_logfile = -1;
static int third_logfile = -1;
static const char *second_logfile_suffix = NULL;
static const char *third_logfile_suffix = NULL;
int block_size = 16384;
int qlog_continue = 0;
int qlog_ignore_exx00u_ap = 0;
int qlog_read_com_data = 0;
int qlog_read_nmea_log = 0;
uint32_t query_panic_addr = 0;
char modem_name_para[32] = {0};
int uis8310_module_in_apdump = 0;
uint8_t dpl_version = 4;
static int qlog_abnormal_exit = 0;
int modem_is_pcie = 0;
int g_qualcomm_log_type = 0; // 0 ~ CP DIAG, 1 ~ QDSS, 2 ~ ADPL

#define safe_close_fd(_fd) do { if (_fd != -1) { int tmpfd = _fd; _fd = -1; close(tmpfd); }} while(0)

typedef struct {
    const qlog_ops_t *ops;
    int fd;
    const char *filter;
} init_filter_cfg_t;

typedef struct {
    int usbfd;
    int ep;
    int outfd;
    int rx_size;
    const char *dev;
} usbfs_read_cfg_t;

typedef struct {
    int dm_ttyfd;
    int dm_usbfd;
    int dm_sockets[2];
    pthread_t dm_tid;
    usbfs_read_cfg_t cfg;

    int general_ttyfd;
    int general_usbfd;
    int general_sockets[2];
    pthread_t general_tid;

    int third_ttyfd;
    int third_usbfd;
    int third_sockets[2];
    pthread_t third_tid;
} ql_fds_t;

struct arguments
{
    // arguments
    char ttyDM[256];
    char logdir[256];

    // configurations
    int logfile_num;
    int logfile_sz;
    const char *filter_cfg;
    const char *delete_logs; // Remove all logfiles in the logdir before catching logs

    const  struct ql_usb_device_info *ql_dev;
    // profiles

    ql_fds_t fds;
};
static struct arguments *qlog_args;

uint16_t qlog_le16 (uint16_t v16) {
    uint16_t tmp = v16;
    const int is_bigendian = 1;

    if ( (*(char*)&is_bigendian) == 0 ) {
        unsigned char *s = (unsigned char *)(&v16);
        unsigned char *d = (unsigned char *)(&tmp);
        d[0] = s[1];
        d[1] = s[0];
    }
    return tmp;
}

uint32_t qlog_le32 (uint32_t v32) {
    uint32_t tmp = v32;
    const int is_bigendian = 1;

    if ( (*(char*)&is_bigendian) == 0 ) {
        unsigned char *s = (unsigned char *)(&v32);
        unsigned char *d = (unsigned char *)(&tmp);
        d[0] = s[3];
        d[1] = s[2];
        d[2] = s[1];
        d[3] = s[0];
    }
    return tmp;
}

uint64_t qlog_le64(uint64_t v64) {
    const uint64_t is_bigendian = 1;
    uint64_t tmp = v64;

    if ((*(char*)&is_bigendian) == 0) {
        unsigned char *s = (unsigned char *)(&v64);
        unsigned char *d = (unsigned char *)(&tmp);
        d[0] = s[7];
        d[1] = s[6];
        d[2] = s[5];
        d[3] = s[4];
        d[4] = s[3];
        d[5] = s[2];
        d[6] = s[1];
        d[7] = s[0];
    }
    return tmp;
}

struct unisoc_8910_aplog_timestamp {
    uint8_t sync;
    uint8_t lenM;
    uint8_t lenL;
    uint8_t flowid;
    uint32_t date;
    uint32_t ms;
};

struct unisoc_8910_aplog_timestamp unisoc_ts;

unsigned qlog_msecs(void) {
    static unsigned start = 0;
    unsigned now;
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    now = (unsigned)ts.tv_sec*1000 + (unsigned)(ts.tv_nsec / 1000000);
    if (start == 0)
        start = now;
    return now - start;
}

/** returns 1 if line starts with prefix, 0 if it does not */
static int strStartsWith(const char *line, const char *prefix)
{
    for (; *line != '\0' && *prefix != '\0'; line++, prefix++)
    {
        if (*line != *prefix)
        {
            return 0;
        }
    }

    return *prefix == '\0';
}

#define RX_URB_SIZE (16*1024) //16KB for catch mdm dump
static void* qlog_usbfs_read(void *arg)
{
    const usbfs_read_cfg_t *cfg = (usbfs_read_cfg_t *)arg;
    void *pbuf;
    int n = 0;
    int idx = 0;

    qlog_dbg("%s ( %s ) enter\n", __func__, cfg->dev);
    pbuf = malloc(cfg->rx_size);
    if (pbuf == NULL) {
        qlog_dbg("%s malloc %d fail\n", __func__, cfg->rx_size);
        return NULL;
    }

    idx = kfifo_alloc(cfg->outfd);
    while (1)
    {
        n = ql_usbfs_read(cfg->usbfd, cfg->ep, pbuf, cfg->rx_size);
        if (n < 0) {
             if (qlog_exit_requested == 0) {
               qlog_dbg("%s (%s) n = %d, usbfd=%d, ep=%02x, errno: %d (%s)\n",
                    __func__, cfg->dev, n, cfg->usbfd, cfg->ep, errno, strerror(errno));
                g_is_usb_disconnect = 1;
                unused_result_write(cfg->outfd, "\0", 1); //to wakeup read thread
            }
            break;
        }
        else if (n == 0) {
            //zero length packet
        }

        if (n > 0) {
            kfifo_write(idx, pbuf, n);
        }
    }
    kfifo_free(idx);

    free(pbuf);
    qlog_dbg("%s ( %s ) exit\n", __func__, cfg->dev);
    return NULL;
}

ssize_t qlog_poll_read_fds(int *fds, int n, void *pbuf, size_t size, unsigned timeout_msec) {
    ssize_t rc = 0;

    while(qlog_exit_requested == 0 && timeout_msec > 0)
    {
        struct pollfd pollfds[4];
        int ret = -1;
        int i = 0;

        for (i = 0; i < n; i++) {
            pollfds[i].events = POLLIN;
            pollfds[i].fd = fds[i];
        }

        do {
            ret = poll(pollfds, n, timeout_msec);
        } while (ret == -1 && errno == EINTR && qlog_exit_requested == 0);

        if (g_is_usb_disconnect)
            break;

        if (ret <= 0) {
            qlog_dbg("poll() = %d, errno: %d (%s)\n", ret, errno, strerror(errno));
            if (ret == 0) errno = ETIMEDOUT;  //1.手动设置poll超时
            break;
        }

        for (i = 0; i < n; i++) {
            if (pollfds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                qlog_dbg("poll fd=%d, revents = %04x\n", pollfds[i].fd, pollfds[i].revents);
                goto _out;
            }

            if (pollfds[i].revents & (POLLIN)) {
                // FIXME:
                // pbuf should not always begin from SEEK_SET when this function monitor more than one fd (that is 'n > 0')
                rc = read(pollfds[i].fd, pbuf, size);
                if (rc <= 0) {
                    qlog_dbg("read( %d ) = %d, errno: %d (%s)\n", pollfds[i].fd, (int)rc, errno, strerror(errno));
                }
                fds[0] = pollfds[i].fd;
                goto _out;
            }
        }
    }

_out:
    return rc;
}

ssize_t qlog_poll_read(int fd,  void *pbuf, size_t size, unsigned timeout_msec) {
    return qlog_poll_read_fds(&fd, 1, pbuf, size, timeout_msec);
}

ssize_t qlog_poll_write(int fd, const void *buf, size_t size, unsigned timeout_msec) {
    size_t wc = 0;
    ssize_t nbytes;

    if (!qlog_read_com_data && fd == qlog_args->fds.dm_sockets[0]) {
        return ql_usbfs_write(qlog_args->fds.dm_usbfd, qlog_args->ql_dev->dm_intf.ep_out, buf, size);;
    }

    nbytes = write(fd, buf+wc, size-wc);

    if (nbytes <= 0) {
        if (errno != EAGAIN) {
            qlog_dbg("Fail to write fd = %d, errno : %d (%s)\n", fd, errno, strerror(errno));
            goto out;
        }
        else {
            nbytes = 0;
        }
    }

    wc += nbytes;

    if (timeout_msec == 0)
        return (wc);

    while (wc < size) {
        int ret;
        struct pollfd pollfds[] = {{fd, POLLOUT, 0}};

        do {
            ret = poll(pollfds, 1, timeout_msec);
        }  while (ret == -1 && errno == EINTR && qlog_exit_requested == 0);

        if (ret <= 0) {
            qlog_dbg("Fail to poll fd = %d, errno : %d (%s)\n", fd, errno, strerror(errno));
            break;
        }

        if (pollfds[0].revents & (POLLERR | POLLHUP | POLLNVAL)) {
            qlog_dbg("Fail to poll fd = %d, revents = %04x\n", fd, pollfds[0].revents);
            break;
        }

        if (pollfds[0].revents & (POLLOUT)) {
            nbytes = write(fd, buf+wc, size-wc);

            if (nbytes <= 0) {
                qlog_dbg("Fail to write fd = %d, errno : %d (%s)\n", fd, errno, strerror(errno));
                break;
            }
            wc += nbytes;
        }
    }

out:
    if (wc != size) {
        qlog_dbg("%s fd=%d, size=%zd, timeout=%d, wc=%zd\n", __func__, fd, size, timeout_msec, wc);
    }

    return (wc);
}

static int is_tftp(void) {
    return (g_tftp_server_ip != NULL);
}

static int is_ftp(void) {
    return (g_ftp_server_ip != NULL);
}

static int is_tty2tcp(void) { //work as tcp server
    return (g_tcp_server_port > 0);
}

static int is_tcp_client(void) {
    return (g_tcp_client_port > 0);
}

static int qlog_is_not_dir(const char *logdir) {
    return (is_ftp() || is_tftp() || !strncmp(logdir, "/dev/null", strlen("/dev/null")));
}

static const char * qlog_time_name(int type) {
    static char time_name[80];
    time_t ltime;
    struct tm *currtime;

    time(&ltime);
    currtime = localtime(&ltime);

    if (type == 1)           //other
    {
        snprintf(time_name, sizeof(time_name), "%04d%02d%02d_%02d%02d%02d",
    	(currtime->tm_year+1900), (currtime->tm_mon+1), currtime->tm_mday,
    	currtime->tm_hour, currtime->tm_min, currtime->tm_sec);
    }
    else if (type == 2)      //for RM500K
    {
        snprintf(time_name, sizeof(time_name), "%04d_%02d%02d_%02d%02d%02d", (currtime->tm_year+1900),
        (currtime->tm_mon+1), currtime->tm_mday, currtime->tm_hour, currtime->tm_min, currtime->tm_sec);
    }
    else if (type == 3)      //for EC200U/EC600U
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        snprintf(time_name, sizeof(time_name), "%02d-%02d-%02d-%02d-%03d", currtime->tm_mday, currtime->tm_hour,
        currtime->tm_min, currtime->tm_sec, (unsigned)(ts.tv_nsec / 1000000));
    }
    else if (type == 4)      //for 8850 EC800G
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        snprintf(time_name, sizeof(time_name), "%04d_%02d_%02d_%02d_%02d_%02d_%03d", (currtime->tm_year+1900), (currtime->tm_mon+1),
        currtime->tm_mday, currtime->tm_hour, currtime->tm_min, currtime->tm_sec, (unsigned)(ts.tv_nsec / 1000000));
    }

    return time_name;
}

size_t qlog_get_filesize_in_logidr(const char *filename) {
    if (g_ftp_server_ip)
        return 0;

    char fullname[256];
    int fd = -1;
    size_t file_len = 0;

    if (qlog_args == NULL || qlog_args->logdir[0] == 0)
        return 0;

    sprintf(fullname, "%.128s/%.64s", qlog_args->logdir, filename);

    fd = open(fullname, O_RDONLY);
    if (fd != -1) {
        file_len = lseek(fd, 0, SEEK_END);
        close(fd);
    }

    return file_len;
}

int qlog_create_file_in_logdir(const char *filename) {
    char fullname[256];
    int fd = -1;

    if (qlog_args == NULL || qlog_args->logdir[0] == 0)
        return -1;

    sprintf(fullname, "%.128s/%.64s", qlog_args->logdir, filename);

    if (is_tcp_client()) //do not support trasnsfer qshrink4 file
        fd = qlog_logfile_create_fullname(2, "/dev/null", 0, 0);
    else
        fd = qlog_logfile_create_fullname(2, fullname, 0, 0);
    if (fd <= 0) {
        qlog_dbg("Fail to create %s! errno : %d (%s)\n", fullname, errno, strerror(errno));
    }

    return fd;
}

int qlog_logfile_create_fullname(int file_type, const char *fullname, long tftp_size, int is_dump)
{
    int fd = -1;

    if (!strncmp(fullname, "/dev/null", strlen("/dev/null"))) {
        fd = open("/dev/null", O_CREAT | O_RDWR | O_TRUNC, 0444);
    }
    else if (is_tftp()) {
        const char *filename = fullname;
        const char *p = strchr(filename, '/');
        while (p) {
            p++;
            filename = p;
            p = strchr(filename, '/');
         }

        fd = tftp_write_request(filename, tftp_size);
    }
    else if (is_ftp()) {
        const char *filename = fullname;
        const char *p = strchr(filename, '/');
        while (p) {
            p++;
            filename = p;
            p = strchr(filename, '/');
         }
        qlog_dbg("%s  filename:%s  g_ftp_server_pass:%s\n",__func__,filename, g_ftp_server_pass);
        fd = ftp_write_request(file_type, g_ftp_server_ip, g_ftp_server_usr, g_ftp_server_pass, filename);
        if (!is_dump)
            kfifo_alloc(fd);
    }
    else {
        fd = open(fullname, O_CREAT | O_RDWR | O_TRUNC, 0444);
        if (!is_dump)
            kfifo_alloc(fd);
    }

    return fd;
}

//write timestamp 8910 ap logfile
int unisoc_8910_ap_file_write_timestap(int logfd, struct unisoc_8910_aplog_timestamp* punisoc_ts)
{
    static char time_name[36];
    time_t ltime;
    struct tm *currtime;

    time(&ltime);
    currtime = localtime(&ltime);

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);

    punisoc_ts->date = ((currtime->tm_year+1900) << 16) + ((currtime->tm_mon+1) << 8) + currtime->tm_mday;
    punisoc_ts->ms = (currtime->tm_hour * 60 * 60 * 1000) + (currtime->tm_min * 60 * 1000) + (currtime->tm_sec * 1000) + (ts.tv_nsec / 1000000);

    snprintf(time_name, sizeof(time_name), "%02d-%02d-%02d-%02d-%03d", currtime->tm_mday, currtime->tm_hour,
        currtime->tm_min, currtime->tm_sec, (unsigned)(ts.tv_nsec / 1000000));
    //qlog_dbg("%s time_name:%s\n", __func__, time_name);

    return qlog_logfile_save(logfd, punisoc_ts, sizeof(struct unisoc_8910_aplog_timestamp));
}

static int qlog_logfile_create(const char *logfile_dir, const char *logfile_suffix, unsigned logfile_seq) {
    int logfd;
    char shortname[100] = {0};
    char filename[380] = {0};

    //delete old logfile
    if (s_logfile_num && s_logfile_List[logfile_seq%s_logfile_num][0]) {
        sprintf(filename, "%s/%s.%s", logfile_dir, s_logfile_List[logfile_seq%s_logfile_num], logfile_suffix);
        if (access(filename, R_OK) == 0) {
            remove(filename);
        }
    }

    if (g_is_mtk_chip)
        snprintf(shortname, sizeof(shortname), "MyLog_%.80s_%04d", qlog_time_name(2), logfile_seq);
    else if (g_is_unisoc_exx00u_chip)
        snprintf(shortname, sizeof(shortname), "Log(%.80s).%04d", qlog_time_name(3), logfile_seq);
    else if (g_is_unisoc_chip == 4)
        snprintf(shortname, sizeof(shortname), "%.80s_%04d", qlog_time_name(4), logfile_seq);
    else
        snprintf(shortname, sizeof(shortname), "%.80s_%04d", qlog_time_name(1), logfile_seq);
    sprintf(filename, "%s/%s.%s", logfile_dir, shortname, logfile_suffix);

    logfd = qlog_logfile_create_fullname(0, filename, 0, 0);
    if (logfd <= 0) {
        qlog_dbg("Fail to create new logfile! errno : %d (%s)\n", errno, strerror(errno));
    }

    qlog_dbg("%s %s logfd=%d\n", __func__, filename, logfd);

    if (s_logfile_num) {
        s_logfile_idx = (logfile_seq%s_logfile_num);
        strcpy(s_logfile_List[s_logfile_idx], shortname);
    }

    if (second_logfile_suffix) {
        memset(filename, 0, sizeof(filename));
        snprintf(filename, sizeof(filename), "%.256s/%s%.12s", logfile_dir, shortname, second_logfile_suffix);
        second_logfile = qlog_logfile_create_fullname(1, filename, 0, 0);
        qlog_dbg("%s %s logfd=%d\n", __func__, filename, second_logfile);

        unisoc_ts.sync= 0xAD;
        unisoc_ts.lenM = 0;
        unisoc_ts.lenL = 0x08;
        unisoc_ts.flowid = 0xa2;

        if (g_is_unisoc_exx00u_chip)  //8910
        {
            if(unisoc_8910_ap_file_write_timestap(second_logfile, &unisoc_ts) <= 0)
            {
                qlog_dbg("%s unisoc 8910 wriet timestamp to ap logfile failed\n", __func__);
            }
        }
    }

    if (third_logfile_suffix) {
        memset(filename, 0, sizeof(filename));
        if (qlog_read_nmea_log)
        {
            snprintf(filename, sizeof(filename), "%.256s/%s%.12s", logfile_dir, shortname, third_logfile_suffix);
        }
        else
        {
            snprintf(filename, sizeof(filename), "%.256s/%s%.12s%d", logfile_dir, shortname, third_logfile_suffix, dpl_version);
        }

        third_logfile = qlog_logfile_create_fullname(1, filename, 0, 0);
        qlog_dbg("%s %s logfd=%d\n", __func__, filename, third_logfile);
    }

    return logfd;
}

size_t qlog_logfile_save(int logfd, const void *buf, size_t size) {
    int idx = kfifo_idx(logfd);

    if (idx != -1 )
        return kfifo_write(idx, buf, size);

    return qlog_poll_write(logfd, buf, size, 1000);
}

int qlog_logfile_close(int logfd) {
    kfifo_free(kfifo_idx(logfd));
    kfifo_free(kfifo_idx(second_logfile));
    safe_close_fd(second_logfile);
    kfifo_free(kfifo_idx(third_logfile));
    safe_close_fd(third_logfile);
    return close(logfd);
}

int qlog_logfile_close_qdb(int logfd) {
    kfifo_free(kfifo_idx(logfd));
    return close(logfd);
}

static void* qlog_logfile_init_filter_thread(void* arg) {
    init_filter_cfg_t *cfg = (init_filter_cfg_t *)arg;

    if (cfg && cfg->ops && cfg->ops->init_filter)
        cfg->ops->init_filter(cfg->fd, cfg->filter);

    qlog_dbg("qlog_init_filter_finished\n");
    return NULL;
}

static int qlog_handle(const struct arguments *args) {
    size_t savelog_size_dm = 0;
    size_t savelog_size_general = 0;
    size_t savelog_size_third = 0;
    size_t savelog_size_total = 0;
    uint8_t *rbuf;
    const size_t rbuf_size = QLOG_BUF_SIZE;
    const char *logfile_suffix = "qmdl";
    static qlog_ops_t qlog_ops;
    pthread_t init_filter_tid;
    init_filter_cfg_t init_filter_cfg;
    size_t total_read = 0;
    unsigned now_msec = 0;
    unsigned last_msec = 0;

    const char *logfile_dir = args->logdir;
    size_t logfile_size = args->logfile_sz;
    const char *filter_cfg = args->filter_cfg;

    int logfile_fd = -1;    //Use as cplogfile_fd in unisoc ecxxxu

    int dmfd = -1;
    int generalfd = -1;
    int thirdfd = -1;

    if (args->fds.dm_ttyfd != -1) {
        dmfd = args->fds.dm_ttyfd;
    }
    else if (args->fds.dm_sockets[0] != -1) {
        dmfd = args->fds.dm_sockets[0];
    }

    if (args->fds.general_ttyfd != -1) {
        generalfd = args->fds.general_ttyfd;
    }
    else if (args->fds.general_sockets[0] != -1) {
        generalfd = args->fds.general_sockets[0];
    }

    if (args->fds.third_ttyfd != -1) {           //DPL
        thirdfd = args->fds.third_ttyfd;
    }
    else if (args->fds.third_sockets[0] != -1) {
        thirdfd = args->fds.third_sockets[0];
    }

    if (g_is_asr_chip) {
        logfile_suffix = "sdl";
    }
    else if (g_is_unisoc_chip) {
        logfile_suffix = "logel";
    }
    else if (g_is_unisoc_exx00u_chip) {
        logfile_suffix = "tra";
    }
    else if (use_qmdl2_v2) {
        logfile_suffix = "qmdl2";
    }
    else if (g_is_mtk_chip) {
        logfile_suffix = "muxraw";
    }
    else if (g_is_eigen_chip) {
        logfile_suffix = "bin";
    }

    second_logfile_suffix = NULL;
    if (args->ql_dev->general_type == MDM_QDSS)
        second_logfile_suffix = "_qdss.bin";
    else if (args->ql_dev->general_type == EC200U_AP)
        second_logfile_suffix = ".bin";

    third_logfile_suffix = NULL;
    if (args->ql_dev->third_type == 1)
        third_logfile_suffix = ".adplv";
    else if (args->ql_dev->third_type == 2)
        third_logfile_suffix = ".log";

    if (is_tty2tcp()) {
        filter_cfg = logfile_dir;
        qlog_ops = tty2tcp_qlog_ops;
        exit_after_usb_disconnet = 1; // do not continue when tty2tcp mode
    }
    else {
        qlog_ops =  mdm_qlog_ops;
        if (g_is_asr_chip) {
            qlog_ops =  asr_qlog_ops;
        }
        else if (g_is_unisoc_chip) {
            qlog_ops =  unisoc_qlog_ops;
        }
        else if (g_is_unisoc_exx00u_chip) {
            qlog_ops =  unisoc_exx00u_qlog_ops;
        }
        else if (g_is_mtk_chip) {
            qlog_ops =  mtk_qlog_ops;
        }
        else if (g_is_eigen_chip) {
            qlog_ops =  eigen_qlog_ops;
        }
    }

    if (!qlog_ops.logfile_create) {
        if(is_tcp_client())
        {
            g_donot_split_logfile = 1;
            qlog_ops.logfile_create = tcp_client_qlog_ops.logfile_create;
        }
        else
            qlog_ops.logfile_create = qlog_logfile_create;
    }

    if (!qlog_ops.logfile_save)
        qlog_ops.logfile_save = qlog_logfile_save;
    if (!qlog_ops.logfile_close)
        qlog_ops.logfile_close = qlog_logfile_close;

    rbuf = (uint8_t *)malloc(rbuf_size);
    if (rbuf == NULL) {
          qlog_dbg("Fail to malloc rbuf_size=%zd, errno: %d (%s)\n", rbuf_size, errno, strerror(errno));
          return -1;
    }

    init_filter_cfg.ops = &qlog_ops;
    if (g_is_unisoc_exx00u_chip)
        init_filter_cfg.fd = generalfd;
    else
        init_filter_cfg.fd = dmfd;
    init_filter_cfg.filter = filter_cfg;
    if (pthread_create(&init_filter_tid, NULL, qlog_logfile_init_filter_thread, (void*)&init_filter_cfg)) {
          qlog_dbg("Fail to create init_filter_thread, errno: %d (%s)\n", errno, strerror(errno));
          free(rbuf);
          return -1;
    }

    now_msec = last_msec = qlog_msecs();
    while (qlog_exit_requested == 0) {
        ssize_t rc, wc = 0;
        int fds[3];
        int fd_n = 0;

        if (dmfd != -1) {
            fds[fd_n++] = dmfd;
        }
        if (generalfd != -1) {
            fds[fd_n++] = generalfd;
        }
        if (thirdfd != -1) {
            fds[fd_n++] = thirdfd;
        }

        rc = qlog_poll_read_fds(fds, fd_n, rbuf, rbuf_size, -1);
        if (rc <= 0) {
            if (qlog_exit_requested == 0)
            {
                qlog_dbg("QLog abnormal exit...\n");
                qlog_abnormal_exit = 1;
            }
            break;
        }

        if (g_is_eigen_chip)
        {
            int ret = enigen_catch_dump(rbuf, rc, logfile_dir, qlog_time_name);
            if (ret > 0)
            {
                qlog_dbg("ECX00E/EGX00Q catch ramdump successfully\n");
            }
            else if (ret < 0)
            {
                qlog_dbg("ECX00E/EGX00Q catch ramdump fail\n");
            }

            if(ret != 0)
            {
                if (qlog_continue && !qlog_exit_requested)  //Automated testing requires no exit
                    sleep(1);
                else
                {
                    qlog_exit_requested = 1;
                }
                break;
            }
        }

        if (g_is_unisoc_chip == 2)   //unisoc EC200D
        {
            if (rc >= 10)  // sizeof(apdump_recv_buf)
            {
                uint8_t apdump_recv_buf[] = {0x7e, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0xff, 0x00, 0x7e};

                int i;
                for(i=0;i<(int)sizeof(apdump_recv_buf);i++)
                {
                    if (rbuf[i] != apdump_recv_buf[i])
                    {
                        uis8310_module_in_apdump = 0;
                        break;
                    }
                    else
                        uis8310_module_in_apdump = 1;
                }

                if (uis8310_module_in_apdump == 1)
                {
                    printf("EC200D-CN into ap dump...\n");
                    unisoc_catch_8310_dump(dmfd, logfile_dir, RX_URB_SIZE, qlog_time_name);
                    sleep(1);
                    qlog_exit_requested = 1;   //Unisoc 8310 captures AP dumps and requires the exit flag to be preserved
                    break;
                }
            }
        }
        else if (g_is_unisoc_chip == 4)  //EC800G-CN
		{
			int ret_blue_screen = unisoc_ec800g_catch_blue_screen(rbuf, logfile_dir);
            if (ret_blue_screen > 0)
            {
                qlog_dbg("unisoc EC800G-CN catch blue screen dump successfully\n");
            }
            else if (ret_blue_screen < 0)
            {
                qlog_dbg("unisoc EC800G-CN catch blue screen dump fail\n");
            }

            if(ret_blue_screen != 0)
            {
                if (qlog_continue && !qlog_exit_requested)  //Automated testing requires no exit
                    sleep(1);
                else
                {
                    qlog_exit_requested = 1;
                }
                break;
            }
		}

        if (g_is_unisoc_exx00u_chip == 1)  //check whether it is blue screen dump
        {
            int ret_blue_screen = unisoc_exx00u_catch_blue_screen(rbuf, logfile_dir);
            if (ret_blue_screen > 0)
            {
                qlog_dbg("unisoc exx00u catch blue screen dump successfully\n");
            }
            else if (ret_blue_screen < 0)
            {
                qlog_dbg("unisoc exx00u catch blue screen dump fail\n");
            }

            if(ret_blue_screen != 0)
            {
                if (qlog_continue && !qlog_exit_requested)  //Automated testing requires no exit
                    sleep(1);
                else
                {
                    qlog_exit_requested = 1;
                }
                break;
            }
        }

        if (!(g_rx_log_count%128)) {
            now_msec = qlog_msecs();
        }
        total_read += rc;

    	if ((total_read >= (16*1024*1024)) || (now_msec >= (last_msec + 5000))) {
            now_msec = qlog_msecs();
            qlog_dbg("recv: %zdM %zdK %zdB  in %u msec\n", total_read/(1024*1024),
                total_read/1024%1024,total_read%1024, now_msec-last_msec);
    		last_msec = now_msec;
    		total_read = 0;
        }

        g_rx_log_count++;

        if (logfile_fd == -1) {
            logfile_fd = qlog_ops.logfile_create(logfile_dir, logfile_suffix, s_logfile_seq);
            if (logfile_fd <= 0) {
                break;
            }

            if (qlog_ops.logfile_init) {
                qlog_ops.logfile_init(logfile_fd, s_logfile_seq);
                s_logfile_seq++;
            }
        }

        if (fds[0] == dmfd) {
            g_unisoc_log_type = 0;
            g_unisoc_exx00u_log_type = 0;
            g_qualcomm_log_type = 0;
            wc = qlog_ops.logfile_save(logfile_fd, rbuf, rc);     //udx710/8310 dm log ; 8910 cp log ; 8850 ap log
            savelog_size_dm += wc;
        }
        else if (fds[0] == generalfd) {
            if (is_tty2tcp() && args->ql_dev->general_type == MDM_QDSS)
            {
                g_qualcomm_log_type = 1; //qdss
                wc = qlog_ops.logfile_save(second_logfile, rbuf, rc);  //qdss log to pc
                savelog_size_general += wc;
            }
            else if (second_logfile_suffix) {
                if (args->ql_dev->general_type == MDM_QDSS)
                {
                    wc = qlog_logfile_save(second_logfile, rbuf, rc);   //qdss
                }
                else
                {
                    g_unisoc_exx00u_log_type = 1;
                    wc = qlog_ops.logfile_save(second_logfile, rbuf, rc); //8910 ap log
                }

                savelog_size_general += wc;
            }
            else {
                g_unisoc_log_type = 1;
                wc = qlog_ops.logfile_save(logfile_fd, rbuf, rc);     //udx710/8310 log ; 8850 cp log
                savelog_size_dm += wc;
           }
        }
        else if (fds[0] == thirdfd)
        {
            if (is_tty2tcp() && args->ql_dev->third_type == 1)
            {
                g_qualcomm_log_type = 2;  //dpl
                wc = qlog_ops.logfile_save(third_logfile, rbuf, rc);  //pcie adpl log to pc
                savelog_size_third += wc;
            }
            else if (third_logfile_suffix)
            {
                if (args->ql_dev->third_type)
                {
                    wc = qlog_logfile_save(third_logfile, rbuf, rc);   //args->ql_dev->third_type == 1 ->dpl   args->ql_dev->third_type == 2 ->udx710 nmea
                }
                savelog_size_third += wc;
            }
        }

        if (wc != rc) {
            qlog_dbg("savelog fail %zd/%zd, break\n", wc, rc);
            exit_after_usb_disconnet = 1; // do not continue when not usb disconnect
            qlog_exit_requested = 1;
            break;
        }

        if (g_is_unisoc_exx00u_chip)
        {
            if (savelog_size_general > (AP_LOG_SIZE - rbuf_size)
                || savelog_size_dm >= logfile_size)
            {
                savelog_size_dm = 0;
                savelog_size_general = 0;
                qlog_ops.logfile_close(logfile_fd);
                logfile_fd = -1;
            }
        }
        else
        {
            savelog_size_total = savelog_size_dm + savelog_size_general + savelog_size_third;
            if (savelog_size_total >= logfile_size && g_donot_split_logfile == 0) {
                savelog_size_dm = 0;
                savelog_size_general = 0;
                savelog_size_third = 0;
                savelog_size_total = 0;
                qlog_ops.logfile_close(logfile_fd);
                logfile_fd = -1;

                if (g_is_unisoc_chip)
                {
                    m_bVer_Obtained_change();
                }
            }
        }
    }

    if (logfile_fd != -1)  {
        qlog_ops.logfile_close(logfile_fd);
        logfile_fd = -1;
    }

    free(rbuf);

    if (qlog_exit_requested && qlog_ops.clean_filter) {
        qlog_dbg("clean_filter\n");
        qlog_ops.clean_filter(dmfd);
    }

    if (!pthread_kill(init_filter_tid, 0)) {
        qlog_dbg("pthread_join(filter)\n");
#ifdef USE_NDK
        //TODO Android NDK do not support pthread_cancel
#else
        pthread_cancel(init_filter_tid);
#endif
        pthread_join(init_filter_tid, NULL);
    }

    return 0;
}

static void ql_sigaction(int signal_num) {
    if (signal_num == SIGTERM || signal_num == SIGHUP || signal_num == SIGINT)
            qlog_exit_requested = 1;

    qlog_dbg("recv signal %d\n", signal_num);
}

static void qlog_usage(const char *self, const char *dev) {
    qlog_dbg("Usage: %s -p <log port> -s <log save dir> -f filter_cfg -n <log file max num> -b <log file size MBytes>\n", self);
    qlog_dbg("Default: %s -p %s -s %s -n %d -b %d to save log to local disk\n",
        self, dev, ".", LOGFILE_NUM, LOGFILE_SIZE_DEFAULT/1024/1024);
    qlog_dbg("    -p    The port to catch log (default '/dev/ttyUSB0')\n");
    qlog_dbg("    -s    Dir to save log, default is '.' \n");
    qlog_dbg("          if set as '9000', QLog will run in TCP Server Mode, and can be connected with 'QPST/QWinLog/CATStudio/Logel'!\n");
    qlog_dbg("          if set as 'IP:9000', QLog will run in TCP Client Mode, and send log to TCP Server, like 'nc -l 9000 > log.bin' \n");
    qlog_dbg("          if set as 'tftp:IP', QLog will run in TFTP Client Mode, and send log to TFTP Server, PC can run tftpd32/tftpd64 \n");
    qlog_dbg("          if set as 'ftp:IP-user:xxx-pass:xxx', The maximum value of user and pass is 32 bytes, QLog will run in FTP Client Mode, and send log to FTP Server, PC can run FileZilla Server \n");
	qlog_dbg("    -D    Delete all log files in the logdir before catching logs\n");
    qlog_dbg("          For instance: -D (indicate delete all supportted log), -Dqmdl (only delte log with suffix *.qmdl)\n");
    qlog_dbg("    -f    filter cfg for catch log, can be found in directory 'conf'. if not set this arg, will use default filter conf\n");
    qlog_dbg("          and UC200T&EC200T do not need filter cfg.\n");
    qlog_dbg("    -n    max num of log file to save, range is '0~512'. default is 0. 0 means no limit.\n");
    qlog_dbg("          or QLog will auto delete oldtest log file if exceed max num\n");
    qlog_dbg("    -a    EXX00U capture blue screen dump, must to specify the gIsPanic address, like '-a 0x12345678', which can be obtained from the 8915dm_cat1.map file\n");
    qlog_dbg("    -m    max size of single log file, unit is MBytes, range is '2~512', default is 256\n");
    qlog_dbg("    -c    Determines whether to exit after QLog captures dump, default is 0, indicating exit\n");
    qlog_dbg("    -g    For the state grid module, the module model needs to be specified, such as '-g EC200T'\n");
    qlog_dbg("    -i    EXX00U AP log is ignored, default is 0, indicating capture\n");
    qlog_dbg("    -t    sony BG770A-GL captures uart logs, the -t parameter must be used and the COM port must be specified by -p, like './QLog -p /dev/ttyUSB0 -t'\n");
    qlog_dbg("          unisoc EXX00U captures uart ap logs, the -t parameter must be used , the COM port must be specified by -p and The -m parameter must be used to set the online ap log file to 10 MB, like './QLog -p /dev/ttyUSB0 -m 10 -t'\n");
    qlog_dbg("    -x    Capture log of udx710 NMEA port\n");
    qlog_dbg("    -q    Exit after usb disconnet\n");

    qlog_dbg("\nNote: For the eigen platform module, the tool needs to be run within 16 seconds after the module dumps to successfully capture the dump, otherwise the timeout fails\n");
    qlog_dbg("\nFor example: %s -s .\n", self);
}

static void parser_tcp(const char *str) {
    int rc;
    int ip[4];

    if (str[0] == '9' && atoi(str) >= 9000) {
        g_tcp_server_port = atoi(str);
        return;
    }

    if (strstr(str, ":") && strstr(str, ".")) {
        if (strstr(str, ":") > strstr(str, "."))
            rc = sscanf(str, "%d.%d.%d.%d:%d",
                    &ip[0], &ip[1], &ip[2], &ip[3], &g_tcp_client_port);
        else
            rc = sscanf(str, "%d:%d.%d.%d.%d",
                    &g_tcp_client_port, &ip[0], &ip[1], &ip[2], &ip[3]);

        if (rc == 5) {
            snprintf(g_tcp_client_ip, sizeof(g_tcp_client_ip),
                "%d.%d.%d.%d", (uint8_t)ip[0], (uint8_t)ip[1], (uint8_t)ip[2], (uint8_t)ip[3]);

            qlog_dbg("save log to tcp server %s:%d\n",
                g_tcp_client_ip, g_tcp_client_port);
        }
    }
}

static void parser_tftp(const char *str) {
    if (!strncmp(str, TFTP_F, strlen(TFTP_F))) {
        g_tftp_server_ip = str+strlen(TFTP_F);
        if (tftp_test_server(g_tftp_server_ip))
            qlog_dbg("save dump to tcp server %s\n", g_tftp_server_ip);
        else
            exit(1);
    }
}

static void parser_ftp(const char *str) {
    if (!strncmp(str, FTP_F, strlen(FTP_F))) {
        static char g_ftp_server_ip_temp[16] = {0};
        static char g_ftp_server_usr_temp[32] = {0};
        static char g_ftp_server_pass_temp[32] = {0};
        char *buf_temp1 = NULL;
        char *buf_temp2 = NULL;
        buf_temp1 = strstr(str,"user:");
        buf_temp2 = strstr(str,"pass:");
        if(!buf_temp1 || !buf_temp2)
             exit(1);

        strncpy(g_ftp_server_ip_temp, str+4, buf_temp1 - str - 5);
        strncpy(g_ftp_server_usr_temp, buf_temp1+5, buf_temp2 - buf_temp1 - 6);
        strncpy(g_ftp_server_pass_temp, buf_temp2+5, strlen(buf_temp2) - 5);
        g_ftp_server_ip = g_ftp_server_ip_temp;
        g_ftp_server_usr = g_ftp_server_usr_temp;
        g_ftp_server_pass = g_ftp_server_pass_temp;
    }
}

static struct arguments *parser_args(int argc, char **argv)
{
    int opt;
    static struct arguments args = {
        .ttyDM = "",
        .logdir = "qlog_files",
        .logfile_num = LOGFILE_NUM,
        .logfile_sz = LOGFILE_SIZE_DEFAULT,
        .delete_logs = NULL, // Do not remove logs
        .filter_cfg = NULL,
    };

    optind = 1; //call by popen(), optind mayby is not 1
    while (-1 != (opt = getopt(argc, argv, "p:s:n:a:g:m:f:D::citqxh")))
    {
        switch (opt)
        {
        case 'p':
            if (optarg[0] == 't') //ttyUSB0
                snprintf(args.ttyDM, sizeof(args.ttyDM), "/dev/%.250s", optarg);
            else if (optarg[0] == 'U') //USB0
                snprintf(args.ttyDM, sizeof(args.ttyDM), "/dev/tty%.247s", optarg);
            else if (optarg[0] == '/')
                snprintf(args.ttyDM, sizeof(args.ttyDM), "%.255s", optarg);
            else
            {
                qlog_dbg("unknow dev %s\n", optarg);
                goto error;
            }
            qlog_dbg("will use device: %s\n", args.ttyDM);
            break;
        case 's':
            snprintf(args.logdir, sizeof(args.logdir), "%.255s", optarg);
            parser_tcp(optarg);
            parser_tftp(optarg);
            parser_ftp(optarg);
            break;
        case 'D':
            args.delete_logs = optarg ? optarg : "";
            break;
        case 'n':
            args.logfile_num = atoi(optarg);
            if (args.logfile_num < 0)
                args.logfile_num = 0;
            else if (args.logfile_num > LOGFILE_NUM)
                args.logfile_num = LOGFILE_NUM;
            s_logfile_num = args.logfile_num;
            break;
        case 'a':
            query_panic_addr = strtoul(optarg, NULL, 16);
            qlog_dbg("query_panic_addr:0x%08x\n", query_panic_addr);
            break;
        case 'g':
            snprintf(modem_name_para, sizeof(modem_name_para), "%s", optarg);
            qlog_dbg("modem_name_para:%s\n", modem_name_para);
            break;
        case 'm':
            args.logfile_sz = atoi(optarg) * 1024 * 1024;
            if (args.logfile_sz < LOGFILE_SIZE_MIN)
                args.logfile_sz = LOGFILE_SIZE_MIN;
            else if (args.logfile_sz > LOGFILE_SIZE_MAX)
                args.logfile_sz = LOGFILE_SIZE_MAX;
            break;
        case 'c':
            qlog_continue = 1;
            qlog_dbg("qlog_continue: %d\n", qlog_continue);
            break;
        case 'i':
            qlog_ignore_exx00u_ap = 1;
            qlog_dbg("qlog_ignore_exx00u_ap: %d\n", qlog_ignore_exx00u_ap);
            break;
        case 't':
            qlog_read_com_data = 1;
            qlog_dbg("qlog_read_com_data: %d\n", qlog_read_com_data);
            break;
        case 'f':
            args.filter_cfg = optarg;
            break;
        case 'q':
            exit_after_usb_disconnet = 1;
            break;
        case 'x':
            qlog_read_nmea_log = 1;
            qlog_dbg("qlog_read_nmea_log: %d\n", qlog_read_nmea_log);
            break;
        case 'h':
        default:
            qlog_usage(argv[0], "/dev/ttyUSB0");
            goto error;
        }
    }

    qlog_dbg("will use filter file: %s\n", args.filter_cfg ? args.filter_cfg : "default filter");

    return &args;
error:
    return NULL;
}

static int serial_open(const char *device)
{
    int ttyfd = open(device, O_RDWR | O_NDELAY | O_NOCTTY);
    if (ttyfd < 0)
    {
        qlog_dbg("Fail to open %s, errno : %d (%s)\n", device, errno, strerror(errno));
    }
    else
    {
        qlog_dbg("open %s ttyfd = %d\n", device, ttyfd);
        struct termios ios;
        memset(&ios, 0, sizeof(ios));
        tcgetattr(ttyfd, &ios);
        cfmakeraw(&ios);
        if (g_is_mtk_chip)
        {
            qlog_dbg("Baud rate = 1500000\n");
            cfsetispeed(&ios, B1500000);
            cfsetospeed(&ios, B1500000);
        }else
        {
            cfsetispeed(&ios, B115200);
            cfsetospeed(&ios, B115200);
        }
        tcsetattr(ttyfd, TCSANOW, &ios);
    }
    return ttyfd;
}

int qlog_avail_space_for_dump(const char *dir, long need_MB) {
    long free_space = 0;
    struct statfs stat;

    if (!statfs(dir, &stat)) {
        free_space = stat.f_bavail*(stat.f_bsize/512)/2; //KBytes
    }
    else {
        qlog_dbg("statfs %s, errno : %d (%s)\n", dir, errno, strerror(errno));
    }

    free_space = (free_space/1024);
    if (free_space < need_MB) {
        qlog_dbg("free space is %ldMBytes, need %ldMB\n", free_space, need_MB);
        return 0;
    }

    return 1;
}

int drv_is_asr(int idProduct, int idVendor)
{
    if ((idVendor == 0x2c7c && ((idProduct & 0xF000) == 0x6000)) && idProduct != 0x6007) // ASR  0x6007 is eigen
        return 1;

    if (!strncasecmp(modem_name_para, "EC200T", 6)       //GW EC200T
        && ((idVendor == 0x3763 && idProduct == 0x3c93)
        || (idVendor == 0x3c93 && idProduct == 0xffff)))
        return 1;

    if (!strncasecmp(modem_name_para, "EC200A", 6)       //GW EC200A
        && ((idVendor == 0x3763 && idProduct == 0x3c93)
        || (idVendor == 0x3c93 && idProduct == 0xffff)))
        return 1;

    return 0;
}

int drv_is_unisoc(int idProduct, int idVendor)
{
    if (idVendor == 0x2c7c && idProduct == 0x0900)
        return 1;
    else if (idVendor == 0x1782 && idProduct == 0x4d00) /* RG500U AP DUMP */
        return 1;
    else if (!strncasecmp(modem_name_para, "RG200U", 6)  //GW RG200U
        && ((idVendor == 0x3763 && idProduct == 0x3c93)
        || (idVendor == 0x3c93 && idProduct == 0xffff)))
        return 1;
    else if (!strncasecmp(modem_name_para, "RM500U", 6)  //GW RG500U
        && (idVendor == 0x3c93 && idProduct == 0xffff))
        return 1;
    else if (idVendor == 0x2c7c && idProduct == 0x0902)   //EC200D-CN    2 capture log    3 capture apdump
        return 2;
    else if (idVendor == 0x2c7c && idProduct == 0x0904)   //EC800G-CN    4 capture log + blue screen dump
        return 4;

    return 0;
}

int drv_is_unisoc_exx00u(int idProduct, int idVendor)
{
    if (idVendor == 0x2c7c && idProduct == 0x0901)   //EXX00U
        return 1;

    return 0;
}

int drv_is_mtk(int idProduct, int idVendor)
{
    if (idVendor == 0x2c7c && idProduct == 0x7001)
        return 1;
    else if (idVendor == 0x0e8d && idProduct == 0x202f)
        return 1;

    return 0;
}

int drv_is_eigen(int idProduct, int idVendor)
{
    if (idVendor == 0x2c7c && idProduct == 0x0903)     // EC618 PLATFORM
        return 1;
    else if (idVendor == 0x2c7c && idProduct == 0x6007)  // QCX216 PLATFORM
        return 2;

    return 0;
}

static int option_send_setup(int usbfd, int interface_num, int dtr_state, int rts_state)
{
    int ret = 0;
    struct usbdevfs_ctrltransfer control;
    int val = 0;

    if (dtr_state)
    	val |= 0x01;
    if (rts_state)
    	val |= 0x02;

    control.bRequestType = 0x21;
    control.bRequest = 0x22;
    control.wValue = val;
    control.wIndex = interface_num;
    control.wLength = 0;
    control.timeout = 0; /* in milliseconds */
    control.data = NULL;

    ret = ioctl(usbfd, USBDEVFS_CONTROL, &control);
    if (ret == -1)
        printf("errno: %d (%s)\n", errno, strerror(errno));
    return ret;
}

static int prepare(struct arguments *args)
{
    const  struct ql_usb_device_info *usb_dev = args->ql_dev;
    int force_use_usbfs = 0;

    memset(&args->fds, -1, sizeof(args->fds));

    use_qmdl2_v2 = 0;
    if (usb_dev->idProduct == 0x0800 || usb_dev->idProduct == 0x0455
        || usb_dev->idProduct == 0x0801) {
        use_qmdl2_v2 = 1;
    }

    if (usb_dev->general_intf.bInterfaceNumber != 0xFF && usb_dev->general_type == MDM_QDSS) {
        use_diag_qdss = 1;
        use_qmdl2_v2 = 1;
    }
    else {
        use_diag_qdss = 0;
    }

    if (usb_dev->third_intf.bInterfaceNumber != 0xFF && usb_dev->third_type == 1)
    {
        use_diag_dpl = 1;
    }
    else
    {
        use_diag_dpl = 0;
    }

    if (args->ql_dev->idVendor == 0x2c7c && (args->ql_dev->idProduct&0xF000) == 0x0000
        && args->ql_dev->bNumInterfaces == 1 && !args->ql_dev->hardware) {
        //to avoid tty's echo cause fail
        force_use_usbfs = 1;
     }

    if (usb_dev->ttyDM[0] && !force_use_usbfs) {
        args->fds.dm_ttyfd = serial_open(usb_dev->ttyDM);
        if (args->fds.dm_ttyfd < 0)
        {
            qlog_dbg("tty open %s failed, errno: %d (%s)\n", usb_dev->ttyDM, errno, strerror(errno));
            goto error;
        }
    }
    else if (usb_dev->dm_intf.bInterfaceNumber != 0xFF) {     //cp
        static usbfs_read_cfg_t cfg;

        args->fds.dm_usbfd = ql_usbfs_open_interface(usb_dev, usb_dev->dm_intf.bInterfaceNumber);
        qlog_dbg("open /dev/%s dm_usbfd = %d\n", usb_dev->devname, args->fds.dm_usbfd);
        if (args->fds.dm_usbfd < 0) {
            goto error;
        }

        if (socketpair(AF_LOCAL, SOCK_STREAM, 0, args->fds.dm_sockets)) {
            safe_close_fd(args->fds.dm_usbfd);
            qlog_dbg("socketpair( dm ) failed, errno: %d (%s)\n", errno, strerror(errno));
            goto error;
        }

        cfg.usbfd = args->fds.dm_usbfd;
        cfg.ep = usb_dev->dm_intf.ep_in;
        cfg.outfd = args->fds.dm_sockets[1];
        cfg.rx_size= RX_URB_SIZE;
        cfg.dev = "dm";
        if (pthread_create(&args->fds.dm_tid, NULL, qlog_usbfs_read, (void*)&cfg)) {
            qlog_dbg("pthread_create( dm ) failed, errno: %d (%s)\n", errno, strerror(errno));
            safe_close_fd(args->fds.dm_usbfd);
            safe_close_fd(args->fds.dm_sockets[0]);
            safe_close_fd(args->fds.dm_sockets[1]);
            goto error;
        }

        if (g_is_unisoc_exx00u_chip || g_is_unisoc_chip == 2 || g_is_unisoc_chip == 4)
            option_send_setup(cfg.usbfd, usb_dev->dm_intf.bInterfaceNumber, 1, 1);  //cp bInterfaceNumber
    }

    if (usb_dev->ttyGENERAL[0] && !force_use_usbfs) {
        args->fds.general_ttyfd = serial_open(usb_dev->ttyGENERAL);
        if (args->fds.general_ttyfd< 0)
        {
            qlog_dbg("tty open %s failed, errno: %d (%s)\n", usb_dev->ttyGENERAL, errno, strerror(errno));
            goto error;
        }
    }
    else if (usb_dev->general_intf.bInterfaceNumber != 0xFF) {      //ap
        static usbfs_read_cfg_t cfg;

        args->fds.general_usbfd = ql_usbfs_open_interface(usb_dev, usb_dev->general_intf.bInterfaceNumber);
        qlog_dbg("open /dev/%s general_usbfd = %d\n", usb_dev->devname, args->fds.general_usbfd);
        if (args->fds.general_usbfd < 0) {
            goto error;
        }

        if (socketpair(AF_LOCAL, SOCK_STREAM, 0, args->fds.general_sockets)) {
            safe_close_fd(args->fds.general_usbfd);
            qlog_dbg("socketpair( log ) failed, errno: %d (%s)\n", errno, strerror(errno));
            goto error;
        }

        cfg.usbfd = args->fds.general_usbfd;
        cfg.ep = usb_dev->general_intf.ep_in;
        cfg.outfd = args->fds.general_sockets[1];

        if (usb_dev->general_type == MDM_QDSS)
            cfg.rx_size= (128*1024);
        else
            cfg.rx_size= RX_URB_SIZE;

        cfg.dev = "general";
        if (pthread_create(&args->fds.general_tid, NULL, qlog_usbfs_read, (void*)&cfg)) {
            qlog_dbg("pthread_create( general ) failed, errno: %d (%s)\n", errno, strerror(errno));
            safe_close_fd(args->fds.general_usbfd);
            safe_close_fd(args->fds.general_sockets[0]);
            safe_close_fd(args->fds.general_sockets[1]);
            goto error;
        }

        if (g_is_unisoc_exx00u_chip || g_is_unisoc_chip == 2 || g_is_unisoc_chip == 4)
            option_send_setup(cfg.usbfd, usb_dev->general_intf.bInterfaceNumber, 1, 1);  //cp bInterfaceNumber
    }

    if (usb_dev->ttyTHIRD[0] && !force_use_usbfs) {              // udx710 NMEA
        args->fds.third_ttyfd = serial_open(usb_dev->ttyTHIRD);
        if (args->fds.third_ttyfd < 0)
        {
            qlog_dbg("tty open %s failed, errno: %d (%s)\n", usb_dev->ttyTHIRD, errno, strerror(errno));
            goto error;
        }
    }
    else if (usb_dev->third_intf.bInterfaceNumber != 0xFF) {     //DPL
        static usbfs_read_cfg_t cfg;

        args->fds.third_usbfd = ql_usbfs_open_interface(usb_dev, usb_dev->third_intf.bInterfaceNumber);
        qlog_dbg("open /dev/%s third_usbfd = %d\n", usb_dev->devname, args->fds.third_usbfd);
        if (args->fds.third_usbfd < 0) {
            goto error;
        }

        if (socketpair(AF_LOCAL, SOCK_STREAM, 0, args->fds.third_sockets)) {
            safe_close_fd(args->fds.third_usbfd);
            qlog_dbg("socketpair( third ) failed, errno: %d (%s)\n", errno, strerror(errno));
            goto error;
        }

        cfg.usbfd = args->fds.third_usbfd;
        cfg.ep = usb_dev->third_intf.ep_in;
        cfg.outfd = args->fds.third_sockets[1];
        cfg.rx_size= RX_URB_SIZE;
        cfg.dev = "third";
        if (pthread_create(&args->fds.third_tid, NULL, qlog_usbfs_read, (void*)&cfg)) {
            qlog_dbg("pthread_create( third ) failed, errno: %d (%s)\n", errno, strerror(errno));
            safe_close_fd(args->fds.third_usbfd);
            safe_close_fd(args->fds.third_sockets[0]);
            safe_close_fd(args->fds.third_sockets[1]);
            goto error;
        }
    }

    return 0;
error:
    return -1;
}

static void close_fds(struct arguments *args) {
    int intf = 0;

    //qlog_dbg("%s enter\n", __func__);
    if (args->fds.dm_usbfd != -1) {
        intf = args->ql_dev->dm_intf.bInterfaceNumber;
        ioctl(args->fds.dm_usbfd, USBDEVFS_RELEASEINTERFACE, &intf);
        safe_close_fd(args->fds.dm_usbfd);
        pthread_join(args->fds.dm_tid, NULL);
        safe_close_fd(args->fds.dm_sockets[0]);
        safe_close_fd(args->fds.dm_sockets[1]);
    }
    else {
        safe_close_fd(args->fds.dm_ttyfd);
    }

    if (args->fds.general_usbfd != -1) {
        intf = args->ql_dev->general_intf.bInterfaceNumber;
        ioctl(args->fds.general_usbfd, USBDEVFS_RELEASEINTERFACE, &intf);
        safe_close_fd(args->fds.general_usbfd);
        pthread_join(args->fds.general_tid, NULL);
        safe_close_fd(args->fds.general_sockets[0]);
        safe_close_fd(args->fds.general_sockets[1]);
    }
    else {
        safe_close_fd(args->fds.general_ttyfd);
    }

    if (args->fds.third_usbfd != -1) {
        intf = args->ql_dev->third_intf.bInterfaceNumber;
        ioctl(args->fds.third_usbfd, USBDEVFS_RELEASEINTERFACE, &intf);
        safe_close_fd(args->fds.third_usbfd);
        pthread_join(args->fds.third_tid, NULL);
        safe_close_fd(args->fds.third_sockets[0]);
        safe_close_fd(args->fds.third_sockets[1]);
    }
    else {
        safe_close_fd(args->fds.third_ttyfd);
    }

    qlog_dbg("%s exit\n", __func__);
}

static int str_has_suffix(const char *str1, const char *str2)
{
    if (!str1 || !str2)
        return 0;

    size_t slen1 = strlen(str1);
    size_t slen2 = strlen(str2);
    return !strncasecmp(str1 + slen1 - slen2, str2, slen2);
}

static void delete_logs(const char *dir, const char *suffix)
{
    char _suffix[256] = {'\0'};
    char tmpstr[512] = {'\0'};
    struct dirent *entptr = NULL;
    DIR *dirptr = NULL;

    if (!dir || !suffix)
        return;

    snprintf (_suffix, sizeof(_suffix), ".%.248s", suffix);
    dirptr = opendir(dir);
    if (!dirptr)
        return;

    tmpstr[0] = '\0';
    while ((entptr = readdir(dirptr)))
    {
        if (entptr->d_name[0] == '.')
            continue;

        if (!str_has_suffix(entptr->d_name, ".sdl") &&
            !str_has_suffix(entptr->d_name, ".qmdl") &&
            !str_has_suffix(entptr->d_name, ".qmdl2") &&
            !str_has_suffix(entptr->d_name, ".logel"))
            continue;

        if (suffix[0] == '\0' || str_has_suffix(entptr->d_name, _suffix))
        {
            snprintf(tmpstr, sizeof(tmpstr), "%.255s/%.255s", dir, entptr->d_name);
            qlog_dbg("try to remove %s\n", tmpstr);
            unlink(tmpstr);
        }
    }
    closedir(dirptr);
}

int main(int argc, char **argv)
{
    int ret = -1;
    struct arguments *args;
    int modules_num = 0;
    int cur_module = 0;
    int loop_times = 0;

    qlog_dbg("Version: QLog_Linux_Android_V%s\n", QLOG_VERSION);

    args = parser_args(argc, argv);
    if (!args)
    {
        return 0;
    }

    signal(SIGTERM, ql_sigaction);
    signal(SIGHUP, ql_sigaction);
    signal(SIGINT, ql_sigaction);

    if (qlog_read_com_data)
    {
        qlog_com_catch_log(args->ttyDM, args->logdir, args->logfile_sz, qlog_time_name);  //COM port data can only be stored locally
        return 0;
    }

    if (args->delete_logs)
        delete_logs(args->logdir, args->delete_logs);

__restart:
    if (qlog_exit_requested)
        return 0;

    args->ql_dev = NULL;
    memset(s_usb_device_info, 0, MAX_USB_DEV * sizeof(struct ql_usb_device_info));
    s_usb_device_info[0].dm_intf.bInterfaceNumber = 0xff;
    s_usb_device_info[0].general_intf.bInterfaceNumber = 0xff;
    s_usb_device_info[0].third_intf.bInterfaceNumber = 0xff;
    s_usb_device_info[0].general_type = -1;
	s_usb_device_info[0].third_type = -1;
    cur_module = modules_num = 0;

    if (strStartsWith(args->ttyDM, "/dev/mhi")) {
        struct ql_usb_device_info *mhi_dev = &s_usb_device_info[0];

        mhi_dev->hardware = 'p';
        mhi_dev->idVendor = 0x2C7C;
        mhi_dev->idProduct = 0x0800;
        if (!strncmp(args->ttyDM, "/dev/mhi_DIAG", strlen("/dev/mhi_DIAG")))
        {
            modem_is_pcie = 1;
            g_is_qualcomm_chip = 1;

            if (!access("/dev/mhi_QDSS", F_OK))
            {
               strcpy(mhi_dev->ttyGENERAL, "/dev/mhi_QDSS");
               mhi_dev->general_intf.bInterfaceNumber = 12;
               s_usb_device_info[0].general_type = MDM_QDSS;
            }

            if (!access("/dev/mhi_ADPL", F_OK))
            {
                strcpy(mhi_dev->ttyTHIRD, "/dev/mhi_ADPL");  //PCIE DPL
                mhi_dev->third_intf.bInterfaceNumber = 13;
                s_usb_device_info[0].third_type = 1;       // 1 QUALCOMM PCIE DPL   2 UDX710 NMEA
            }

            mhi_dev->bNumInterfaces = 5;    //not important in PCIE, only need longer than 3
        }
        else if (!strncmp(args->ttyDM, "/dev/mhi_SAHARA", strlen("/dev/mhi_SAHARA")))
            mhi_dev->bNumInterfaces = 1;
        strncpy(mhi_dev->ttyDM, args->ttyDM, sizeof(mhi_dev->ttyDM));
        mhi_dev->dm_intf.bInterfaceNumber = 0;
        modules_num = 1;
        exit_after_usb_disconnet = 1;
    }
    else if (strStartsWith(args->ttyDM, "/dev/sdiag")) {
        struct ql_usb_device_info *unisoc_dev = &s_usb_device_info[0];

        unisoc_dev->hardware = 'p';
        unisoc_dev->idVendor = 0x2C7C;
        unisoc_dev->idProduct = 0x0900;
        strncpy(unisoc_dev->ttyDM, args->ttyDM, sizeof(unisoc_dev->ttyDM));
        strncpy(unisoc_dev->ttyGENERAL, "/dev/slog_nr", sizeof(unisoc_dev->ttyGENERAL));
        unisoc_dev->bNumInterfaces = 2;

        if (qlog_read_nmea_log)
        {
            if (!access("/dev/snv_nr", F_OK))
            {
                strcpy(unisoc_dev->ttyTHIRD, "/dev/snv_nr");  //PCIE NMEA
                unisoc_dev->third_intf.bInterfaceNumber = 6;
                s_usb_device_info[0].third_type = 2;         // 1 QUALCOMM PCIE DPL   2 UDX710 NMEA
                unisoc_dev->bNumInterfaces = 3;
            }
        }

        unisoc_dev->dm_intf.bInterfaceNumber = 0;
        modules_num = 1;
        exit_after_usb_disconnet = 1;
    }
    else if (strStartsWith(args->ttyDM, "/dev/wwan")) {
        struct ql_usb_device_info *wwan_dev = &s_usb_device_info[0];

        wwan_dev->hardware = 'p';
        wwan_dev->idVendor = 0x2C7C;
        wwan_dev->idProduct = 0x0512;
        strncpy(wwan_dev->ttyDM, args->ttyDM, sizeof(wwan_dev->ttyDM));
        wwan_dev->bNumInterfaces = 1;
        if (strstr(args->ttyDM, "qcdm") || strstr(args->ttyDM, "QCDM"))
            wwan_dev->bNumInterfaces = 5;
        wwan_dev->dm_intf.bInterfaceNumber = 0;
        modules_num = 1;
        exit_after_usb_disconnet = 1;
    }

    if (modules_num == 0) {
        modules_num = ql_find_quectel_modules();
        if (modules_num == 0) {
            #if 0
            if (g_is_unisoc_chip)
                return 0; //for easy debug
            #endif
            qlog_dbg("No Quectel Modules found, Wait for connect or Press CTRL+C to quit!\n");
            sleep(2);
            goto __restart;
        }
    }

    //The UNISOC ECx00U or EGx00U is unavailable and no DM port is used
    if (strStartsWith(args->ttyDM, "/dev/ttyUSB")
        || strStartsWith(args->ttyDM, "/dev/ttyACM")
        || strStartsWith(args->ttyDM, "/sys/bus/usb/")
        ) {
        for (cur_module = 0; cur_module < modules_num; cur_module++) {
            if (!strcmp(args->ttyDM, s_usb_device_info[cur_module].usbdevice_pah))
                break;

            if (!strcmp(args->ttyDM, s_usb_device_info[cur_module].ttyDM) ||
                !ql_match_dm_device(args->ttyDM, &s_usb_device_info[cur_module])) {
                break;
            }
        }
        if (cur_module == modules_num) {
            qlog_dbg("No %s find, wait for connect!\n", args->ttyDM);
			sleep(1);
            goto __restart;
        }
    }

    if (s_usb_device_info[cur_module].idProduct == 0x4d00 && s_usb_device_info[cur_module].idVendor == 0x1782)
    {
        char devpath[256] = {0};

        snprintf(devpath, sizeof(devpath), "/dev/bus/usb/%03d/%03d", s_usb_device_info[cur_module].busnum, s_usb_device_info[cur_module].devnum);
        qlog_dbg("devpath:%s\n",devpath);

        int i;
        for(i=0;i<8;i++)
        {
            if (access(devpath,F_OK))
                goto __restart;
            sleep(1);
        }
    }

    args->ql_dev = &s_usb_device_info[cur_module];

    g_is_asr_chip = drv_is_asr(args->ql_dev->idProduct,args->ql_dev->idVendor);
    g_is_unisoc_chip = drv_is_unisoc(args->ql_dev->idProduct,args->ql_dev->idVendor);
    g_is_unisoc_exx00u_chip = drv_is_unisoc_exx00u(args->ql_dev->idProduct,args->ql_dev->idVendor);
    g_is_mtk_chip = drv_is_mtk(args->ql_dev->idProduct,args->ql_dev->idVendor);
    g_is_eigen_chip = drv_is_eigen(args->ql_dev->idProduct,args->ql_dev->idVendor);
    g_is_usb_disconnect = 0;
    g_donot_split_logfile = 0;

    if (args->ql_dev->idProduct == 0x4d00  && args->ql_dev->idVendor == 0x1782 && args->ql_dev->bcdDevice == 1)
        g_is_unisoc_chip = 3;     //EC200D ap dump

    if (qlog_abnormal_exit && use_diag_qdss == 1)
    {
        qlog_abnormal_exit = 0;
        mdm_reset_global_variables();
    }
    else if (qlog_abnormal_exit && use_qmdl2_v2 == 1)
    {
        qlog_abnormal_exit = 0;
        mdm_reset_global_variables();
    }

    qlog_args = args;
    ret = prepare(args);
    if (ret < 0)
    {
        qlog_dbg("arg do prepare failed\n");
        return ret;
    }

    loop_times++;
    if (access(args->logdir, F_OK) && errno == ENOENT
         && !is_tftp() && !is_ftp() && !is_tty2tcp() && !is_tcp_client())
        mkdir(args->logdir, 0755);

    qlog_dbg("Press CTRL+C to stop catch log.\n");
    if (args->ql_dev->bNumInterfaces == 1)
    {
        int dmfd = -1;
        char dump_dir[262];

        if (args->fds.dm_ttyfd != -1) {
            dmfd = args->fds.dm_ttyfd;
        }
        else if (args->fds.dm_sockets[0] != -1) {
            dmfd = args->fds.dm_sockets[0];
        }

        s_logfile_List[s_logfile_idx][0] = '\0'; //to prevent this log delete, log before dump

        if (qlog_is_not_dir(args->logdir)) {
            snprintf(dump_dir, sizeof(dump_dir), "%s", args->logdir);
        }
        else if (is_tty2tcp()) {
            qlog_dbg("tty2tcp only support catch log, but modem is in ram dump state\n");
            qlog_exit_requested = 1;
            goto error;
        }
        else {
            snprintf(dump_dir, sizeof(dump_dir), "%.172s/dump_%.80s", args->logdir, qlog_time_name(1));
            mkdir(dump_dir, 0755);
            if (!qlog_avail_space_for_dump(dump_dir, g_is_asr_chip ? 128 : 256)) {
                 qlog_dbg("no enouth disk to save dump\n");
                 qlog_exit_requested = 1;
                 goto error;
           }
        }

        if (g_is_asr_chip)
        {
            sleep(5);
            qlog_dbg("catch dump for asr chipset\n");
            ret = asr_catch_dump(dmfd, dump_dir);
        }
        else if (g_is_unisoc_chip)
        {
            if (is_tftp())
                block_size = 8192;

            qlog_dbg("catch dump for unisoc chipset\n");
            ret = unisoc_catch_dump(args->fds.dm_usbfd, dmfd, dump_dir, RX_URB_SIZE, qlog_time_name);
            sleep(1);
            qlog_exit_requested = 1;   //Unisoc captures AP dumps and requires the exit flag to be preserved
        }
        else
        {
            qlog_dbg("catch dump for mdm chipset\n");
            ret = sahara_catch_dump(dmfd, dump_dir, 1);
        }

        if (qlog_continue && !qlog_exit_requested)
            sleep(6);    //dump to normal mode need max -> 6s (EC600N-CN)
        else
            qlog_exit_requested = 1;

    }
    else if (args->ql_dev->bNumInterfaces > 1) {
        if (args->fds.dm_usbfd != -1 || args->fds.general_usbfd != -1 || args->fds.third_usbfd != -1)
            qlog_dbg("catch log via usbfs\n");
        else {
            qlog_dbg("catch log via tty port\n");
        }
        if (is_tftp()) {
            qlog_dbg("tftp only support catch ram dump, but modem is not in ram dump state\n");
            qlog_exit_requested = 1;
            goto error;
        }
        ret = qlog_handle(args);
    }
    else {
        qlog_dbg("unknow state! quit!\n");
        qlog_dbg("for pcie module, you need to select the correct port\n");
        goto error;
    }

error:
    close_fds(args);

    if (qlog_exit_requested == 0 && exit_after_usb_disconnet == 0) {
        sleep(1);
        goto __restart;
    }

    if (is_ftp())
        ftp_quit();

    return ret;
}
