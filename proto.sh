#!/bin/bash

set -e

# Generate protobuf code
find src -type f \( -iname '*_pb2.py' -o -iname '*_pb2.pyi' -o -iname '*_pb2_grpc.py' \) -delete
protoc-wrapper -I/usr/include  \
        --proto_path=google/api=proto/google/api \
        --proto_path=protoc-gen-openapiv2/options=proto/protoc-gen-openapiv2/options \
        --grpc-python_out=src \
        --pyi_out=src \
        --python_out=src \
        google/api/annotations.proto \
        google/api/http.proto \
        protoc-gen-openapiv2/options/annotations.proto \
        protoc-gen-openapiv2/options/openapiv2.proto
protoc-wrapper -I/usr/include  \
        --proto_path=proto/app \
        --grpc-python_out=src/app/proto \
        --pyi_out=src/app/proto \
        --python_out=src/app/proto \
        permission.proto \
        service.proto

# Generate gateway code
rm -rf gateway/pkg/pb/*
mkdir -p gateway/pkg/pb
protoc-wrapper -I/usr/include  \
        --proto_path=proto/app \
        --go_out=gateway/pkg/pb \
        --go_opt=paths=source_relative \
        --go-grpc_out=require_unimplemented_servers=false:gateway/pkg/pb \
        --go-grpc_opt=paths=source_relative \
        --grpc-gateway_out=logtostderr=true:gateway/pkg/pb \
        --grpc-gateway_opt paths=source_relative \
        permission.proto \
        service.proto

# Generate swagger.json
rm -rf gateway/apidocs/*
protoc-wrapper -I/usr/include  \
        --proto_path=proto/app \
        --openapiv2_out gateway/apidocs \
        --openapiv2_opt logtostderr=true \
        --openapiv2_opt use_go_templates=true \
        service.proto
