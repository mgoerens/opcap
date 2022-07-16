.DEFAULT_GOAL:=help

BINARY?=bin/opcap
IMAGE_BUILDER?=podman
IMAGE_REPO?=quay.io/opdev
VERSION=$(shell git rev-parse HEAD)
RELEASE_TAG ?= "0.0.0"

PLATFORMS=linux
ARCHITECTURES=amd64 arm64 ppc64le s390x

.PHONY: build
build:
	go build -o $(BINARY) -ldflags "-X github.com/opdev/opcap/version.commit=$(VERSION) -X github.com/opdev/opcap/version.version=$(RELEASE_TAG)" main.go
	@ls | grep -e '^opcap$$' &> /dev/null

.PHONY: build-multi-arch
build-multi-arch: $(addprefix build-linux-,$(ARCHITECTURES))

define ARCHITECTURE_template
.PHONY: build-linux-$(1)
build-linux-$(1):
	GOOS=linux GOARCH=$(1) go build -o $(BINARY)-linux-$(1) -ldflags "-X github.com/opdev/opcap/version.commit=$(VERSION) \
				-X github.com/opdev/opcap/version.version=$(RELEASE_TAG)" main.go
endef

$(foreach arch,$(ARCHITECTURES),$(eval $(call ARCHITECTURE_template,$(arch))))

.PHONY: fmt
fmt: gofumpt
	${GOFUMPT} -l -w .
	git diff --exit-code

.PHONY: tidy
tidy:
	go mod tidy -compat=1.17
	git diff --exit-code

#.PHONY: image-build
#image-build:
#	$(IMAGE_BUILDER) build --build-arg release_tag=$(RELEASE_TAG) --build-arg opcap_commit=$(VERSION) -t $(IMAGE_REPO)/opcap:$(VERSION) .

#.PHONY: image-push
#image-push:
#	$(IMAGE_BUILDER) push $(IMAGE_REPO)/opcap:$(VERSION)

.PHONY: test
test:
	go test -v $$(go list ./...) \
	-ldflags "-X github.com/opdev/opcap/version.commit=bar -X github.com/opdev/opcap/version.version=foo"

.PHONY: cover
cover:
	go test -v \
	 -ldflags "-X github.com/opdev/opcap/version.commit=bar -X github.com/opdev/opcap/version.version=foo" \
	 $$(go list ./...) \
	 -race \
	 -cover -coverprofile=coverage.out

.PHONY: vet
vet:
	go vet ./...

.PHONY: clean
clean:
	@go clean
	@# cleans the binary created by make build
	$(shell if [ -f "$(BINARY)" ]; then rm -f $(BINARY); fi)
	@# cleans all the binaries created by make build-multi-arch
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES),\
	$(shell if [ -f "$(BINARY)-$(GOOS)-$(GOARCH)" ]; then rm -f $(BINARY)-$(GOOS)-$(GOARCH); fi)))

GOFUMPT = $(shell pwd)/bin/gofumpt
gofumpt: ## Download envtest-setup locally if necessary.
	$(call go-install-tool,$(GOFUMPT),mvdan.cc/gofumpt@latest)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-install-tool
@[ -f $(1) ] || { \
GOBIN=$(PROJECT_DIR)/bin go install $(2) ;\
}
endef