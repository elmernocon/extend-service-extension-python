# 5. Project Structure

This chapter offers an overview of the Guild Service's project structure. Understanding this structure will help you navigate the project and identify where to make changes as you add new features or fix bugs.

```bash
.                                            
├── docs/
├── gateway/                                                # gRPC Gateway code (GoLang)
│   ├── apidocs/                                            # Generated Swagger specification files                                        
│   ├── main.go
│   ├── pkg/
│   │   ├── common/
│   │   └── pb/                                             # Where the Go protobuf-gRPC files will be generated
│   └── third_party/
│       ├── embed.go
│       └── swagger-ui/                                     # Directory containing Swagger UI
├── proto/                                                  # Your .proto files
├── src/
│   ├── accelbyte_grpc_plugin/                              # AccelByte gRPC Plugin framework
│   │   └── ...
│   ├── app/                                                # Service's project
│   │   ├── proto/                                          # Where the Python protobuf-gRPC files will be generated
│   │   ├── services/                                       # Your gRPC Server implementation here
│   │   ├── ...
│   │   └── __main__.py                                     # Entrypoint
├── test/app_tests                                          # Service's Unit Test
├── Dockerfile                                              # To build complete image with service and grpc-gateway
├── docker-compose.yaml                                     # Compose file that use complete image
└── Makefile
```

The most important files and directories are:

- `Makefile`: This file contains scripts that automate tasks like building our service, running tests, and cleaning up.
- All `Dockerfile`: Dockerfile(s) for our service. This is used by Docker to build a container image for our service.
- All `docker-compose.yaml`: Defines the services that make up our application, so they can be run together using Docker Compose.
- `gateway/apidocs`: This is where the generated OpenAPI spec located.
- `gateway`: Contains grpc-gateway code. Visit [extend-service-extension-go](https://github.com/AccelByte/extend-service-extension-go) for more information on this.
- `gateway/main.go`: This is the main entry point of the gateway.
- `gateway/common/config.go`: Contains the base path of the HTTP server.
- `gateway/common/gateway.go`: Contains the code for our gRPC-Gateway, which translates HTTP/JSON requests into gRPC and vice versa.
- `gateway/pkg/pb`: This directory contains the Go code that was generated from our .proto files by the protoc compiler.
- `gateway/pkg/third_party`: This directory contains third party libraries that are used by our service. Namely, Swagger-UI.
- `src`: Contains service's project.
- `test/app_tests`: Contains service's unit tests.

In the following chapters, we will discuss how to define and implement new services and messages in our `.proto` files,
how to generate grpc-gateway code from these `.proto` files, and how to implement these services in our server.