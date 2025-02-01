/******************************************************************************
  @file    eigen.c
  @brief   eigen log tool.

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

#define MAX_RETRY_TIME 32
#define MAX_CMD_DATALEN	512
#define DUMP_CID 0xdc
#define N_DUMP_CID 0x23

#define GetDataCmd	0x20
#define GetInfoCmd	0x21
#define FinishCmd	0x25

#define nullptr	NULL

extern int g_is_eigen_chip;

enum RamDumpType {
	TRIGGER_ASSERT,
	RESPONSE_ASSERT,
	HANDSHAKE_READY,
	CHANGE_BAUD_RATE,
    SendReqGetInfo,
    SendRspGetInfo,
    SendReqGetCMD,
	SendFinishCMD
};

enum RamDumpStausType {
  UE_TIMEOUT_ERR = 0,
  UE_NOT_COMMAND_COMM_ERR,
  UE_OK
};

typedef struct
{
	uint8_t Command;
	uint8_t Sequence;
	uint8_t CID;
	uint8_t NCID;
	uint16_t Status;
    uint16_t Length;
	uint8_t Data[MAX_CMD_DATALEN];
	uint32_t FCS;
}DumpRspWrap, *PtrDumpRspWrap;

typedef struct
{
	uint8_t Command;
	uint8_t Sequence;
	uint8_t CID;
	uint8_t NCID;
    uint32_t Length;
	uint8_t Data[MAX_CMD_DATALEN];
	uint32_t FCS;
}DumpReqWrap, *PtrDumpReqWrap;

typedef struct{
    uint16_t tm_year;
    uint16_t tm_mon;
    uint16_t tm_wday;
    uint16_t tm_mday;
    uint16_t tm_hour;
    uint16_t tm_min;
    uint16_t tm_sec;
    uint16_t tm_msec;
}tm_eigen;

typedef struct
{
	uint32_t ReadDataAddr;
	uint32_t ReadLen;
}ReadDataReqCell, *PtrReadDataReqCell;

ReadDataReqCell RDReqCell[100];

int RDReqCell_count = 0;
int eigen_logfile_dump = -1;

const uint16_t wCRCTalbeAbs[] =
{
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401, 0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
};

const uint8_t eigen_log_time_start[8] =
{
    0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xAA
};

const uint8_t eigen_log_time_end[8] =
{
    0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xBA, 0xAA
};

tm_eigen qlog_eigen_time_stamp(void)
{
    tm_eigen tm_log;
    uint16_t millisecond = 0;
    time_t ltime;
    struct tm *currtime;
    struct timeval tm;

    time(&ltime);
    currtime = localtime(&ltime);
    gettimeofday(&tm, NULL);

    millisecond = (uint16_t)(tm.tv_usec / 1000);
    memset(&tm_log, 0, sizeof(tm_log));
    tm_log.tm_year = currtime->tm_year+1900;
    tm_log.tm_mon = currtime->tm_mon+1;
    tm_log.tm_wday = currtime->tm_wday;
    tm_log.tm_mday = currtime->tm_mday;
    tm_log.tm_hour = currtime->tm_hour;
    tm_log.tm_min = currtime->tm_min;
    tm_log.tm_sec = currtime->tm_sec;
    tm_log.tm_msec = millisecond;

    return tm_log;
}

uint16_t CRC16(uint16_t wCRC, uint8_t* pchMsg, uint16_t wDataLen)
{
    //uint16_t wCRC = 0xFFFF;
    uint16_t i;
    uint8_t chChar;
    for (i = 0; i < wDataLen; i++)
    {
        chChar = *pchMsg++;
        wCRC = wCRCTalbeAbs[(chChar ^ wCRC) & 15] ^ (wCRC >> 4);
        wCRC = wCRCTalbeAbs[((chChar >> 4) ^ wCRC) & 15] ^ (wCRC >> 4);
    }
    return wCRC;
}


static int eigen_dump_fd = 0;

static int eigen_init_filter(int fd, const char *cfg) {

    eigen_dump_fd = fd;

    return 0;
}

static int eigen_clean_filter(int fd) {

    return 0;
}

static int eigen_logfile_init(int logfd, unsigned logfile_seq) {

    return 0;
}

static size_t eigen_logfile_save(int logfd, const void *buf, size_t size) {
    if (size <= 0 || NULL == buf || logfd <= 0)
        return size;

    uint8_t eigen_log_header[40] = {0};
    tm_eigen tm_log_save;
    tm_log_save = qlog_eigen_time_stamp();
    memmove(eigen_log_header, eigen_log_time_start, 8);
    memmove(eigen_log_header + 8, &tm_log_save, 16);
    memmove(eigen_log_header + 24, eigen_log_time_end, 8);

    qlog_logfile_save(logfd, eigen_log_header, 32);
    return qlog_logfile_save(logfd, buf, size);
}

qlog_ops_t eigen_qlog_ops = {
    .init_filter = eigen_init_filter,
    .clean_filter = eigen_clean_filter,
    .logfile_init = eigen_logfile_init,
    .logfile_save = eigen_logfile_save,
};

int SendCommand(uint8_t *sbuf, size_t size, int crln)
{
    int ret = -1;
    int err_code = UE_TIMEOUT_ERR;

    if (crln == 1)
    {
        //Treatment of crln
        uint8_t sbuf_tmp[8] = {0};
        memmove(sbuf_tmp, sbuf, size);
        sbuf_tmp[size] = 0x0d;
        sbuf_tmp[size+1] = 0x0a;

        ret = qlog_poll_write(eigen_dump_fd, sbuf_tmp, sizeof(sbuf_tmp), 1000);
        if (ret > 0)
        {    return UE_OK;}
    }
    else
    {
        ret = qlog_poll_write(eigen_dump_fd, sbuf, size, 1000);
        if (ret > 0)
        {    return UE_OK;}
    }

    return err_code;
}

int SendRamDumpAck(int id, uint8_t *sbuf, size_t size)
{
    int CRLN = 0;
    int err_code;

    if (id == RESPONSE_ASSERT)
    {
        CRLN = 1;
        err_code = SendCommand(sbuf, size, CRLN);
    }
    else
    {
        err_code = SendCommand(sbuf, size, CRLN);
    }

    return err_code;
}

int WaitRamDumpAckAndData(int id, void *rbuf, int* psize, unsigned timeout_msec)
{
    int err_code = UE_TIMEOUT_ERR;
    int read_len = qlog_poll_read(eigen_dump_fd, rbuf, 65535, timeout_msec);

    if (read_len <= 0)
        return err_code;

    if (SendReqGetCMD == id)
    {
        *psize = read_len;
        return UE_OK;
    }
    else if (HANDSHAKE_READY == id)
    {
        if (strstr((char*)rbuf, "DUMPDUMP"))
        {
            return UE_OK;
        }
    }
    else if (SendRspGetInfo == id)
    {
        if (!strstr((char*)rbuf, "DUMP")) //It is not the handshake data. If it is not found, it returns success
        {
            *psize = read_len;
            return UE_OK;
        }
    }

    return err_code;
}

static int wait_tty_echo_not_busy(int fd) {
    int retry = 0;
    int ret;

    for (retry = 0; retry < 10; retry++) {
        struct pollfd pollfds[] = {{fd, POLLOUT, 0}};

        ret = poll(pollfds, 1, -1);
        if (ret < 0)
            break;
        usleep(100*1000);
    }

    return ret == 1;
}

int SyncStart(void)
{
    int err_code = UE_TIMEOUT_ERR;
    uint8_t respAssertCmd[] = "okokok";
    uint8_t messageBuf[65535] = {0};
    int nRetry = 0;

    if (!wait_tty_echo_not_busy(eigen_dump_fd))
    {
	    printf("%s wait_tty_echo_not_busy faileed\n", __func__);
        return -1;
    }

    struct termios options;

    tcgetattr(eigen_dump_fd, &options);
    //setting baud rates and stuff
    cfsetispeed(&options, B115200);
    cfsetospeed(&options, B115200);
    options.c_cflag |= (CLOCAL | CREAD);
    tcsetattr(eigen_dump_fd, TCSANOW, &options);

    tcsetattr(eigen_dump_fd, TCSAFLUSH, &options);

    options.c_cflag &= ~PARENB;//next 4 lines setting 8N1
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;

    //options.c_cflag &= ~CNEW_RTSCTS;

    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); //raw input

    options.c_iflag &= ~(IXON | IXOFF | IXANY);         //disable software flow control
    sleep(2);                                           //required to make flush work, for some reason
    tcflush(eigen_dump_fd,TCIOFLUSH);

    for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
    {
        err_code = SendRamDumpAck(RESPONSE_ASSERT, respAssertCmd, 6);  //Either -1 or the number of bytes actually written to the module is returned
        if (err_code != UE_OK)
        {
            printf("%s SendRamDumpAck error\n", __func__);
            continue;
        }
	    else
	    {
	        printf("%s SendRamDumpAck success\n", __func__);
	    }

        int nTemp = 0;
 	    memset(messageBuf, 0, 65535);
        err_code = WaitRamDumpAckAndData(HANDSHAKE_READY, messageBuf, &nTemp, 1000);   //Either -1 or the number of bytes actually read from the module is returned
        if (err_code == UE_OK)
        {
            printf("%s WaitRamDumpAckAndData success\n", __func__);
            break;
        }
	    else
	    {
            printf("%s WaitRamDumpAckAndData fail\n", __func__);
	    }
    }

    if (nRetry >= MAX_RETRY_TIME && err_code != UE_OK)
    {
        return err_code;
    }

    usleep(50*1000);

    uint8_t hsAssertCmd[] = "DUMPDUMP";

    for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
    {
        err_code = SendRamDumpAck(HANDSHAKE_READY, hsAssertCmd, sizeof(hsAssertCmd));
        if (err_code != UE_OK)
        {
            continue;
        }

        int nTemp1 = 0;
        err_code = WaitRamDumpAckAndData(HANDSHAKE_READY, messageBuf, &nTemp1, 5000);
        if (err_code == UE_OK)
        {
	        printf("%s WaitRamDumpAckAndData success -1\n", __func__);
            break;
        }
    }

    if (nRetry >= MAX_RETRY_TIME && err_code != UE_OK)
    {
        return err_code;
    }

    return UE_OK;

}

int SendGetInfoUsb(void)
{
    int nRetry = 0;
    uint8_t uSeq = 0;
    int err_code = UE_TIMEOUT_ERR;

    uint8_t messageBuf[65535] = { 0 };
	uint8_t message[65535] = { 0 };

    DumpReqWrap dataReq;
	memset(&dataReq, 0, sizeof(dataReq));
	dataReq.CID = DUMP_CID;
	dataReq.NCID = N_DUMP_CID;
	dataReq.Command = GetInfoCmd;
	dataReq.Sequence = uSeq++;
	dataReq.Length = 0;
	dataReq.FCS = 10;

    uint8_t data[256];
	int nCount = 0;

    nCount = sizeof(dataReq.Command) + sizeof(dataReq.CID) +
		sizeof(dataReq.Sequence) + sizeof(dataReq.NCID) + sizeof(dataReq.Length);

    const int nRspHeaderCount = sizeof(uint8_t) * 4 + sizeof(uint16_t) * 2;

    memcpy(data, (void*)&dataReq, nCount);

    if (dataReq.Length > 0)
	{
		memcpy((void*)&data[nCount], dataReq.Data, dataReq.Length);
		nCount += dataReq.Length;
	}

    dataReq.FCS = CRC16(0xFFFF, data, nCount);

    ReadDataReqCell *readData = nullptr;
    int bSuc = 0;
    DumpRspWrap* dataRsp = nullptr;

    for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
	{
        sleep(1);

        err_code = SendRamDumpAck(SendReqGetInfo, data, nCount);
        if (err_code != UE_OK)
            continue;

        err_code = SendRamDumpAck(SendReqGetInfo, (uint8_t*)&dataReq.FCS, sizeof(dataReq.FCS));
        if (err_code != UE_OK)
            continue;

        dataRsp = nullptr;

        int nPktIndex = 0;
        int ntry;

		for (ntry = 0; ntry < MAX_RETRY_TIME; ++ntry)
		{
			//wait
			int nMsgDataLen = 0;
			err_code = WaitRamDumpAckAndData(SendRspGetInfo, messageBuf, &nMsgDataLen, 500);
			if (err_code != UE_OK)
                continue;

			memcpy(message + nPktIndex, messageBuf, nMsgDataLen);
			nPktIndex += nMsgDataLen;



			dataRsp = (DumpRspWrap*)message;

			if (dataRsp->Length > (int)(nPktIndex - nRspHeaderCount - sizeof(dataRsp->FCS)))
			{
				continue;
            }
			else
            {
				break;
            }
		}

		if (err_code != UE_OK)
            continue;

		uint16_t crc = CRC16(0xFFFF, message, dataRsp->Length + nRspHeaderCount);
		uint32_t srcCrc = *(uint32_t*)(message + nRspHeaderCount + dataRsp->Length);

		if (crc == srcCrc)
		{
			bSuc = 1;
			break;
		}
	}

    if (!bSuc)
	{
		return UE_NOT_COMMAND_COMM_ERR;
	}

    const int nCellSize = sizeof(ReadDataReqCell);
    int i;

    for (i = 0; i < dataRsp->Length / nCellSize; i++)
    {
        readData = (ReadDataReqCell*)(message + nRspHeaderCount + i * nCellSize);

		if (readData)
		{
            memmove(&RDReqCell[i], readData, nCellSize);
            RDReqCell_count++;
		}
    }

    return UE_OK;
}

int WriteData(uint8_t* pData, int nLen)
{
    int nwrites = 0;
    nwrites = qlog_logfile_save(eigen_logfile_dump, pData , nLen);
    if (nLen != nwrites)
    {
        qlog_dbg("nLen:%d  nwrites:%d\n",nLen,nwrites);
        return -1;
    }

    return nwrites;
}

int GetDumpDataUsb(uint32_t nTotalData, uint32_t nReadAddr, int bFinish)
{
	int nReadLen = 0;
	int nReadTime = 0;
	int uSeq = 1;
	int nRetry = 0;
	int err_code = UE_TIMEOUT_ERR;;
	uint8_t messageBuf[65535] = { 0 };
	uint8_t message[65535] = { 0 };

	DumpReqWrap dataReq;
	memset((void*)&dataReq, 0x0, sizeof(dataReq));
	dataReq.CID = DUMP_CID;
	dataReq.NCID = N_DUMP_CID;
	dataReq.Length = 0;
	dataReq.FCS = 10;

	uint8_t data[256];
	int nPktIndex = 0;
    const uint32_t dwUsbMaxDataLen = MAX_CMD_DATALEN * 20;
	ReadDataReqCell newReadData = {0};
	newReadData.ReadLen = dwUsbMaxDataLen;
	newReadData.ReadDataAddr = nReadAddr;

	int nCount = 0;

	nCount = sizeof(dataReq.Command) + sizeof(dataReq.CID) +
		sizeof(dataReq.Sequence) + sizeof(dataReq.NCID) + sizeof(dataReq.Length);

	const int nReqHeaderCount = nCount;
	const int nRspHeaderCount = sizeof(uint8_t) * 4 + sizeof(uint16_t) * 2;

	usleep(200*1000);

	while (nReadLen < nTotalData && nTotalData > 0 && nReadTime < MAX_RETRY_TIME / 2)
	{
		dataReq.Command = GetDataCmd;

		dataReq.Length = sizeof(ReadDataReqCell)/*dataRsp->Length*/;
		dataReq.Sequence = uSeq; //Failed retries do not accumulate

		nCount = nReqHeaderCount;

		memcpy(data, (void*)&dataReq, nCount);

        for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
        {
            err_code = SendRamDumpAck(SendReqGetCMD, data, nCount);
            if (err_code == UE_OK)
                break;
        }

        if (dataReq.Length > 0)
        {
            memcpy(dataReq.Data, (void*)&newReadData, sizeof(newReadData));
            memcpy((void*)&data[nCount], dataReq.Data, dataReq.Length);
            nCount += dataReq.Length;
            for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
            {
                err_code = SendRamDumpAck(SendReqGetCMD, dataReq.Data, dataReq.Length);
                if (err_code == UE_OK)
                    break;
            }
        }

        dataReq.FCS = CRC16(0xFFFF, data, nCount);

        for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
        {
            err_code = SendRamDumpAck(SendReqGetCMD, (uint8_t*)&dataReq.FCS, sizeof(dataReq.FCS));
            if (err_code == UE_OK)
                break;
        }

        if (err_code != UE_OK)
        {
            continue;
        }


		DumpRspWrap* dataRsp = nullptr;
		nPktIndex = 0;
		nRetry = 0;

		while(nPktIndex < newReadData.ReadLen + 12 && nRetry < MAX_RETRY_TIME / 4)
		{
			int nMsgDataLen = 0;
			err_code = WaitRamDumpAckAndData(SendReqGetCMD, messageBuf, &nMsgDataLen, 500);
			if (err_code != UE_OK)
			{
				nRetry++;
				continue;
			}
			memcpy(message + nPktIndex, messageBuf, nMsgDataLen);
			nPktIndex += nMsgDataLen;

			dataRsp = (DumpRspWrap*)message;

			if (dataRsp->Length > newReadData.ReadLen)
				break;
		}

		if (err_code != UE_OK || nRetry >= MAX_RETRY_TIME / 4)
		{
			continue;
		}

		if (err_code == UE_OK)
		{
			dataRsp = (DumpRspWrap*)message;
			uint8_t* pDumpData = (uint8_t*)(message + nRspHeaderCount);
			uint32_t dwDumpDataCRC = *(uint32_t*)(message + nRspHeaderCount + dataRsp->Length);
			uint16_t wNewCRC = CRC16(0xFFFF, message, dataRsp->Length + nRspHeaderCount);

			if (wNewCRC == (uint16_t)dwDumpDataCRC)
			{
				WriteData(pDumpData, dataRsp->Length);
				nReadLen += dataRsp->Length;
				uSeq++;
				newReadData.ReadDataAddr += dataRsp->Length;
				//qlog_dbg("dataRsq len:%d\n", dataRsp->Length);
				//qlog_dbg("data addr:%x, nreadlen:%d, seq:%d\n", newReadData.ReadDataAddr, nReadLen, uSeq - 1);

				if (nTotalData - nReadLen < dwUsbMaxDataLen)
					newReadData.ReadLen = nTotalData - nReadLen;
				nReadTime = 0;
			}
			else
			{
				nReadTime++;
				continue;
			}
		}
	}

	if (nReadTime >= MAX_RETRY_TIME / 2)
	{
		return -1;
	}

    if ( bFinish)
    {
        //send finish cmd
        memset((void*)&dataReq, 0x0, sizeof(dataReq));
        dataReq.CID = DUMP_CID;
        dataReq.NCID = N_DUMP_CID;
        dataReq.Command = FinishCmd;
        dataReq.Sequence = uSeq++;
        dataReq.Length = 0;

        nCount = sizeof(dataReq.Command) + sizeof(dataReq.CID) +
            sizeof(dataReq.Sequence) + sizeof(dataReq.NCID) + sizeof(dataReq.Length);

        memcpy(data, (void*)&dataReq, nCount);

        for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
        {
            err_code = SendRamDumpAck(SendFinishCMD, data, nCount);
            if (err_code == UE_OK)
				break;
        }

		dataReq.FCS = CRC16(0xFFFF, data, nCount);
		memcpy((void*)&data[0], (void*)&dataReq.FCS, sizeof(dataReq.FCS));

		nCount = sizeof(dataReq.FCS);

		for (nRetry = 0; nRetry < MAX_RETRY_TIME; ++nRetry)
		{
			err_code = SendRamDumpAck(SendFinishCMD, data, nCount);
			if (err_code == UE_OK)
				break;
		}

        if (err_code != UE_OK)
        {
            return err_code;
        }
    }

	return UE_OK;
}

void PaddingDumpFile(int nLen)
{
    uint8_t szData[MAX_CMD_DATALEN] = {0};

    while (nLen > 0)
    {
        if (nLen > MAX_CMD_DATALEN)
        {
            WriteData(szData, MAX_CMD_DATALEN);
            nLen -= MAX_CMD_DATALEN;
        }
        else
        {
            WriteData(szData, nLen);
            nLen = 0;
        }
    }
}

int enigen_catch_dump(uint8_t* pbuf, ssize_t size, const char *logfile_dir, const char* (*qlog_time_name)(int))
{
    int k;
    int err_code = UE_TIMEOUT_ERR;

    if (g_is_eigen_chip == 1)  //EC600E/EC800E
    {
        for(k=0;k<size;k++)
        {
            if ((size - k) > 4 && (pbuf[k] == 0x22 && pbuf[k+1] == 0x0a && pbuf[k+2] == 0x45 && pbuf[k+3] == 0x80))
            {
                qlog_dbg("modem into ramdump ...\n");
                break;
            }
        }

        if (k == size)
        {
            return 0;    //Module does not enter dump, continue to grab log
        }
    }
    else if (g_is_eigen_chip == 2)  //EG800Q
    {
        for(k=0;k<size;k++)
        {
            if ((size - k) > 4 && (pbuf[k] == 0x22 && pbuf[k+1] == 0x04 && pbuf[k+2] == 0x02 && pbuf[k+3] == 0x00))
            {
                qlog_dbg("modem into ramdump ...\n");
                break;
            }
        }

        if (k == size)
        {
            return 0;    //Module does not enter dump, continue to grab log
        }
    }

    //Module enter dump
    err_code = SyncStart();
    if (err_code != UE_OK)
    {
        qlog_dbg("%s : SyncStart failed\n", __func__);
        return -1;
    }

    err_code = SendGetInfoUsb();
    if (err_code != UE_OK)
    {
        qlog_dbg("%s : SendGetInfoUsb failed\n", __func__);
        return -1;
    }

    char logFileName[100] = {0};
    char cure_dir_path[256] = {0};
    char dump_dir[262] = {0};

    snprintf(dump_dir, sizeof(dump_dir), "%.172s/dump_%.80s", logfile_dir, qlog_time_name(1));
    mkdir(dump_dir, 0755);
    if (!qlog_avail_space_for_dump(dump_dir, 256)) {
         qlog_dbg("no enouth disk to save dump\n");
         qlog_exit_requested = 1;
         return -1;
    }

    snprintf(logFileName, sizeof(logFileName), "ramdump_%.80s.bin",qlog_time_name(1));
    snprintf(cure_dir_path,sizeof(cure_dir_path),"%.155s/%.80s",dump_dir,logFileName);
    qlog_dbg("%s : cure_dir_path:%s\n", __func__, cure_dir_path);

    eigen_logfile_dump = qlog_logfile_create_fullname(0, cure_dir_path, 0, 1);
    if (eigen_logfile_dump == -1)
    {
        qlog_dbg("%s : open failed\n", __func__);
        return -1;
    }

    int i;
    for (i = 0; i < RDReqCell_count; i++)
    {
        err_code = GetDumpDataUsb(RDReqCell[i].ReadLen, RDReqCell[i].ReadDataAddr, i == RDReqCell_count - 1);
        if (err_code != UE_OK)
        {
            if (eigen_logfile_dump > 0)
            {
                close(eigen_logfile_dump);
                eigen_logfile_dump = -1;
            }
            return -1;
        }

        //The dump data of CAT1 has 3 blocks, the addresses are not continuous, and 0x0 is filled in the middle
        if ( i + 1 < RDReqCell_count)
            PaddingDumpFile(RDReqCell[i + 1].ReadDataAddr - (RDReqCell[i].ReadLen + RDReqCell[i].ReadDataAddr));

    }

    if (eigen_logfile_dump > 0)
    {
        close(eigen_logfile_dump);
        eigen_logfile_dump = -1;
    }

    return 1;
}