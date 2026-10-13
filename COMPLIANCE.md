# Project Daedalus V2 — Regulatory Compliance & Deception Matrix

## Executive Overview
Project Daedalus V2 implements **Deception Technology as Code (DaC)** within a 2-tier AWS environment. It provides real-time detection of insider threats and unauthorized lateral movement targeting SWIFT ISO 20022 payment channels and core banking databases.

---

## Regulatory Control Mapping

| Security Risk / Attack Vector | Compliance Requirement | Governance Standard | Daedalus V2 Implementation | Target Terraform Resource |
| :--- | :--- | :--- | :--- | :--- |
| **Credential Harvesting & Recon** | PCI-DSS v4.0 Req 10.2.1.4 | FFIEC Architecture & Operations | Deploys a dormant IAM Canary Role with an explicit `DenyAll` policy to detect illegal role assumption attempts. | `aws_iam_role.canary_swift_operator` |
| **Data Exfiltration / Database Probing** | PCI-DSS v4.0 Req 10.4.1 | HIPAA §164.312(b) Audit Controls | Injects synthetic database connection strings into Secrets Manager to trigger alerts upon access. | `aws_secretsmanager_secret.honeytoken_db_creds` |
| **Audit Log Tampering & Erasure** | PCI-DSS v4.0 Req 10.3.1 | NIST SP 800-53 AU-9 | Protects audit log streams using customer-managed KMS keys with forced key rotation. | `aws_kms_key.daedalus_log_key` |
| **Alert Delay / Unattributed Incident** | PCI-DSS v4.0 Req 10.2.2 | HIPAA §164.312(a)(2)(i) | Formats EventBridge payloads with `User-Agent`, `Source-IP`, and `Principal ARN` directly to SNS. | `aws_cloudwatch_event_target.send_to_sns` |

---

## Technical Audit Proof
* **Telemetry Retention:** Log Group retention is fixed at 90 days (`retention_in_days = 90`).
* **KMS Rotation:** Key rotation is enforced (`enable_key_rotation = true`).
* **Zero Blast Radius:** Canary IAM policies explicitly deny all API operations across all resources (`Action = "*", Resource = "*", Effect = "Deny"`).
