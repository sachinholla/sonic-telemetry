ifeq ($(GOPATH),)
export GOPATH=/tmp/go
endif
export PATH := $(PATH):$(GOPATH)/bin

INSTALL := /usr/bin/install
DBDIR := /var/run/redis/sonic-db/
GO ?= /usr/local/go/bin/go
TOP_DIR := $(abspath ..)
MGMT_COMMON_DIR := $(TOP_DIR)/sonic-mgmt-common
BUILD_DIR := build/bin
export CVL_SCHEMA_PATH := $(MGMT_COMMON_DIR)/cvl/schema
export GOBIN := $(abspath $(BUILD_DIR))

SRC_FILES=$(shell find . -name '*.go' | grep -v '_test.go' | grep -v '/tests/')
TEST_FILES=$(wildcard *_test.go)
TELEMETRY_TEST_DIR = build/tests/gnmi_server
TELEMETRY_TEST_BIN = $(TELEMETRY_TEST_DIR)/server.test
ifeq ($(SONIC_TELEMETRY_READWRITE),y)
BLD_FLAGS := -tags readwrite
endif

GO_DEPS := vendor/.done
PATCHES := $(wildcard patches/*.patch)

all: sonic-telemetry $(TELEMETRY_TEST_BIN)

go.mod:
	$(GO) mod init github.com/Azure/sonic-telemetry

$(GO_DEPS): go.mod $(PATCHES)
	# FIXME temporary workaround for crypto not downloading..
	$(GO) get golang.org/x/crypto/ssh/terminal@e9b2fee46413
	
	$(GO) mod vendor
	$(MGMT_COMMON_DIR)/patches/apply.sh vendor
	cp -r $(GOPATH)/pkg/mod/golang.org/x/crypto@v0.0.0-20191206172530-e9b2fee46413 vendor/golang.org/x/crypto
	chmod -R u+w vendor
	patch -d vendor -p0 <patches/gnmi_cli.all.patch

go-deps: $(GO_DEPS)

go-deps-clean:
	$(RM) -r vendor

sonic-telemetry: $(GO_DEPS)
	$(GO) install -mod=vendor $(BLD_FLAGS) github.com/Azure/sonic-telemetry/telemetry
	$(GO) install -mod=vendor $(BLD_FLAGS) github.com/Azure/sonic-telemetry/dialout/dialout_client_cli
	$(GO) install github.com/jipanyang/gnxi/gnmi_get
	$(GO) install github.com/jipanyang/gnxi/gnmi_set
	$(GO) install -mod=vendor github.com/openconfig/gnmi/cmd/gnmi_cli

check:
	sudo mkdir -p ${DBDIR}
	sudo cp ./testdata/database_config.json ${DBDIR}
	sudo mkdir -p /usr/models/yang || true
	sudo find $(MGMT_COMMON_DIR)/models -name '*.yang' -exec cp {} /usr/models/yang/ \;
	-$(GO) test -mod=vendor $(BLD_FLAGS) -v github.com/Azure/sonic-telemetry/gnmi_server
	-$(GO) test -mod=vendor $(BLD_FLAGS) -v github.com/Azure/sonic-telemetry/dialout/dialout_client

clean:
	$(RM) -r build
	$(RM) -r vendor

$(TELEMETRY_TEST_BIN): $(TEST_FILES) $(SRC_FILES)
	mkdir -p $(@D)
	cp -r testdata $(@D)/
	$(GO) test -mod=vendor $(BLD_FLAGS) -c -cover github.com/Azure/sonic-telemetry/gnmi_server -o $@

install:
	$(INSTALL) -D $(BUILD_DIR)/telemetry $(DESTDIR)/usr/sbin/telemetry
	$(INSTALL) -D $(BUILD_DIR)/dialout_client_cli $(DESTDIR)/usr/sbin/dialout_client_cli
	$(INSTALL) -D $(BUILD_DIR)/gnmi_get $(DESTDIR)/usr/sbin/gnmi_get
	$(INSTALL) -D $(BUILD_DIR)/gnmi_set $(DESTDIR)/usr/sbin/gnmi_set
	$(INSTALL) -D $(BUILD_DIR)/gnmi_cli $(DESTDIR)/usr/sbin/gnmi_cli


deinstall:
	rm $(DESTDIR)/usr/sbin/telemetry
	rm $(DESTDIR)/usr/sbin/dialout_client_cli
	rm $(DESTDIR)/usr/sbin/gnmi_get
	rm $(DESTDIR)/usr/sbin/gnmi_set


