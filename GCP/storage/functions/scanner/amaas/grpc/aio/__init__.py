import io
import os
from typing import BinaryIO, List

import grpc
import logging

from ..protos import scan_pb2
from ..protos import scan_pb2_grpc
from ..exception import AMaasException
from ..exception import AMaasErrorCode
from ..util import _init_by_region_util
from ..util import _init_util
from ..util import _validate_tags
from ..util import _digest_hex
from ..util import APP_NAME_HEADER, APP_NAME_FILE_SCAN

logger = logging.getLogger(__name__)
logger.addHandler(logging.StreamHandler())
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(LOG_LEVEL)
logger.propagate = False

timeout_in_seconds = int(os.environ.get('TM_AM_SCAN_TIMEOUT_SECS', 300))


def init_by_region(region, api_key, enable_tls=True, ca_cert=None):
    return _init_by_region_util(region, api_key, enable_tls, ca_cert, True)


def init(host, api_key=None, enable_tls=False, ca_cert=None):
    return _init_util(host, api_key, enable_tls, ca_cert, True)


async def quit(handle):
    await handle.close()


# https://github.com/grpc/grpc/blob/91083659fa88c938779dd41e57a7f97981b6c9a1/src/python/grpcio_tests/tests_aio/unit/channel_test.py#L180


async def _scan_data(channel: grpc.Channel, data_reader: BinaryIO, size: int, identifier: str, tags: List[str],
                     pml: bool, feedback: bool, verbose: bool, digest: bool) -> str:
    _validate_tags(tags)
    stub = scan_pb2_grpc.ScanStub(channel)
    stats = {}
    result = None
    bulk = True
    file_sha1 = ""
    file_sha256 = ""

    if digest:
        file_sha1 = "sha1:" + _digest_hex(data_reader, "sha1")
        file_sha256 = "sha256:" + _digest_hex(data_reader, "sha256")

    try:
        metadata = (
            (APP_NAME_HEADER, APP_NAME_FILE_SCAN),
        )
        call = stub.Run(timeout=timeout_in_seconds, metadata=metadata)

        request = scan_pb2.C2S(stage=scan_pb2.STAGE_INIT,
                               file_name=identifier,
                               rs_size=size,
                               offset=0,
                               chunk=None,
                               tags=tags,
                               trendx=pml,
                               file_sha1=file_sha1,
                               file_sha256=file_sha256,
                               bulk=bulk,
                               spn_feedback=feedback,
                               verbose=verbose)

        await call.write(request)

        while True:
            response = await call.read()

            if response.cmd == scan_pb2.CMD_RETR:
                if response.stage != scan_pb2.STAGE_RUN:
                    raise AMaasException(AMaasErrorCode.MSG_ID_ERR_UNEXPECTED_CMD_AND_STAGE, response.cmd,
                                         response.stage)
                length = []
                offset = []

                if bulk:
                    logger.debug("enter bulk mode")
                    bulk_count = len(response.bulk_offset)

                    if bulk_count > 1:
                        logger.debug("bulk transfer triggered")

                    length = response.bulk_length[:]
                    offset = response.bulk_offset[:]
                else:
                    logger.debug("enter non-bulk mode")
                    length.append(response.length)
                    offset.append(response.offset)

                for i in range(len(length)):
                    logger.debug(f"try to read {length[i]} at offset {offset[i]}")
                    data_reader.seek(offset[i])
                    chunk = data_reader.read(length[i])

                    request = scan_pb2.C2S(
                        stage=scan_pb2.STAGE_RUN,
                        file_name=None,
                        rs_size=0,
                        offset=offset[i],
                        chunk=chunk)

                    stats["total_upload"] = stats.get(
                        "total_upload", 0) + len(chunk)

                    await call.write(request)
            elif response.cmd == scan_pb2.CMD_QUIT:
                if response.stage != scan_pb2.STAGE_FINI:
                    raise AMaasException(AMaasErrorCode.MSG_ID_ERR_UNEXPECTED_CMD_AND_STAGE, response.cmd,
                                         response.stage)
                result = response.result
                logger.debug("receive QUIT, exit loop...")
                break
            else:
                logger.debug("unknown command...")
                raise AMaasException(AMaasErrorCode.MSG_ID_ERR_UNKNOWN_CMD, response.cmd)

        await call.done_writing()

        total_upload = stats.get("total_upload", 0)
        logger.debug(f"total upload {total_upload} bytes")

    except AMaasException:
        raise
    except grpc.aio.AioRpcError as rpc_error:
        if "429" in str(rpc_error):
            raise AMaasException(AMaasErrorCode.MSG_ID_ERR_RATE_LIMIT_EXCEEDED)
        elif rpc_error.code() == grpc.StatusCode.UNAUTHENTICATED:
            raise AMaasException(AMaasErrorCode.MSG_ID_ERR_KEY_AUTH_FAILED)
        else:
            raise AMaasException(AMaasErrorCode.MSG_ID_GRPC_ERROR, rpc_error.code().value[0], rpc_error.details())
    except Exception as err:
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_UNEXPECTED_ERROR, str(err))

    return result


async def scan_file(channel: grpc.Channel, file_name: str, tags: List[str] = None,
                    pml: bool = False, feedback: bool = False, verbose: bool = False, digest: bool = True) -> str:
    try:
        f = open(file_name, "rb")
        fid = os.path.basename(file_name)
        n = os.stat(file_name).st_size
    except FileNotFoundError as err:
        logger.debug("File not exist: " + str(err))
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_FILE_NOT_FOUND, file_name)
    except (PermissionError, IOError) as err:
        logger.debug("Permission error: " + str(err))
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_FILE_NO_PERMISSION, file_name)
    return await _scan_data(channel, f, n, fid, tags, pml, feedback, verbose, digest)


async def scan_buffer(channel: grpc.Channel, bytes_buffer: bytes, uid: str, tags: List[str] = None,
                      pml: bool = False, feedback: bool = False, verbose: bool = False, digest: bool = True) -> str:
    f = io.BytesIO(bytes_buffer)
    return await _scan_data(channel, f, len(bytes_buffer), uid, tags, pml, feedback, verbose, digest)
