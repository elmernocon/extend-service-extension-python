# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import Union

import grpc_reflection.v1alpha.reflection

from ..app import App, AppOptionApplyOrderEnum, AppOptionBase


class AppOptionGRPCReflection(AppOptionBase):
    def apply(self, app: App, /, *args, **kwargs) -> None:
        full_name = grpc_reflection.v1alpha.reflection.SERVICE_NAME
        service_names = [full_name, *app.grpc_service_names]
        grpc_reflection.v1alpha.reflection.enable_server_reflection(
            service_names=service_names, server=app.grpc_server
        )

    def get_order(self) -> Union[int, AppOptionApplyOrderEnum]:
        return AppOptionApplyOrderEnum.MAX - 1


__all__ = [
    "AppOptionGRPCReflection",
]
