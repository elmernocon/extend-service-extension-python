# Copyright (c) 2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from logging import Logger
from typing import Any, Dict, Optional, Set

from grpc import HandlerCallDetails

from environs import Env

from grpc import StatusCode
from grpc.aio import AioRpcError, Metadata

from opentelemetry.propagate import get_global_textmap

from accelbyte_py_sdk import AccelByteSDK
from accelbyte_py_sdk.core import HttpxHttpClient, RequestsHttpClient


def create_env(**kwargs) -> Env:
    env = Env(
        eager=kwargs.get("env_eager", True),
        expand_vars=kwargs.get("env_expand_vars", False),
    )
    env.read_env(
        path=kwargs.get("env_path", None),
        recurse=kwargs.get("env_recurse", True),
        verbose=kwargs.get("env_verbose", False),
        override=kwargs.get("env_override", False),
    )
    return env


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


def get_headers_from_metadata(handler_call_details: HandlerCallDetails) -> Dict[str, Any]:
    headers = {}
    invocation_metadata = getattr(handler_call_details, "invocation_metadata", [])
    for metadata in invocation_metadata:
        key = getattr(metadata, "key", None)
        value = getattr(metadata, "value", None)
        if key is not None and value is not None:
            headers[key] = value
    return headers


def get_propagator_header_keys() -> Set[str]:
    return get_global_textmap().fields


def instrument_sdk_http_client(sdk: AccelByteSDK, logger: Optional[Logger] = None) -> None:
    http_client = sdk.get_http_client(raise_when_none=False)
    if http_client is not None:
        if isinstance(http_client, HttpxHttpClient):
            try:
                from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
                HTTPXClientInstrumentor().instrument()
                if logger:
                    logger.info("httpx client instrumented")
            except ImportError:
                if logger:
                    logger.warning("failed to instrument httpx client")
        elif isinstance(http_client, RequestsHttpClient):
            try:
                from opentelemetry.instrumentation.requests import RequestsInstrumentor
                RequestsInstrumentor().instrument()
                if logger:
                    logger.info("requests client instrumented")
            except ImportError:
                if logger:
                    logger.warning("failed to instrument requests client")
        else:
            if logger:
                logger.warning("failed to instrument unknown client")


__all__ = [
    "create_env",
    "create_aio_rpc_error",
    "get_headers_from_metadata",
    "get_propagator_header_keys",
    "instrument_sdk_http_client",
]
