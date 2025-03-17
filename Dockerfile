# Copyright (c) 2024 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

# gRPC Gateway Gen
FROM --platform=$BUILDPLATFORM rvolosatovs/protoc:4.1.0 AS grpc-gateway-gen
WORKDIR /build
COPY gateway gateway
COPY proto proto
COPY src src
COPY proto.sh .
RUN bash proto.sh

# gRPC Gateway Builder
FROM --platform=$BUILDPLATFORM golang:1.20 AS grpc-gateway-builder
ARG TARGETOS
ARG TARGETARCH
ARG GOOS=$TARGETOS
ARG GOARCH=$TARGETARCH
ARG CGO_ENABLED=0
WORKDIR /build
COPY gateway/go.mod gateway/go.sum .
RUN go mod download
COPY gateway/ .
RUN rm -rf pkg/pb
COPY --from=grpc-gateway-gen /build/gateway/pkg/pb ./pkg/pb
RUN go build -v -o /output/$TARGETOS/$TARGETARCH/grpc_gateway .

# Extend App
FROM ubuntu:22.04

ARG TARGETOS
ARG TARGETARCH

RUN apt update && \
    apt install -y python3-pip python-is-python3 && \
    python -m pip install --no-cache-dir --upgrade pip && \
    apt upgrade -y && \
    apt dist-upgrade -y && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1
# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

# Install pip requirements
WORKDIR /app
COPY requirements.txt requirements.txt
RUN python -m pip install --no-cache-dir --force-reinstall --requirement requirements.txt
COPY --from=grpc-gateway-gen /build/gateway/apidocs ./apidocs
COPY gateway/third_party third_party
COPY src .
COPY --from=grpc-gateway-builder /output/$TARGETOS/$TARGETARCH/grpc_gateway .
COPY wrapper.sh .
RUN chmod +x wrapper.sh

# Plugin arch gRPC server port
EXPOSE 6565
# gRPC gateway port
EXPOSE 8000
# Prometheus /metrics web server port
EXPOSE 8080

CMD ["sh", "/app/wrapper.sh"]
