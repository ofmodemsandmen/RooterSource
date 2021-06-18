#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-mosquitto
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-mosquitto
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Optional Applications
  DEPENDS:=+mosquitto-ssl +mosquitto-client-ssl +libmosquitto +lua-mosquitto
  TITLE:=Install scripts for MQTT Remote
  PKGARCH:=all
endef

define Package/ext-mosquitto/description
  Helper scripts to install scripts for MQTT Remote
endef


define Build/Compile
endef

define Package/ext-mosquitto/install
	$(CP) ./files/* $(1)/


endef

$(eval $(call BuildPackage,ext-mosquitto))
