#!/bin/bash

python -m app &

./grpc_gateway &

wait -n

exit $?

# https://docs.docker.com/config/containers/multi-service_container/#use-a-wrapper-script