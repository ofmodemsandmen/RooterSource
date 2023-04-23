NDK_BUILD:=/home/aaron/share-aaron-1/android-ndk-r10e/ndk-build
SRC=firehose_protocol.c  qfirehose.c  sahara_protocol.c usb_linux.c stream_download_protocol.c md5.c usb2tcp.c 

CFLAGS += -Wall -Wextra -Werror -O1 #-s
LDFLAGS += -lpthread -ldl
ifeq ($(CC),cc)
CC=${CROSS_COMPILE}gcc
endif

linux: clean
	${CC} ${CFLAGS} ${SRC} -o QFirehose ${LDFLAGS}
	
android: clean
	rm -rf android
	$(NDK_BUILD) V=0 APP_BUILD_SCRIPT=Android.mk NDK_PROJECT_PATH=`pwd` NDK_DEBUG=0 APP_ABI='armeabi-v7a,arm64-v8a' APP_PLATFORM=android-22 #16~4.1 22~5.1 25~7.1 27-32~8-12
	rm -rf obj
	mv libs android

clean:
	rm -rf QFirehose obj libs usb2tcp *~
