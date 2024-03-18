# Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash
PYTHONX := python

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := $(IMAGE_NAME)-builder

VENV_DIR := venv
SOURCE_DIR := src
TEST_DIR := test

PROJECT_DIR ?= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: venv test

clean-apidocs:
	rm -rfv apidocs/*

clean-app:
	find src -type f \( -iname '*_pb2.py' -o -iname '*_pb2.pyi' -o -iname '*_pb2_grpc.py' \) -delete

clean-gateway:
	rm -rfv gateway/pkg/pb/*

clean: clean-apidocs clean-app clean-gateway

protoc-apidocs: clean-apidocs
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $(PROJECT_DIR)/proto:/proto \
		--volume $(PROJECT_DIR)/apidocs:/apidocs \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=/proto/app \
			--openapiv2_out /apidocs \
			--openapiv2_opt logtostderr=true \
			--openapiv2_opt use_go_templates=true \
			guildService.proto

protoc-gateway: clean-gateway
	mkdir -p gateway/pkg/pb
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $(PROJECT_DIR)/proto:/proto \
		--volume $(PROJECT_DIR)/gateway:/gateway \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=/proto/app \
			--go_out=/gateway/pkg/pb \
			--go_opt=paths=source_relative \
			--go-grpc_out=require_unimplemented_servers=false:/gateway/pkg/pb \
			--go-grpc_opt=paths=source_relative \
			--grpc-gateway_out=logtostderr=true:/gateway/pkg/pb \
			--grpc-gateway_opt paths=source_relative \
			permission.proto \
			guildService.proto

protoc-app: clean-app
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $(PROJECT_DIR)/proto:/proto \
		--volume $(PROJECT_DIR)/src:/src \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=google/api=/proto/google/api \
			--proto_path=protoc-gen-openapiv2/options=/proto/protoc-gen-openapiv2/options \
			--grpc-python_out=/src \
			--pyi_out=/src \
			--python_out=/src \
			google/api/annotations.proto \
			google/api/http.proto \
			protoc-gen-openapiv2/options/annotations.proto \
			protoc-gen-openapiv2/options/openapiv2.proto
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $(PROJECT_DIR)/proto:/proto \
		--volume $(PROJECT_DIR)/src:/src \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=/proto/app \
			--grpc-python_out=/src/app/proto \
			--pyi_out=/src/app/proto \
			--python_out=/src/app/proto \
			permission.proto \
			guildService.proto

protoc: protoc-apidocs protoc-gateway protoc-app

venv:
	python3.9 -m venv ${VENV_DIR} \
			&& ${VENV_DIR}/bin/pip install -r requirements-dev.txt

build: protoc

run: venv protoc
	docker run --rm -it -u $$(id -u):$$(id -g) -v $(PROJECT_DIR):/data -w /data -e HOME=/data --entrypoint /bin/sh python:3.9-slim \
			-c 'ln -sf $$(which python) ${VENV_DIR}/bin/python-docker \
					&& PYTHONPATH=${SOURCE_DIR} GRPC_VERBOSITY=debug ${VENV_DIR}/bin/python-docker -m app'

help: venv protoc
	docker run --rm -t -u $$(id -u):$$(id -g) -v $(PROJECT_DIR):/data -w /data -e HOME=/data --entrypoint /bin/sh python:3.9-slim \
			-c 'ln -sf $$(which python) ${VENV_DIR}/bin/python-docker \
					&& PYTHONPATH=${SOURCE_DIR} ${VENV_DIR}/bin/python-docker -m app --help'

imagex:
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(IMAGE_NAME) --platform linux/arm64/v8,linux/amd64 .
	docker buildx build --tag $(IMAGE_NAME) --load .
	docker buildx rm --keep-state $(BUILDER)

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(REPO_URL):$(IMAGE_TAG) --platform linux/arm64/v8,linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)

test: venv protoc
	docker run --rm -t -u $$(id -u):$$(id -g) -v $(PROJECT_DIR):/data -w /data -e HOME=/data --entrypoint /bin/sh python:3.9-slim \
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
