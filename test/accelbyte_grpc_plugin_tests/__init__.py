# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import List

import grpc
import grpc.aio
from grpc.aio import Server, ServerInterceptor


def create_access_token_credentials(access_token: str):
    return grpc.composite_channel_credentials(
        grpc.local_channel_credentials(),
        grpc.access_token_call_credentials(access_token=access_token),
    )


def create_server(insecure_port: str, interceptors: List[ServerInterceptor]) -> Server:
    server = grpc.aio.server(interceptors=interceptors)
    server.add_insecure_port(address=insecure_port)
    return server
