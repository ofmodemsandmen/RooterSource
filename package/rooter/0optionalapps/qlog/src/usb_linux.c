#include "qlog.h"
#include "getopt.h"
#include <sys/statfs.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

extern char g_platform_choice[16];
extern int qlog_ignore_exx00u_ap;
extern char modem_name_para[32];
extern int qlog_read_nmea_log;

struct ql_usb_device_info s_usb_device_info[MAX_USB_DEV];

struct usbfs_getdriver
{
    unsigned int interface;
    char driver[256];
};

struct usbfs_ioctl
{
    int ifno;       /* interface 0..N ; negative numbers reserved */
    int ioctl_code; /* MUST encode size + direction of data so the
			 * macros in <asm/ioctl.h> give correct values */
    void *data;     /* param buffer (in, or out) */
};

#define IOCTL_USBFS_DISCONNECT _IO('U', 22)
#define IOCTL_USBFS_CONNECT _IO('U', 23)

static int usbfs_is_kernel_driver_alive(int fd, int ifnum)
{
    struct usbfs_getdriver getdrv;
    getdrv.interface = ifnum;
    if (ioctl(fd, USBDEVFS_GETDRIVER, &getdrv) < 0)
    {
        if (errno != ENODATA)
            qlog_dbg("%s ioctl USBDEVFS_GETDRIVER on interface %d failed, kernel driver may be inactive\n", __func__, ifnum);
        return 0;
    }
    qlog_dbg("%s find interface %d has match the driver %s\n", __func__, ifnum, getdrv.driver);
    return 1;
}

static void usbfs_detach_kernel_driver(int fd, int ifnum)
{
    struct usbfs_ioctl operate;
    operate.data = NULL;
    operate.ifno = ifnum;
    operate.ioctl_code = IOCTL_USBFS_DISCONNECT;
    if (ioctl(fd, USBDEVFS_IOCTL, &operate) < 0)
        qlog_dbg("%s detach kernel driver failed\n", __func__);
    else
        qlog_dbg("%s detach kernel driver success\n", __func__);
}

static int get_value_from_file(const char *fname, int base)
{
    char buff[64] = {'\0'};

    int fd = open(fname, O_RDONLY);
    if (fd <= 0)
    {
        if (errno != ENOENT)
            qlog_dbg("Fail to open %s,  errno: %d (%s)\n", fname, errno, strerror(errno));
        return -1;
    }
    if (read(fd, buff, sizeof(buff)) == -1) {
    }
    close(fd);
    return strtoul(buff, NULL, base);
}

static int strStartsWith(const char *line, const char *prefix)
{
    for ( ; *line != '\0' && *prefix != '\0' ; line++, prefix++) {
        if (*line != *prefix) {
            return 0;
        }
    }

    return *prefix == '\0';
}

static const char *get_value_from_uevent(const char *uevent,  const char *key) {
    FILE *fp;
    static char line[256];

    fp = fopen(uevent, "r");
    if (fp == NULL) {
        qlog_dbg("fail to fopen %s, errno: %d (%s)\n", uevent, errno, strerror(errno));
        return "-1";
    }

    //dbg_time("%s\n", uevent);
    while (fgets(line, sizeof(line), fp)) {
        if (line[strlen(line) - 1] == '\n' || line[strlen(line) - 1] == '\r') {
            line[strlen(line) - 1] = '\0';
        }

        //dbg_time("%s\n", line);
        if (strStartsWith(line, key) && line[strlen(key)] == '=') {
            fclose(fp);
            return &line[strlen(key)+1];
        }
    }

    fclose(fp);

    return "-1";
}

static void ql_get_dm_major_and_minor(const char *devname, struct ql_usb_device_info *ql_dev)
{
    char devpath[256];

    if(devname[0] == '\0')
        return;

    snprintf(devpath, sizeof(devpath), "/sys/class/tty/%.27s/uevent", devname + strlen("/dev/"));
    if(access(devpath, F_OK) && errno == ENOENT)
        return;

    ql_dev->dm_major = atoi(get_value_from_uevent(devpath, "MAJOR"));
    ql_dev->dm_minor = atoi(get_value_from_uevent(devpath, "MINOR"));
}

int ql_match_dm_device(const char *devname, struct ql_usb_device_info *ql_dev)
{
    struct stat buf;

    if (!stat(devname, &buf) && (int)major(buf.st_rdev) == ql_dev->dm_major && (int)minor(buf.st_rdev) == ql_dev->dm_minor) {
        snprintf(ql_dev->ttyDM, sizeof(ql_dev->ttyDM), "%.31s", devname);
        return 0;
    }

    return 1;
}

static void ql_find_usb_interface_info(const char *intfpath, struct ql_usb_interface_info *pIntf)
{
    DIR *dev_dir = NULL;
    struct dirent *dev = NULL;
    char devpath[256+32];

    dev_dir = opendir(intfpath);
    if (!dev_dir) {
        qlog_dbg("fail to opendir('%s'), errno: %d (%s)\n", intfpath, errno, strerror(errno));
        return;
    }

    while (NULL != (dev = readdir(dev_dir)))
    {
        if (!strncasecmp(dev->d_name, "ep_", 3)) {
            int ep = strtoul(&dev->d_name[3], NULL, 16);
            if (ep&0x80)
                pIntf->ep_in = ep;
            else
                 pIntf->ep_out = ep;
       }
    }

    closedir(dev_dir);

    snprintf(devpath, sizeof(devpath), "%.256s/bInterfaceClass", intfpath);
    pIntf->bInterfaceClass = get_value_from_file(devpath, 16);

    snprintf(devpath, sizeof(devpath), "%.256s/bInterfaceSubClass", intfpath);
    pIntf->bInterfaceSubClass = get_value_from_file(devpath, 16);

    snprintf(devpath, sizeof(devpath), "%.256s/bInterfaceProtocol", intfpath);
    pIntf->bInterfaceProtocol = get_value_from_file(devpath, 16);

    snprintf(devpath, sizeof(devpath), "%.256s/bNumEndpoints", intfpath);
    pIntf->bNumEndpoints = get_value_from_file(devpath, 16);

#if 0
    qlog_dbg("Interface Class: %02x, SubClass: %02x, Protocol: %02x\n",
        pIntf->bInterfaceClass, pIntf->bInterfaceSubClass, pIntf->bInterfaceProtocol);
    qlog_dbg("NumEndpoints: %d, ep_in: %02x, ep_out: %02x\n", pIntf->bNumEndpoints, pIntf->ep_in, pIntf->ep_out);
#endif
}

static void ql_find_tty_info(const char *intfpath, char *ttyport, size_t len)
{
    DIR *dev_dir = NULL;
    struct dirent *dev = NULL;
    char devpath[256];
    int wait_tty_register = 10;

    ttyport[0] = '\0';

_scan_tty:
    // find tty device
    dev_dir = opendir(intfpath);
    if (!dev_dir) {
        qlog_dbg("fail to opendir('%s'), errno: %d (%s)\n", intfpath, errno, strerror(errno));
        return;
    }

    while (NULL != (dev = readdir(dev_dir)))
    {
        if (!strncasecmp(dev->d_name, "tty", 3)) {
            snprintf(ttyport, len, "/dev/%.16s", dev->d_name);
            break;
        }
    }

    closedir(dev_dir);

    if (!strcmp(ttyport, "/dev/tty")) { //find tty not ttyUSBx or ttyACMx
        snprintf(devpath, sizeof(devpath), "%.128s/tty", intfpath);

        dev_dir = opendir(devpath);
        if (dev_dir)
        {
            while (NULL != (dev = readdir(dev_dir)))
            {
                if (!strncasecmp(dev->d_name, "tty", 3))
                {
                        snprintf(ttyport, len, "/dev/%.16s", dev->d_name);
                        break;
                }
            }
            closedir(dev_dir);
        }
    }

    if (ttyport[0] == '\0' && wait_tty_register) {
        usleep(100*1000); //maybe other files not ready
        wait_tty_register--;
        goto _scan_tty;
    }
}

int ql_find_quectel_modules(void)
{
    DIR *usb_dir = NULL;
    struct dirent *usb = NULL;
    const char *usbpath = "/sys/bus/usb/devices";
    struct ql_usb_device_info ql_dev;
    int modules_num = 0;

    usb_dir = opendir(usbpath);
    if (NULL == usb_dir)
        return modules_num;

    while (NULL != (usb = readdir(usb_dir)))
    {
        char devpath[256] = {'\0'};
        if (usb->d_name[0] == '.' || usb->d_name[0] == 'u')
            continue;

        memset(&ql_dev, 0, sizeof(struct ql_usb_device_info));

        snprintf(devpath, sizeof(devpath), "%.24s/%.16s/idVendor", usbpath, usb->d_name);
        ql_dev.idVendor = get_value_from_file(devpath, 16);

        snprintf(devpath, sizeof(devpath), "%.24s/%.16s/idProduct", usbpath, usb->d_name);
        ql_dev.idProduct = get_value_from_file(devpath, 16);

        if ((ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93)
            || (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff))
        {
            if (!modem_name_para[0])
            {
                printf("The state grid module needs to specify the module, like -g EC200T\n");
                return modules_num;
            }
        }

        if ((ql_dev.idVendor == 0x05c6 && ql_dev.idProduct == 0x9003) //UC15
            || (ql_dev.idVendor == 0x05c6 && ql_dev.idProduct == 0x9090) //UC20
            || (ql_dev.idVendor == 0x05c6 && ql_dev.idProduct == 0x9215) //EC20
            || (ql_dev.idVendor == 0x05c6 && ql_dev.idProduct == 0x90db) //sdx12
            || (ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93) //GW qualcomm
            || (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff) //GW qualcomm
            || drv_is_unisoc(ql_dev.idProduct,ql_dev.idVendor) //RG500U
            || drv_is_unisoc_exx00u(ql_dev.idProduct,ql_dev.idVendor) //ECx00U or EGx00U
            || drv_is_mtk(ql_dev.idProduct,ql_dev.idVendor) //RM500K
            || drv_is_eigen(ql_dev.idProduct,ql_dev.idVendor) //EIGENCOMM
            || drv_is_asr(ql_dev.idProduct, ql_dev.idVendor)
            || (ql_dev.idVendor == 0x2c7c && (ql_dev.idProduct&0xF000) == 0x0000) //mdm
            )
        {
        }
        else {
            continue;
        }

        usleep(100*1000); //maybe other files not ready

        snprintf(devpath, sizeof(devpath), "%.24s/%.16s/bNumInterfaces", usbpath, usb->d_name);
        ql_dev.bNumInterfaces = get_value_from_file(devpath, 10);

        snprintf(devpath, sizeof(devpath), "%.24s/%.16s/uevent", usbpath, usb->d_name);
        ql_dev.major = atoi(get_value_from_uevent(devpath, "MAJOR"));
        ql_dev.minor = atoi(get_value_from_uevent(devpath, "MINOR"));
        ql_dev.busnum = atoi(get_value_from_uevent(devpath, "BUSNUM"));
        ql_dev.devnum = atoi(get_value_from_uevent(devpath, "DEVNUM"));
        strncpy(ql_dev.devname, get_value_from_uevent(devpath, "DEVNAME"), sizeof(ql_dev.devname));

        snprintf(devpath, sizeof(devpath), "%s/%.16s/bcdDevice", usbpath, usb->d_name);
        ql_dev.bcdDevice = get_value_from_file(devpath, 10);

        memset(&ql_dev.dm_intf, 0xff, sizeof(struct ql_usb_interface_info));
        memset(&ql_dev.general_intf, 0xff, sizeof(struct ql_usb_interface_info));
        memset(&ql_dev.third_intf, 0xff, sizeof(struct ql_usb_interface_info));
        ql_dev.general_type = -1;
		ql_dev.third_type = -1;

        ql_dev.dm_intf.bInterfaceNumber = 0;    //include EC20 GW
        if (ql_dev.bNumInterfaces > 1) {
            if (drv_is_asr(ql_dev.idProduct, ql_dev.idVendor)) { //ASR
                if (!strncasecmp(modem_name_para, "EC200T", 6))   //EC200T GW
                {
                    if (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff)
                        ql_dev.dm_intf.bInterfaceNumber = 8;
                    else if (ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93)
                        ql_dev.dm_intf.bInterfaceNumber = 0;
                }
                else if (!strncasecmp(modem_name_para, "EC200A", 6))   //EC200A GW
                {
                    if (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff)
                        ql_dev.dm_intf.bInterfaceNumber = 8;
                    else if (ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93)
                        ql_dev.dm_intf.bInterfaceNumber = 0;
                }
                else
                    ql_dev.dm_intf.bInterfaceNumber = 2;
            }
            else if (drv_is_unisoc(ql_dev.idProduct,ql_dev.idVendor)) { //unisoc
                if (!strncasecmp(modem_name_para, "RM500U", 6))   //RM500U GW
                {
                    if (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff)
                    {
                        ql_dev.dm_intf.bInterfaceNumber = 8;
                        ql_dev.general_intf.bInterfaceNumber = 10; //log_intf
                        ql_dev.general_type = RG500U_LOG;
                    }
                }
                else if (!strncasecmp(modem_name_para, "RG200U", 6))  //RG200U GW
                {
                    if (ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93)
                    {
                        ql_dev.dm_intf.bInterfaceNumber = 5;       //dm_intf
                        ql_dev.general_intf.bInterfaceNumber = 6;  //log_intf
                        ql_dev.general_type = RG500U_LOG;
                    }
                    else if (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff)
                    {
                        ql_dev.dm_intf.bInterfaceNumber = 8;       //dm_intf
                        ql_dev.general_intf.bInterfaceNumber = 10;  //log_intf
                        ql_dev.general_type = RG500U_LOG;
                    }
                }
                else if (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0902)  //8310 EC200D-CN
                {
                    ql_dev.dm_intf.bInterfaceNumber = 3;       //dm_intf
                    ql_dev.general_intf.bInterfaceNumber = 5;  //log_intf
                    ql_dev.general_type = RG500U_LOG;
                }
                else if (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0904)  //8850 EC800G-CN
                {
                    ql_dev.dm_intf.bInterfaceNumber = 3;       //ap log
                    ql_dev.general_intf.bInterfaceNumber = 5;  //cp log
                    ql_dev.general_type = RG500U_LOG;
                }
                else                                           //udx710 standard RG500U/RM500U/RG200U/...
                {
                    ql_dev.dm_intf.bInterfaceNumber = 2;
                    ql_dev.general_intf.bInterfaceNumber = 3;  //log_intf
                    ql_dev.general_type = RG500U_LOG;

                    if (qlog_read_nmea_log)
                    {
                        ql_dev.third_intf.bInterfaceNumber = 6;        //third_intf
                        ql_dev.third_type = 2;
                    }
                }
            }
            else if (drv_is_unisoc_exx00u(ql_dev.idProduct,ql_dev.idVendor)) {  //unisoc ECx00U or EGx00U
                ql_dev.dm_intf.bInterfaceNumber = 5;            //cplog_intf
                if (!qlog_ignore_exx00u_ap)
                {
                    ql_dev.general_intf.bInterfaceNumber = 6;   //aplog_intf
                    ql_dev.general_type = EC200U_AP;
                }
            }
            else if (drv_is_mtk(ql_dev.idProduct,ql_dev.idVendor)) {     //mtk RM500K / AG568N
                if (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x7001)
                {
                    ql_dev.dm_intf.bInterfaceNumber = 9;
                }
                else if (ql_dev.idVendor == 0x0e8d && ql_dev.idProduct == 0x202f)
                {
                    ql_dev.dm_intf.bInterfaceNumber = 5;
                }
            }
			else if (drv_is_eigen(ql_dev.idProduct,ql_dev.idVendor)) {         //eigencomm
                if (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0903)  //EC600E/EC800E
                    ql_dev.dm_intf.bInterfaceNumber = 2;
                else                                                          //EG800Q
                    ql_dev.dm_intf.bInterfaceNumber = 0;
            }
            else if (ql_dev.idVendor == 0x05c6 && ql_dev.idProduct == 0x90db) {
                ql_dev.general_intf.bInterfaceNumber = 4;         //qdss_intf
                ql_dev.general_type = MDM_QDSS;
                g_is_qualcomm_chip = 1;    //USB qdss log to pc
            }
            else if (ql_dev.idVendor == 0x2c7c && (ql_dev.idProduct&0xF000) == 0x0000) {  //mdm
                ql_dev.general_intf.bInterfaceNumber = 12;        //qdss_intf
                ql_dev.general_type = MDM_QDSS;

                ql_dev.third_intf.bInterfaceNumber = 13;        //third_intf
                ql_dev.third_type = 1;
                
                g_is_qualcomm_chip = 1;   //USB qdss and adpl log to pc
            }
            else if (!strncasecmp(modem_name_para, "EC20", 4) && strlen(modem_name_para) <= 4)
            {
                if (ql_dev.idVendor == 0x3763 && ql_dev.idProduct == 0x3c93)
                {
                    ql_dev.dm_intf.bInterfaceNumber = 0;       //dm_intf  EC20 GW
                }
                else if (ql_dev.idVendor == 0x3c93 && ql_dev.idProduct == 0xffff)
                {
                    ql_dev.dm_intf.bInterfaceNumber = 8;       //dm_intf  EC20 GW
                }
            }
        }

        //Adapt to capture dump(ql_dev.bNumInterfaces == 1) and capture log(ql_dev.bNumInterfaces > 1) to specify DM port
        if ((ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0127)       //EM05CEFC-LNV  Laptop
            || (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0310)    //EM05-CN       Laptop
            || (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x030a)    //EM05-G        Laptop
            || (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x0309)    //EM05E-EDU     Laptop
            || (ql_dev.idVendor == 0x2c7c && ql_dev.idProduct == 0x030d))   //EM05G-FCCL    Laptop
            ql_dev.dm_intf.bInterfaceNumber = 3;

_rescan_dm:
        snprintf(devpath, sizeof(devpath), "%.24s/%.16s/%.16s:1.%d", usbpath, usb->d_name, usb->d_name, ql_dev.dm_intf.bInterfaceNumber);
        if (access(devpath, F_OK))
            continue;

        ql_find_usb_interface_info(devpath, &ql_dev.dm_intf);
        if (ql_dev.dm_intf.bInterfaceNumber == 0
            && ql_dev.dm_intf.bInterfaceClass == 0x02
            && ql_dev.dm_intf.bInterfaceSubClass == 0x0e) { //EM05-G 's interface 0 is MBIM
            ql_dev.dm_intf.bInterfaceNumber = 3;
            goto _rescan_dm;
        }

        ql_find_tty_info(devpath, ql_dev.ttyDM, sizeof(ql_dev.ttyDM));
        if (ql_dev.ttyDM[0]) {
            ql_get_dm_major_and_minor(ql_dev.ttyDM, &ql_dev);
        }

        if (ql_dev.general_intf.bInterfaceNumber != 0xFF
            && (ql_dev.general_type == EC200U_AP || ql_dev.general_type == RG500U_LOG)) {
            snprintf(devpath, sizeof(devpath), "%.24s/%.16s/%.16s:1.%d", usbpath, usb->d_name, usb->d_name, ql_dev.general_intf.bInterfaceNumber);
            if (access(devpath, F_OK))
                continue;

            ql_find_usb_interface_info(devpath, &ql_dev.general_intf);
            ql_find_tty_info(devpath, ql_dev.ttyGENERAL, sizeof(ql_dev.ttyGENERAL));
        }
        else if (ql_dev.general_intf.bInterfaceNumber != 0xFF && ql_dev.general_type == MDM_QDSS) {

            snprintf(devpath, sizeof(devpath), "%.24s/%.16s/%.16s:1.%d", usbpath, usb->d_name, usb->d_name, ql_dev.general_intf.bInterfaceNumber);
            if (!access(devpath, F_OK)) {
                ql_find_usb_interface_info(devpath, &ql_dev.general_intf);
                if (ql_dev.general_intf.bInterfaceClass != 0xff
                     ||ql_dev.general_intf.bInterfaceSubClass != 0xff
                     || ql_dev.general_intf.bInterfaceProtocol != 0x70
                     || ql_dev.general_intf.bNumEndpoints != 1
                     || ql_dev.general_intf.ep_out != 0xff
                     || ql_dev.general_intf.ep_in == 0xff) {
                    qlog_dbg("not a vaild qdss usb interface!\n");
                    memset(&ql_dev.general_intf, 0xff, sizeof(struct ql_usb_interface_info));
                    ql_dev.general_type = -1;
                }
            }else {
                memset(&ql_dev.general_intf, 0xff, sizeof(struct ql_usb_interface_info));
                ql_dev.general_type = -1;
            }
        }

        if (ql_dev.third_intf.bInterfaceNumber != 0xFF && ql_dev.third_type == 2) {
            snprintf(devpath, sizeof(devpath), "%.24s/%.16s/%.16s:1.%d", usbpath, usb->d_name, usb->d_name, ql_dev.third_intf.bInterfaceNumber);
            if (access(devpath, F_OK))
                continue;

            ql_find_usb_interface_info(devpath, &ql_dev.third_intf);
            ql_find_tty_info(devpath, ql_dev.ttyTHIRD, sizeof(ql_dev.ttyTHIRD));
        }
        else if (ql_dev.third_intf.bInterfaceNumber != 0xFF && ql_dev.third_type == 1)
        {

            snprintf(devpath, sizeof(devpath), "%.24s/%.16s/%.16s:1.%d", usbpath, usb->d_name, usb->d_name, ql_dev.third_intf.bInterfaceNumber);
            if (!access(devpath, F_OK)) {
                ql_find_usb_interface_info(devpath, &ql_dev.third_intf);
                if (ql_dev.third_intf.bInterfaceClass != 0xff
                     ||ql_dev.third_intf.bInterfaceSubClass != 0xff
                     || ql_dev.third_intf.bInterfaceProtocol != 0x80
                     || ql_dev.third_intf.bNumEndpoints != 1
                     || ql_dev.third_intf.ep_out != 0xff
                     || ql_dev.third_intf.ep_in == 0xff) {
                    qlog_dbg("not a vaild DPL usb interface!\n");
                    memset(&ql_dev.third_intf, 0xff, sizeof(struct ql_usb_interface_info));
                    ql_dev.third_type = -1;
                }
            }else {
                memset(&ql_dev.third_intf, 0xff, sizeof(struct ql_usb_interface_info));
                ql_dev.third_type = -1;
            }
        }

        snprintf(ql_dev.usbdevice_pah, sizeof(ql_dev.usbdevice_pah), "%.24s/%.16s", usbpath, usb->d_name);
        qlog_dbg("Find [%d] idVendor=%04x, idProduct=%04x, bNumInterfaces=%d, ttyDM=%s, ttyGENERAL=%s, ttyTHIRD=%s, busnum=%03d, dev=%03d, usbdevice_pah=%s\n",
            modules_num, ql_dev.idVendor, ql_dev.idProduct, ql_dev.bNumInterfaces, ql_dev.ttyDM,
            ql_dev.ttyGENERAL, ql_dev.ttyTHIRD, ql_dev.busnum, ql_dev.devnum, ql_dev.usbdevice_pah);

        if (modules_num < MAX_USB_DEV)
            s_usb_device_info[modules_num++] = ql_dev;
    }

    closedir(usb_dir);
    return modules_num;
}

int ql_usbfs_open_interface(const struct ql_usb_device_info *usb_dev, int intf)
{
    char devname[64];
    int dev_mknod_and_delete_after_use = 0;
    int usbfd = -1;
    int ret;

    snprintf(devname, sizeof(devname), "/dev/%s", usb_dev->devname);
    if (access(devname, F_OK) && errno == ENOENT) {
        char *p = strstr(devname+strlen("/dev/"), "/");

        while (p) {
            p[0] = '_';
            p = strstr(p, "/");
        }

#define MKDEV(__ma, __mi) (((__ma & 0xfff) << 8) | (__mi & 0xff) | ((__mi & 0xfff00) << 12))
        if (mknod(devname, S_IFCHR|0666, MKDEV(usb_dev->major, usb_dev->minor))) {
            devname[1] = 't';
            devname[2] = 'm';
            devname[3] = 'p';

            if (mknod(devname, S_IFCHR|0666, MKDEV(usb_dev->major, usb_dev->minor))) {
                qlog_dbg("Fail to mknod %s, errno : %d (%s)\n", devname, errno, strerror(errno));
            }
        }

        dev_mknod_and_delete_after_use = 1;
    }

    usbfd = open(devname, O_RDWR | O_NDELAY);
    if (dev_mknod_and_delete_after_use) {
        remove(devname);
    }

    if (usbfd == -1) {
        qlog_dbg("usbfs open %s failed, errno: %d (%s)\n", devname, errno, strerror(errno));
        return -1;
    }

    if (usbfs_is_kernel_driver_alive(usbfd, intf))
        usbfs_detach_kernel_driver(usbfd, intf);

    ret = ioctl(usbfd, USBDEVFS_CLAIMINTERFACE, &intf); // attach usbfs driver
    if (ret != 0)
    {
        qlog_dbg("ioctl USBDEVFS_CLAIMINTERFACE failed, errno = %d(%s)\n", errno, strerror(errno));
        close(usbfd);
        return -1;
    }

    return usbfd;
}

int ql_usbfs_read(int usbfd, int ep_in, void *pbuf, unsigned len)
{
    struct usbdevfs_bulktransfer bulk;
    int n = 0;

    bulk.ep = ep_in;
    bulk.len = len;
    bulk.data = (void *)pbuf;
    bulk.timeout = 0; // keep waiting

    n = ioctl(usbfd, USBDEVFS_BULK, &bulk);
    if (n < 0) {
        qlog_dbg("%s n = %d, errno: %d (%s)\n", __func__, n, errno, strerror(errno));
    }
    else if (n == 0) {
        //zero length packet
    }

    return n;
}

int ql_usbfs_write(int usbfd, int ep_out, const void *pbuf, unsigned len)
{
    struct usbdevfs_urb bulk;
    struct usbdevfs_urb *urb = &bulk;
    int n = 0;

    memset(urb, 0, sizeof(struct usbdevfs_urb));
    urb->type = USBDEVFS_URB_TYPE_BULK;
    urb->endpoint = ep_out;
    urb->status = -1;
    urb->buffer = (void *)pbuf;
    urb->buffer_length = len;
    urb->usercontext = urb;
    urb->flags = 0;

    n = ioctl(usbfd, USBDEVFS_SUBMITURB, urb);
    if (n < 0) {
        qlog_dbg("%s submit n = %d, errno: %d (%s)\n", __func__, n, errno, strerror(errno));
        return 0;
    }

    urb = NULL;
    n = ioctl(usbfd, USBDEVFS_REAPURB, &urb);
    if (n < 0) {
        qlog_dbg("%s reap n = %d, errno: %d (%s)\n", __func__, n, errno, strerror(errno));
        return 0;
    }

    if (urb && urb->status == 0 && urb->actual_length) {
        // qlog_dbg("urb->actual_length = %u\n", urb->actual_length);
        return urb->actual_length;
    }

    return 0;
}

