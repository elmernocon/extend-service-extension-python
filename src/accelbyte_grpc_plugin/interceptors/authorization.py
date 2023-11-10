# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import Awaitable, Callable

from grpc import HandlerCallDetails, RpcMethodHandler, StatusCode
from grpc.aio import AioRpcError, Metadata, ServerInterceptor

from accelbyte_py_sdk.token_validation import TokenValidatorProtocol


class AuthorizationServerInterceptor(ServerInterceptor):
    def __init__(
        self,
        resource: str,
        action: int,
        namespace: str,
        token_validator: TokenValidatorProtocol,
    ) -> None:
        self.resource = resource
        self.action = action
        self.namespace = namespace
        self.token_validator = token_validator

    async def intercept_service(
        self,
        continuation: Callable[[HandlerCallDetails], Awaitable[RpcMethodHandler]],
        handler_call_details: HandlerCallDetails,
    ) -> RpcMethodHandler:
        # noinspection PyUnresolvedReferences
        if (
            authorization := next(
                (
                    metadata.value
                    for metadata in handler_call_details.invocation_metadata
                    if metadata.key == "authorization"
                ),
                None,
            )
        ) and authorization is None:
            raise self.create_aio_rpc_error(error="no authorization token found")

        if not authorization.startswith("Bearer "):
            raise self.create_aio_rpc_error(error="invalid authorization token format")

        try:
            token = authorization.removeprefix("Bearer ")
            error = self.token_validator.validate_token(
                token=token,
                resource=self.resource,
                action=self.action,
                namespace=self.namespace,
            )
            if error is not None:
                raise error
        except Exception as error:
            raise self.create_aio_rpc_error(
                error=str(error), code=StatusCode.INTERNAL
            ) from error

        return await continuation(handler_call_details)

    @staticmethod
    def create_aio_rpc_error(
        error: str, code: StatusCode = StatusCode.UNAUTHENTICATED
    ) -> AioRpcError:
        return AioRpcError(
            code=code,
            initial_metadata=Metadata(),
            trailing_metadata=Metadata(),
            details=error,
            debug_error_string=error,
        )


__all__ = [
    "AuthorizationServerInterceptor",
]
