# Cloud Assessment — Production-like AWS Architecture

**Candidate:** Ganapathy Ram  
**Position:** Cloud Engineer  
**Company:** Siddhan Intelligence  

---

## Architecture Overview

A containerized Node.js application deployed on AWS ECS Fargate, behind an
Application Load Balancer, with auto-scaling and CloudWatch monitoring.
All infrastructure is defined as code using Terraform and deployed via
GitHub Actions CI/CD pipelines.

---

## Architecture Diagram

![Architecture Diagram](architecture-diagram.png)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Node.js + Express |
| Containerization | Docker (Multi-stage build) |
| Infrastructure as Code | Terraform 1.15.3 |
| Cloud Provider | AWS (ap-south-1 — Mumbai) |
| Container Registry | Amazon ECR |
| Container Orchestration | Amazon ECS Fargate |
| Load Balancer | AWS Application Load Balancer |
| Auto Scaling | AWS Application Auto Scaling |
| Monitoring | Amazon CloudWatch |
| CI/CD | GitHub Actions |
| Secret Scanning | GitLeaks |
| Image Scanning | Trivy |
| IaC Security | Checkov |
| State Management | S3 + S3 Native Locking (Terraform 1.15+) |

---

## Repository Structure

```
cloud-assessment/
├── app/
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── index.js                # Express app with /health endpoint
│   ├── package.json
│   ├── package-lock.json
│   └── .dockerignore
├── terraform/
│   ├── main.tf                 # Root module — calls all child modules
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── provider.tf             # AWS provider configuration
│   ├── versions.tf             # Terraform and provider version constraints
│   ├── backend.tf              # S3 remote state with native locking
│   └── modules/
│       ├── vpc/                # VPC, subnets, IGW, NAT, route tables
│       ├── alb/                # ALB, target group, listener, security group
│       ├── ecr/                # ECR repository and lifecycle policy
│       ├── ecs/                # ECS cluster, task definition, service, IAM
│       ├── autoscaling/        # ECS auto scaling policies
│       └── monitoring/         # CloudWatch dashboard and alarms
├── .github/
│   └── workflows/
│       ├── terraform.yml       # Infrastructure pipeline
│       └── deploy.yml          # Application deployment pipeline
├── .gitignore
└── README.md
```

---

## Infrastructure Components

### Networking — VPC
- VPC with CIDR `10.0.0.0/16`
- 2 Public subnets across 2 Availability Zones
- 2 Private subnets across 2 Availability Zones
- Internet Gateway for public subnet access
- NAT Gateway for private subnet outbound traffic
- Separate route tables for public and private subnets
- Default security group with all traffic restricted

### Load Balancer — ALB
- Application Load Balancer deployed in public subnets
- Target group with `/health` health checks on port 8080
- HTTP listener on port 80 forwarding traffic to ECS tasks
- Security group allowing HTTP inbound, restricted egress to ECS only

### Container Registry — ECR
- Private ECR repository with image scanning on every push
- Lifecycle policy retaining only the last 10 images

### Container Orchestration — ECS Fargate
- ECS Fargate cluster — no EC2 nodes to manage or patch
- Task definition: 0.25 vCPU, 512 MB memory
- 2 desired tasks running across private subnets
- IAM execution role with least privilege permissions
- CloudWatch log group with 365 days retention
- Security group — inbound from ALB only, outbound HTTPS only

### Auto Scaling
- Minimum tasks: 2, Maximum tasks: 6
- Scale out when CPU utilization exceeds 70%
- Scale out when Memory utilization exceeds 75%
- Scale in cooldown: 300 seconds
- Scale out cooldown: 60 seconds

### Monitoring — CloudWatch
- Dashboard with ECS CPU, ECS Memory, and ALB Request Count widgets
- Alarm: ECS CPU > 80%
- Alarm: ECS Memory > 80%
- Alarm: ALB 5xx errors > 10 per minute

---

## CI/CD Pipelines

### Pipeline 1 — Terraform Infrastructure

Triggers on push to `main` when `terraform/**` files change.

```
GitLeaks Secret Scan
        ↓
Checkov IaC Security Scan (soft fail)
        ↓
Terraform Init
        ↓
Terraform Validate
        ↓
Terraform Plan
        ↓
Terraform Apply
```

### Pipeline 2 — Application Deployment

Triggers on push to `main` when `app/**` files change.

```
GitLeaks Secret Scan
        ↓
Build Docker Image
        ↓
Push to ECR
        ↓
Trivy Image Scan (fails on HIGH/CRITICAL CVEs)
        ↓
Deploy to ECS (rolling update)
```

### Security Tools

| Tool | What it checks | Fails pipeline? |
|---|---|---|
| GitLeaks | Secrets and API keys in git history | Yes |
| Checkov | Terraform IaC misconfigurations | No (soft fail) |
| Trivy | Docker image CVE vulnerabilities | Yes |

---

## How to Deploy

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.15.3
- Docker installed

### Step 1 — Create S3 bucket for Terraform state
```bash
aws s3api create-bucket \
  --bucket cloud-assessment-tfstate \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket cloud-assessment-tfstate \
  --versioning-configuration Status=Enabled
```

### Step 2 — Add GitHub Secrets
Go to repository → **Settings → Secrets and variables → Actions**

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user secret key |

### Step 3 — Infrastructure deployment (automatic)
```bash
git checkout dev
git add terraform/
git commit -m "feat: infrastructure changes"
git push origin dev
# Raise PR → merge to main → terraform.yml triggers automatically
```

### Step 4 — Application deployment (automatic)
```bash
git checkout dev
git add app/
git commit -m "feat: app changes"
git push origin dev
# Raise PR → merge to main → deploy.yml triggers automatically
```

### Step 5 — Access the application
```bash
cd terraform
terraform output alb_dns_name
```
Open in browser:
```
http://<alb-dns-name>/
http://<alb-dns-name>/health
```

---

## Branch Strategy

```
dev   → all development work happens here
  ↓
PR raised from dev → main
  ↓
Pipeline runs on PR (security scans)
  ↓
PR merged to main
  ↓
Pipeline runs on main (apply / deploy)
```

- Direct pushes to `main` are blocked via branch ruleset
- All changes go through PR from `dev` to `main`
- Pipelines trigger only on `main` — never on `dev`

---

## Design Decisions

**ECS Fargate over EC2**
Fargate eliminates node management, patching, and capacity planning. The
tradeoff is slightly higher per-task cost, but the operational savings are
significant for a small team.

**ALB over NLB**
ALB provides HTTP layer-7 routing and native health checks needed for a
web application. NLB is better suited for TCP-level, ultra-low-latency
workloads.

**Multi-stage Dockerfile**
The builder stage installs all dependencies. The production stage copies
only the final artifact and installs only production dependencies — resulting
in a smaller, more secure image running as a non-root user.

**Private subnets for ECS**
ECS tasks are never directly reachable from the internet. All inbound
traffic flows through the ALB. Outbound traffic routes through the NAT Gateway.

**ap-south-1 — Mumbai**
Closest AWS region to South India, minimising latency for end users.

**S3 native locking over DynamoDB**
Terraform 1.15+ supports S3 native state locking via `use_lockfile = true`,
removing the need for a separate DynamoDB table and reducing cost.

**Separate pipelines for infra and app**
Infrastructure changes are rare and need careful review. Application
deployments happen frequently and need fast feedback. Separating them
prevents app deployments from being blocked by infra changes.

---

## Trade-offs Considered

| Decision | Trade-off |
|---|---|
| Single NAT Gateway | Saves ~$32/month vs one per AZ — single point of failure for outbound traffic |
| Fargate CPU 256 / Memory 512 | Minimal for Node.js — scale up if response times degrade under load |
| HTTP only, no HTTPS | Acceptable for assessment — production would use ACM certificate + HTTPS |
| `enable_deletion_protection = false` | Easy teardown after assessment — must be `true` in production |
| Checkov `soft_fail: true` | Pipeline continues with warnings — production would enforce all checks |
| WAF not implemented | Saves ~$5/month — production would attach AWS WAF to ALB for OWASP Top 10 protection |

---

## Cost Awareness

Estimated monthly cost (ap-south-1):

| Resource | Specification | Cost |
|---|---|---|
| ECS Fargate | 2 tasks, 0.25 vCPU, 0.5 GB | ~$6/month |
| Application Load Balancer | 1 ALB | ~$16/month |
| NAT Gateway | 1 NAT GW | ~$34/month |
| ECR | Storage + transfer | ~$1/month |
| CloudWatch | Logs + metrics + dashboard | ~$4/month |
| S3 | Terraform state | < $1/month |
| **Total** | | **~$61/month** |

### Cost Optimisation Approaches
- **Fargate Spot** for non-production — up to 70% cost savings
- **ECR lifecycle policy** keeps only last 10 images — prevents storage bloat
- **CloudWatch log retention** set to 365 days — auto-expires old logs
- **Single NAT Gateway** instead of one per AZ — saves ~$32/month
- **Auto scaling** ensures only required tasks run at any time

---

## Screenshots

### Terraform Pipeline
![Terraform Pipeline](screenshots/terraform-pipeline.png)

### Deploy Pipeline
![Deploy Pipeline](screenshots/deploy-pipeline.png)

### ECS Cluster
![ECS Cluster](screenshots/ecs-cluster.png)

### ECS Service Running
![ECS Service](screenshots/ecs-service.png)

### ECR Image Pushed
![ECR Image](screenshots/ecr-image.png)

### Application Load Balancer
![ALB](screenshots/alb.png)

### Application Live
![App Live](screenshots/app-live.png)

### VPC
![VPC](screenshots/vpc.png)

### CloudWatch Dashboard
![CloudWatch Dashboard](screenshots/cloudwatch-dashboard.png)

### CloudWatch Alarms
![CloudWatch Alarms](screenshots/cloudwatch-alarms.png)
