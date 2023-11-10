# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

import platform
from typing import Any, Awaitable, Callable, Dict, Optional

from grpc import HandlerCallDetails, RpcMethodHandler
from grpc.aio import ServerInterceptor
from prometheus_client import Counter


class MetricsServerInterceptor(ServerInterceptor):
    def __init__(
        self,
        labels: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.labels = labels if labels else {"os": platform.system().lower()}
        self.counter = Counter(
            name="grpc_server_calls",
            documentation="number of gRPC calls",
            labelnames=self.labels.keys(),
            unit="count",
        )

    async def intercept_service(
        self,
        continuation: Callable[[HandlerCallDetails], Awaitable[RpcMethodHandler]],
        handler_call_details: HandlerCallDetails,
    ) -> RpcMethodHandler:
        self.counter.labels(**self.labels).inc(amount=1)
        return await continuation(handler_call_details)
