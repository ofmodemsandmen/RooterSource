static const int diag_pkt_debug = 0;
struct diag_pkt;
typedef void (handle_pkt_func)(struct diag_pkt *diag_pkt);
struct diag_pkt {
    size_t max_pkt_len;
    size_t min_pkt_len;
    uint32_t start_7e;
    uint32_t last_7d;
    uint32_t errors;
    size_t pkt_len;
    handle_pkt_func *handle_pkt;
    uint8_t reserved[8];
    uint8_t buf[0];
};

static struct diag_pkt *diag_pkt_malloc(size_t min_size, size_t max_size, uint32_t start_7e, handle_pkt_func handle_pkt) {
    struct diag_pkt *diag_pkt = (struct diag_pkt *)malloc((max_size + min_size)*2);
    if (!diag_pkt)
        return NULL;

    diag_pkt->max_pkt_len =max_size;
    diag_pkt->min_pkt_len = min_size;
    diag_pkt->start_7e = start_7e;
    diag_pkt->last_7d = 0;
    diag_pkt->errors = 0;
    diag_pkt->pkt_len = 0;
    diag_pkt->handle_pkt = handle_pkt;

    return diag_pkt;
}

static void diag_pkt_input(struct diag_pkt *diag_pkt, const uint8_t *pSrc, size_t size) {
    size_t i;

    if (diag_pkt->last_7d) {
        if (diag_pkt->start_7e == 0 ||  diag_pkt->pkt_len) {
            diag_pkt->buf[diag_pkt->pkt_len++] = (*pSrc ^ 0x20);
        }
        else {
            diag_pkt->errors++;
            if (diag_pkt_debug) qlog_dbg("should get 0x7e here 1 !\n");
        }

        pSrc++;
        size--;
        diag_pkt->last_7d = 0;
    }

    for (i = 0; i < size; i++) {
        if (*pSrc == 0x7d) {
            pSrc++;
            i++;
            if (i == size) {
                if (diag_pkt_debug) qlog_dbg("last_7d\n");
                diag_pkt->last_7d = 1;
                break;
            }

            if (diag_pkt->start_7e == 0 ||  diag_pkt->pkt_len) {
                diag_pkt->buf[diag_pkt->pkt_len++] = (*pSrc++ ^ 0x20);
            }
            else {
                diag_pkt->errors++;
                if (diag_pkt_debug) qlog_dbg("should get 0x7e here 2 !\n");
            }
        }
        else if (*pSrc == 0x7E) {
            diag_pkt->buf[diag_pkt->pkt_len++] = (*pSrc++);

            if (diag_pkt->pkt_len >= diag_pkt->min_pkt_len) {
                static size_t max_pkt_size = 0;
                if (diag_pkt->pkt_len > max_pkt_size) {
                    max_pkt_size = diag_pkt->pkt_len;
                    if (diag_pkt_debug) qlog_dbg("max_pkt_size %zd\n", max_pkt_size);
                }
                diag_pkt->handle_pkt(diag_pkt);
                diag_pkt->pkt_len = 0;
            }
            else if (diag_pkt->start_7e && diag_pkt->pkt_len == 1) {
                //start of frame
            }
            else if (diag_pkt->start_7e && diag_pkt->pkt_len == 2) {
                diag_pkt->errors++;
                if (diag_pkt_debug) qlog_dbg("get 7e7e here!\n");
                diag_pkt->pkt_len = 1;
            }
            else {
                diag_pkt->errors++;
                if (diag_pkt_debug) qlog_dbg("two short pkt len %zd!\n", diag_pkt->pkt_len);
                diag_pkt->pkt_len = 0;
            }
        }
        else if (diag_pkt->start_7e && diag_pkt->pkt_len == 0) {
            diag_pkt->errors++;
            if (diag_pkt_debug) qlog_dbg("should get 0x7e here 3 !\n");
            pSrc++;
        }
        else {
            diag_pkt->buf[diag_pkt->pkt_len++] = (*pSrc++);
            if (diag_pkt->pkt_len > diag_pkt->max_pkt_len) {
                diag_pkt->errors++;
                if (diag_pkt_debug) qlog_dbg("two long pkt len %zd!\n", diag_pkt->pkt_len);
                diag_pkt->pkt_len = 0;
            }
        }
    }
}
