# Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash
PYTHONX := python

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := $(IMAGE_NAME)-builder
PYTHON_VERSION := 3.10

VENV_DIR := venv
SOURCE_DIR := src
TEST_DIR := test

PROJECT_DIR ?= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: proto test venv

venv:
	python${PYTHON_VERSION} -m venv ${VENV_DIR} \
			&& ${VENV_DIR}/bin/pip install -r requirements-dev.txt

proto:
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd):/build \
		-w /build \
		--entrypoint /bin/bash \
		rvolosatovs/protoc:4.1.0 \
			proto.sh

build_server: proto
	
build_gateway: proto
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-e GOCACHE=/data/.cache/go-cache \
		-e GOPATH=/data/.cache/go-path \
		-v $$(pwd):/data \
		-w /data/gateway \
		golang:1.20-alpine3.19 \
		go build -o grpc_gateway

run_server: venv proto
	docker run --rm -it -u $$(id -u):$$(id -g) \
			-e HOME=/data \
			--env-file .env \
			-v $(PROJECT_DIR):/data \
			-w /data \
			--entrypoint /bin/sh \
			-p 6565:6565 \
			-p 8080:8080 \
			python:${PYTHON_VERSION}-slim \
					-c 'ln -sf $$(which python) ${VENV_DIR}/bin/python-docker \
							&& PYTHONPATH=${SOURCE_DIR} GRPC_VERBOSITY=debug ${VENV_DIR}/bin/python-docker -m app'

run_gateway: proto
	docker run -it --rm -u $$(id -u):$$(id -g) \
		-e GOCACHE=/data/.cache/go-cache \
		-e GOPATH=/data/.cache/go-path \
		--env-file .env \
		-v $$(pwd):/data \
		-w /data/gateway \
		-p 8000:8000 \
		--add-host host.docker.internal:host-gateway \
		golang:1.20-alpine3.19 \
				go run main.go --grpc-addr host.docker.internal:6565

help: venv proto
	docker run --rm -t -u $$(id -u):$$(id -g) -v $(PROJECT_DIR):/data -w /data -e HOME=/data --entrypoint /bin/sh python:${PYTHON_VERSION}-slim \
			-c 'ln -sf $$(which python) ${VENV_DIR}/bin/python-docker \
					&& PYTHONPATH=${SOURCE_DIR} ${VENV_DIR}/bin/python-docker -m app --help'

build: build_server build_gateway

imagex:
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(IMAGE_NAME) --platform linux/amd64 .
	docker buildx build --tag $(IMAGE_NAME) --load .
	docker buildx rm --keep-state $(BUILDER)

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(REPO_URL):$(IMAGE_TAG) --platform linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)

test: venv proto
	docker run --rm -t -u $$(id -u):$$(id -g) -v $(PROJECT_DIR):/data -w /data -e HOME=/data --entrypoint /bin/sh python:${PYTHON_VERSION}-slim \
			-c 'ln -sf $$(which python) ${VENV_DIR}/bin/python-docker \
					&& PYTHONPATH=${SOURCE_DIR}:${TEST_DIR} ${VENV_DIR}/bin/python-docker -m app_tests'

test_functional_local_hosted: proto
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
	docker build --tag service-extension-test-functional -f test/functional/Dockerfile test/functional && \
	docker run --rm -t \
		--env-file $(ENV_PATH) \
		-e HOME=/data \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		-u $$(id -u):$$(id -g) \
		-v $(PROJECT_DIR):/data \
		-w /data service-extension-test-functional bash ./test/functional/test-local-hosted.sh

test_functional_accelbyte_hosted: proto
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
ifeq ($(shell uname), Linux)
	$(eval DARGS := -u $$(shell id -u):$$(shell id -g) --group-add $$(shell getent group docker | cut -d ':' -f 3))
endif
	docker build --tag service-extension-test-functional -f test/functional/Dockerfile test/functional && \
	docker run --rm -t \
		--env-file $(ENV_PATH) \
		-e HOME=/data \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		-e DOCKER_CONFIG=/tmp/.docker \
		-e PROJECT_DIR=$(PROJECT_DIR) \
		$(DARGS) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PROJECT_DIR):/data \
		-w /data service-extension-test-functional bash ./test/functional/test-accelbyte-hosted.sh
