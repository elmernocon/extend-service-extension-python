# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import Awaitable, Callable, List

import grpc
from grpc import HandlerCallDetails, RpcMethodHandler, StatusCode
from grpc.aio import ServerInterceptor

from accelbyte_py_sdk.services.auth import parse_access_token
from accelbyte_py_sdk.token_validation import TokenValidatorProtocol


class AuthorizationServerInterceptor(ServerInterceptor):
    whitelisted_methods: List[str] = [
        "/grpc.health.v1.Health/Check",
        "/grpc.health.v1.Health/Watch",
        "/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo",
    ]

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
        method = getattr(handler_call_details, "method", "")
        if method in self.whitelisted_methods:
            return await continuation(handler_call_details)

        # noinspection PyUnresolvedReferences
        authorization = next(
            (
                str(metadata.value)
                for metadata in handler_call_details.invocation_metadata
                if metadata.key == "authorization"
            ),
            None,
        )

        if not authorization:
            return self.create_aio_rpc_error(error="no authorization token found")

        if not authorization.startswith("Bearer "):
            return self.create_aio_rpc_error(error="invalid authorization token format")

        try:
            token = authorization.removeprefix("Bearer ")
            error = self.token_validator.validate_token(
                token=token,
                resource=self.resource,
                action=self.action,
                namespace=self.namespace,
            )
            if error is not None:
                return self.create_aio_rpc_error(error=str(error))

            claims, error = parse_access_token(token)
            if error is not None:
                return self.create_aio_rpc_error(error=str(error))

            if extend_namespace := claims.get("extend_namespace", None):
                if extend_namespace != self.namespace:
                    return self.create_aio_rpc_error(
                        error=f"'{extend_namespace}' does not match '{self.namespace}'",
                        code=StatusCode.PERMISSION_DENIED,
                    )
        except Exception as error:
            return self.create_aio_rpc_error(error=str(error), code=StatusCode.INTERNAL)

        return await continuation(handler_call_details)

    @staticmethod
    def create_aio_rpc_error(error: str, code: StatusCode = StatusCode.UNAUTHENTICATED):
        async def abort(ignored_request, context):
            await context.abort(code, error)

        return grpc.unary_unary_rpc_method_handler(abort)


__all__ = [
    "AuthorizationServerInterceptor",
]
