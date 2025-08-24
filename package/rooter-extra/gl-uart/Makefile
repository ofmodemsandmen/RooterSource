#
# Copyright (C) 2017 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=gl-uart
PKG_VERSION:=3.0.9
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/gl-uart
	SECTION:=base
	CATEGORY:=gl-inet
	TITLE:=GL iNet QCA9563 and MCU 
	#DEPENDS:= +libjson-c 
endef

define Package/gl-uart/description
VPN daemon for gl-inet.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)
endef

define Package/gl-uart/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/gl_uart $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uartinit $(1)/usr/bin
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,gl-uart))
