# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

import logging
from typing import Awaitable, Callable, Optional

from grpc import HandlerCallDetails, RpcMethodHandler
from grpc.aio import ServerInterceptor


class LoggingServerInterceptor(ServerInterceptor):
    def __init__(
        self, logger: Optional[logging.Logger] = None, level: Optional[int] = None
    ) -> None:
        self.logger = logger
        self.level = level if level is not None else logging.DEBUG

    async def intercept_service(
        self,
        continuation: Callable[[HandlerCallDetails], Awaitable[RpcMethodHandler]],
        handler_call_details: HandlerCallDetails,
    ) -> RpcMethodHandler:
        if self.logger:
            # noinspection PyUnresolvedReferences
            self.logger.log(self.level, "method: %s", handler_call_details.method)
        return await continuation(handler_call_details)


__all__ = ["LoggingServerInterceptor"]
