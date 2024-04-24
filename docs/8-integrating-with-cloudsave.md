# Chapter 8: Integrating with AccelByte's CloudSave

In this chapter, we'll learn how to integrate the AccelByte's CloudSave feature into our GuildService.

## 8.1. Understanding CloudSave

AccelByte's CloudSave is a cloud-based service that enables you to save and retrieve game data in 
a structured manner. It allows for easy and quick synchronization of player data across different 
devices. This can be especially useful in multiplayer games where players' data needs to be synced 
in real-time. Please refer to our docs portal for more details

## 8.2. Setting up CloudSave

The first step to using CloudSave is setting it up.
In the context of our GuildService, this involves adding the CloudSave client to our server struct and initializing it during server startup.

During server startup, you would initialize the requirement of CloudSave client like so:

1. Add Python AccelByte SDK package using `pip install accelbyte-py-sdk` inside service project directory.

2. Create `AppSettingConfigRepository` class as a configuration model for our service. Later we can associate its properties in `appsettings.json`. Read more about ASPNET.Core configuration [here](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-6.0)

```python
from environs import Env

from accelbyte_py_sdk.core import (
    AccelByteSDK,
    DictConfigRepository,
    InMemoryTokenRepository,
    HttpxHttpClient,
)
from accelbyte_py_sdk.services import auth as auth_service

async def main() -> None:
    env = Env()
    # env.read_env(...)
    
    http = HttpxHttpClient()
    http.client.follow_redirects = True
    sdk = AccelByteSDK()
    sdk.initialize(
        options={
            "config": DictConfigRepository(dict(env.dump())),
            "token": InMemoryTokenRepository(),
            "http": http,
        }
    )
    _, error = await auth_service.login_client_async(sdk=sdk)
    if error:
        raise Exception(str(error))

```

## 8.3. Using CloudSave in GuildService

Let's go over an example of how we use CloudSave within our GuildService.

When updating the guild progress, after performing any necessary validations and computations, 
you would save the updated progress to CloudSave like so:

```python
from accelbyte_py_sdk.api import cloudsave as cs_service
from accelbyte_py_sdk.api.cloudsave import models as cs_models

async def CreateOrUpdateGuildProgress(
    self, request: CreateOrUpdateGuildProgressRequest, context: Any
) -> CreateOrUpdateGuildProgressResponse:
    guild_id = request.guild_progress.guild_id.strip()
    if not guild_id:
        guild_id = self.generate_new_guild_id()

    gp_key = self.format_guild_progress_key(guild_id)
    gp_value = cs_models.ModelsGameRecordRequest()
    gp_value["guild_id"] = guild_id
    gp_value["namespace"] = request.guild_progress.namespace
    gp_value["objectives"] = dict(request.guild_progress.objectives)

    (
        response,
        error,
    ) = await cs_service.admin_post_game_record_handler_v1_async(
        body=gp_value,
        key=gp_key,
        namespace=request.namespace,
        sdk=self.sdk,
    )
    if error:
        raise Exception(error)

    assert isinstance(response, cs_models.ModelsGameRecordResponse)

    result = CreateOrUpdateGuildProgressResponse()
    result.guild_progress.guild_id = response.value["guild_id"]
    result.guild_progress.namespace = response.value["namespace"]
    for k, v in response.value["objectives"].items():
        result.guild_progress.objectives[k] = v

    return result
```

For more accurate details how it was implemented please refer to [src/app/services/my_service.py](../src/app/services/my_service.py)

That's it! You've now integrated AccelByte's CloudSave into your GuildService. 
You can now use CloudSave to save and retrieve guild progress, along with any other 
data you might need to store.