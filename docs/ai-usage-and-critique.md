# AI usage and technical critique

## How AI was used

- Terraform authoring
- APIM and Function integration
- mTLS testing
- Troubleshooting Azure and Terraform errors
- Repository audit
- Documentation

## What AI helped with

- Designing internal APIM
- Restricting Function access to APIM
- Passing request IDs through APIM and the Function
- Configuring private DNS
- Setting up OIDC and runtime tests

## What had to be corrected

- Thumbprint-based mTLS worked, but it did not meet the requested design of a CA and a separate CA-signed client certificate.
- APIM certificate import expected PFX/PKCS#12 rather than the PEM bundle used.
- APIM client-certificate settings depended on the selected APIM SKU.

## Verification

- `terraform fmt`
- `terraform validate`
- `terraform plan`
- Python compilation and local Function run
- Positive and negative runtime tests
- Final audit against the assessment PDF

## Main lesson

AI was useful for speed, but every suggestion had to be checked against the Terraform provider, observed Azure behaviour, and the original requirements.
