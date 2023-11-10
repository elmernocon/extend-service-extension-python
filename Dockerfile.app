FROM rvolosatovs/protoc:4.1.0 as proto-builder
WORKDIR /.build
COPY proto proto
RUN mkdir -p /.output/src && \
    protoc \
        --proto_path=google/api=proto/google/api \
        --proto_path=protoc-gen-openapiv2/options=proto/protoc-gen-openapiv2/options \
        --python_out=/.output/src \
        --pyi_out=/.output/src \
        --grpc-python_out=/.output/src \
        google/api/annotations.proto \
        google/api/http.proto \
        protoc-gen-openapiv2/options/annotations.proto \
        protoc-gen-openapiv2/options/openapiv2.proto
RUN mkdir -p /.output/src/app/proto && \
    protoc \
        --proto_path=proto/app \
        --python_out=/.output/src/app/proto \
        --pyi_out=/.output/src/app/proto \
        --grpc-python_out=/.output/src/app/proto \
        permission.proto \
        guildService.proto
RUN sed -i 's/import permission_pb2 as permission__pb2/from . import permission_pb2 as permission__pb2/' \
        /.output/src/app/proto/guildService_pb2.py
RUN sed -i 's/import permission_pb2 as _permission_pb2/from . import permission_pb2 as _permission_pb2/' \
        /.output/src/app/proto/guildService_pb2.pyi
RUN sed -i 's/import guildService_pb2 as guildService__pb2/from . import guildService_pb2 as guildService__pb2/' \
        /.output/src/app/proto/guildService_pb2_grpc.py


FROM python:3.9-slim-bullseye
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /build
COPY pyproject.toml pyproject.toml
COPY src src
COPY --from=proto-builder /.output/src src
RUN python -m pip install .
WORKDIR /app
EXPOSE 6565
EXPOSE 8080
ENTRYPOINT [ "app" ]
