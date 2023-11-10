# Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

from typing import Optional

import logging_loki

from ..app import App, AppOptionBase


class AppOptionLoki(AppOptionBase):
    DEFAULT_URL: str = "http://localhost:3100/loki/api/v1/push"
    DEFAULT_USERNAME: str = ""
    DEFAULT_PASSWORD: str = ""
    DEFAULT_VERSION: str = "1"

    def __init__(
        self,
        url: Optional[str] = None,
        username: Optional[str] = None,
        password: Optional[str] = None,
        version: Optional[str] = None,
    ) -> None:
        self.url = url
        self.username = username
        self.password = password
        self.version = version

    def apply(self, app: App, /, *args, **kwargs) -> None:
        with app.env.prefixed("LOKI_"):
            if not self.url:
                self.url = app.env.str("URL", self.DEFAULT_URL)
            if not self.username:
                self.username = app.env.str("USERNAME", self.DEFAULT_USERNAME)
            if not self.password:
                self.password = app.env.str("PASSWORD", self.DEFAULT_PASSWORD)
            if not self.version:
                self.version = app.env.str("VERSION", self.DEFAULT_VERSION)
        auth = (self.username, self.password) if self.username else None
        hdlr = logging_loki.LokiHandler(url=self.url, auth=auth, version=self.version)
        app.logger.addHandler(hdlr=hdlr)


__all__ = [
    "AppOptionLoki",
]
