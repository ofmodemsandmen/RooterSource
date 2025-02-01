#define SINK_USB		3
#define SINK_PCIE		8

#define DIAG_DIAG_STM				0x214
#define DIAG_QDSS_TRACE_SINK		0x101
#define DIAG_QDSS_FILTER_STM		0x103
#define DIAG_DIAG_HW_ACCEL_CMD		0x224
#define DIAG_DIAG_FEATURE_QUERY		0x225

#define DIAG_QDSS_FILTER_SWTRACE	0x06
#define DIAG_QDSS_FILTER_ENTITY		0x08

#define DIAG_QDSS_PROCESSOR_APPS	0x0100
#define DIAG_QDSS_PROCESSOR_MODEM	0x0200
#define DIAG_QDSS_PROCESSOR_WCNSS	0x0300
#define DIAG_QDSS_PROCESSOR_LPASS	0x0500
#define DIAG_QDSS_PROCESSOR_SENSOR	0x0800
#define DIAG_QDSS_PROCESSOR_CDSP	0x0d00
#define DIAG_QDSS_PROCESSOR_NPU		0x0e00

#define DIAG_STM_MODEM	0x01
#define DIAG_STM_LPASS	0x02
#define DIAG_STM_WCNSS	0x04
#define DIAG_STM_APPS	0x08
#define DIAG_STM_SENSORS 0x10
#define DIAG_STM_CDSP 0x20
#define DIAG_STM_NPU 0x40

#define ADPL_SUBSYS_CMD_CODE 16384

#define DIAG_HW_ACCEL_CMD	0x224

/*
 * HW Acceleration operation definition
 */
#define DIAG_HW_ACCEL_OP_DISABLE	0
#define DIAG_HW_ACCEL_OP_ENABLE	1
#define DIAG_HW_ACCEL_OP_QUERY	2

/*
 * HW Acceleration TYPE definition
 */
#define DIAG_HW_ACCEL_TYPE_ALL	0
#define DIAG_HW_ACCEL_TYPE_STM	1
#define DIAG_HW_ACCEL_TYPE_ATB	2
#define DIAG_HW_ACCEL_TYPE_MAX	2

#define DIAG_HW_ACCEL_VER_MIN 1
#define DIAG_HW_ACCEL_VER_MAX 1

typedef struct {
	diag_pkt_header_t header;
	uint8 version;
} __attribute__ ((packed))  diag_feature_query_req;

typedef struct {
	diag_pkt_header_t header;
	uint8 version;
	uint8 feature_len;
	uint8 feature_mask[4];
} __attribute__ ((packed)) diag_feature_query_rsp;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 version;
	uint8 processor_mask;
	uint8 stm_cmd;
}  __attribute__ ((packed)) diag_qdss_config_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 state;
}  __attribute__ ((packed)) diag_enable_qdss_tracer_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 state;
	uint8 entity_id;
}  __attribute__ ((packed)) diag_enable_qdss_diag_tracer_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 state;
}  __attribute__ ((packed)) diag_enable_qdss_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 dpl_version;
	uint8 agg_pkt_limit;
    uint16 agg_byte_limit;
    uint8 dpl_cmd;
    uint8 res[3];
}  __attribute__ ((packed)) diag_adpl_req;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 dpl_version;
    uint8 dpl_cmd;
}  __attribute__ ((packed)) diag_adpl_rsp;

typedef struct {
	uint8 cmd_code;
	uint8 subsys_id;
	uint16 subsys_cmd_code;
	uint8 sink;
}  __attribute__ ((packed)) diag_set_out_mode;

typedef struct {
    diag_pkt_header_t header;
    uint8 version;
    uint8 op;
    uint16 reserved;
    uint8 hw_accel_type;
    uint8 hw_accel_version;
} __attribute__ ((packed)) diag_hw_accel_query_cmd_req;

/*
 * hw acceleration query response sub payload
 * in mulitples of the num_accel_rsp
 */

typedef struct {
	uint8 hw_accel_type;
	uint8 hw_accel_ver;
	uint32 diagid_mask_supported;
	uint32 diagid_mask_enabled;
} __attribute__ ((packed)) diag_hw_accel_query_sub_payload_rsp_t;

/*
 * hw acceleration query operation response payload structure
 */
typedef struct {
	uint8 status;
	uint8 diag_transport;
	uint8 num_accel_rsp;
	diag_hw_accel_query_sub_payload_rsp_t
		sub_query_rsp[DIAG_HW_ACCEL_TYPE_MAX][DIAG_HW_ACCEL_VER_MAX];
} __attribute__ ((packed)) diag_hw_accel_query_rsp_payload_t;

/*
 * hw acceleration command query response structure
 */
typedef struct {
	diag_pkt_header_t header;
	uint8 version;
	uint8 operation;
	uint16 reserved;
	diag_hw_accel_query_rsp_payload_t query_rsp;
} __attribute__ ((packed)) diag_hw_accel_cmd_query_resp_t;

static unsigned char dpl_cmd_req_buf[50];

static unsigned char qdss_cmd_req_buf[50];
static int hw_accel_support[1][DIAG_HW_ACCEL_TYPE_MAX + 1];
static int hw_accel_query_state = 0;
static int peripheral_init = 0;
extern uint8 dpl_version;
extern int modem_is_pcie;

static int diag_set_etr_out_mode(int peripheral_type, int peripheral, uint8 sink) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_set_out_mode *req = (diag_set_out_mode *)ptr;

    (void)peripheral_type;
    (void)peripheral;
    qlog_dbg("%s sink = %d\n", __func__, sink);
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_QDSS;
    req->subsys_cmd_code = qlog_le16(DIAG_QDSS_TRACE_SINK);
    req->sink = sink;

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));

    return 0;
}

static int diag_send_enable_qdss_req(int peripheral_type, int peripheral, uint8 state) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_enable_qdss_req *req = (diag_enable_qdss_req *)ptr;

    (void)peripheral_type;
    (void)peripheral;
    qlog_dbg("%s state = %d\n", __func__, state);
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_QDSS;
    req->subsys_cmd_code = qlog_le16(DIAG_QDSS_FILTER_STM);
    req->state = state;

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));

    return 0;
}

static int diag_send_enable_dpl_req(int peripheral_type, int peripheral, int enable) {
    unsigned char *ptr = dpl_cmd_req_buf;
    diag_adpl_req *req = (diag_adpl_req *)ptr;

    (void)peripheral_type;
    (void)peripheral;
    uint16 agg_byte_limit = 15360;
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_DS_IPA;
    req->subsys_cmd_code = qlog_le16(ADPL_SUBSYS_CMD_CODE);
    req->dpl_version = 0xFF;
	req->agg_pkt_limit = 0x00;
	req->agg_byte_limit = qlog_le16(agg_byte_limit);
	if(enable)
		req->dpl_cmd = 0x01;
	else
		req->dpl_cmd = 0x00;
	memset(req->res, 0x00, sizeof(req->res));

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));

    return 0;
}

static int diag_set_diag_transport(int peripheral_type, int peripheral, uint8 stm_cmd) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_qdss_config_req *req = (diag_qdss_config_req *)ptr;

    (void)peripheral_type;
    qlog_dbg("%s peripheral = %d, stm_cmd = %d\n", __func__, peripheral, stm_cmd);
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->subsys_cmd_code = qlog_le16(DIAG_DIAG_STM);
    req->version = 2;
    switch (peripheral) {
    case DIAG_MODEM_PROC :
    	req->processor_mask = DIAG_STM_MODEM;
    	break;
    case DIAG_APPS_PROC :
    	req->processor_mask = DIAG_STM_APPS;
    	break;
    default:
        return 0;
    break;
    }
    req->stm_cmd = stm_cmd;

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));
    return 0;
}

static int diag_set_diag_qdss_diag_tracer(int peripheral_type, int peripheral, uint8 state) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_enable_qdss_tracer_req *req = (diag_enable_qdss_tracer_req *)ptr;

    (void)peripheral_type;
    qlog_dbg("%s peripheral = %d, state = %d\n", __func__, peripheral, state);
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_QDSS;
    req->subsys_cmd_code = DIAG_QDSS_FILTER_SWTRACE;
    req->state = state;

    switch (peripheral) {
        case DIAG_APPS_PROC :
        	req->subsys_cmd_code += DIAG_QDSS_PROCESSOR_APPS;
        	break;
        case DIAG_MODEM_PROC :
        	req->subsys_cmd_code += DIAG_QDSS_PROCESSOR_MODEM;
        	break;
           default:
                return 0;
            break;
    }

    req->subsys_cmd_code = qlog_le16(req->subsys_cmd_code);
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));
    return 0;
}

static int diag_set_diag_qdss_tracer(int peripheral_type, int peripheral, uint8 state) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_enable_qdss_diag_tracer_req *req = (diag_enable_qdss_diag_tracer_req *)ptr;

    (void)peripheral_type;
    qlog_dbg("%s peripheral = %d, state = %d\n", __func__, peripheral, state);
    req->cmd_code = DIAG_SUBSYS_CMD_F;
    req->subsys_id = DIAG_SUBSYS_QDSS;
    req->subsys_cmd_code = DIAG_QDSS_FILTER_ENTITY;
    req->state = state;
    req->entity_id = 0x0D;

	switch (peripheral) {
	case DIAG_APPS_PROC :
		req->subsys_cmd_code += DIAG_QDSS_PROCESSOR_APPS;
		break;
	case DIAG_MODEM_PROC :
		req->subsys_cmd_code += DIAG_QDSS_PROCESSOR_MODEM;
		break;
       default:
            return 0;
            break;
       }

    req->subsys_cmd_code = qlog_le16(req->subsys_cmd_code);
    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));
    return 0;
}

static int diag_qdss_query_hw_accel(int peripheral_type) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_hw_accel_query_cmd_req *req = (diag_hw_accel_query_cmd_req *)ptr;

    (void)peripheral_type;
    qlog_dbg("%s\n", __func__);
    req->header.cmd_code = DIAG_SUBSYS_CMD_F;
    req->header.subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->header.subsys_cmd_code = qlog_le16(DIAG_HW_ACCEL_CMD);
    req->version = 1;
    req->op = DIAG_HW_ACCEL_OP_QUERY;
    req->reserved = 0;
    req->hw_accel_type = DIAG_HW_ACCEL_TYPE_ALL;
    req->hw_accel_version = DIAG_HW_ACCEL_VER_MAX;

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));

    return 0;
}

int process_diag_hw_accel_query_rsp(int peripheral_type, const uint8_t *buf_ptr)
{
    diag_hw_accel_cmd_query_resp_t *rsp = NULL;
    int i;
    int mask = 0;

    if (buf_ptr[0] == DIAG_BAD_CMD_F)
    	return 0;
    else {
    	rsp = (diag_hw_accel_cmd_query_resp_t*)buf_ptr;
    	if ((rsp->version != 1) || (qlog_le16(rsp->header.subsys_cmd_code) != DIAG_HW_ACCEL_CMD)) {
    		return 0;
    	}
    	//trace_sink[peripheral_type] = rsp->query_rsp.diag_transport;
    	for (i = DIAG_HW_ACCEL_TYPE_STM; i <= DIAG_HW_ACCEL_TYPE_MAX; i++) {
            uint32 diag_id_hw_accel_mask = 0x7fffffff;
            uint32 diagid_mask_supported = qlog_le32(rsp->query_rsp.sub_query_rsp[i-1][DIAG_HW_ACCEL_VER_MAX - 1].diagid_mask_supported);
            hw_accel_support[peripheral_type][i] = diag_id_hw_accel_mask & diagid_mask_supported;
    	}
    	return mask;
    }

    return 0;
}

static int diag_send_enable_hw_accel_req(int peripheral_type, int peripheral, /*int diag_id,
					int hw_accel_type, int hw_accel_ver, */uint8 state) {
    //nerver come here
    (void)peripheral_type;
    (void)peripheral;
    (void)state;
    return 0;
}

static int diag_qdss_query_feature_mask(int peripheral_type) {
    unsigned char *ptr = qdss_cmd_req_buf;
    diag_feature_query_req *req = (diag_feature_query_req *)ptr;

    (void)peripheral_type;
    qlog_dbg("%s\n", __func__);
    req->header.cmd_code = DIAG_SUBSYS_CMD_F;
    req->header.subsys_id = DIAG_SUBSYS_DIAG_SERV;
    req->header.subsys_cmd_code = qlog_le16(DIAG_DIAG_FEATURE_QUERY);
    req->version = 1;

    diag_send_data(ptr, diag_qsr4_append_crc16(ptr, sizeof(*req)));

    return 0;
}

int diag_send_cmds_to_peripheral_init(int peripheral_type, int pd)
{
    uint8 sink;
    if (modem_is_pcie)
        sink = SINK_PCIE;
    else
        sink = SINK_USB;
    
    qlog_dbg("%s modem_is_pcie = %d\n", __func__, modem_is_pcie);
    int peripheral = DIAG_MODEM_PROC;
    int retry = 0;
	
    (void)pd;
	
    for (retry=0;retry<10;retry++)      //Repeat sending until sending succeeds(module to be ready)
    {
        peripheral_init = 1;
        diag_qdss_query_feature_mask(peripheral_type);
        diag_set_etr_out_mode(peripheral_type, peripheral, sink);

        hw_accel_query_state = 1;
        diag_qdss_query_hw_accel(peripheral_type);
        hw_accel_query_state = 0;
        if (hw_accel_support[peripheral_type][DIAG_HW_ACCEL_TYPE_ATB] ||
            hw_accel_support[peripheral_type][DIAG_HW_ACCEL_TYPE_STM]) {
            diag_send_enable_hw_accel_req(peripheral_type, peripheral, 1);
            return 0;
        }

        diag_send_enable_qdss_req(peripheral_type, peripheral, 1);
        diag_set_diag_qdss_tracer(peripheral_type, peripheral, 1);
        diag_set_diag_qdss_diag_tracer(peripheral_type, peripheral, 1);
        diag_set_diag_transport(peripheral_type, peripheral, 1);

        sleep(1);  //wait reponse peripheral_init

        if (peripheral_init == 1)
        {
            qlog_dbg("%s send init cmds success\n", __func__);
            break;
        }
    }

    return 0;
}

int diag_send_cmds_to_peripheral_kill(int peripheral_type, int pd)
{
    int peripheral = DIAG_MODEM_PROC;

    (void)pd;
    if (hw_accel_support[peripheral_type][DIAG_HW_ACCEL_TYPE_ATB] ||
		hw_accel_support[peripheral_type][DIAG_HW_ACCEL_TYPE_STM]) {
        diag_send_enable_hw_accel_req(peripheral_type, peripheral, 0);
        return 0;
    }

    diag_set_diag_transport(peripheral_type, peripheral, 0);
    diag_set_diag_qdss_diag_tracer(peripheral_type, peripheral, 0);
    diag_set_diag_qdss_tracer(peripheral_type, peripheral, 0);
    diag_send_enable_qdss_req(peripheral_type, peripheral, 0);

    // jerry.meng
    // if this process exits too fast, the req sent by diag_send_enable_qdss_req() won't be recieved properly by the device
    // It causes the device keeping active and can't sleep.
    sleep(1);

    return 0;
}

int diag_qdss_handle_response(const uint8_t *buf, size_t size) {
    diag_pkt_header_t *rsp = (diag_pkt_header_t *)buf;

    (void)size;
    if (rsp->cmd_code == DIAG_BAD_CMD_F || rsp->cmd_code == DIAG_BAD_PARM_F) {
        qlog_dbg("DIAG_BAD %02x\n", buf[0]);
        if (hw_accel_query_state != 1)
            peripheral_init = 0;
    }

    if (rsp->cmd_code == DIAG_SUBSYS_CMD_F && rsp->subsys_id == DIAG_SUBSYS_QDSS) {
        if (qlog_le16(rsp->subsys_cmd_code) == DIAG_QDSS_TRACE_SINK
            || qlog_le16(rsp->subsys_cmd_code) == DIAG_QDSS_FILTER_STM) {
            //printf("status = %02x\n", buf[sizeof(diag_pkt_header_t)]);
        }
        else if (qlog_le16(rsp->subsys_cmd_code) == DIAG_HW_ACCEL_CMD) {
            if ( hw_accel_query_state == 1) {
                process_diag_hw_accel_query_rsp(0, buf);
            }
        }
    }
    else if (rsp->cmd_code == DIAG_SUBSYS_CMD_F && rsp->subsys_id == DIAG_SUBSYS_DIAG_SERV) {
        if (qlog_le16(rsp->subsys_cmd_code) == DIAG_DIAG_STM) {
        }
    }

    return 0;
}

int diag_dpl_handle_response(const uint8_t *buf, size_t size) {
    diag_adpl_rsp *rsp = (diag_adpl_rsp *)buf;

    (void)size;
    if (rsp->cmd_code == DIAG_BAD_CMD_F || rsp->cmd_code == DIAG_BAD_PARM_F) {
        qlog_dbg("DIAG_BAD %02x\n", buf[0]);
    }

    if (rsp->cmd_code == DIAG_SUBSYS_CMD_F && rsp->subsys_id == DIAG_SUBSYS_DS_IPA) {
        if (rsp->dpl_cmd == 1)
        {
            dpl_version = rsp->dpl_version;
            //printf("%s rsp->dpl_version:%d\n", __func__, rsp->dpl_version);
        }
    }

    return 0;
}
