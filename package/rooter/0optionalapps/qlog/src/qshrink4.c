static int diag_verbose = 0;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;

#define MSM	0
#define MDM	1
#define MDM_2	2
#define DIAG_MODEM_PROC		0
#define DIAG_APPS_PROC                 7

#define GUID_LEN 16
#define MAX_GUID_ENTRIES 16
#define NUM_PROC 10

#include "diagcmd.h"

#define DIAG_GET_DIAG_ID	0x222

#define DIAGDIAG_QSR4_FILE_OP_MODEM            0x0816

#define DIAGDIAG_FILE_LIST_OPERATION           0x00
#define DIAGDIAG_FILE_OPEN_OPERATION           0x01
#define DIAGDIAG_FILE_READ_OPERATION           0x02
#define DIAGDIAG_FILE_CLOSE_OPERATION          0x03

typedef struct {
	uint32 data1;
	uint16 data2;
	uint16 data3;
	uint8 data4[8];
} __attribute__ ((packed))  GUID;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
} __attribute__ ((packed)) diag_pkt_header_t;

typedef struct  {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint16 version;
	uint16 opcode;
}  __attribute__ ((packed)) diag_qsr_header_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint32 delayed_rsp_status;
	uint16 delayed_rsp_id;
	uint16 rsp_cnt;
	uint16 version;
	uint16 opcode;
} __attribute__ ((packed)) diag_qsr_header_rsp;

typedef struct {
	uint8 guid[16];
	uint32 file_len;
} __attribute__ ((packed)) qshrink4_file_info;

typedef struct {
	diag_qsr_header_rsp rsp_header;
	uint8 status;
	uint8 num_files;
	qshrink4_file_info info[0];
} __attribute__ ((packed)) diag_qsr_file_list_rsp;

typedef struct  {
	diag_qsr_header_req req;
	uint8 guid[16];
} __attribute__ ((packed)) diag_qsr_file_open_req;

typedef struct  {
	diag_qsr_header_rsp rsp_header;
	uint8 guid[16];
	uint16 read_file_fd;
	uint8 status;
}  __attribute__ ((packed)) diag_qsr_file_open_rsp;

typedef struct {
	diag_qsr_header_req req;
	uint16 read_file_fd;
} __attribute__ ((packed))  diag_qsr_file_close_req;

typedef struct  {
	diag_qsr_header_rsp rsp_header;
	uint16 read_file_fd;
	uint8 status;
} __attribute__ ((packed)) diag_qsr_file_close_rsp;

typedef struct {
	diag_qsr_header_req req;
	uint16 read_file_fd;
	uint32 req_bytes;
	uint32 offset;
} __attribute__ ((packed)) diag_qsr_file_read_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint32 delayed_rsp_status;
	uint16 delayed_rsp_id;
	uint16 rsp_cnt;
	uint16 version;
	uint16 opcode;
	uint16 read_file_fd;
	uint32 offset;
	uint32 num_read;
	uint8 status;
	uint8 data[0];
}  __attribute__ ((packed)) diag_qsr_file_read_rsp;

typedef struct {
	uint32_t header_length;
	uint8_t version;
	uint8_t hdlc_data_type;
	uint32_t guid_list_entry_count;
	uint8_t guid[MAX_GUID_ENTRIES][GUID_LEN];
	uint32_t guid_file_len[MAX_GUID_ENTRIES];
} __attribute__ ((packed)) qshrink4_header;

typedef struct {
	uint8 diag_id;
	char process_name[30];
	uint8 guid[GUID_LEN];
}__attribute__ ((packed)) diagid_guid_struct;

typedef struct {
    uint8 cmd_code;
    uint8 subsys_id;
    uint16 subsys_cmd_code;
    uint8 version;
} __attribute__ ((packed)) diag_id_list_req;

typedef struct {
	uint8 diag_id;
	uint8 len;
	char process_name[];
} __attribute__ ((packed)) diag_id_entry_struct;

typedef struct {
    uint8 cmd_code;
    uint8 subsys_id;
    uint16 subsys_cmd_code;
    uint8 version;
    uint8 num_entries;
    diag_id_entry_struct entry;
} __attribute__ ((packed)) diag_id_list_rsp;

typedef struct {
    uint8 diag_id;
    uint8 peripheral;
    char process_name[30];
} __attribute__ ((packed)) diag_id_list;

#define QSR4_DB_CMD_REQ_BUF_SIZE 50
#define QSR4_DB_READ_BUF_SIZE 5000
#define MAX_QSR4_DB_FILE_READ_PER_RSP 4000

typedef enum {
	DB_PARSER_STATE_OFF,
	DB_PARSER_STATE_ON,
	DB_PARSER_STATE_LIST,
	DB_PARSER_STATE_OPEN,
	DB_PARSER_STATE_READ,
	DB_PARSER_STATE_CLOSE,
} qsr4_db_file_parser_state;

static int parser_state;
static int diag_id_state;
static int qdss_state;
static int dpl_state;
static int diag_disable_qtrace_state;
static int diag_disable_qtrace_rsp;
extern int diag_qdss_handle_response(const uint8_t *buf, size_t size);
extern int diag_dpl_handle_response(const uint8_t *buf, size_t size);

static qshrink4_header qshrink4_data;
static diagid_guid_struct diagid_guid[MAX_GUID_ENTRIES];
static uint8 diag_id_count;
static diag_id_list diag_id_table[NUM_PROC];

static uint8_t cur_peripheral = DIAG_MODEM_PROC;
static int dm_fd = -1;

#include "diag_pkt.c"
static struct diag_pkt *mdm_diag_pkt;
static int read_file_fd = -1;
static uint32_t read_file_total_len = 0;
static uint32_t read_file_len = 0;
extern int disk_file_fd;
static int skip_wakeup = 0;
static int qshrink4_init = 0;

static void mdm_add_qshrink4_header(void) {
    uint32_t header_length = 0;
    uint32_t count = qlog_le32(qshrink4_data.guid_list_entry_count);
    uint32_t *data_ptr = NULL;
    int fd = -1;

    header_length = 10 + count*GUID_LEN + sizeof(count) + count*sizeof(diagid_guid_struct);

    qshrink4_data.version = 2;
    qshrink4_data.hdlc_data_type = 1;

    data_ptr = (uint32_t *)(&qshrink4_data.guid[count][0]);
    *data_ptr++ = qshrink4_data.guid_list_entry_count;
    memcpy(data_ptr, diagid_guid, count*sizeof(diagid_guid_struct));

    qshrink4_data.header_length = qlog_le32(header_length);

    //fd = qlog_create_file_in_logdir("qlog.qmdl2");
    if (fd != -1) {
        qlog_logfile_save(fd, &qshrink4_data, header_length);
        close(fd);
    }
}

static unsigned char qsr4_db_cmd_req_buf[100];

#define CRC_16_L_SEED           0xFFFF
#define CRC_TAB_SIZE    256             /* 2^CRC_TAB_BITS      */
#define CRC_16_L_POLYNOMIAL     0x8408

const unsigned short crc_16_l_table[ CRC_TAB_SIZE ] = {
        0x0000, 0x1189, 0x2312, 0x329b, 0x4624, 0x57ad, 0x6536, 0x74bf,
        0x8c48, 0x9dc1, 0xaf5a, 0xbed3, 0xca6c, 0xdbe5, 0xe97e, 0xf8f7,
        0x1081, 0x0108, 0x3393, 0x221a, 0x56a5, 0x472c, 0x75b7, 0x643e,
        0x9cc9, 0x8d40, 0xbfdb, 0xae52, 0xdaed, 0xcb64, 0xf9ff, 0xe876,
        0x2102, 0x308b, 0x0210, 0x1399, 0x6726, 0x76af, 0x4434, 0x55bd,
        0xad4a, 0xbcc3, 0x8e58, 0x9fd1, 0xeb6e, 0xfae7, 0xc87c, 0xd9f5,
        0x3183, 0x200a, 0x1291, 0x0318, 0x77a7, 0x662e, 0x54b5, 0x453c,
        0xbdcb, 0xac42, 0x9ed9, 0x8f50, 0xfbef, 0xea66, 0xd8fd, 0xc974,
        0x4204, 0x538d, 0x6116, 0x709f, 0x0420, 0x15a9, 0x2732, 0x36bb,
        0xce4c, 0xdfc5, 0xed5e, 0xfcd7, 0x8868, 0x99e1, 0xab7a, 0xbaf3,
        0x5285, 0x430c, 0x7197, 0x601e, 0x14a1, 0x0528, 0x37b3, 0x263a,
        0xdecd, 0xcf44, 0xfddf, 0xec56, 0x98e9, 0x8960, 0xbbfb, 0xaa72,
        0x6306, 0x728f, 0x4014, 0x519d, 0x2522, 0x34ab, 0x0630, 0x17b9,
        0xef4e, 0xfec7, 0xcc5c, 0xddd5, 0xa96a, 0xb8e3, 0x8a78, 0x9bf1,
        0x7387, 0x620e, 0x5095, 0x411c, 0x35a3, 0x242a, 0x16b1, 0x0738,
        0xffcf, 0xee46, 0xdcdd, 0xcd54, 0xb9eb, 0xa862, 0x9af9, 0x8b70,
        0x8408, 0x9581, 0xa71a, 0xb693, 0xc22c, 0xd3a5, 0xe13e, 0xf0b7,
        0x0840, 0x19c9, 0x2b52, 0x3adb, 0x4e64, 0x5fed, 0x6d76, 0x7cff,
        0x9489, 0x8500, 0xb79b, 0xa612, 0xd2ad, 0xc324, 0xf1bf, 0xe036,
        0x18c1, 0x0948, 0x3bd3, 0x2a5a, 0x5ee5, 0x4f6c, 0x7df7, 0x6c7e,
        0xa50a, 0xb483, 0x8618, 0x9791, 0xe32e, 0xf2a7, 0xc03c, 0xd1b5,
        0x2942, 0x38cb, 0x0a50, 0x1bd9, 0x6f66, 0x7eef, 0x4c74, 0x5dfd,
        0xb58b, 0xa402, 0x9699, 0x8710, 0xf3af, 0xe226, 0xd0bd, 0xc134,
        0x39c3, 0x284a, 0x1ad1, 0x0b58, 0x7fe7, 0x6e6e, 0x5cf5, 0x4d7c,
        0xc60c, 0xd785, 0xe51e, 0xf497, 0x8028, 0x91a1, 0xa33a, 0xb2b3,
        0x4a44, 0x5bcd, 0x6956, 0x78df, 0x0c60, 0x1de9, 0x2f72, 0x3efb,
        0xd68d, 0xc704, 0xf59f, 0xe416, 0x90a9, 0x8120, 0xb3bb, 0xa232,
        0x5ac5, 0x4b4c, 0x79d7, 0x685e, 0x1ce1, 0x0d68, 0x3ff3, 0x2e7a,
        0xe70e, 0xf687, 0xc41c, 0xd595, 0xa12a, 0xb0a3, 0x8238, 0x93b1,
        0x6b46, 0x7acf, 0x4854, 0x59dd, 0x2d62, 0x3ceb, 0x0e70, 0x1ff9,
        0xf78f, 0xe606, 0xd49d, 0xc514, 0xb1ab, 0xa022, 0x92b9, 0x8330,
        0x7bc7, 0x6a4e, 0x58d5, 0x495c, 0x3de3, 0x2c6a, 0x1ef1, 0x0f78
};

unsigned short crc_16_l_calc(const uint8_t *buf_ptr, int len) {
        int data, crc_16;
        for (crc_16 = CRC_16_L_SEED; len >= 8; len -= 8, buf_ptr++) {
                crc_16 = crc_16_l_table[(crc_16 ^ *buf_ptr) & 0x00ff] ^ (crc_16 >> 8);
        }
        if (len != 0) {

                data = ((int) (*buf_ptr)) << (16 - 8);

                while (len-- != 0) {
                        if (((crc_16 ^ data) & 0x01) != 0) {

                                crc_16 >>= 1;
                                crc_16 ^= CRC_16_L_POLYNOMIAL;

                        } else {

                                crc_16 >>= 1;

                        }

                        data >>= 1;
                }
        }
        return (~crc_16);
}

static uint16_t diag_qsr4_append_crc16(uint8_t *buf_ptr, int len)
{
    uint16_t crc = crc_16_l_calc(buf_ptr, len*8);

    buf_ptr[len++] = crc&0xFF;
    buf_ptr[len++] = (crc>>8)&0xFF;
    buf_ptr[len++] = 0x7E;

    return len;
}

static const char *guid_file_name(const uint8_t *guid)
{
    static char read_buf[128];
    GUID*  guid_val = (GUID *)guid;

    snprintf(read_buf, 100, "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x.qdb", qlog_le32(guid_val->data1),
    	       qlog_le16(guid_val->data2), qlog_le16(guid_val->data3), guid_val->data4[0], guid_val->data4[1],
    	       guid_val->data4[2], guid_val->data4[3], guid_val->data4[4], guid_val->data4[5],
    	       guid_val->data4[6], guid_val->data4[7]);

    return read_buf;
}

static int diag_send_data(unsigned char buf[], size_t bytes)
{
    size_t i, size = 0;
    unsigned char *dst = &qsr4_db_cmd_req_buf[bytes];

    bytes -= 1; //skip 0x7E
    for (i = 0; i < bytes; i++) {
        uint8_t ch = buf[i];

        if (ch == 0x7E || ch == 0x7D) {
            dst[size++] = 0x7D;
            dst[size++] = (0x20 ^ ch);
        } else {
            dst[size++] = ch;
        }
    }
    dst[size++] = 0x7E;

    if (dm_fd != -1) {
        if (qlog_exit_requested)
            return qlog_poll_write(dm_fd, dst, size, 1000);
        else
            return mdm_send_cmd(dm_fd, dst, size, 1);
    }

    return 0;
}

static int diag_qsr4_get_cmd_code_for_peripheral(int peripheral)
{
    switch (peripheral) {
    case DIAG_MODEM_PROC:
    	return DIAGDIAG_QSR4_FILE_OP_MODEM;
    default:
    	return -1;
    }
}

static int diag_query_pd_name(const char *process_name, const char *search_str)
{
	if (!process_name)
		return -EINVAL;

	if (strstr(process_name, search_str))
		return 1;

	return 0;
}

static int diag_query_pd(const char *process_name)
{
	if (!process_name)
		return -EINVAL;

	if (diag_query_pd_name(process_name, "APPS"))
		return DIAG_APPS_PROC;
	if (diag_query_pd_name(process_name, "Apps"))
		return DIAG_APPS_PROC;
	if (diag_query_pd_name(process_name, "modem/root_pd"))
		return DIAG_MODEM_PROC;

	return -EINVAL;
}

static diag_id_list *get_diag_id(int peripheral)
{
    diag_id_list *item = NULL;
    uint8_t i;

    for (i = 0; i < diag_id_count; i++) {
        item = &diag_id_table[i];

        if ((peripheral == item->peripheral) && diag_query_pd_name(item->process_name, "root"))
            return item;
    }

    return NULL;
}

static void insert_diag_qsr4_db_guid_to_list(qshrink4_file_info* db_file_info, int peripheral) {
    diag_id_list *item = NULL;
    qshrink4_header *qshrink4_data_ptr;
    uint32_t guid_list_entry_count;

    qshrink4_data_ptr = &qshrink4_data;
    guid_list_entry_count = qlog_le32(qshrink4_data_ptr->guid_list_entry_count);

    if (guid_list_entry_count >= MAX_GUID_ENTRIES)
        return;

    memcpy(&qshrink4_data_ptr->guid[guid_list_entry_count], db_file_info->guid, GUID_LEN);
    qshrink4_data_ptr->guid_file_len[guid_list_entry_count] = qlog_le32(db_file_info->file_len);

    item = get_diag_id(peripheral);
    if (item) {
        diagid_guid[guid_list_entry_count].diag_id = item->diag_id;
        strncpy(diagid_guid[guid_list_entry_count].process_name, item->process_name, 30);
    }
    memcpy(&diagid_guid[guid_list_entry_count].guid, db_file_info->guid, GUID_LEN);

    guid_list_entry_count++;
    qshrink4_data_ptr->guid_list_entry_count = qlog_le32(guid_list_entry_count);
}

static int diag_send_qsr4_db_file_list_cmd_req(int peripheral)
{
    unsigned char* ptr = qsr4_db_cmd_req_buf;
    diag_qsr_header_req* req = NULL;

    if (diag_qsr4_get_cmd_code_for_peripheral(peripheral) == -1)
        return 0;

    qlog_dbg("%s peripheral=%d\n", __func__, peripheral);

    cur_peripheral = peripheral;

    req = (diag_qsr_header_req*)ptr;

    req->cmd_code = DIAG_SUBSYS_CMD_VER_2_F;
    req->subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->subsys_cmd_code = qlog_le16(diag_qsr4_get_cmd_code_for_peripheral(peripheral));
    req->version = qlog_le16(1);
    req->opcode = qlog_le16(DIAGDIAG_FILE_LIST_OPERATION);

    parser_state = DB_PARSER_STATE_OPEN;
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(diag_qsr_header_req)));
    parser_state = 0;

    return 0;
}

static void process_qsr4_db_file_list_response(const uint8_t *buf, size_t size)
{
    diag_qsr_file_list_rsp *list_rsp = (diag_qsr_file_list_rsp*)buf;
    uint8_t i;

    (void)size;
    if (list_rsp->status == 0) {
        for (i = 0; i < list_rsp->num_files; i++) {
            if (qlog_le32(list_rsp->info[i].file_len)) {
                qlog_dbg("guid: len = %u, name = %s\n", qlog_le32(list_rsp->info[i].file_len), guid_file_name(list_rsp->info[i].guid));
                insert_diag_qsr4_db_guid_to_list(&list_rsp->info[i], cur_peripheral);
            }
        }
    }
    else {
        qlog_dbg("%s status %d\n", __func__, list_rsp->status);
    }
}

static int diag_send_qsr4_file_open_cmd_req(int idx)
{
    unsigned char* ptr = qsr4_db_cmd_req_buf;
    diag_qsr_file_open_req* req_ptr;

    qlog_dbg("%s idx=%d\n", __func__, idx);

    req_ptr = (diag_qsr_file_open_req*)ptr;
    req_ptr->req.cmd_code = DIAG_SUBSYS_CMD_VER_2_F;
    req_ptr->req.subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req_ptr->req.subsys_cmd_code = qlog_le16(diag_qsr4_get_cmd_code_for_peripheral(cur_peripheral));
    req_ptr->req.version = qlog_le16(1);
    req_ptr->req.opcode = qlog_le16(DIAGDIAG_FILE_OPEN_OPERATION);
    memcpy(req_ptr->guid, qshrink4_data.guid[idx], GUID_LEN);

    read_file_total_len = 0;
    read_file_fd = -1;
    parser_state = DB_PARSER_STATE_OPEN;
    diag_send_data(qsr4_db_cmd_req_buf, diag_qsr4_append_crc16(ptr, sizeof(diag_qsr_file_open_req)));
    parser_state = 0;

    if (read_file_fd != -1) {
        read_file_total_len = qlog_le32(qshrink4_data.guid_file_len[idx]);
        disk_file_fd = qlog_create_file_in_logdir(guid_file_name(qshrink4_data.guid[idx]));
    }

    return 0;
}

static void process_qsr_db_file_open_rsp(const uint8_t *buf, size_t size)
{
    diag_qsr_file_open_rsp *open_rsp = (diag_qsr_file_open_rsp*)buf;

    (void)size;
   if (open_rsp->status == 0)
    {
        qlog_dbg("open read_file_fd %d\n", qlog_le16(open_rsp->read_file_fd));
        read_file_fd = qlog_le16(open_rsp->read_file_fd);
    }
    else {
        qlog_dbg("%s status %d\n", __func__, open_rsp->status);
    }
}

static int diag_send_qsr4_file_close_send_req(int idx) {
    unsigned char* ptr = qsr4_db_cmd_req_buf;
    diag_qsr_file_close_req* req_ptr;

    qlog_dbg("%s idx=%d, read_file_fd=%d\n", __func__, idx, read_file_fd);

    if (read_file_fd == -1) {
        return 0;
    }

    if (disk_file_fd != -1) {
        qlog_logfile_close_qdb(disk_file_fd);   //qdb fd
        disk_file_fd = -1;
    }

    req_ptr = (diag_qsr_file_close_req*)ptr;
    req_ptr->req.cmd_code = DIAG_SUBSYS_CMD_VER_2_F;
    req_ptr->req.subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req_ptr->req.subsys_cmd_code = qlog_le16(DIAGDIAG_QSR4_FILE_OP_MODEM);
    req_ptr->req.version = qlog_le16(1);
    req_ptr->req.opcode = qlog_le16(DIAGDIAG_FILE_CLOSE_OPERATION);
    req_ptr->read_file_fd = qlog_le16(read_file_fd);

    parser_state = DB_PARSER_STATE_CLOSE;
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(diag_qsr_file_close_req)));
    parser_state = 0;
    read_file_fd = -1;

    return 0;
}

static void process_qsr_db_file_close_rsp(const uint8_t *buf, size_t size)
{
    diag_qsr_file_close_rsp *close_rsp = (diag_qsr_file_close_rsp*)buf;

    (void)size;
    if (qlog_le32(close_rsp->status) == 0)
    {
        qlog_dbg("close read_file_fd %d\n", qlog_le16(close_rsp->read_file_fd));
        if (read_file_fd == qlog_le16(close_rsp->read_file_fd)) {
            read_file_fd = -1;
        }
    }
    else {
        qlog_dbg("%s status %d\n", __func__, qlog_le16(close_rsp->status));
    }
}

static int diag_send_qsr4_file_read_cmd_req(unsigned int file_offset, int file_len)
{
    unsigned char* ptr = qsr4_db_cmd_req_buf;
    diag_qsr_file_read_req* req;

    if (read_file_fd == -1)
        return 0;

    if (file_offset >= read_file_total_len)
        return 0;

    if ((file_offset + file_len) > read_file_total_len) {
        file_len = read_file_total_len - file_offset;
    }

    if (diag_verbose || (file_offset == 0 || ((file_offset + file_len) == read_file_total_len)))
        qlog_dbg("%s offset=%08d, len=%d\n", __func__, file_offset, file_len);

    req = (diag_qsr_file_read_req*)ptr;
    req->req.cmd_code = DIAG_SUBSYS_CMD_VER_2_F;
    req->req.subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->req.subsys_cmd_code = qlog_le16(diag_qsr4_get_cmd_code_for_peripheral(cur_peripheral));
    req->req.version = qlog_le16(1);
    req->req.opcode = qlog_le16(DIAGDIAG_FILE_READ_OPERATION);
    req->read_file_fd = qlog_le16(read_file_fd);
    req->offset = qlog_le32(file_offset);
    req->req_bytes = qlog_le32(file_len);

    read_file_len = 0;
    parser_state = DB_PARSER_STATE_READ;
    skip_wakeup = 0;
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(diag_qsr_file_read_req)));
    parser_state = 0;
    skip_wakeup = 0;

    return read_file_len;
}

static void process_qsr_db_file_read_delayed_rsp(const uint8_t *buf, size_t size)
{
    diag_qsr_file_read_rsp *read_rsp = (diag_qsr_file_read_rsp *)buf;

    (void)size;
    if (read_rsp->status == 0) {
        uint32 num_read = qlog_le32(read_rsp->num_read);
        if (diag_verbose) qlog_dbg("%s offset=%08x, len=%d, rsp_cnt=%d\n", __func__, qlog_le32(read_rsp->offset), num_read , qlog_le16(read_rsp->rsp_cnt));
        if (num_read) {
            if (disk_file_fd != -1) {
                qlog_logfile_save(disk_file_fd, read_rsp->data, num_read);
            }
            read_file_len = num_read;
        }
        else {
            if (parser_state == DB_PARSER_STATE_READ) { skip_wakeup = 1; };
        }
    }
    else {
        qlog_dbg("%s status %d\n", __func__, read_rsp->status);
    }
}

static void insert_diag_id_entry(diag_id_entry_struct *entry)
{
    diag_id_list *new_entry;

    if (diag_id_count >= NUM_PROC)
        return;

    new_entry = &(diag_id_table[diag_id_count++]);

    new_entry->diag_id = entry->diag_id;
    strncpy(new_entry->process_name, entry->process_name, 30);
    new_entry->peripheral = diag_query_pd(new_entry->process_name);

    qlog_dbg("%s diag_id=%d, peripheral=%d, process_name=%s\n", __func__,
        new_entry->diag_id, new_entry->peripheral, new_entry->process_name);
}

static int diag_query_diag_id(void)
{
    unsigned char* ptr = qsr4_db_cmd_req_buf;
    diag_id_list_req* req = NULL;

    qlog_dbg("%s\n", __func__);

    req = (diag_id_list_req*)ptr;

    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->subsys_cmd_code = qlog_le16(DIAG_GET_DIAG_ID);
    req->version = 1;

    diag_id_state = 1;
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(diag_id_list_req)));
    diag_id_state = 0;

    return 0;
}

static void process_diag_id_response(const uint8_t *buf, size_t size) {
    diag_id_list_rsp *list_rsp = (diag_id_list_rsp*)buf;
    diag_id_entry_struct *diag_id_ptr;
    uint8_t i;

    (void)size;
    qlog_dbg("%s\n", __func__);

    if (list_rsp->cmd_code != DIAG_SUBSYS_CMD_F || list_rsp->version != 1) {
        qlog_dbg("error %d\n", __LINE__);
        return;
    }

    diag_id_ptr = &list_rsp->entry;
    for (i = 0; i < list_rsp->num_entries; i++) {
        insert_diag_id_entry(diag_id_ptr);
        diag_id_ptr = (diag_id_entry_struct *)(((uint8_t *)diag_id_ptr) + diag_id_ptr->len + sizeof(diag_id_entry_struct));
    }
}

void mdm_handle_data_for_command_rsp(const uint8_t *buf, size_t size) {
    if (diag_verbose && (diag_id_state || parser_state)) {
        char str[256]= " ";
        size_t i;
        for (i = 0; i < size && i < 40; i+=4) {
            snprintf(str+((i/4)*9), sizeof(str), "%02x%02x%02x%02x ", buf[i+0],buf[i+1],buf[i+2],buf[i+3]);
        }
        qlog_dbg("rsp=%zd, %s\n", size, str);
    }

    if (diag_id_state)
    {
        diag_id_list_rsp *rsp = (diag_id_list_rsp*)buf;

        if ((buf[0] == DIAG_BAD_CMD_F || buf[0] == DIAG_BAD_PARM_F || buf[0] == DIAG_BAD_LEN_F)
            && buf[1] == DIAG_SUBSYS_CMD_F && buf[2] == DIAG_SUBSYS_DIAG_SERV)
        {
            qlog_dbg("error %d, buf[0]=%d\n", __LINE__, buf[0] );
            return;
        }

        if (rsp->cmd_code == DIAG_SUBSYS_CMD_F && rsp->subsys_id == DIAG_SUBSYS_DIAG_SERV
            && qlog_le16(rsp->subsys_cmd_code) == DIAG_GET_DIAG_ID)
        {
            return process_diag_id_response(buf, size);
        }
    }else if (diag_disable_qtrace_state)
    {
        if ((buf[0] == DIAG_BAD_CMD_F || buf[0] == DIAG_BAD_PARM_F || buf[0] == DIAG_BAD_LEN_F)
            && buf[1] == DIAG_SUBSYS_CMD_F && buf[2] == DIAG_SUBSYS_LTE)
        {
            qlog_dbg("error %d, buf[0]=%d\n", __LINE__, buf[0] );
            diag_disable_qtrace_rsp = 0;
            return;
        }

        diag_disable_qtrace_rsp = 1;
    }
    else if (parser_state)
    {
        diag_qsr_header_rsp *rsp = (diag_qsr_header_rsp*)buf;

        if ((buf[0] == DIAG_BAD_CMD_F || buf[0] == DIAG_BAD_PARM_F || buf[0] == DIAG_BAD_LEN_F)
            && buf[1] == DIAG_SUBSYS_CMD_VER_2_F && buf[2] == DIAG_SUBSYS_DIAG_SERV) {
            qlog_dbg("error %d, buf[0]=%d\n", __LINE__, buf[0] );
            return;
        }

        if (rsp->cmd_code == DIAG_SUBSYS_CMD_VER_2_F && rsp->subsys_id == DIAG_SUBSYS_DIAG_SERV
            && qlog_le16(rsp->subsys_cmd_code) == DIAGDIAG_QSR4_FILE_OP_MODEM)
        {
            uint16_t opcode = qlog_le16(rsp->opcode);

            if (qlog_le16(rsp->version) != 1) {
                qlog_dbg("%s version %d\n", __func__, qlog_le16(rsp->version));
                return;
            }
            else if (opcode == DIAGDIAG_FILE_LIST_OPERATION) {
                return process_qsr4_db_file_list_response(buf, size);
            }
            else if (opcode == DIAGDIAG_FILE_OPEN_OPERATION) {
                return process_qsr_db_file_open_rsp(buf, size);
            }
            else if (opcode == DIAGDIAG_FILE_CLOSE_OPERATION) {
                return process_qsr_db_file_close_rsp(buf, size);
            }
            else if (opcode == DIAGDIAG_FILE_READ_OPERATION) {
                return process_qsr_db_file_read_delayed_rsp(buf, size);
            }
            else {
                qlog_dbg("opcode %04x\n", opcode);
            }
        }
    }
    else if (qdss_state) {
        diag_qdss_handle_response(buf, size);
    }
    else if (dpl_state) {
        diag_dpl_handle_response(buf, size);
    }
}

static void mdm_handle_diag_pkt_func(struct diag_pkt *diag_pkt) {
    if (g_mdm_req != -1) {
        pthread_mutex_lock(&diag_cmd_mutex);
        if ((diag_pkt->buf[0] == g_mdm_req)
            || ((diag_pkt->buf[0] == DIAG_BAD_PARM_F && diag_pkt->buf[1] == g_mdm_req))
            || ((diag_pkt->buf[0] == DIAG_BAD_CMD_F && diag_pkt->buf[1] == g_mdm_req))
        )
        {
            mdm_handle_data_for_command_rsp(diag_pkt->buf, diag_pkt->pkt_len);
            if ((parser_state == DB_PARSER_STATE_READ) && skip_wakeup)
                skip_wakeup = 0;
            else
                pthread_cond_signal(&diag_cmd_cond);
        }
        else {
            //qlog_dbg("rx %02x%02x%02x%02x\n", q[0], q[1], q[2], q[3]);
        }
        pthread_mutex_unlock(&diag_cmd_mutex);
    }
}

static void mdm_parse_data_for_command_rsp(const uint8_t *src_ptr, size_t src_length)
{
    if (diag_verbose) {
        char str[256] = " ";
        size_t i;
        for (i = 0; i < src_length && i < 40; i+=4) {
            snprintf(str+((i/4)*9), sizeof(str), "%02x%02x%02x%02x ", src_ptr[i+0],src_ptr[i+1],src_ptr[i+2],src_ptr[i+3]);
        }
        qlog_dbg("< %zd, %s\n", src_length, str);
    }

    if (mdm_diag_pkt) {
        diag_pkt_input(mdm_diag_pkt, src_ptr, src_length);
        }
}

static char cmd_disable_log_mask[] = { 0x73, 0, 0, 0, 0, 0, 0, 0};
static char cmd_disable_msg_mask[] = { 0x7D, 0x05, 0, 0, 0, 0, 0, 0};
static char cmd_disable_event_mask[] = { 0x60, 0};
static char cmd_disable_qtrace_mask[] = { 0x4B, 0x44, 0x01, 0x90, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

static void mdm_send_empty_mask(void)
{
    unsigned char* ptr = qsr4_db_cmd_req_buf;

    memcpy(ptr, cmd_disable_log_mask, sizeof(cmd_disable_log_mask));
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(cmd_disable_log_mask)));

    memcpy(ptr, cmd_disable_msg_mask, sizeof(cmd_disable_log_mask));
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(cmd_disable_log_mask)));

    memcpy(ptr, cmd_disable_event_mask, sizeof(cmd_disable_event_mask));
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(cmd_disable_event_mask)));

    diag_disable_qtrace_state = 1;
    diag_disable_qtrace_rsp = 0;
    int retry = 120;

    while (retry-- && qlog_exit_requested == 0)
    {
        memcpy(ptr, cmd_disable_qtrace_mask, sizeof(cmd_disable_qtrace_mask));
        diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(cmd_disable_qtrace_mask)));

        if (diag_disable_qtrace_rsp)
        {
            break;
        }
        usleep(500000);
    }
    diag_disable_qtrace_state = 0;

    if (retry == 0)
    {
        qlog_dbg("%s send cmd_disable_qtrace_mask failed\n", __func__);
    }
}

static void mdm_create_qshrink4_file(int fd) {
    //static int qshrink4_init = 0;

    if (qshrink4_init)
        return;
    qshrink4_init = 1;

    if (use_qmdl2_v2 && diag_id_count == 0) {
        uint8_t i;

        dm_fd = fd;
        mdm_send_empty_mask();
        diag_query_diag_id();

        for (i = 0; i < diag_id_count; i++) {
            diag_send_qsr4_db_file_list_cmd_req(diag_id_table[i].peripheral);
        }

        for (i = 0; i < qlog_le32(qshrink4_data.guid_list_entry_count); i++) {
            int read_len;
            unsigned int total_len = 0;

            size_t guid_file_len = qlog_get_filesize_in_logidr(guid_file_name(qshrink4_data.guid[i]));
            if (guid_file_len == qlog_le32(qshrink4_data.guid_file_len[i]))
                continue;

            diag_send_qsr4_file_open_cmd_req(i);
            do {
                read_len = diag_send_qsr4_file_read_cmd_req(total_len, MAX_QSR4_DB_FILE_READ_PER_RSP);
                total_len += read_len;
            } while (read_len == MAX_QSR4_DB_FILE_READ_PER_RSP);
            qlog_dbg("total_len = %u\n", total_len);
            diag_send_qsr4_file_close_send_req(i);
        }

        mdm_add_qshrink4_header();
    }
}

void mdm_reset_global_variables(void)
{
    diag_id_count = 0;
    qshrink4_init = 0;
    if (dm_fd != -1)
    {
        close(dm_fd);
        dm_fd = -1;
    }
}