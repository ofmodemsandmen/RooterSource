/******************************************************************************
  @file    asr.c
  @brief   asr log tool.

  DESCRIPTION
  QLog Tool for USB and PCIE of Quectel wireless cellular modules.

  INITIALIZATION AND SEQUENCING REQUIREMENTS
  None.

  ---------------------------------------------------------------------------
  Copyright (c) 2016 - 2020 Quectel Wireless Solution, Co., Ltd.  All Rights Reserved.
  Quectel Wireless Solution Proprietary and Confidential.
  ---------------------------------------------------------------------------
******************************************************************************/

#include <sys/mman.h>
#include "qlog.h"

struct CSDLFileHeader
{
    uint32_t dwHeaderVersion; //0x0
    uint32_t dwDataFormat;    //0x1
    uint32_t dwAPVersion;
    uint32_t dwCPVersion;
    uint32_t dwSequenceNum; //�ļ���ţ���?��ʼ����
    uint32_t dwTime;        //Total seconds from 1970.1.1 0:0:0
    uint32_t dwCheckSum;    //0x0
};

/**
 * Command Format:
 *      PDU(4 byte) + SDU
 *      
 * Diag PDU部分:
 *      4 byte fixed data '10 00 00 00'
 * Diag SDU部分
 *      CP (12 byte): 00 00 FF FF 00 00 00 00 00 00 00 00 
 *      AP (12 byte): 80 00 FF FF 00 00 00 00 00 00 00 00 
 *
 * Example CP communication from tty
 * Request
 *      10 00 00 00 00 00 FF FF   00 00 00 00 00 00 00 00
 * Response
 *      1b 00 00 00 01 00 00 00   ff ff 00 00 45 49 5c 05
 *      30 78 30 30 30 30 31 30   30 62 00    // 0x0000100b
 * 
 * Example AP communication from tty
 * Request
 *      10 00 00 00 80 00 FF FF   00 00 00 00 00 00 00 00
 * Response
 *      1b 00 00 00 01 80 00 00   ff ff 00 00 19 11 06 00
 *      30 78 36 36 30 63 65 39   38 64 00    // 0x660ce98d
 * 
 * NOTICE:
 *      always try to get AP/CP DB version until you finally get them.
 */
#define DIAG_SAP_CP 0x01
#define DIAG_SAP_AP 0x8001
#define DIAG_MODID 0xffff
#define DIAG_MSGID 0x00
struct DBVerInfo
{
    uint16_t wPduLen;  // Packet Length
    uint16_t wDirInd;  // Fixed: 0
    uint16_t wSap;     // CP: 1, AP: 0x8001
    uint16_t wCnt;     // Counter
    uint16_t wModID;   // Fixed: 0xFFFF
    uint16_t wMsgID;   // Service ID: DIAG(0)
    uint32_t dwUETime; // UE time from startup
    char version[0];
};

struct SAP5
{
    uint16_t wPduLen;  // Packet Length
    uint16_t wDirInd;  // Fixed: 0
    uint16_t wSap;     // CP: 1, AP: 0x8001
    uint16_t wCnt;     // Counter
    uint32_t dwUETime; // UE time from startup
};

// static void asr_hex_dump(const unsigned char *buf, size_t size)
// {
//     char buffer[1024 * 16] = {'\0'};

//     for (int i = 0; i < size && strlen(buffer) < 8 * 1024; i++)
//     {
//         if (i % 16 == 0)
//             snprintf(buffer + strlen(buffer), sizeof(buffer), "\n");
//         if (i % 8 == 0)
//             snprintf(buffer + strlen(buffer), sizeof(buffer), "   ");
//         snprintf(buffer + strlen(buffer), sizeof(buffer), "%02x ", buf[i]);
//     }
//     qlog_dbg("%s\n", buffer);
// }

ssize_t asr_send_cmd(int fd, const unsigned char *buf, size_t size) {
    size_t wc = 0;

    while (wc < size) {
        uint32_t *cmd_data = (uint32_t *)(buf + wc);
        unsigned cmd_len = qlog_le32(cmd_data[0]);
        unsigned rx_count = g_rx_log_count;
        int rx_wait = 100;
        //unsigned i;

        if (cmd_len > (size - wc))
            break;

        if (qlog_poll_write(fd, buf + wc, cmd_len, 1000) != (ssize_t)cmd_len)
            break;

        while (rx_wait-- > 0) {
            if (g_rx_log_count != rx_count)
                break;
            usleep(1 * 1000);
        }

        wc += cmd_len;
    }

    return wc;
}

static uint32_t  g_dwUETime; // UE time from startup
static uint32_t g_u32APVersion = 0;
static uint32_t g_u32CPVersion = 0;
static uint32_t g_query_version_done = 0;
static int asr_init_filter(int fd, const char *cfg)
{
    unsigned char ACATReady[16] = {0x10, 0x00, 0x00, 0x00, 0x00, 0x04, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};  // ACAT Ready command
    unsigned char GetAPDBVer[16] = {0x10, 0x00, 0x00, 0x00, 0x80, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}; // Get AP DB Ver command
    unsigned char GetCPDBVer[16] = {0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}; // Get CP DB Ver command
    unsigned char ACATKeepAlive_AP[16] = {0x10, 0x00, 0x00, 0x00, 0x80, 0x0D, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    uint32_t t = 0;

    (void)cfg;
    g_dwUETime = 0;
    g_u32APVersion = 0;
    g_u32CPVersion = 0;
    g_query_version_done = 0;
    asr_send_cmd(fd, ACATReady, sizeof(ACATReady));
    usleep(1000);

#define _my_write(_cmd) do { if (asr_send_cmd(fd, _cmd, sizeof(_cmd)) != sizeof(_cmd)) { goto my_write_fail; } }  while (0)
    for (t = 0; t < 10; t++)
    {
        if (g_query_version_done)
            break;

        if (!g_u32APVersion) {
            _my_write(GetAPDBVer);
            usleep(1000);
        }

        if (!g_u32CPVersion) {
            _my_write(GetCPDBVer);
            usleep(1000);
        }

        sleep(1);
        if (g_rx_log_count < 5) {
            _my_write(ACATReady);
        }
    }

    g_query_version_done = 1;

    while (1) {
        sleep(5);
        _my_write(ACATKeepAlive_AP);
    }

my_write_fail:
    return 0;
}

static void *g_pmap = NULL;
static int asr_logfile_init(int logfd, unsigned logfile_seq) {
    struct CSDLFileHeader SDLHeader;
    size_t size = sizeof(struct CSDLFileHeader);
    ssize_t nbytes;
    time_t ltime;

    time(&ltime);
    // init the SDL file header
    SDLHeader.dwHeaderVersion = 0x0;
    SDLHeader.dwDataFormat = qlog_le32(0x1); //0x1
    SDLHeader.dwAPVersion = qlog_le32(g_u32APVersion);
    SDLHeader.dwCPVersion = qlog_le32(g_u32CPVersion);
    SDLHeader.dwSequenceNum = qlog_le32(logfile_seq); //�ļ���ţ���?��ʼ����
    SDLHeader.dwTime = qlog_le32(ltime);              //Total seconds from 1970.1.1 0:0:0
    SDLHeader.dwCheckSum = 0x0;                       //0x0

    // Write the file header.
    nbytes = write(logfd, &SDLHeader, size);
    if (nbytes != (ssize_t)size)
        qlog_dbg("write %zd/%zd, errno: %d (%s)\n", nbytes, size, errno, strerror(errno));

    if (logfd > 0 && !g_query_version_done && !g_ftp_server_ip)
    {
        g_pmap = mmap(NULL, sizeof(struct CSDLFileHeader), PROT_READ | PROT_WRITE, MAP_SHARED, logfd, 0);
        if (MAP_FAILED == g_pmap)
        {
            qlog_dbg("mmap fail for errno: %d (%s)\n", errno, strerror(errno));
        }
    }

    return 0;
}

static void asr_parser_dbversion(const void *buf, size_t size)
{
#define data_max 8192
    static uint8_t *data_buf = NULL;
    static size_t data_len = 0;
    size_t offset = 0;
    size_t left_room;

    if (!data_buf)
        data_buf = (uint8_t *)malloc(data_max);
    if (!data_buf)
        return;

_start:
    left_room = data_max - data_len;
    if (size > left_room) {
        //qlog_dbg("oops! left_room = %zd, size = %zd!\n", left_room, size);
        memcpy(data_buf + data_len, buf, left_room);
        data_len = data_max;
        size -= left_room;
        buf += left_room;
    }
    else {
        memcpy(data_buf + data_len, buf, size);
        data_len += size;
        size = 0;
    }

    offset = 0;
    while ((offset + sizeof(struct DBVerInfo)) < data_len)
    {
        uint8_t *pbuf = data_buf + offset;
        struct DBVerInfo *info = (struct DBVerInfo *)pbuf;
        uint16_t len = qlog_le16(info->wPduLen); //Android NDK donot support le16toh
        uint16_t wDirInd = qlog_le16(info->wDirInd);
        uint16_t wSap = qlog_le16(info->wSap);
        uint32_t dwUETime = qlog_le32(info->dwUETime);

        if (len == 0 || wDirInd != 0) {
            offset++;
            continue;
        }

        if (wSap == 5) {
            if (len > 5328) {
                offset++;
                continue;
            }
            dwUETime = qlog_le32(((struct SAP5 *)pbuf)->dwUETime);
        }
        else {
            if (len > 7680) {
                offset++;
                continue;
            }
        }

        if (g_dwUETime && dwUETime && dwUETime != 0xFFFFFFFF
            && abs((int)(dwUETime - g_dwUETime)) > (4*1000*1000)) {
            //qlog_dbg("dwUETime: %x -> %x\n", g_dwUETime, dwUETime);
        }
        else
            g_dwUETime = dwUETime;

        if (offset + len > data_len)
            break;

        if (0x1b == len && info->version[0] == '0' &&
            info->version[1] == 'x' && pbuf[len - 1] == 0 &&
            DIAG_MODID == qlog_le16(info->wModID) &&
            DIAG_MSGID == qlog_le16(info->wMsgID))
        {
            uint32_t ver = strtoul(info->version, NULL, 16);
            if (DIAG_SAP_AP == qlog_le16(info->wSap))
            {
                g_u32APVersion = ver;
                qlog_dbg("APDBVersion=0x%x\n", g_u32APVersion);
            }
            else if (DIAG_SAP_CP == qlog_le16(info->wSap))
            {
                g_u32CPVersion = ver;
                qlog_dbg("CPDBVersion=0x%x\n", g_u32CPVersion);
            }

            if (g_u32APVersion && g_u32CPVersion)
            {
                g_query_version_done = 1;
                break;
            }
        }

        offset += len;
    }

    data_len -= offset;
    if (data_len && offset)
        memmove(data_buf, data_buf + offset, data_len);

    if (size)
        goto _start;
}

static size_t asr_logfile_save(int logfd, const void *buf, size_t size)
{
    if (size <= 0 || NULL == buf || logfd <= 0)
        return size;

    if (!g_query_version_done)
        asr_parser_dbversion(buf, size);
    return qlog_logfile_save(logfd, buf, size);
}

static int asr_log_shutdown(int fd)
{
    static uint8_t ACATDisconnect_CP[16] = {0x10, 0x00, 0x00, 0x00, 0x00, 0x0C, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    static uint8_t ACATDisconnect_AP[16] = {0x10, 0x00, 0x00, 0x00, 0x80, 0x0C, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

    usleep(200);
    asr_send_cmd(fd, ACATDisconnect_CP, 16);

    usleep(200);
    asr_send_cmd(fd, ACATDisconnect_AP, 16);

    return 0;
}

static int asr_logfile_close(int logfd)
{
    struct CSDLFileHeader *pSDLHeader = NULL;

    fsync(logfd);
    if (g_pmap && g_pmap != MAP_FAILED)
    {
        pSDLHeader = (struct CSDLFileHeader *)g_pmap;
        pSDLHeader->dwAPVersion = qlog_le32(g_u32APVersion);
        pSDLHeader->dwCPVersion = qlog_le32(g_u32CPVersion);
        munmap(g_pmap, sizeof(struct CSDLFileHeader));
        qlog_dbg("try to reset APDBVersion(0x%x) and CPDBVersion(0x%x)\n", g_u32APVersion, g_u32CPVersion);
    }
    g_pmap = NULL;
    qlog_logfile_close(logfd);

    return 0;
}

qlog_ops_t asr_qlog_ops = {
    .init_filter = asr_init_filter,
    .logfile_init = asr_logfile_init,
    .logfile_save = asr_logfile_save,
    .clean_filter = asr_log_shutdown,
    .logfile_close = asr_logfile_close,
};
