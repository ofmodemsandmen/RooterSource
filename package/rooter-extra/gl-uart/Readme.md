# Communication protocol between cpu and mcu

## Communication format

| Header | Type | R/W  | Control | Length | Data                                        | Checksum |
| ------ | ---- | ---- | ------- | ------ | ------------------------------------------- | -------: |
| 0x474C | 4Bit | 1Bit | 3Bit    | 1Byte  | Data   area is variable according to length |    1Byte |

## Format description

### Protocol header

| Header | Description                            |
| ------ | -------------------------------------- |
| 0x474C | The protocol header is fixed at 0x474C |

### Type

| Type     | Description                           |
| -------- | ------------------------------------- |
| 1        | Operating Led                         |
| 2        | 4G module power operation   (No use)  |
| 3        | Temperature sensor operation (No use) |
| 4        | GPS operation   (No use)              |
| 5        | RTC operation                         |
| Reserved | Reserved                              |

### R/W

| R/W  | Description |
| ---- | ----------- |
| 0    | Read        |
| 1    | Write       |

### Control

| Control  | Description        |
| -------- | ------------------ |
| 0        | Determined by Type |
| 1        | Determined by Type |
| 2        | Determined by Type |
| 3        | Determined by Type |
| Reserved | Reserved           |

### Length

| Length | Description                                                  |
| ------ | ------------------------------------------------------------ |
| Hex    | 1 byte of data, depending on the Type, the value will be different |

### Data

| Data | Description                                 |
| ---- | ------------------------------------------- |
| Hex  | The data area length is specified by Length |

### Checksum

| Checksum | Description                                                  |
| -------- | ------------------------------------------------------------ |
| Hex      | Calculated by Type, R/W, Control, Length, Data, currently tentatively used and verified |

## 4G Signal Control Protocol

### Read Protocol

| Header | Type | R/W  | Control | Length | Checksum |
| ------ | ---- | ---- | ------- | ------ | -------- |
| 0x474C | 1    | 0    | 0/1/2   | 0x0    | 1Byte    |

Read protocol format description

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 1      | 4G signal led operation                                      |
| R/W      | 0      | read                                                         |
| Control  | 0/1/2  | 0：4G modules 1 and 2   1：4G modules 1  2：4G module 2   other：Reserved |
| Length   | 0x0    | Read data area is not required. Specific 4G signal strength and LED light correspondence |
| Checksum | 1 byte | Type+R/W+Control                                             |

The read operation response format type is shown in the following table

| Header | Type | R/W  | Control | Lenght | Data  | Checksum |
| ------ | ---- | ---- | ------- | ------ | ----- | -------- |
| 0x474C | 1    | 0    | 0/1/2   | 0x1    | 1Byte | 1Byte    |

Read operation response format description as shown in the following table

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 1      | 4G signal led operation                                      |
| R/W      | 0      | read                                                         |
| Control  | 0/1/2  | 0：4G modules 1 and 2  1：4Gmodule 1  2：4G module 2   other：Reserved |
| Length   | 0x1    | Read return value data area length 1 byte                    |
| Data     | 1 byte | 0~2 bit means 4G module 1 LED light information 3~5bit means 4G module 2 LED light information 0: Off light 1: Light up . Specific 4G signal strength and LED light correspondence. |
| Checksum | 1 byte | Type+R/W+Control+Data                                        |

### Write Protocol

| Header | Type | R/W  | Control | Lenght | Data  | Checksum |
| ------ | ---- | ---- | ------- | ------ | ----- | -------- |
| 0x474C | 1    | 1    | 0/1/2   | 0x1    | 1Byte | 1Byte    |

Write protocol format description

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 1      | 4G signal led operation                                      |
| R/W      | 1      | write                                                        |
| Control  | 0/1/2  | 0：4G modules 1 and 2  1：4Gmodule 1  2：4G module 2   other：Reserved |
| Length   | 0x1    | Write requires a byte of the Data area                       |
| Data     | 1 byte | 0~2 bit means 4G module 1 LED light information 3~5bit means 4G module 2 LED light information 0: Off light 1: Light up . Specific 4G signal strength and LED light correspondence. |
| Checksum | 1 byte | Type+R/W+Control+Data                                        |

The write operation response format type is shown in the following table

| Header | Type | R/W  | Control | Lenght | Data      | Checksum |
| ------ | ---- | ---- | ------- | ------ | --------- | -------- |
| 0x474C | 1    | 0    | 0/1/2   | 0x1    | 0x00/0x01 | 1Byte    |

Write operation response format description as shown in the following table

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 1      | 4G signal led operation                                      |
| R/W      | 1      | write                                                        |
| Control  | 0/1/2  | 0：4G modules 1 and 2  1：4Gmodule 1  2：4G module 2   other：Reserved |
| Length   | 0x1    | Write requires a byte of the Data area                       |
| Data     | 1Byte  | Get the current LED status value and return it to the master |
| Checksum | 1Byte  | Type+R/W+Control+Data                                        |

### 4G module signal strength and LED correspondence

Refer to the current interface RSSI calculation method: Rssi = (read module signal strength) * 2 – 113

The signal strength and LED light on and off are as follows:

| Rssi                      | LED                        |
| ------------------------- | -------------------------- |
| Rssi >= -80               | LED1/LED2/LED3  bright     |
| Rssi >= -95 && Rssi < -80 | LED1/LED2 bright，LED3 off |
| Rssi < -95                | LED1 bright，LED2/LED3 off |

Remarks:

       When the signal strength of the reading module is 99, it means that the module is abnormal and the lights are not lit.

## RTC Data Transfer Protocol between MCU and CPU

### Obtaining the Current RTC Time Protocol Format 

Read Protocol

| Header | Type | R/W  | Control | Length | Checksum |
| ------ | ---- | ---- | ------- | ------ | -------- |
| 0x474C | 5    | 0    | 0       | 0x0    | 1Byte    |

The format of the read operation is shown in the following table:

| Type     | Value  | Description                |
| -------- | ------ | -------------------------- |
| Header   | 0x474C | protocol header            |
| Type     | 5      | rtc                        |
| R/W      | 0      | read                       |
| Control  | 0      | Reserved bit, default is 0 |
| Length   | 0x0    | Data area length is 0      |
| Checksum | 1 byte | Type+Control   +R/W        |

The read operation response format types are as follows:

| Header | Type | R/W  | Control | Length | Data   | Checksum |
| ------ | ---- | ---- | ------- | ------ | ------ | -------- |
| 0x474C | 5    | 0    | 0       | 0xb    | 7Bytes | 1Byte    |

The format of the read operation response is shown in the following table:

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 5      | rtc                                                          |
| R/W      | 0      | read                                                         |
| Control  | 0      | reserved bit, default is 0                                   |
| Length   | 0x8    | return value data area length 8 bytes                        |
| Data     | 7Bytes | format：          second：1byte   minute：1byte   hour：1byte   week：1byte   day：1byte   month：1byte   year：1byte |
| Checksum | 1byte  | Type+R/W+Control+Data                                        |

### Setting the Current RTC Time Protocol Format 

Write Protocol

| Header | Type | R/W  | Control | Length | Data   | Checksum |
| ------ | ---- | ---- | ------- | ------ | ------ | -------- |
| 0x474C | 5    | 1    | 0       | 0x7    | 7Bytes | 1Byte    |

The format of the write operation is shown in the following table:

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 5      | rtc                                                          |
| R/W      | 1      | write                                                        |
| Control  | 0      | reserved bit, default is 0                                   |
| Length   | 0x7    | Data area length is 7                                        |
| Data     | 7Bytes | format：          second：1byte   minute：1byte   hour：1byte   week：1byte   day：1byte   month：1byte   year：1byte |
| Checksum | 1byte  | Type+Control   +R/W                                          |

The write operation response format type is shown in the following table:

| Header | Type | R/W  | Control | Length | Data   | Checksum |
| ------ | ---- | ---- | ------- | ------ | ------ | -------- |
| 0x474C | 5    | 1    | 0       | 0x7    | 7Bytes | 1Byte    |

The format of the write operation response is shown in the following table:

| Type     | Value  | Description                                                  |
| -------- | ------ | ------------------------------------------------------------ |
| Header   | 0x474C | protocol header                                              |
| Type     | 5      | rtc                                                          |
| R/W      | 1      | write                                                        |
| Control  | 0      | reserved bit, default is 0                                   |
| Length   | 0x8    | return value data area length 8 bytes                        |
| Data     | 8Bytes | format：          second：1byte   minute：1byte   hour：1byte   week：1byte   day：1byte   month：1byte   year：1byte |
| Checksum | 1byte  | Type+R/W+Control+Data                                        |

## Led Control Example
Modem1 4G Led Control  
All Leds light  
	gl_uart 474c190107  
Two Leds light  
	gl_uart 474c190103  
One Led light  
	gl_uart 474c190101  
No Led light  
	gl_uart 474c190100  

Modem2 4G Led Control  
All Leds light  
	gl_uart 474c1a0138  
Two Leds light  
	gl_uart 474c1a0118  
One Led light  
	gl_uart 474c1a0108  
No Led light  
	gl_uart 474c1a0100  

