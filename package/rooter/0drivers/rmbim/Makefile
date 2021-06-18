include $(TOPDIR)/rules.mk

PKG_NAME:=umbim
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=$(PROJECT_GIT)/project/umbim.git
PKG_SOURCE_DATE:=2019-09-11
PKG_SOURCE_VERSION:=184b707ddaa0acee84d02e0ffe599cb8b67782bd
PKG_MIRROR_HASH:=482ff69144f81fafed99035840f5a24e772472f2df2f3ac0219d6de791ac5835
PKG_MAINTAINER:=John Crispin <john@phrozen.org>

PKG_LICENSE:=GPLv2
PKG_LICENSE_FILES:=

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/rmbim
  SECTION:=net
  CATEGORY:=ROOter
  SUBMENU:=Drivers
  DEPENDS:=+libubox +kmod-usb-net +kmod-usb-net-cdc-mbim +luci-proto-mbim
  TITLE:=Control utility for mobile broadband modems
endef

define Package/rmbim/description
  rmbim is a command line tool for controlling mobile broadband modems using
  the MBIM-protocol.
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include -ffunction-sections -fdata-sections

TARGET_LDFLAGS += -Wl,--gc-sections

define Package/rmbim/install
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/umbim $(1)/sbin/
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,rmbim))
