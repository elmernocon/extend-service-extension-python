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
FROM python:3.10-slim-bullseye
ARG TARGETOS
ARG TARGETARCH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt requirements.txt
RUN python -m pip install -r requirements.txt
COPY --from=grpc-gateway-gen /build/gateway/apidocs ./apidocs
COPY gateway/third_party third_party
COPY src .
COPY --from=grpc-gateway-builder /output/$TARGETOS/$TARGETARCH/grpc_gateway .
COPY wrapper.sh .
RUN chmod +x wrapper.sh
# gRPC server port, gRPC gateway port, Prometheus /metrics port
EXPOSE 6565 8000 8080
CMD ./wrapper.sh
