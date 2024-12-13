# Copyright (c) 2024 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := extend-builder

PYTHON_VERSION := 3.10

TEST_SAMPLE_CONTAINER_NAME := sample-service-extension-test

SOURCE_DIR := src
TEST_DIR := test

.PHONY: proto test

proto:
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd):/build \
		-w /build \
		--entrypoint /bin/bash \
		rvolosatovs/protoc:4.1.0 \
			proto.sh

build_server:
	
build_gateway: proto
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-e GOCACHE=/data/.cache/go-cache \
		-e GOPATH=/data/.cache/go-path \
		-v $$(pwd):/data \
		-w /data/gateway \
		golang:1.20-alpine3.19 \
		go build -o grpc_gateway

run_server:
	docker run --rm -it -u $$(id -u):$$(id -g) \
		-e HOME=/data \
		--env-file .env \
		-v $$(pwd):/data \
		-w /data \
		--entrypoint /bin/sh \
		-p 6565:6565 \
		-p 8080:8080 \
		python:${PYTHON_VERSION}-slim \
		-c 'python -m pip install -r requirements.txt \
			&& PYTHONPATH=${SOURCE_DIR}:${TEST_DIR} python -m app'

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

help:
	docker run --rm -t \
		-u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data \
		-e HOME=/data \
		--entrypoint /bin/sh \
		python:${PYTHON_VERSION}-slim \
		-c 'python -m pip install -r requirements.txt \
			&& PYTHONPATH=${SOURCE_DIR}:${TEST_DIR} python -m app --help'

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

test_with_env:
	@test -n "$(ENV_FILE_PATH)" || (echo "ENV_FILE_PATH is not set" ; exit 1)
	docker run --rm -t \
		-u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data -e HOME=/data \
		--env-file $(ENV_FILE_PATH)  \
		--entrypoint /bin/sh \
		python:${PYTHON_VERSION}-slim \
		-c 'python -m pip install -r requirements-dev.txt \
			&& PYTHONPATH=${SOURCE_DIR}:${TEST_DIR} python -m app_tests'

test_sample_local_hosted:
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
	docker build \
		--tag $(TEST_SAMPLE_CONTAINER_NAME) \
		-f test/sample/Dockerfile \
		test/sample
	docker run --rm -t \
		-u $$(id -u):$$(id -g) \
		-e HOME=/data \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		--env-file $(ENV_PATH) \
		-v $$(pwd):/data \
		-w /data \
		--name $(TEST_SAMPLE_CONTAINER_NAME) \
		$(TEST_SAMPLE_CONTAINER_NAME) \
		bash ./test/sample/test-local-hosted.sh

test_sample_accelbyte_hosted:
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
ifeq ($(shell uname), Linux)
	$(eval DARGS := -u $$(shell id -u) --group-add $$(shell getent group docker | cut -d ':' -f 3))
endif
	docker build \
		--tag $(TEST_SAMPLE_CONTAINER_NAME) \
		-f test/sample/Dockerfile \
		test/sample
	docker run --rm -t \
		-e HOME=/data \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		-e DOCKER_CONFIG=/tmp/.docker \
		--env-file $(ENV_PATH) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $$(pwd):/data \
		-w /data \
		--name $(TEST_SAMPLE_CONTAINER_NAME) \
		$(DARGS) \
		$(TEST_SAMPLE_CONTAINER_NAME) \
		bash ./test/sample/test-accelbyte-hosted.sh
