#ifndef __DEVICE_H__
#define __DEVICE_H__

#include <stdint.h>

#define INVALIDEP 0xff

enum
{
    INTF_DIAG,
    INTF_CMD,
    INTF_DATA,
};

enum
{
    USB_MATCH_INTF,
    USB_MATCH_INTF_INFO,
};

#define USB_DEVICE_AND_INTF(type, vid, pid, ifno) \
    {                                             \
        USB_MATCH_INTF, type, vid, pid, ifno      \
    }

#define USB_DEVICE_AND_INTF_INFO(type, vid, pid, ifno, cls, scls, proto) \
    {                                                                    \
        USB_MATCH_INTF_INFO, type, vid, pid, ifno, cls, scls, proto      \
    }

typedef struct
{
    /**
     * DIAG port for Qualcomm chipset
     * COMMAND port for others
     */
    uint8_t com_port;
    uint8_t data_port;
} stintf;

typedef struct
{
    int match_flag;
    int intf_type;
    uint16_t idVendor;
    uint16_t idProduct;
    uint8_t nIntfNum;
    uint8_t bIntfClass;
    uint8_t bIntfSubClass;
    uint8_t bIntfProto;
} support_device;

#endif //__DEVICE_H__