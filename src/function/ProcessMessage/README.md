# ProcessMessage Function

Minimal Python Azure Function for the Checkout.com assessment `POST /api/process-message` endpoint.

## Prerequisites

- Python 3.11
- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) v4

## Local setup

Create and activate a virtual environment:

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Copy the example local settings file:

```powershell
Copy-Item local.settings.json.example local.settings.json
```

## Run locally

```powershell
func start
```

The function listens on `http://localhost:7071/api/process-message`.

## Successful request example

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:7071/api/process-message" `
  -ContentType "application/json" `
  -Body '{"message":"hello"}' `
  -Headers @{ "x-request-id" = "demo-request-123" }
```

Example response:

```json
{
  "message": "hello",
  "timestamp": "2026-07-21T12:00:00.000000+00:00",
  "requestId": "demo-request-123"
}
```

## Invalid request example

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:7071/api/process-message" `
  -ContentType "application/json" `
  -Body '{"message":""}'
```

Example response (HTTP 400):

```json
{
  "error": "The message property must be a non-empty string.",
  "requestId": "<generated-or-supplied-request-id>"
}
```
