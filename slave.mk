###############################################################################
## Presettings
###############################################################################

# Select bash for commands
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

.SECONDEXPANSION:

SPACE := 
SPACE += 

###############################################################################
## General definitions
###############################################################################

SRC_PATH = src
RULES_PATH = rules
TARGET_PATH = target
DOCKERS_PATH = dockers
DEBS_PATH = $(TARGET_PATH)/debs
PYTHON_WHEELS_PATH = $(TARGET_PATH)/python-wheels
PROJECT_ROOT = $(shell pwd)

CONFIGURED_PLATFORM := $(shell [ -f .platform ] && cat .platform || echo generic)
PLATFORM_PATH = platform/$(CONFIGURED_PLATFORM)
export BUILD_NUMBER

###############################################################################
## Utility rules
## Define configuration, help etc.
###############################################################################

.platform :
ifneq ($(CONFIGURED_PLATFORM),generic)
	@echo Build system is not configured, please run make configure
	@exit 1
endif

configure :
	@mkdir -p target/debs
	@mkdir -p target/python-wheels
	@echo $(PLATFORM) > .platform

distclean : .platform clean
	@rm -f .platform

###############################################################################
## Include other rules
###############################################################################


include $(RULES_PATH)/config
include $(RULES_PATH)/functions
include $(RULES_PATH)/*.mk
ifneq ($(CONFIGURED_PLATFORM), undefined)
include $(PLATFORM_PATH)/rules.mk
endif

ifeq ($(USERNAME),)
override USERNAME := $(DEFAULT_USERNAME)
endif

ifeq ($(PASSWORD),)
override PASSWORD := $(DEFAULT_PASSWORD)
endif

ifeq ($(SONIC_ENABLE_SYNCD_RPC),y)
ENABLE_SYNCD_RPC = y
endif

MAKEFLAGS += -j $(SONIC_CONFIG_BUILD_JOBS)

###############################################################################
## Dumping key config attributes associated to current building exercise
###############################################################################

ifndef $(CONFIGURED_PLATFORM)
$(info CONFIGURED_PLATFORM is $(CONFIGURED_PLATFORM))
endif

ifndef $(SONIC_ROUTING_STACK)
$(info ROUTING_STACK is $(SONIC_ROUTING_STACK))
endif

###############################################################################
## Generic rules section
## All rules must go after includes for propper targets expansion
###############################################################################

###############################################################################
## Local targets
###############################################################################

# Copy debian packages from local directory
# Add new package for copy:
#     SOME_NEW_DEB = some_new_deb.deb
#     $(SOME_NEW_DEB)_PATH = path/to/some_new_deb.deb
#     SONIC_COPY_DEBS += $(SOME_NEW_DEB)
$(addprefix $(DEBS_PATH)/, $(SONIC_COPY_DEBS)) : $(DEBS_PATH)/% : .platform
	$(HEADER)
	$(foreach deb,$* $($*_DERIVED_DEBS), \
	    { cp $($(deb)_PATH)/$(deb) $(DEBS_PATH)/ $(LOG) || exit 1 ; } ; )
	$(FOOTER)

# Copy regular files from local directory
# Add new package for copy:
#     SOME_NEW_FILE = some_new_file
#     $(SOME_NEW_FILE)_PATH = path/to/some_new_file
#     SONIC_COPY_FILES += $(SOME_NEW_FILE)
$(addprefix $(DEBS_PATH)/, $(SONIC_COPY_FILES)) : $(DEBS_PATH)/% : .platform
	$(HEADER)
	cp $($*_PATH)/$* $(DEBS_PATH)/ $(LOG) || exit 1
	$(FOOTER)

###############################################################################
## Online targets
###############################################################################

# Download debian packages from online location
# Add new package for download:
#     SOME_NEW_DEB = some_new_deb.deb
#     $(SOME_NEW_DEB)_URL = https://url/to/this/deb.deb
#     SONIC_ONLINE_DEBS += $(SOME_NEW_DEB)
$(addprefix $(DEBS_PATH)/, $(SONIC_ONLINE_DEBS)) : $(DEBS_PATH)/% : .platform
	$(HEADER)
	$(foreach deb,$* $($*_DERIVED_DEBS), \
	    { wget -O $(DEBS_PATH)/$(deb) $($(deb)_URL) $(LOG) || exit 1 ; } ; )
	$(FOOTER)

# Download regular files from online location
# Files are stored in deb packages directory for convenience
# Add new file for download:
#     SOME_NEW_FILE = some_new_file
#     $(SOME_NEW_FILE)_URL = https://url/to/this/file
#     SONIC_ONLINE_FILES += $(SOME_NEW_FILE)
$(addprefix $(DEBS_PATH)/, $(SONIC_ONLINE_FILES)) : $(DEBS_PATH)/% : .platform
	$(HEADER)
	wget -O  $@ $($*_URL) $(LOG)
	$(FOOTER)

###############################################################################
## Debian package related targets
###############################################################################

# Build project using build.sh script
# They are essentially a one-time build projects that get sources from some URL
# and compile them
# Add new package for build:
#     SOME_NEW_DEB = some_new_deb.deb
#     $(SOME_NEW_DEB)_SRC_PATH = $(SRC_PATH)/project_name
#     $(SOME_NEW_DEB)_DEPENDS = $(SOME_OTHER_DEB1) $(SOME_OTHER_DEB2) ...
#     SONIC_MAKE_DEBS += $(SOME_NEW_DEB)
$(addprefix $(DEBS_PATH)/, $(SONIC_MAKE_DEBS)) : $(DEBS_PATH)/% : .platform $$(addsuffix -install,$$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS)))
	$(HEADER)
	# remove target to force rebuild
	rm -f $(addprefix $(DEBS_PATH)/, $* $($*_DERIVED_DEBS) $($*_EXTRA_DEBS))
	# apply series of patches if exist
	if [ -f $($*_SRC_PATH).patch/series ]; then pushd $($*_SRC_PATH) && QUILT_PATCHES=../$(notdir $($*_SRC_PATH)).patch quilt push -a; popd; fi
	# build project and take package
	make DEST=$(shell pwd)/$(DEBS_PATH) -C $($*_SRC_PATH) $(shell pwd)/$(DEBS_PATH)/$* $(LOG)
	# clean up
	if [ -f $($*_SRC_PATH).patch/series ]; then pushd $($*_SRC_PATH) && quilt pop -a -f; popd; fi
	$(FOOTER)

# Build project with dpkg-buildpackage
# Add new package for build:
#     SOME_NEW_DEB = some_new_deb.deb
#     $(SOME_NEW_DEB)_SRC_PATH = $(SRC_PATH)/project_name
#     $(SOME_NEW_DEB)_DEPENDS = $(SOME_OTHER_DEB1) $(SOME_OTHER_DEB2) ...
#     SONIC_DPKG_DEBS += $(SOME_NEW_DEB)
$(addprefix $(DEBS_PATH)/, $(SONIC_DPKG_DEBS)) : $(DEBS_PATH)/% : .platform $$(addsuffix -install,$$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS)))
	$(HEADER)
	# Build project and take package
	rm -f $($*_SRC_PATH)/debian/*.debhelper.log
	# apply series of patches if exist
	if [ -f $($*_SRC_PATH).patch/series ]; then pushd $($*_SRC_PATH) && QUILT_PATCHES=../$(notdir $($*_SRC_PATH)).patch quilt push -a; popd; fi
	pushd $($*_SRC_PATH) $(LOG)
	[ ! -f ./autogen.sh ] || ./autogen.sh $(LOG)
	dpkg-buildpackage -rfakeroot -b -us -uc $(LOG)
	popd $(LOG)
	# clean up
	if [ -f $($*_SRC_PATH).patch/series ]; then pushd $($*_SRC_PATH) && quilt pop -a -f; popd; fi
	mv $(addprefix $($*_SRC_PATH)/../, $* $($*_DERIVED_DEBS) $($*_EXTRA_DEBS)) $(DEBS_PATH) $(LOG)
	$(FOOTER)

# Build project with python setup.py --command-packages=stdeb.command
# Add new package for build:
#     SOME_NEW_DEB = some_new_deb.deb
#     $(SOME_NEW_DEB)_SRC_PATH = $(SRC_PATH)/project_name
#     $(SOME_NEW_DEB)_DEPENDS = $(SOME_OTHER_DEB1) $(SOME_OTHER_DEB2) ...
#     SONIC_PYTHON_STDEB_DEBS += $(SOME_NEW_DEB)
$(addprefix $(DEBS_PATH)/, $(SONIC_PYTHON_STDEB_DEBS)) : $(DEBS_PATH)/% : .platform $$(addsuffix -install,$$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS)))
	$(HEADER)
	# Build project and take package
	pushd $($*_SRC_PATH) $(LOG)
	python setup.py --command-packages=stdeb.command bdist_deb $(LOG)
	popd $(LOG)
	mv $(addprefix $($*_SRC_PATH)/deb_dist/, $* $($*_DERIVED_DEBS)) $(DEBS_PATH) $(LOG)
	$(FOOTER)

# Rules for derived debian packages (dev, dbg, etc.)
# All noise takes place in main deb recipe, so we are just telling that
# we depend on it and move our deb to other targets
# Add new dev package:
#     $(eval $(call add_derived_package,$(ORIGINAL_DEB),derived_deb_file.deb))
$(addprefix $(DEBS_PATH)/, $(SONIC_DERIVED_DEBS)) : $(DEBS_PATH)/% : .platform $$(addsuffix -install,$$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS)))
	$(HEADER)
	# All noise takes place in main deb recipe, so we are just telling that
	# we depend on it
	# Put newer timestamp
	[ -f $@ ] && touch $@
	$(FOOTER)

# Rules for extra debian packages
# All noise takes place in main deb recipe, so we are just telling that
# we need to build the main deb and move our deb to other targets
# Add new dev package:
#     $(eval $(call add_extra_package,$(ORIGINAL_DEB),extra_deb_file.deb))
$(addprefix $(DEBS_PATH)/, $(SONIC_EXTRA_DEBS)) : $(DEBS_PATH)/% : .platform $$(addprefix $(DEBS_PATH)/,$$($$*_MAIN_DEB))
	$(HEADER)
	# All noise takes place in main deb recipe, so we are just telling that
	# we depend on it
	# Put newer timestamp
	[ -f $@ ] && touch $@
	$(FOOTER)

# Targets for installing debian packages prior to build one that depends on them
SONIC_INSTALL_TARGETS = $(addsuffix -install,$(addprefix $(DEBS_PATH)/, \
			$(SONIC_ONLINE_DEBS) \
			$(SONIC_COPY_DEBS) \
			$(SONIC_MAKE_DEBS) \
			$(SONIC_DPKG_DEBS) \
			$(SONIC_PYTHON_STDEB_DEBS) \
			$(SONIC_DERIVED_DEBS) \
			$(SONIC_EXTRA_DEBS)))
$(SONIC_INSTALL_TARGETS) : $(DEBS_PATH)/%-install : .platform $$(addsuffix -install,$$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS))) $(DEBS_PATH)/$$*
	$(HEADER)
	[ -f $(DEBS_PATH)/$* ] || { echo $(DEBS_PATH)/$* does not exist $(LOG) && exit 1; }
	# put a lock here because dpkg does not allow installing packages in parallel
	while true; do
	if mkdir $(DEBS_PATH)/dpkg_lock &> /dev/null; then
	{ sudo dpkg -i $(DEBS_PATH)/$* $(LOG) && rm -d $(DEBS_PATH)/dpkg_lock && break; } || { rm -d $(DEBS_PATH)/dpkg_lock && exit 1 ; }
	fi
	done
	$(FOOTER)

###############################################################################
## Python packages
###############################################################################

# Build project using python setup.py bdist_wheel
# Projects that generate python wheels
# Add new package for build:
#     SOME_NEW_WHL = some_new_whl.whl
#     $(SOME_NEW_WHL)_SRC_PATH = $(SRC_PATH)/project_name
#     $(SOME_NEW_WHL)_PYTHON_VERSION = 2 (or 3)
#     $(SOME_NEW_WHL)_DEPENDS = $(SOME_OTHER_WHL1) $(SOME_OTHER_WHL2) ...
#     SONIC_PYTHON_WHEELS += $(SOME_NEW_WHL)
$(addprefix $(PYTHON_WHEELS_PATH)/, $(SONIC_PYTHON_WHEELS)) : $(PYTHON_WHEELS_PATH)/% : .platform $$(addsuffix -install,$$(addprefix $(PYTHON_WHEELS_PATH)/,$$($$*_DEPENDS)))
	$(HEADER)
	pushd $($*_SRC_PATH) $(LOG)
	# apply series of patches if exist
	if [ -f ../$(notdir $($*_SRC_PATH)).patch/series ]; then QUILT_PATCHES=../$(notdir $($*_SRC_PATH)).patch quilt push -a; fi
	python$($*_PYTHON_VERSION) setup.py test $(LOG)
	python$($*_PYTHON_VERSION) setup.py bdist_wheel $(LOG)
	# clean up
	if [ -f ../$(notdir $($*_SRC_PATH)).patch/series ]; then quilt pop -a -f; fi
	popd $(LOG)
	mv $($*_SRC_PATH)/dist/$* $(PYTHON_WHEELS_PATH) $(LOG)
	$(FOOTER)

# Targets for installing python wheels.
# Autogenerated
SONIC_INSTALL_WHEELS = $(addsuffix -install, $(addprefix $(PYTHON_WHEELS_PATH)/, $(SONIC_PYTHON_WHEELS)))
$(SONIC_INSTALL_WHEELS) : $(PYTHON_WHEELS_PATH)/%-install : .platform $$(addsuffix -install,$$(addprefix $(PYTHON_WHEELS_PATH)/,$$($$*_DEPENDS))) $(PYTHON_WHEELS_PATH)/$$*
	$(HEADER)
	[ -f $(PYTHON_WHEELS_PATH)/$* ] || { echo $(PYTHON_WHEELS_PATH)/$* does not exist $(LOG) && exit 1; }
	# put a lock here to avoid race conditions
	while true; do
	if mkdir $(PYTHON_WHEELS_PATH)/pip_lock &> /dev/null; then
	{ sudo pip$($*_PYTHON_VERSION) install $(PYTHON_WHEELS_PATH)/$* $(LOG) && rm -d $(PYTHON_WHEELS_PATH)/pip_lock && break; } || { rm -d $(PYTHON_WHEELS_PATH)/pip_lock && exit 1 ; }
	fi
	done
	$(FOOTER)

###############################################################################
## Docker images related targets
###############################################################################

# start docker daemon
docker-start :
	@sudo service docker start &> /dev/null && sleep 1

# targets for building simple docker images that do not depend on any debian packages
$(addprefix $(TARGET_PATH)/, $(SONIC_SIMPLE_DOCKER_IMAGES)) : $(TARGET_PATH)/%.gz : .platform docker-start $$(addsuffix -load,$$(addprefix $(TARGET_PATH)/,$$($$*.gz_LOAD_DOCKERS)))
	$(HEADER)
	docker build --squash --no-cache -t $* $($*.gz_PATH) $(LOG)
	docker save $* | gzip -c > $@
	$(FOOTER)

# Targets for building docker images
$(addprefix $(TARGET_PATH)/, $(SONIC_DOCKER_IMAGES)) : $(TARGET_PATH)/%.gz : .platform docker-start $$(addprefix $(DEBS_PATH)/,$$($$*.gz_DEPENDS) $$($$*.gz_FILES)) $$(addprefix $(PYTHON_WHEELS_PATH)/,$$($$*.gz_PYTHON_WHEELS)) $$(addsuffix -load,$$(addprefix $(TARGET_PATH)/,$$($$*.gz_LOAD_DOCKERS))) $$($$*.gz_PATH)/Dockerfile.j2
	$(HEADER)
	mkdir -p $($*.gz_PATH)/debs $(LOG)
	mkdir -p $($*.gz_PATH)/python-wheels $(LOG)
	sudo mount --bind $(DEBS_PATH) $($*.gz_PATH)/debs $(LOG)
	sudo mount --bind $(PYTHON_WHEELS_PATH) $($*.gz_PATH)/python-wheels $(LOG)
	# Export variables for j2. Use path for unique variable names, e.g. docker_orchagent_debs
	$(eval export $(subst -,_,$(notdir $($*.gz_PATH)))_debs=$(shell printf "$(subst $(SPACE),\n,$(call expand,$($*.gz_DEPENDS),RDEPENDS))\n" | awk '!a[$$0]++'))
	$(eval export $(subst -,_,$(notdir $($*.gz_PATH)))_whls=$(shell printf "$(subst $(SPACE),\n,$(call expand,$($*.gz_PYTHON_WHEELS)))\n" | awk '!a[$$0]++'))
	$(eval export $(subst -,_,$(notdir $($*.gz_PATH)))_dbgs=$(shell printf "$(subst $(SPACE),\n,$(call expand,$($*.gz_DBG_PACKAGES)))\n" | awk '!a[$$0]++'))
	j2 $($*.gz_PATH)/Dockerfile.j2 > $($*.gz_PATH)/Dockerfile
	docker build --squash --no-cache -t $* $($*.gz_PATH) $(LOG)
	docker save $* | gzip -c > $@
	$(FOOTER)

DOCKER_LOAD_TARGETS = $(addsuffix -load,$(addprefix $(TARGET_PATH)/, \
		      $(SONIC_SIMPLE_DOCKER_IMAGES) \
		      $(SONIC_DOCKER_IMAGES)))
$(DOCKER_LOAD_TARGETS) : $(TARGET_PATH)/%.gz-load : .platform docker-start $$(TARGET_PATH)/$$*.gz
	$(HEADER)
	docker load -i $(TARGET_PATH)/$*.gz $(LOG)
	$(FOOTER)

###############################################################################
## Installers
###############################################################################

# targets for building installers with base image
$(addprefix $(TARGET_PATH)/, $(SONIC_INSTALLERS)) : $(TARGET_PATH)/% : .platform onie-image.conf $$(addprefix $(DEBS_PATH)/,$$($$*_DEPENDS)) $$(addprefix $(DEBS_PATH)/,$$($$*_INSTALLS)) $(addprefix $(DEBS_PATH)/,$(INITRAMFS_TOOLS) $(LINUX_KERNEL) $(IGB_DRIVER) $(SONIC_DEVICE_DATA) $(SONIC_UTILS)) $$(addprefix $(TARGET_PATH)/,$$($$*_DOCKERS)) $$(addprefix $(PYTHON_WHEELS_PATH)/,$(SONIC_CONFIG_ENGINE))
	$(HEADER)
	## Pass initramfs and linux kernel explicitly. They are used for all platforms
	export initramfs_tools="$(DEBS_PATH)/$(INITRAMFS_TOOLS)"
	export linux_kernel="$(DEBS_PATH)/$(LINUX_KERNEL)"
	export kversion="$(KVERSION)"
	export image_type="$($*_IMAGE_TYPE)"
	export sonicadmin_user="$(USERNAME)"
	export sonic_asic_platform="$(CONFIGURED_PLATFORM)"
	export enable_dhcp_graph_service="$(ENABLE_DHCP_GRAPH_SERVICE)"
	export installer_debs="$(addprefix $(DEBS_PATH)/,$($*_DEPENDS))"
	export lazy_installer_debs="$(foreach deb, $($*_INSTALLS),$(foreach device, $($(deb)_PLATFORM),$(addprefix $(device)@, $(DEBS_PATH)/$(deb))))"
	export installer_images="$(addprefix $(TARGET_PATH)/,$($*_DOCKERS))"
	export config_engine_wheel_path="$(addprefix $(PYTHON_WHEELS_PATH)/,$(SONIC_CONFIG_ENGINE))"
	export swsssdk_py2_wheel_path="$(addprefix $(PYTHON_WHEELS_PATH)/,$(SWSSSDK_PY2))"
	
	$(foreach docker, $($*_DOCKERS),\
		export docker_image="$(docker)"
		export docker_image_name="$(basename $(docker))"
		export docker_container_name="$($(docker)_CONTAINER_NAME)"
		export docker_image_run_opt="$($(docker)_RUN_OPT)"
		j2 files/build_templates/docker_image_ctl.j2 > $($(docker)_CONTAINER_NAME).sh
		if [ -f files/build_templates/$($(docker)_CONTAINER_NAME).service.j2 ]; then
			j2 files/build_templates/$($(docker)_CONTAINER_NAME).service.j2 > $($(docker)_CONTAINER_NAME).service
		fi
		chmod +x $($(docker)_CONTAINER_NAME).sh
	)

	export installer_start_scripts="$(foreach docker, $($*_DOCKERS),$(addsuffix .sh, $($(docker)_CONTAINER_NAME)))"
	export installer_services="$(foreach docker, $($*_DOCKERS),$(addsuffix .service, $($(docker)_CONTAINER_NAME)))"
	export installer_extra_files="$(foreach docker, $($*_DOCKERS), $(foreach file, $($(docker)_BASE_IMAGE_FILES), $($(docker)_PATH)/base_image_files/$(file)))"

	j2 -f env files/initramfs-tools/union-mount.j2 onie-image.conf > files/initramfs-tools/union-mount
	j2 -f env files/initramfs-tools/arista-convertfs.j2 onie-image.conf > files/initramfs-tools/arista-convertfs

	$(if $($*_DOCKERS), 
		j2 files/build_templates/sonic_debian_extension.j2 > sonic_debian_extension.sh
		chmod +x sonic_debian_extension.sh,
	)

	./build_debian.sh "$(USERNAME)" "$(shell perl -e 'print crypt("$(PASSWORD)", "salt"),"\n"')" $(LOG)
	TARGET_MACHINE=$($*_MACHINE) IMAGE_TYPE=$($*_IMAGE_TYPE) ./build_image.sh $(LOG)

	$(foreach docker, $($*_DOCKERS), \
		rm -f $($(docker)_CONTAINER_NAME).sh
		rm -f $($(docker)_CONTAINER_NAME).service
	)

	$(if $($*_DOCKERS),
		rm sonic_debian_extension.sh,
	)

	chmod a+x $@
	$(FOOTER)

###############################################################################
## Clean targets
###############################################################################

SONIC_CLEAN_DEBS = $(addsuffix -clean,$(addprefix $(DEBS_PATH)/, \
		   $(SONIC_ONLINE_DEBS) \
		   $(SONIC_ONLINE_FILES) \
		   $(SONIC_COPY_DEBS) \
		   $(SONIC_COPY_FILES) \
		   $(SONIC_MAKE_DEBS) \
		   $(SONIC_DPKG_DEBS) \
		   $(SONIC_PYTHON_STDEB_DEBS) \
		   $(SONIC_DERIVED_DEBS) \
		   $(SONIC_EXTRA_DEBS)))
$(SONIC_CLEAN_DEBS) : $(DEBS_PATH)/%-clean : .platform $$(addsuffix -clean,$$(addprefix $(DEBS_PATH)/,$$($$*_MAIN_DEB)))
	@# remove derived or extra targets if main one is removed, because we treat them
	@# as part of one package
	@rm -f $(addprefix $(DEBS_PATH)/, $* $($*_DERIVED_DEBS) $($*_EXTRA_DEBS))

SONIC_CLEAN_TARGETS += $(addsuffix -clean,$(addprefix $(TARGET_PATH)/, \
		       $(SONIC_DOCKER_IMAGES) \
		       $(SONIC_SIMPLE_DOCKER_IMAGES) \
		       $(SONIC_INSTALLERS)))
$(SONIC_CLEAN_TARGETS) : $(TARGET_PATH)/%-clean : .platform
	@rm -f $(TARGET_PATH)/$*

SONIC_CLEAN_WHEELS = $(addsuffix -clean,$(addprefix $(PYTHON_WHEELS_PATH)/, \
		     $(SONIC_PYTHON_WHEELS)))
$(SONIC_CLEAN_WHEELS) : $(PYTHON_WHEELS_PATH)/%-clean : .platform
	@rm -f $(PYTHON_WHEELS_PATH)/$*

clean-logs : .platform
	@rm -f $(TARGET_PATH)/*.log $(DEBS_PATH)/*.log

clean : .platform clean-logs $$(SONIC_CLEAN_DEBS) $$(SONIC_CLEAN_TARGETS) $$(SONIC_CLEAN_WHEELS)

###############################################################################
## all
###############################################################################

all : .platform $$(addprefix $(TARGET_PATH)/,$$(SONIC_ALL))

###############################################################################
## Standard targets
###############################################################################

.PHONY : $(SONIC_CLEAN_DEBS) $(SONIC_CLEAN_TARGETS) $(SONIC_CLEAN_WHEELS) clean distclean configure

.INTERMEDIATE : $(SONIC_INSTALL_TARGETS) $(SONIC_INSTALL_WHEELS) $(DOCKER_LOAD_TARGETS) docker-start .platform
