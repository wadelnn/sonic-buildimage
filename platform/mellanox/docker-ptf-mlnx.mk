# docker image for docker-ptf-mlnx

DOCKER_PTF_MLNX = docker-ptf-mlnx.gz
$(DOCKER_PTF_MLNX)_PATH = $(DOCKERS_PATH)/docker-ptf-saithrift
$(DOCKER_PTF_MLNX)_DEPENDS += $(PYTHON_SAITHRIFT_MLNX)
$(DOCKER_PTF_MLNX)_LOAD_DOCKERS += $(DOCKER_PTF)
SONIC_DOCKER_IMAGES += $(DOCKER_PTF_MLNX)
