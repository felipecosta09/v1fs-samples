import grpc
import hashlib
from typing import BinaryIO, List
from .exception import AMaasException
from .exception import AMaasErrorCode

HASH_CHUNK_SIZE = 512 * 1024

APP_NAME_HEADER = "tm-app-name"
APP_NAME_FILE_SCAN = "V1FS"

# regions
AWS_JP_REGION = "ap-northeast-1"
AWS_SG_REGION = "ap-southeast-1"
AWS_AU_REGION = "ap-southeast-2"
AWS_IN_REGION = "ap-south-1"
AWS_US_REGION = "us-east-1"
AWS_DE_REGION = "eu-central-1"
AWS_CA_REGION = "ca-central-1"
AWS_TREND_REGION = "us-east-2"
AWS_GB_REGION = "eu-west-2"
C1_JP_REGION = "jp-1"
C1_SG_REGION = "sg-1"
C1_AU_REGION = "au-1"
C1_IN_REGION = "in-1"
C1_US_REGION = "us-1"
C1_DE_REGION = "de-1"
C1_CA_REGION = "ca-1"
C1_TREND_REGION = "trend-us-1"
C1_GB_REGION = "gb-1"

C1Regions = [C1_AU_REGION, C1_CA_REGION, C1_DE_REGION, C1_GB_REGION, C1_IN_REGION, C1_JP_REGION, C1_SG_REGION,
             C1_US_REGION, C1_TREND_REGION]
V1Regions = [AWS_AU_REGION, AWS_DE_REGION, AWS_IN_REGION, AWS_JP_REGION, AWS_SG_REGION, AWS_US_REGION]
SupportedV1Regions = V1Regions
SupportedC1Regions = [C1_AU_REGION, C1_CA_REGION, C1_DE_REGION, C1_GB_REGION, C1_IN_REGION, C1_JP_REGION, C1_SG_REGION,
                      C1_US_REGION]

AllRegions = C1Regions + V1Regions
AllValidRegions = SupportedC1Regions + SupportedV1Regions

V1ToC1RegionMapping = {AWS_AU_REGION: C1_AU_REGION,
                       AWS_DE_REGION: C1_DE_REGION,
                       AWS_IN_REGION: C1_IN_REGION,
                       AWS_JP_REGION: C1_JP_REGION,
                       AWS_SG_REGION: C1_SG_REGION,
                       AWS_US_REGION: C1_US_REGION,
                       }


class _GrpcAuth(grpc.AuthMetadataPlugin):
    def __init__(self, key):
        self._key = key

    def __call__(self, context, callback):
        callback((('authorization', self._key),), None)


def _init_util(host, api_key=None, enable_tls=False, ca_cert=None, is_aio_channel=False):
    call_creds = None
    if api_key:
        auth_key_str = 'ApiKey ' + api_key
        call_creds = grpc.metadata_call_credentials(_GrpcAuth(auth_key_str))

    if enable_tls:
        if ca_cert:
            # Bring Your Own Certificate case
            with open(ca_cert, 'rb') as f:
                ssl_creds = grpc.ssl_channel_credentials(f.read())
        else:
            ssl_creds = grpc.ssl_channel_credentials()

        # if authentication is necessary, combined call_creds with ssl_creds.
        # Otherwise, just use ssl_creds for channel credentials.
        if call_creds is None:
            creds = ssl_creds
        else:
            creds = grpc.composite_channel_credentials(ssl_creds, call_creds)

        channel = grpc.aio.secure_channel(host, creds) if is_aio_channel else grpc.secure_channel(host, creds)
    else:
        channel = grpc.aio.insecure_channel(host) if is_aio_channel else grpc.insecure_channel(host)

    return channel


def _init_by_region_util(region, api_key, enable_tls=True, ca_cert=None, is_aio_channel=False):
    mapping = {
        C1_US_REGION: 'antimalware.us-1.cloudone.trendmicro.com:443',
        C1_IN_REGION: 'antimalware.in-1.cloudone.trendmicro.com:443',
        C1_DE_REGION: 'antimalware.de-1.cloudone.trendmicro.com:443',
        C1_SG_REGION: 'antimalware.sg-1.cloudone.trendmicro.com:443',
        C1_AU_REGION: 'antimalware.au-1.cloudone.trendmicro.com:443',
        C1_JP_REGION: 'antimalware.jp-1.cloudone.trendmicro.com:443',
        C1_GB_REGION: 'antimalware.gb-1.cloudone.trendmicro.com:443',
        C1_CA_REGION: 'antimalware.ca-1.cloudone.trendmicro.com:443',
    }

    # make sure it is valid V1 or C1 region
    if region not in SupportedV1Regions:
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_INVALID_REGION, region, SupportedV1Regions)
    else:
        # map it to C1 region if it is V1 region
        c1_region = V1ToC1RegionMapping.get(region)
        if not c1_region:
            raise AMaasException(AMaasErrorCode.MSG_ID_ERR_INVALID_REGION, region, SupportedV1Regions)
        region = c1_region

    host = mapping.get(region, None)
    if host is None:
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_INVALID_REGION, region)
    return _init_util(host, api_key, enable_tls, ca_cert, is_aio_channel)


def _validate_tags(tags: List[str]):
    if tags is not None:
        if len(tags) > 8:
            raise AMaasException(AMaasErrorCode.MSG_ID_ERR_TAG_NUMBER_EXCEED, len(tags))

        for t in tags:
            if not (0 < len(t) < 64):
                raise AMaasException(AMaasErrorCode.MSG_ID_ERR_INVALID_TAG, t)


def _digest_hex(data_reader: BinaryIO, algorithm: str):
    if algorithm == "sha1":
        file_hash = hashlib.sha1()
    elif algorithm == "sha256":
        file_hash = hashlib.sha256()
    else:
        raise AMaasException(AMaasErrorCode.MSG_ID_ERR_UNEXPECTED_ERROR, "unsupported hash algorithm " + algorithm)

    w = data_reader.tell()
    data_reader.seek(0)

    chunk = data_reader.read(HASH_CHUNK_SIZE)
    while chunk:
        file_hash.update(chunk)
        chunk = data_reader.read(HASH_CHUNK_SIZE)

    data_reader.seek(w)
    return file_hash.hexdigest()
