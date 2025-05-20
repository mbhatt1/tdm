# Image URL to use all building/pushing image targets
IMG_LIME_CTRL ?= lime-ctrl:latest
IMG_KVM_DEVICE_PLUGIN ?= kvm-device-plugin:latest

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes
# This is a requirement for 'setup-envtest.sh' in the test target
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

test: fmt vet ## Run tests.
	go test ./... -coverprofile cover.out

##@ Build

build: build-lime-ctrl build-kvm-device-plugin ## Build all binaries.

build-lime-ctrl: fmt vet ## Build lime-ctrl binary.
	go build -o bin/lime-ctrl cmd/lime-ctrl/main.go

build-kvm-device-plugin: fmt vet ## Build kvm-device-plugin binary.
	go build -o bin/kvm-device-plugin cmd/kvm-device-plugin/main.go

run-lime-ctrl: fmt vet ## Run lime-ctrl from your host.
	go run ./cmd/lime-ctrl/main.go

run-kvm-device-plugin: fmt vet ## Run kvm-device-plugin from your host.
	go run ./cmd/kvm-device-plugin/main.go

docker-build: docker-build-lime-ctrl docker-build-kvm-device-plugin ## Build all docker images.

docker-build-lime-ctrl: ## Build lime-ctrl docker image.
	docker build -t ${IMG_LIME_CTRL} -f build/lime-ctrl/Dockerfile .

docker-build-kvm-device-plugin: ## Build kvm-device-plugin docker image.
	docker build -t ${IMG_KVM_DEVICE_PLUGIN} -f build/kvm-device-plugin/Dockerfile .

docker-push: docker-push-lime-ctrl docker-push-kvm-device-plugin ## Push all docker images.

docker-push-lime-ctrl: ## Push lime-ctrl docker image.
	docker push ${IMG_LIME_CTRL}

docker-push-kvm-device-plugin: ## Push kvm-device-plugin docker image.
	docker push ${IMG_KVM_DEVICE_PLUGIN}

##@ Deployment

install-crds: ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	kubectl apply -f deploy/crds/

uninstall-crds: ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	kubectl delete -f deploy/crds/

deploy: install-crds ## Deploy all components to the K8s cluster specified in ~/.kube/config.
	kubectl apply -f deploy/

undeploy: ## Undeploy all components from the K8s cluster specified in ~/.kube/config.
	kubectl delete -f deploy/
	kubectl delete -f deploy/crds/

##@ Lima

lima-setup: ## Setup Lima VM for development.
	limactl start --name=vvm-dev template://k8s

lima-shell: ## Shell into Lima VM.
	limactl shell vvm-dev

lima-stop: ## Stop Lima VM.
	limactl stop vvm-dev

lima-delete: ## Delete Lima VM.
	limactl delete vvm-dev