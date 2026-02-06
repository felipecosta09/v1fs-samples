from enum import Enum


#
# AMAAS exceptions class.
#
class AMaasException(Exception):
    def __init__(self, error_code, *params):
        self.error_code = error_code
        self.params = params
        self.message = error_code.value % params

    def __str__(self):
        return f"{self.error_code.name}: {self.message}"


#
# Error codes for AMAAS exceptions
#
class AMaasErrorCode(Enum):
    MSG_ID_ERR_FILE_NOT_FOUND = "Failed to open file. No such file or directory %s."
    MSG_ID_ERR_FILE_NO_PERMISSION = "Failed to open file. Permission denied to open %s."
    MSG_ID_ERR_INVALID_REGION = "%s is not a supported region, region value should be one of %s"
    MSG_ID_ERR_MISSING_AUTH = "Must provide an API key to use the client."
    MSG_ID_GRPC_ERROR = "Received gRPC status code: %s, msg: %s."
    MSG_ID_ERR_KEY_AUTH_FAILED = "Invalid token or Api Key."
    MSG_ID_ERR_UNKNOWN_CMD = "Received unknown command from server: %d"
    MSG_ID_ERR_UNKNOWN_STAGE = "Received unknown stage from server: %d"
    MSG_ID_ERR_UNEXPECTED_CMD_AND_STAGE = "Received unexpected command %d and stage %d."
    MSG_ID_ERR_UNEXPECTED_ERROR = "Unexpected error encountered. %s"
    MSG_ID_ERR_RATE_LIMIT_EXCEEDED = "Raised by the SDK library to indicate http 429 too many request error."
    MSG_ID_ERR_INVALID_TAG = "Invalid tag format: %s."
    MSG_ID_ERR_TAG_NUMBER_EXCEED = "Too many tags: %d."
