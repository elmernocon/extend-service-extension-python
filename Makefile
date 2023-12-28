# Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash
PYTHONX := python

IMAGE_NAME := $(shell basename "$$(pwd)")-app

BUILDER := $(IMAGE_NAME)-builder


clean-apidocs:
	rm -rfv apidocs/*

clean-app:
	find src -type f \( -iname '*_pb2.py' -o -iname '*_pb2.pyi' -o -iname '*_pb2_grpc.py' \) -delete

clean-gateway:
	rm -rfv gateway/pkg/pb/*

clean: clean-apidocs clean-app clean-gateway

protoc-apidocs: clean-apidocs
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $$(pwd)/proto:/proto \
		--volume $$(pwd)/apidocs:/apidocs \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=/proto/app \
			--openapiv2_out /apidocs \
			--openapiv2_opt logtostderr=true \
			--openapiv2_opt use_go_templates=true \
			guildService.proto

protoc-app: clean-app
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $$(pwd)/proto:/proto \
		--volume $$(pwd)/src:/src \
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
		--volume $$(pwd)/proto:/proto \
		--volume $$(pwd)/src:/src \
		rvolosatovs/protoc:4.1.0 \
			--proto_path=/proto/app \
			--grpc-python_out=/src/app/proto \
			--pyi_out=/src/app/proto \
			--python_out=/src/app/proto \
			permission.proto \
			guildService.proto
	sed -i 's/import permission_pb2 as permission__pb2/from . import permission_pb2 as permission__pb2/' \
		src/app/proto/guildService_pb2.py
	sed -i 's/import permission_pb2 as _permission_pb2/from . import permission_pb2 as _permission_pb2/' \
		src/app/proto/guildService_pb2.pyi
	sed -i 's/import guildService_pb2 as guildService__pb2/from . import guildService_pb2 as guildService__pb2/' \
		src/app/proto/guildService_pb2_grpc.py

protoc-gateway: clean-gateway
	mkdir -p gateway/pkg/pb
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $$(pwd)/proto:/proto \
		--volume $$(pwd)/gateway:/gateway \
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

protoc: protoc-apidocs protoc-app protoc-gateway

build-gateway: OS=linux
build-gateway:
	docker run --tty --rm --user $$(id -u):$$(id -g) \
		--volume $$(pwd)/gateway:/gateway \
		--workdir /gateway \
		--env CGO_ENABLED=1 \
		--env GOCACHE=/gateway/.cache/go-build \
		--env GOOS=$(OS) \
		golang:1.20-bullseye \
		sh -c "go mod tidy && go mod verify && go build -o gateway.so -buildmode=c-shared extend-grpc-gateway"
	mv gateway/gateway.h gateway.h
	mv gateway/gateway.so gateway.so

install:
	$(PYTHONX) -m pip install .

run:
	$(PYTHONX) -m app --gateway

image:
	docker build --tag $(IMAGE_NAME) .

build: image

run: .env
	docker run --rm --env-file .env -p 6565:6565 -p 8000:8000 -p 8080:8080 $(IMAGE_NAME)

imagex:
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(IMAGE_NAME) --platform linux/arm64/v8,linux/amd64 .
	docker buildx build --tag $(IMAGE_NAME) --load .
	#docker buildx rm $(BUILDER)

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build --tag $(REPO_URL):$(IMAGE_TAG) --platform linux/arm64/v8,linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)

test: .env
	docker run --tty --rm \
		--env-file '.env' \
		--volume $$(pwd):/data \
		--workdir /data \
		python:3.9-slim-bullseye \
		sh -c "python -m pip install . && \
				PYTHONPATH=tests python -m app_tests"
