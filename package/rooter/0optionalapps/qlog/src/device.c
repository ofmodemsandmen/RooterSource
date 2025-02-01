#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/types.h>

#include "device.h"
#include "common.h"
#include "list.h"

typedef enum
{
    BULK_IN,
    BULK_OUT,
    INTR_IN,
} enEndpointType;

typedef struct
{
    uint32_t bIntfNum : 8;
    uint32_t bIntfClass : 8;
    uint32_t bIntfSubClass : 8;
    uint32_t bIntfProtocol : 8;
    uint8_t bBulkin;
    uint8_t bBulkout;
    const char *device; // ttyUSB, wwan0
    const char *driver;
    struct list_head list;
} usbintf;

typedef struct
{
    uint32_t busnum : 8;
    uint32_t devnum : 16;
    uint32_t bNumIntf : 8;

    uint32_t vid : 16;
    uint32_t pid : 16;

    const char *devpath;
    const char *usbdevpath;
    usbintf intfs;
    struct list_head list;
} usbdev;

#if 0
/**
 * Add more device here
 */
static support_device support_log_devices[] = {
    /* Qualcomm devices */
    USB_DEVICE_AND_INTF(INTF_DIAG, 0x2c7c, 0x0125, 0x00),

    /* device butt */
    {0, 0},
};

/**
 * Add more device here
 */
static support_device support_dump_devices[] = {
    /* Qualcomm devices */
    USB_DEVICE_AND_INTF(INTF_DIAG, 0x2c7c, 0x0125, 0x00),

    /* device butt */
    {0, 0},
};
#endif

static const char *file_get_first_line(const char *path)
{
    static char buf[1024] = {'\0'};
    FILE *fp = fopen(path, "r");
    ERR_RETURN(!fp, NULL, "%s", "");

    if (fgets(buf, sizeof(buf), fp))
    {
        buf[strlen(buf) - 1] = '\0';
        fclose(fp);
        return buf;
    }
    return NULL;
}

#define file_get_str(path) ({ const char *line = file_get_first_line(path); SAFETYSTR(line); })
#define file_get_int(path, invalid) ({ const char *line = file_get_first_line(path); line? atoi(line):invalid; })
#define file_get_xint(path, invalid) ({ const char *line = file_get_first_line(path); line? strtoul(line, NULL, 16):invalid; })

static const char *dir_get_child(const char *dirname, const char *prefix)
{
    struct dirent *entptr = NULL;
    DIR *dirptr = NULL;
    static char buf[1024];

    buf[0] = '\0';
    dirptr = opendir(dirname);
    ERR_RETURN(!dirptr, NULL, "%s", "");

    while ((entptr = readdir(dirptr)))
    {
        if (entptr->d_name[0] == '.')
            continue;

        if (!prefix || !strncasecmp(entptr->d_name, prefix, strlen(prefix)))
        {
            snprintf(buf, sizeof(buf), "%s", entptr->d_name);
            break;
        }
    }
    closedir(dirptr);

    return (buf[0] == '\0') ? NULL : buf;
}

static const char *usb_intf_get_driver_name(const char *devpath)
{
    static char linkname[1024] = {'\0'};
    int n = readlink(devpath, linkname, sizeof(linkname));
    if (n > 0 && n < sizeof(linkname))
    {
        linkname[n] = '\0';
        strcpy(linkname, rindex(linkname, '/') + 1);
    }
    else
    {
        linkname[0] = '\0';
    }

    return linkname;
}

static const char *usb_intf_find_device(const char *devpath)
{
    char path[256] = {'\0'};
    const char *dev = NULL;

    // tty or net
    dev = dir_get_child(devpath, "tty");
    if (!dev)
    {
        snprintf(path, sizeof(path), "%s/net", devpath);
        dev = dir_get_child(path, NULL);
    }

    return dev ? strdup(dev) : NULL;
}

/**
 * 0xff for not exist
 */
static uint8_t usb_intf_get_endpoint(const char *dirname, enEndpointType eptype)
{
    struct dirent *entptr = NULL;
    DIR *dirptr = NULL;
    char path[512] = {'\0'};
    uint32_t bEPAddr = INVALIDEP;

    dirptr = opendir(dirname);
    ERR_RETURN(!dirptr, INVALIDEP, "%s", "");

    while ((entptr = readdir(dirptr)))
    {
        char direction[512] = {'\0'};
        char type[512] = {'\0'};
        if (entptr->d_name[0] == '.')
            continue;

        if (strncasecmp(entptr->d_name, "ep_", 3))
            continue;

        snprintf(path, sizeof(path), "%s/%s/direction", dirname, entptr->d_name);
        snprintf(direction, sizeof(direction), "%s", file_get_str(path));
        if (direction[0] == '\0')
            continue;

        snprintf(path, sizeof(path), "%s/%s/type", dirname, entptr->d_name);
        snprintf(type, sizeof(type), "%s", file_get_str(path));
        if (type[0] == '\0')
            continue;

        if (!((eptype == BULK_OUT && !strncasecmp(direction, "out", 3) && !strncasecmp(type, "Bulk", 4)) ||
              (eptype == BULK_IN && !strncasecmp(direction, "in", 3) && !strncasecmp(type, "Bulk", 4)) ||
              (eptype == INTR_IN && !strncasecmp(direction, "in", 3) && !strncasecmp(type, "Interrupt", 4))))
            continue;

        snprintf(path, sizeof(path), "%s/%s/bEndpointAddress", dirname, entptr->d_name);
        bEPAddr = file_get_xint(path, INVALIDEP);
        break;
    }
    closedir(dirptr);

    return bEPAddr;
}

static void show_usb_devices(usbdev *usbdevices)
{
    usbdev *pos, *n;
    if (!usbdevices)
        return;

    list_for_each_entry_safe(pos, n, &usbdevices->list, list)
    {
        usbintf *intfpos, *intfn;
        LOG("Bus %03d Device %03d: ID %04x:%04x bNumInterfaces %02u devpath \"%s\",\"%s\"\n",
            pos->busnum, pos->devnum, pos->vid, pos->pid, pos->bNumIntf, pos->devpath, pos->usbdevpath);
        list_for_each_entry_safe(intfpos, intfn, &pos->intfs.list, list)
            LOG("  |__If %02u Cls=%02x, Sub=%02x, Prot=%02x BulkIn:%02x BulkOut:%02x Info=%s,%s\n",
                intfpos->bIntfNum, intfpos->bIntfClass, intfpos->bIntfSubClass, intfpos->bIntfProtocol,
                intfpos->bBulkin, intfpos->bBulkout, SAFETYSTR(intfpos->driver), SAFETYSTR(intfpos->device));
    }
}

static void free_usb_devices(usbdev *usbdevices)
{
    usbdev *pos, *n;
    if (!usbdevices)
        return;

    list_for_each_entry_safe(pos, n, &usbdevices->list, list)
    {
        usbintf *intfpos, *intfn;
        SAFETYFREE(pos->devpath);
        SAFETYFREE(pos->usbdevpath);
        list_for_each_entry_safe(intfpos, intfn, &pos->intfs.list, list)
        {
            SAFETYFREE(intfpos->device);
            SAFETYFREE(intfpos->driver);
            list_del(&intfpos->list);
            SAFETYFREE(intfpos);
        }
        list_del(&pos->list);
        SAFETYFREE(pos);
    }
}

static void scan_usb_intfs(usbintf *head, const char *devpath)
{
    struct dirent *entptr = NULL;
    DIR *dirptr = NULL;

    dirptr = opendir(devpath);
    ERR_RETURN(!dirptr, , "open %s fail for %s", devpath, strerror(errno));

    while ((entptr = readdir(dirptr)))
    {
        char path[512] = {'\0'};
        usbintf *intf = NULL;

        if (entptr->d_name[0] == '.')
            continue;

        intf = (usbintf *)malloc(sizeof(usbintf));
        memset(intf, 0, sizeof(usbintf));
        INIT_LIST_HEAD(&intf->list);
        intf->bBulkin = INVALIDEP;
        intf->bBulkout = INVALIDEP;

        snprintf(path, sizeof(path), "%s/%s/bInterfaceNumber", devpath, entptr->d_name);
        intf->bIntfNum = file_get_xint(path, 0);
        if (intf->bIntfNum == 0)
        {
            SAFETYFREE(intf);
            continue;
        }

        snprintf(path, sizeof(path), "%s/%s/bInterfaceClass", devpath, entptr->d_name);
        intf->bIntfClass = file_get_xint(path, 0);

        snprintf(path, sizeof(path), "%s/%s/bInterfaceSubClass", devpath, entptr->d_name);
        intf->bIntfSubClass = file_get_xint(path, 0);

        snprintf(path, sizeof(path), "%s/%s/bInterfaceProtocol", devpath, entptr->d_name);
        intf->bIntfProtocol = file_get_xint(path, 0);

        snprintf(path, sizeof(path), "%s/%s/driver", devpath, entptr->d_name);
        intf->driver = strdup(usb_intf_get_driver_name(path));

        snprintf(path, sizeof(path), "%s/%s", devpath, entptr->d_name);
        intf->device = usb_intf_find_device(path);

        intf->bBulkin = usb_intf_get_endpoint(path, BULK_IN);
        intf->bBulkout = usb_intf_get_endpoint(path, BULK_OUT);

        list_add_tail(&intf->list, &head->list);
    }
    closedir(dirptr);

    return;
}

static int scan_usb_devices(const char *rootdir)
{
    struct dirent *entptr = NULL;
    DIR *dirptr = NULL;
    usbdev usbdevices;

    memset(&usbdevices, 0, sizeof(usbdev));
    INIT_LIST_HEAD(&usbdevices.list);

    dirptr = opendir(rootdir);
    ERR_RETURN(!dirptr, ERR_FAIL, "open %s fail for %s", rootdir, strerror(errno));

    while ((entptr = readdir(dirptr)))
    {
        char path[512] = {'\0'};
        char devpath[512] = {'\0'};
        usbdev *dev = NULL;

        if (entptr->d_name[0] == '.' || !strncasecmp(entptr->d_name, "usb", 3))
            continue;

        snprintf(path, sizeof(path), "%s/%s/devpath", rootdir, entptr->d_name);
        snprintf(devpath, sizeof(devpath), "%s", file_get_str(path));
        if (devpath[0] == '\0')
            continue;

        dev = (usbdev *)malloc(sizeof(usbdev));
        memset(dev, 0, sizeof(usbdev));
        INIT_LIST_HEAD(&dev->intfs.list);
        dev->devpath = strdup(devpath);
        snprintf(path, sizeof(path), "%s/%s", rootdir, entptr->d_name);
        dev->usbdevpath = strdup(path);

        snprintf(path, sizeof(path), "%s/%s/busnum", rootdir, entptr->d_name);
        dev->busnum = file_get_int(path, 0);

        snprintf(path, sizeof(path), "%s/%s/devnum", rootdir, entptr->d_name);
        dev->devnum = file_get_int(path, 0);

        snprintf(path, sizeof(path), "%s/%s/idVendor", rootdir, entptr->d_name);
        dev->vid = file_get_xint(path, 0);

        snprintf(path, sizeof(path), "%s/%s/idProduct", rootdir, entptr->d_name);
        dev->pid = file_get_xint(path, 0);

        snprintf(path, sizeof(path), "%s/%s/bNumInterfaces", rootdir, entptr->d_name);
        dev->bNumIntf = file_get_int(path, 0);

        snprintf(path, sizeof(path), "%s/%s", rootdir, entptr->d_name);
        scan_usb_intfs(&dev->intfs, path);

        list_add_tail(&dev->list, &usbdevices.list);
    }
    closedir(dirptr);

    show_usb_devices(&usbdevices);
    free_usb_devices(&usbdevices);
    return 0;
}

/**
 * ➜  QLog（复件） cc device.c -g                  
 * ➜  QLog（复件） ./a.out 
 * Bus 001 Device 033: ID 0403:6001 bNumInterfaces 01 devpath 5.1
 * Bus 001 Device 003: ID 05e3:0610 bNumInterfaces 01 devpath 5
 * Bus 001 Device 069: ID 2c7c:0125 bNumInterfaces 05 devpath 1
 *   |__If 03 Cls=ff, Sub=00, Prot=00 BulkIn:86 BulkOut:04 Info=option,ttyUSB4
 *   |__If 01 Cls=ff, Sub=00, Prot=00 BulkIn:82 BulkOut:02 Info=option,ttyUSB2
 *   |__If 04 Cls=ff, Sub=ff, Prot=ff BulkIn:88 BulkOut:05 Info=qmi_wwan,wwp0s20f0u1i4
 *   |__If 02 Cls=ff, Sub=00, Prot=00 BulkIn:84 BulkOut:03 Info=option,ttyUSB3
 * Bus 002 Device 002: ID 05e3:0612 bNumInterfaces 01 devpath 4
 * Bus 001 Device 006: ID 413c:301a bNumInterfaces 01 devpath 8
 * Bus 001 Device 004: ID 413c:2113 bNumInterfaces 02 devpath 6
 *   |__If 01 Cls=03, Sub=00, Prot=00 BulkIn:ff BulkOut:ff Info=usbhid,
 */
int main()
{
    // valgrind test pass
    return scan_usb_devices("/sys/bus/usb/devices");
}
