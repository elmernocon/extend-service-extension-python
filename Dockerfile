FROM golang:1.20-bullseye as gateway-builder
WORKDIR /build
COPY gateway .
RUN go mod tidy \
        && CGO_ENABLED=0 go build -o /output/gateway extend-grpc-gateway


FROM python:3.9-slim-bullseye
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
RUN apt-get update  \
        && apt-get install -y supervisor procps --no-install-recommends \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt requirements.txt
RUN python -m pip install -r requirements.txt
COPY apidocs apidocs
COPY gateway/third_party third_party
COPY src src
COPY --from=gateway-builder /output/gateway gateway
COPY supervisord.conf /etc/supervisor/supervisord.conf
EXPOSE 6565 8000 8080
ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
