# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import Union

from grpc_health.v1 import health, health_pb2, health_pb2_grpc

from ..app import App, AppOptionApplyOrderEnum, AppOptionBase


class AppOptionGRPCHealthCheck(AppOptionBase):
    def apply(self, app: App, /, *args, **kwargs) -> None:
        full_name = health_pb2.DESCRIPTOR.services_by_name["Health"].full_name
        health_pb2_grpc.add_HealthServicer_to_server(
            health.aio.HealthServicer(), app.grpc_server
        )
        app.grpc_service_names.append(full_name)

    def get_order(self) -> Union[int, AppOptionApplyOrderEnum]:
        return AppOptionApplyOrderEnum.CREATE_GRPC_SERVER + 1


__all__ = [
    "AppOptionGRPCHealthCheck",
]
