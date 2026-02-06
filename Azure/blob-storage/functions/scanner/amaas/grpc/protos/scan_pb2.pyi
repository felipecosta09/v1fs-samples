from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Iterable as _Iterable, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class Stage(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    STAGE_INIT: _ClassVar[Stage]
    STAGE_RUN: _ClassVar[Stage]
    STAGE_FINI: _ClassVar[Stage]

class Command(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    CMD_RETR: _ClassVar[Command]
    CMD_QUIT: _ClassVar[Command]
STAGE_INIT: Stage
STAGE_RUN: Stage
STAGE_FINI: Stage
CMD_RETR: Command
CMD_QUIT: Command

class C2S(_message.Message):
    __slots__ = ("stage", "file_name", "rs_size", "offset", "chunk", "trendx", "file_sha1", "file_sha256", "tags", "bulk", "spn_feedback", "verbose")
    STAGE_FIELD_NUMBER: _ClassVar[int]
    FILE_NAME_FIELD_NUMBER: _ClassVar[int]
    RS_SIZE_FIELD_NUMBER: _ClassVar[int]
    OFFSET_FIELD_NUMBER: _ClassVar[int]
    CHUNK_FIELD_NUMBER: _ClassVar[int]
    TRENDX_FIELD_NUMBER: _ClassVar[int]
    FILE_SHA1_FIELD_NUMBER: _ClassVar[int]
    FILE_SHA256_FIELD_NUMBER: _ClassVar[int]
    TAGS_FIELD_NUMBER: _ClassVar[int]
    BULK_FIELD_NUMBER: _ClassVar[int]
    SPN_FEEDBACK_FIELD_NUMBER: _ClassVar[int]
    VERBOSE_FIELD_NUMBER: _ClassVar[int]
    stage: Stage
    file_name: str
    rs_size: int
    offset: int
    chunk: bytes
    trendx: bool
    file_sha1: str
    file_sha256: str
    tags: _containers.RepeatedScalarFieldContainer[str]
    bulk: bool
    spn_feedback: bool
    verbose: bool
    def __init__(self, stage: _Optional[_Union[Stage, str]] = ..., file_name: _Optional[str] = ..., rs_size: _Optional[int] = ..., offset: _Optional[int] = ..., chunk: _Optional[bytes] = ..., trendx: bool = ..., file_sha1: _Optional[str] = ..., file_sha256: _Optional[str] = ..., tags: _Optional[_Iterable[str]] = ..., bulk: bool = ..., spn_feedback: bool = ..., verbose: bool = ...) -> None: ...

class S2C(_message.Message):
    __slots__ = ("stage", "cmd", "offset", "length", "result", "bulk_offset", "bulk_length", "session_id")
    STAGE_FIELD_NUMBER: _ClassVar[int]
    CMD_FIELD_NUMBER: _ClassVar[int]
    OFFSET_FIELD_NUMBER: _ClassVar[int]
    LENGTH_FIELD_NUMBER: _ClassVar[int]
    RESULT_FIELD_NUMBER: _ClassVar[int]
    BULK_OFFSET_FIELD_NUMBER: _ClassVar[int]
    BULK_LENGTH_FIELD_NUMBER: _ClassVar[int]
    SESSION_ID_FIELD_NUMBER: _ClassVar[int]
    stage: Stage
    cmd: Command
    offset: int
    length: int
    result: str
    bulk_offset: _containers.RepeatedScalarFieldContainer[int]
    bulk_length: _containers.RepeatedScalarFieldContainer[int]
    session_id: str
    def __init__(self, stage: _Optional[_Union[Stage, str]] = ..., cmd: _Optional[_Union[Command, str]] = ..., offset: _Optional[int] = ..., length: _Optional[int] = ..., result: _Optional[str] = ..., bulk_offset: _Optional[_Iterable[int]] = ..., bulk_length: _Optional[_Iterable[int]] = ..., session_id: _Optional[str] = ...) -> None: ...
