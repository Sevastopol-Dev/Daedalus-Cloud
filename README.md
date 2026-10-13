# Project Daedalus V2: Enterprise Deception-Technology-as-Code (DaC)

An enterprise-grade, event-driven **Deception-Technology-as-Code (DaC)** framework deployed via Terraform. Project Daedalus V2 embeds high-signal canary roles, stealth honeytokens, and automated SOC alert pipelines into cloud infrastructure to detect unauthorized recon and credential misuse in real time.

---

## 📐 Architecture Overview

```text
                        +-------------------------------------------------+
                        |              ATTACKER / RECON ACTOR             |
                        +-------------------------------------------------+
                                                 |
                                                 | 1. sts:AssumeRole
                                                 v
                      +-----------------------------------------------------+
                      | Canary Role: swift-payment-gateway-operator         |
                      | Policy: DenyAll (Explicit Deny *)                   |
                      +-----------------------------------------------------+
                                                 |
                                                 | 2. CloudTrail API Event
                                                 v
                      +-----------------------------------------------------+
                      | AWS EventBridge Rule: daedalus-swift-canary-alert   |
                      +-----------------------------------------------------+
                                       /                   \
            3a. Encrypted Audit Event /                     \ 3b. High-Priority Alert
                                     v                       v
      +-----------------------------------------+   +------------------------------------+
      | CloudWatch Log Group (KMS Encrypted)    |   | AWS SNS Topic                      |
      | /aws/events/daedalus-soc-alerts         |   | Input Transformer (SOC Payload)    |
      +-----------------------------------------+   +------------------------------------+
                                                             |
                                                             v
                                                    +--------------------+
                                                    | SQS / SOC Webhook  |
                                                    +--------------------+

```

### Modular Security Architecture

* **Deception Module (`modules/daedalus_core`)**: Encapsulates all decoy assets including the canary IAM role (`swift-payment-gateway-operator`), DB credential honeytokens (`prod/swift/core-ledger-db-credentials`), synthetic security groups, KMS encryption keys, CloudWatch log sinks, and EventBridge detection routing.
* **Root Deployment (`terraform/`)**: Configures environment providers, variable mappings, and instantiates the `daedalus_core` module across environments.
* **Regulatory Compliance Framework (`COMPLIANCE.md`)**: Full mapping against PCI-DSS v4.0 Requirement 10, HIPAA § 164.312(b) audit controls, and FFIEC threat detection guidelines.
* **Automated Proof Harness (`verify_proof.sh`)**: Scripted validation suite that simulates attacker interactions, extracts IAM policies, queries CloudWatch log sinks, and captures transformed SNS/SQS alert payloads.

---

## 📁 Project Structure

```text
.
├── COMPLIANCE.md                # Regulatory compliance mapping matrix
├── docker-compose.yml           # LocalStack container specification
├── modules/
│   └── daedalus_core/          # Core reusable deception module
│       ├── main.tf              # Canary roles, KMS, EventBridge & SNS resources
│       ├── outputs.tf           # Module outputs (ARNs, Log Group names)
│       └── variables.tf         # Module inputs & default configurations
├── terraform/                   # Environment deployment root
│   ├── main.tf                  # Module instantiation
│   ├── providers.tf             # AWS / LocalStack provider configuration
│   ├── terraform.tfvars        # Local variable overrides
│   └── variables.tf             # Root environment variables
└── verify_proof.sh              # Automated proof-of-work test harness

```

---

## ⚡ Quickstart & Local Test Harness

This repository is optimized for localized testing using **LocalStack Community Edition**.

### Prerequisites

* [Terraform](https://developer.hashicorp.com/terraform/downloads) >= v1.5.0
* [Docker](https://www.docker.com/) & Docker Compose
* [AWS CLI](https://aws.amazon.com/cli/)

### 1. Launch Local Environment

Start LocalStack with the required core service endpoints (`sts,iam,secretsmanager,events,logs,sns,sqs,kms,s3`):

```bash
docker-compose up -d

```

### 2. Deploy Infrastructure via Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
cd ..

```

### 3. Run Automated Validation Suite

Execute the automated test script to run an attacker recon simulation, query the CloudWatch SOC sink, and capture the transformed alert from SQS:

```bash
chmod +x verify_proof.sh
./verify_proof.sh

```

---

## 🛡 Compliance Mapping

| Regulatory Standard | Control ID | Implementation Summary |
| --- | --- | --- |
| **PCI-DSS v4.0** | Requirement 10.2.1 | Real-time automated auditing and alerting on administrative credential access attempts. |
| **HIPAA** | § 164.312(b) Audit Controls | KMS-encrypted log sinks storing immutable records of unauthorized identity interaction. |
| **FFIEC** | Architecture & Operations | Active deception assets identifying reconnaissance prior to lateral movement. |

*See [`COMPLIANCE.md`](https://www.google.com/search?q=COMPLIANCE.md) for full control alignment detail.*

---

## 👤 Author

**Malik Thaxton**

*Cloud Security Engineering & Offensive Security*

GitHub: [@Sevastopol-Dev](https://www.google.com/search?q=https://github.com/Sevastopol-Dev)

---

