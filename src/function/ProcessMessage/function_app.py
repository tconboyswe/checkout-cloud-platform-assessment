import json
import logging
import uuid
from datetime import datetime, timezone

import azure.functions as func

app = func.FunctionApp()


def _resolve_request_id(req: func.HttpRequest) -> str:
    request_id = req.headers.get("x-request-id", "").strip()
    if not request_id:
        request_id = str(uuid.uuid4())
    return request_id


def _json_response(body: dict, status_code: int, request_id: str) -> func.HttpResponse:
    return func.HttpResponse(
        body=json.dumps(body),
        status_code=status_code,
        mimetype="application/json",
        headers={"x-request-id": request_id},
    )


@app.route(route="process-message", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def process_message(req: func.HttpRequest) -> func.HttpResponse:
    request_id = _resolve_request_id(req)
    logging.info("ProcessMessage request received. requestId=%s", request_id)

    try:
        body_bytes = req.get_body()
        if not body_bytes:
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "empty body",
            )
            return _json_response(
                {"error": "Request body is required.", "requestId": request_id},
                400,
                request_id,
            )

        try:
            payload = json.loads(body_bytes.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "malformed JSON",
            )
            return _json_response(
                {"error": "Request body must be valid JSON.", "requestId": request_id},
                400,
                request_id,
            )

        if not isinstance(payload, dict):
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "not an object",
            )
            return _json_response(
                {"error": "Request body must be a JSON object.", "requestId": request_id},
                400,
                request_id,
            )

        if "message" not in payload:
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "missing message",
            )
            return _json_response(
                {"error": "The message property is required.", "requestId": request_id},
                400,
                request_id,
            )

        message = payload["message"]
        if message is None:
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "null message",
            )
            return _json_response(
                {"error": "The message property must be a non-empty string.", "requestId": request_id},
                400,
                request_id,
            )

        if not isinstance(message, str):
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "message not string",
            )
            return _json_response(
                {"error": "The message property must be a string.", "requestId": request_id},
                400,
                request_id,
            )

        if not message.strip():
            logging.warning(
                "ProcessMessage validation failed. requestId=%s reason=%s",
                request_id,
                "empty message",
            )
            return _json_response(
                {"error": "The message property must be a non-empty string.", "requestId": request_id},
                400,
                request_id,
            )

        timestamp = datetime.now(timezone.utc).isoformat()
        response_body = {
            "message": message,
            "timestamp": timestamp,
            "requestId": request_id,
        }
        logging.info("ProcessMessage request processed successfully. requestId=%s", request_id)
        return _json_response(response_body, 200, request_id)

    except Exception:
        logging.exception("ProcessMessage unexpected error. requestId=%s", request_id)
        return _json_response(
            {"error": "An unexpected error occurred.", "requestId": request_id},
            500,
            request_id,
        )
