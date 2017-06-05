include $(PLATFORM_PATH)/cavm-sai.mk
include $(PLATFORM_PATH)/docker-syncd-cavm.mk
include $(PLATFORM_PATH)/docker-syncd-cavm-rpc.mk
include $(PLATFORM_PATH)/docker-orchagent-cavm.mk
include $(PLATFORM_PATH)/cavm-platform-modules.mk
include $(PLATFORM_PATH)/cavm-xpnet.mk
include $(PLATFORM_PATH)/one-image.mk
include $(PLATFORM_PATH)/libsaithrift-dev.mk
include $(PLATFORM_PATH)/python-saithrift.mk
include $(PLATFORM_PATH)/docker-ptf-cavm.mk

SONIC_ALL += $(SONIC_ONE_IMAGE) \
             $(DOCKER_FPM) \
             $(DOCKER_PTF_CAVM) \
             $(DOCKER_SYNCD_CAVM_RPC)

# Inject cavium sai into sairedis
$(LIBSAIREDIS)_DEPENDS += $(CAVM_SAI) $(CAVM_LIBSAI) $(LIBSAITHRIFT_DEV_CAVM)

# Runtime dependency on cavium sai is set only for syncd
$(SYNCD)_RDEPENDS += $(CAVM_SAI)

