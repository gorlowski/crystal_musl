BASE_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

CURL := curl -RL

CC = musl-gcc
CFLAGS += -O3	# last one wins
CXXFLAGS += -O3

CONFIGURE_ENV = env CC=$(CC) CFLAGS=$(CFLAGS) CXXFLAGS=$(CXXFLAGS)

CRYSTAL = $(shell which crystal)
CRYSTAL_ROOT = $(shell dirname $(shell dirname $(shell readlink -f $(CRYSTAL))))
PREFIX = $(CRYSTAL_ROOT)/lib/crystal_musl

# The libgc maintainers state on their project page that v8.0.0 is an experimental
# release. If you have trouble, you may need to try 7.6.10 or newer releases > 8.0.0.
LIBGC_VERSION = 8.0.0
LIBEVENT_VERSION = 2.1.8-stable
LIBPCRE_VERSION = 8.39

BUILD_DIR = $(BASE_DIR)/build

LIBCRYSTAL_SOURCES = $(CRYSTAL_ROOT)/share/crystal/src/ext/*.c
LIBCRYSTAL_ARCHIVE = $(PREFIX)/lib/libcrystal.a

LIBGC_SOURCE_DIR = $(BUILD_DIR)/gc-$(LIBGC_VERSION)
LIBEVENT_SOURCE_DIR = $(BUILD_DIR)/libevent-$(LIBEVENT_VERSION)
LIBPCRE_SOURCE_DIR = $(BUILD_DIR)/pcre-$(LIBPCRE_VERSION)

LIBGC_SOURCE_URL = https://github.com/ivmai/bdwgc/releases/download/v$(LIBGC_VERSION)/gc-$(LIBGC_VERSION).tar.gz
LIBEVENT_SOURCE_URL = https://github.com/libevent/libevent/releases/download/release-$(LIBEVENT_VERSION)/libevent-$(LIBEVENT_VERSION).tar.gz
LIBPCRE_SOURCE_URL = https://ftp.pcre.org/pub/pcre/pcre-$(LIBPCRE_VERSION).tar.gz

LIBGC_SOURCE_ARCHIVE = gc-$(LIBGC_VERSION).tar.gz
LIBEVENT_SOURCE_ARCHIVE = libevent-$(LIBEVENT_VERSION).tar.gz
LIBPCRE_SOURCE_ARCHIVE = pcre-$(LIBPCRE_VERSION).tar.gz

SOURCE_ARCHIVES = $(LIBGC_SOURCE_ARCHIVE) $(LIBEVENT_SOURCE_ARCHIVE) $(LIBPCRE_SOURCE_ARCHIVE)

LIBGC_LOCAL_SOURCE_ARCHIVE = $(BUILD_DIR)/$(LIBGC_SOURCE_ARCHIVE)
LIBEVENT_LOCAL_SOURCE_ARCHIVE = $(BUILD_DIR)/$(LIBEVENT_SOURCE_ARCHIVE)
LIBPCRE_LOCAL_SOURCE_ARCHIVE = $(BUILD_DIR)/$(LIBPCRE_SOURCE_ARCHIVE)

LIBEVENT_ARCHIVE = $(LIBEVENT_SOURCE_DIR)/.libs/libevent.a
LIBGC_ARCHIVE = $(LIBGC_SOURCE_DIR)/.libs/libgc.a
LIBPCRE_ARCHIVE = $(LIBPCRE_SOURCE_DIR)/.libs/libpcre.a

build: $(LIBPCRE_ARCHIVE) $(LIBGC_ARCHIVE) $(LIBEVENT_ARCHIVE) $(LIBCRYSTAL_ARCHIVE)
install: install_event install_pcre install_gc install_scripts

$(PREFIX):
	mkdir -p $(PREFIX)

fetch_sources: $(LIBGC_SOURCE_DIR) $(LIBEVENT_SOURCE_DIR) $(LIBPCRE_SOURCE_DIR)
help:
	@echo "Library versions to build with musl:" 
	@echo -n "- "
	@echo $(SOURCE_ARCHIVES) | sed 's/.tar.gz//g' | sed "s/  */\n- /g"
	@echo 
	@echo "Using CC=$(CC)"
	@echo "Preparing to install library archives compiled against musl to PREFIX=$(PREFIX)"
	@echo 
	@echo "To fetch remote source libraries, run: make fetch_sources"
	@echo "To compile libraries, run: make build"
	@echo "To install libraries, run: make install"
	@echo 
	@echo "To fetch sources, compile + install all in one step, run: make all"
	@echo 

all: fetch_sources build install

install_event: $(LIBEVENT_ARCHIVE)
	cd $(LIBEVENT_SOURCE_DIR) && make install
install_gc: $(LIBGC_ARCHIVE)
	cd $(LIBGC_SOURCE_DIR) && make install
install_pcre: $(LIBPCRE_ARCHIVE)
	cd $(LIBPCRE_SOURCE_DIR) && make install
install_scripts:
	cp $(BASE_DIR)/bin/crystal_musl $(CRYSTAL_ROOT)/bin/crystal_musl

$(LIBCRYSTAL_ARCHIVE): $(LIBCRYSTAL_SOURCES)
	$(CC) -o $(BUILD_DIR)/libcrystal.o -c -O3 $<
	$(AR) -rc $@ $(BUILD_DIR)/libcrystal.o

libevent: $(LIBEVENT_SOURCE_DIR) $(LIBEVENT_ARCHIVE)
libpcre: $(LIBPCRE_SOURCE_DIR) $(LIBPCRE_ARCHIVE)
libgc: $(LIBGC_SOURCE_DIR) $(LIBGC_ARCHIVE)

$(LIBEVENT_SOURCE_DIR)/Makefile:
	cd $(LIBEVENT_SOURCE_DIR); $(CONFIGURE_ENV) ./configure \
		--prefix="$(PREFIX)" \
		--disable-openssl \
		--enable-static

$(LIBEVENT_ARCHIVE): $(LIBEVENT_SOURCE_DIR)/Makefile 
	cd $(LIBEVENT_SOURCE_DIR); make

# This will likely not work with versions of libgc < 8 unless we add libatomic. Try without it.
$(LIBGC_SOURCE_DIR)/Makefile:
	cd $(LIBGC_SOURCE_DIR); $(CONFIGURE_ENV) ./configure \
		--prefix="$(PREFIX)" \
		--enable-static

$(LIBGC_ARCHIVE): $(LIBGC_SOURCE_DIR)/Makefile
	cd $(LIBGC_SOURCE_DIR); make

$(LIBPCRE_SOURCE_DIR)/Makefile:
	cd $(LIBPCRE_SOURCE_DIR); $(CONFIGURE_ENV) ./configure \
		--prefix="$(PREFIX)" \
		--disable-openssl \
		--enable-utf \
		--enable-static

$(LIBPCRE_ARCHIVE): $(LIBPCRE_SOURCE_DIR)/Makefile 
	cd $(LIBPCRE_SOURCE_DIR); make

### Sources
$(LIBGC_LOCAL_SOURCE_ARCHIVE):
	mkdir -p $(BUILD_DIR)
	[ -f "$@" ] || $(CURL) -o "$@" "$(LIBGC_SOURCE_URL)"
$(LIBEVENT_LOCAL_SOURCE_ARCHIVE):
	mkdir -p $(BUILD_DIR)
	[ -f "$@" ] || $(CURL) -o "$@" "$(LIBEVENT_SOURCE_URL)"
$(LIBPCRE_LOCAL_SOURCE_ARCHIVE):
	mkdir -p $(BUILD_DIR)
	[ -f "$@" ] || $(CURL) -o "$@" "$(LIBPCRE_SOURCE_URL)"

### Unpack sources
$(LIBGC_SOURCE_DIR): $(LIBGC_LOCAL_SOURCE_ARCHIVE)
	if [ ! -f "$@"/configure ]; then cd "$(BUILD_DIR)" && tar xzvf $(LIBGC_SOURCE_ARCHIVE); fi
	touch $@
$(LIBEVENT_SOURCE_DIR): $(LIBEVENT_LOCAL_SOURCE_ARCHIVE)
	if [ ! -f "$@"/configure ]; then cd "$(BUILD_DIR)" && tar xzvf $(LIBEVENT_SOURCE_ARCHIVE); fi
	touch $@
$(LIBPCRE_SOURCE_DIR): $(LIBPCRE_LOCAL_SOURCE_ARCHIVE)
	if [ ! -f "$@"/configure ]; then cd "$(BUILD_DIR)" && tar xzvf $(LIBPCRE_SOURCE_ARCHIVE); fi
	touch $@

clean:
	$(RM) -r $(BUILD_DIR)/*

.PHONY: fetch_sources libevent libgc libpcre help build
.PHONY: install install_event install_pcre install_gc
.DEFAULT_GOAL := help
