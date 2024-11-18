# pylint: disable=too-few-public-methods
from typing import Optional
from typing import List, Type, Dict
from pydantic import BaseModel, RootModel, Field
from typing_extensions import Annotated
from fastapi import FastAPI
from pydantic import constr

try:
    from version import VERSION
except ImportError:
    VERSION = "0.0.0"

# ========================================================================
# DATA MODELS
# ========================================================================

class UrisList(RootModel):
    root: Annotated[List[str], Field(
        min_length=1,
        max_length=10,
        title="Uris List",
        description="List of URIs to be processed",
        example=["https://cujo.com", "https://cujo.com/privacy"],
    )]


# Example:
# {
#     "http://cujo.com": {
#         "cache_key": "https://cujo.com",
#         "content": [
#             2,
#             5,
#             306
#         ],
#         "safety": 96,
#         "ttl": 86400,
#         "vut": 1731960901
#     }
# }
class OrbRating(BaseModel):
    # cache_key: Optional[Annotated[str, Field(
    #     title="Cache Key",
    #     description="The cache key for the URI, may be None.",
    #     example="https://cujo.com",
    #     required=False,
    #     default=None,
    # )]]
    cache_key: Optional[str] = None
    content: List[int]
    safety: int
    ttl: int
    vut: Annotated[int, Field(
        title="vut",
        description="Valid Until Timestamp, a fixed timestamp in the future",
        example=1731960901,
    )]


class OrbResponse(RootModel):
    root: Annotated[Dict[str, OrbRating], Field(
        title="ORB Response",
        description="The response from the Orb API",
        example={
            "http://cujo.com": {
                "cache_key": "https://cujo.com",
                "content": [
                    2,
                    5,
                    306
                ],
                "safety": 96,
                "ttl": 86400,
                "vut": 1731960901
            }
        },
    )]

class UrisRequest(BaseModel):
    uris: UrisList


# ========================================================================
# API SERVER
# ========================================================================
app = FastAPI(
    title="ACME API",
    description="This is the API for the ACME Corporation",
    summary="ACME API, intended for internal use only",
    contact={
        "slack": "#acme-public",
    },
    version=VERSION,
)


@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.post("/orb")
async def orb(uris: UrisRequest) -> OrbResponse:
    return {
        "ORB": {
            "content": [
                2,
                5,
                306
            ],
            "safety": 96,
            "ttl": 86400,
            "vut": 1731960901
        }
    }
