#include "qlog.h"

#include <sys/epoll.h>
#include <inttypes.h>

#define SOH_PAYLOAD_LEN 128
#define STX_PAYLOAD_LEN 1024
#define YMODEM_CRC16(_buff, _len) ((_buff[_len - 2] << 8) | (_buff[_len - 1]))

struct FrameHdr
{
    uint8_t tag;
    uint8_t idx;
    uint8_t comp;
    uint8_t data[1024];
    uint8_t crc[2];
};

enum
{
    SOH = 0x01,
    STX = 0x02,
    EOT = 0x04,
    ACK = 0x06,
    NAK = 0x15,
    CAN = 0x18,
    CNC = 0x43,
};

static size_t g_total_recvsz = 0;
static int g_current_fd = -1;
static size_t g_current_filesz = 0;
static size_t g_current_recvsz = 0;
static char g_current_filename[128];

#if 0 //USB is stable, so skip crc
static uint16_t calc_crc16(const uint8_t *buff, int sz)
{
    uint16_t crc = 0;
    int i;

    while (sz--)
    {
        crc = crc ^ *buff++ << 8;
        for (i = 0; i < 8; i++)
        {
            if (crc & 0x8000)
                crc = crc << 1 ^ 0x1021;
            else
                crc = crc << 1;
        }
    }
    return crc;
}

static int varify_rx_pkt(uint8_t *buff, int len)
{
    uint16_t crc_expt = YMODEM_CRC16(buff, len);
    uint16_t crc_real = calc_crc16(buff, len - 2);
    int ret = (crc_expt == crc_real);

    if (!ret)
        qlog_dbg("%s crc check failed, datalen %d, (real)0x%x != (expt)0x%x\n", __func__, len, crc_real, crc_expt);
    return ret;
}
#endif

static void status_bar(int byte_recv, int byte_all, int len)
{
    const char status[] = {'-', '\\', '|', '/'};
    const int size = (128*len); //too much print on uart debug will cost too much time

    if (len == 0)
    {
        qlog_raw_log("status: %d/%d\n", byte_recv, byte_all);
        return;
    }

    if ((byte_recv%size) == 0) {
        qlog_raw_log("status: %c", status[(byte_recv/size)%4]);
    }
}

static int finishup()
{
    qlog_dbg("recv %s finished\n", g_current_filename);
    qlog_dbg("expect %zd bytes, actually get %zd bytes\n", g_current_filesz, g_current_recvsz);
    qlog_logfile_close(g_current_fd);
    g_current_recvsz = 0;
    g_current_filesz = 0;
    g_current_filename[0] = '\0';
    g_current_fd = -1;
    return 0;
}

static int parser_hdr(const char *logfile_dir, uint8_t *buff, int len)
{
    int offset = 0;
    char full_filename[512];

    (void)len;
    snprintf(g_current_filename, sizeof(g_current_filename), "%.127s", (const char *)(buff + offset));
    offset += strlen(g_current_filename) + 1;
    g_current_filesz = strtoul((const char *)(buff + offset), NULL, 10);
    g_current_recvsz = 0;
    qlog_dbg("\n");
    qlog_dbg("prepare to recv file '%s' with size of %zd bytes\n", g_current_filename, g_current_filesz);

    if (g_current_filename[0] != '\0')
    {
        snprintf(full_filename, sizeof(full_filename), "%.256s/%s", logfile_dir, g_current_filename);
        g_current_fd = qlog_logfile_create_fullname(0, full_filename, 0, 1);
    }
    else
        return 0;   //g_current_filename[0] == '\0'  The default is the end of dump, regardless of whether the module has no return

    return (g_current_fd > 0) ? 0 : -1;
}

static int save_data(uint8_t *buff, int len)
{
    int remain_len = g_current_filesz - g_current_recvsz;
    int data_len = (remain_len < len) ? remain_len : len;
    int ret = len;

    g_current_recvsz += data_len;
    g_total_recvsz += data_len;

    if (buff && len > 0 && g_current_fd > 0) {
        ret = qlog_logfile_save(g_current_fd, buff, len);
        if (ret != len)
            qlog_dbg("%s save data failed, want write %d bytes, actually write %d bytes\n", __func__, len, ret);
    }
    status_bar(g_current_recvsz, g_current_filesz, len);
    return (ret == len) ? 0 : -1;
}

static int ymodem_tx_data(int ttyfd, uint8_t data)
{
    size_t rc;

    rc = qlog_poll_write(ttyfd, &data, 1, 1000);
    if (rc == 1)
        return 0;
    return errno ? -errno: -1;
}

static int ymodem_rx_data(int ttyfd, void *pbuf, size_t size) {
    ssize_t rc = -1;
    struct FrameHdr *pHdr = (struct FrameHdr *)pbuf;

    rc = qlog_poll_read(ttyfd, pbuf, size, 10000);

    if (rc > 0) {
        if (pHdr->tag == SOH) {
            if (rc != (128+5)) {
                qlog_dbg("rx tag is SOH, but read %zd\n", rc);
                goto _error;
            }
        }
        else if (pHdr->tag == STX) {
            if (rc !=(1024+5)) {
                qlog_dbg("rx tag is STX, but read %zd\n", rc);
                goto _error;
            }
        }
        else if (pHdr->tag == EOT) {
            if (rc != 1) {
                qlog_dbg("rx tag is EOT, but read %zd\n", rc);
                goto _error;
            }
        }
        else {
            qlog_dbg("rx tag is %d, read %zd\n", pHdr->tag, rc);
        }
        return 0;
    }

_error:
    return errno ? -errno: -1;
}

static struct FrameHdr YmodemBuff;
int asr_catch_dump(int ttyfd, const char *logfile_dir)
{
    int ret;
    size_t size = sizeof(struct FrameHdr);
    struct FrameHdr *pHdr = &YmodemBuff;
    unsigned start_t = qlog_msecs();

    qlog_dbg("try to catch dump with YMODEM protocol(not standard)\n");
    qlog_dbg("Windows platfrom can use \"Tera Term\" to do this job\n");
    qlog_dbg("try to catch dump, it will take several minutes\n");
    qlog_dbg("\n");

    ret = ymodem_tx_data(ttyfd, CNC);
    if (ret) goto QUIT;

    g_total_recvsz = 0;
    g_current_fd = -1;
    while (qlog_exit_requested == 0) {
        int wait_file_retry = 0;
        g_current_recvsz = 0;

        while (wait_file_retry < 5) {
            ret = ymodem_rx_data(ttyfd, pHdr, size);
            if (ret == 0) {
                break;
            } else if (ret == -ETIMEDOUT) {
                if (wait_file_retry) //ASR need some time to prepare next fils
                    qlog_dbg("rx timeout and cnc again!\n");
                ymodem_tx_data(ttyfd, CNC);
            } else {
                goto QUIT;
            }
            wait_file_retry++;
        }

        if (pHdr->tag == STX || pHdr->tag == EOT || (pHdr->tag == SOH && pHdr->idx != 0x00)) {
            //maybe abort above time, try to recover
            ymodem_tx_data(ttyfd, ACK);
            continue;
        }

        ret = parser_hdr(logfile_dir, pHdr->data, 128);
        if (ret) goto QUIT;

        ret = ymodem_tx_data(ttyfd, ACK);
        if (ret) goto QUIT;

        if (g_current_filesz == 0 && g_current_filename[0] == '\0') {
            qlog_dbg("asr_catch_dump finish transfer\n");
            qlog_dbg("totally recv %zd bytes, cost %u seconds\n", g_total_recvsz, (qlog_msecs()-start_t+500)/1000);
            usleep(100*1000);
            ymodem_tx_data(ttyfd, CNC); //here to make asr reboot
            goto QUIT;
        }

        while (qlog_exit_requested == 0) {
            int data_len = 0;
            ret = ymodem_rx_data(ttyfd, pHdr, size);
            if (ret == -ETIMEDOUT) {
                qlog_dbg("rx timeout and ack again!\n");
                ymodem_tx_data(ttyfd, ACK);
                ret = ymodem_rx_data(ttyfd, pHdr, size);
            }
            if (ret) goto QUIT;

            if (pHdr->tag == SOH) {
                data_len = 128;
            }
            else if (pHdr->tag == STX) {
                data_len = 1024;
            }
            else if (pHdr->tag == EOT) {
                ymodem_tx_data(ttyfd, ACK);
                save_data(NULL, 0);
                finishup();
                break;
            }
            else {
                qlog_dbg("NOT SOH/STX/EOT!");
                ret = -1;
                goto QUIT;
            }

            ret = ymodem_tx_data(ttyfd, ACK);
            if (ret) goto QUIT;

            if (data_len)
                save_data(pHdr->data, data_len); //first send ack, then save file, reduce some time
        }
        if (g_current_fd != -1)
        {
            qlog_logfile_close(g_current_fd);
            g_current_fd = -1;
        }
			
    }

QUIT:
    qlog_dbg("%s returns with code %d\n", __func__, ret);
    //if (ret) exit(ret);
    return ret;
}
