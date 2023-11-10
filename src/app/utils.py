# Copyright (c) 2021 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from environs import Env

from accelbyte_grpc_plugin.utils import create_env as _create_env


def create_env(**kwargs) -> Env:
    env = _create_env(**kwargs)
    env("AB_BASE_URL")
    env("AB_CLIENT_ID")
    env("AB_CLIENT_SECRET")
    env("AB_NAMESPACE")
    return env
