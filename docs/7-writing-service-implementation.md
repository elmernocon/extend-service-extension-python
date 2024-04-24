# Chapter 7: Writing Service Implementations

Now that we have defined our service, the next step is to implement our service. 
This is where we define the actual logic of our gRPC methods.
You can read more information related to Python gRPC [here](https://grpc.io/docs/languages/python/basics/).

We'll be doing this in the `src/app/services/service.py` file.

Here's a brief outline of what this chapter will cover:

## 7.1 Setting Up the Guild Service

### 7.1 Setting Up the Guild Service
To set up our guild service, we'll first create a class derived from `ServiceServicer`.
This class will act as our service implementation.

```python
from ..proto.service_pb2 import (
    CreateOrUpdateGuildProgressRequest,
    CreateOrUpdateGuildProgressResponse,
    GetGuildProgressRequest,
    GetGuildProgressResponse,
    DESCRIPTOR,
)

from ..proto.service_pb2_grpc import ServiceServicer

class AsyncService(ServiceServicer):
    full_name: str = DESCRIPTOR.services_by_name["Service"].full_name

    # Implement your service logic in here.
```

To implement the `CreateOrUpdateGuildProgress` function, you can override the method like this:

```python
async def CreateOrUpdateGuildProgress(
    self, request: CreateOrUpdateGuildProgressRequest, context: Any
) -> CreateOrUpdateGuildProgressResponse:
    ...

```

And similarly for the `GetGuildProgress` function:

```python
async def GetGuildProgress(
    self, request: GetGuildProgressRequest, context: Any
) -> GetGuildProgressResponse:
    ...

```

In these methods, you would include the logic to interact with CloudSave or 
any other dependencies in order to process the requests.
