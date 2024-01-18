# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

import logging
from unittest import IsolatedAsyncioTestCase

from accelbyte_py_sdk.core import (
    AccelByteSDK,
    DictConfigRepository,
    InMemoryTokenRepository,
    HttpxHttpClient,
)
from accelbyte_py_sdk.services import auth as auth_service
from app.proto.guildService_pb2 import (
    CreateOrUpdateGuildProgressRequest,
    CreateOrUpdateGuildProgressResponse,
    GetGuildProgressRequest,
    GetGuildProgressResponse,
)
from app.services.guild_service import AsyncGuildService
from app.utils import create_env


class AsyncGuildServiceTestCase(IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        env = create_env()

        http = HttpxHttpClient()
        http.client.follow_redirects = True
        self.sdk = AccelByteSDK()
        self.sdk.initialize(
            options={
                "config": DictConfigRepository(dict(env.dump())),
                "token": InMemoryTokenRepository(),
                "http": http,
            }
        )
        _, error = await auth_service.login_client_async(sdk=self.sdk)
        if error:
            self.fail(str(error))

        self.logger = logging.getLogger("tests")
        self.service = AsyncGuildService(sdk=self.sdk, logger=self.logger)

    async def asyncTearDown(self) -> None:
        self.sdk.reset()

    async def test_create_or_update_guild_progress(self):
        # arrange
        request = CreateOrUpdateGuildProgressRequest()
        request.namespace = self.sdk.get_namespace()[0]
        request.guild_progress.objectives["likes"] = 1

        # act
        response = await self.service.CreateOrUpdateGuildProgress(request, None)

        # assert
        self.assertIsNotNone(response)
        self.assertIsInstance(response, CreateOrUpdateGuildProgressResponse)

    async def test_get_guild_progress(self):
        # arrange
        request = CreateOrUpdateGuildProgressRequest()
        request.namespace = self.sdk.get_namespace()[0]
        request.guild_progress.objectives["likes"] = 1

        response = await self.service.CreateOrUpdateGuildProgress(request, None)

        if response is None or not isinstance(response, CreateOrUpdateGuildProgressResponse):
            self.skipTest(reason="failed to create guild progress")
            return

        guild_id = response.guild_progress.guild_id

        request = GetGuildProgressRequest()
        request.namespace = self.sdk.get_namespace()[0]
        request.guild_id = guild_id

        # act
        response = await self.service.GetGuildProgress(request, None)

        # assert
        self.assertIsNotNone(response)
        self.assertIsInstance(response, GetGuildProgressResponse)
