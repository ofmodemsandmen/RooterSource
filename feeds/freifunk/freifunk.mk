#
# Copyright (C) 2008-2015 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

LUCIMKFILE:=$(wildcard $(TOPDIR)/feeds/*/luci.mk)

# verify that there is only one single file returned
ifneq (1,$(words $(LUCIMKFILE)))
ifeq (0,$(words $(LUCIMKFILE)))
$(error did not find luci.mk in any feed)
else
$(error found multiple luci.mk files in the feeds)
endif
else
#$(info found luci.mk at $(LUCIMKFILE))
endif

include $(LUCIMKFILE)
