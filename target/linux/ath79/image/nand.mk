define Device/glinet_gl-ar300m-nand
  ATH_SOC := qca9531
  DEVICE_TITLE := GL-AR300M (NAND)
  DEVICE_PACKAGES := kmod-usb-core kmod-usb2 kmod-usb-storage kmod-usb-ledtrig-usbport
  KERNEL_SIZE := 2048k
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  VID_HDR_OFFSET := 512
  IMAGES += factory.ubi
  IMAGE/sysupgrade.bin := sysupgrade-tar
  IMAGE/factory.ubi := append-kernel | pad-to $$$$(KERNEL_SIZE) | append-ubi
endef
#TARGET_DEVICES += glinet_gl-ar300m-nand

define Device/glinet_gl-x1200-nor
  ATH_SOC := qca9563
  DEVICE_TITLE := GL.iNet GL-X1200 (NOR)
  DEVICE_PACKAGES := kmod-usb2 kmod-ath10k-ct ath10k-firmware-qca9887-ct-htt block-mount
  IMAGE_SIZE := 16000k
  SUPPORTED_DEVICES += gl-x1200 glinet,gl-x1200
endef
TARGET_DEVICES += glinet_gl-x1200-nor

define Device/glinet_gl-x1200-nor-nand
  ATH_SOC := qca9563
  DEVICE_TITLE := GL.iNet GL-X1200 (NOR/NAND)
  DEVICE_PACKAGES := kmod-usb2 kmod-ath10k-ct ath10k-firmware-qca9887-ct-htt block-mount PCI_SUPPORT
  KERNEL_SIZE := 2048k
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  VID_HDR_OFFSET := 2048
  IMAGES := factory.img sysupgrade.tar
  IMAGE/sysupgrade.tar := sysupgrade-tar | append-metadata
  IMAGE/factory.img := append-kernel | pad-to $$$$(KERNEL_SIZE) | append-ubi
  SUPPORTED_DEVICES += gl-x1200 glinet,gl-x1200
endef
TARGET_DEVICES += glinet_gl-x1200-nor-nand