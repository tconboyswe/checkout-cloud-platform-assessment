# Self-signed certificate material generated with the tls provider and imported into Key Vault.
# PKCS#8 private key format is required for Azure Key Vault certificate import.

resource "tls_private_key" "assessment" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "assessment" {
  private_key_pem = tls_private_key.assessment.private_key_pem

  subject {
    common_name  = var.certificate_common_name
    organization = var.certificate_organization
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

locals {
  # PEM bundle: PKCS#8 private key followed by the self-signed certificate.
  key_vault_certificate_pem = sensitive("${tls_private_key.assessment.private_key_pem_pkcs8}${tls_self_signed_cert.assessment.cert_pem}")
}

resource "azurerm_key_vault_certificate" "assessment" {
  name         = local.assessment_certificate_name
  key_vault_id = azurerm_key_vault.main.id

  certificate {
    contents = base64encode(local.key_vault_certificate_pem)
    password = ""
  }

  depends_on = [
    azurerm_role_assignment.key_vault_terraform_admin,
  ]
}
