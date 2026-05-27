# Cloud Assessment — Production-like AWS Architecture

## Architecture Overview

A containerized Node.js application deployed on AWS ECS Fargate, behind an Application Load Balancer, with auto-scaling, RDS PostgreSQL, and CloudWatch monitoring. All infrastructure is defined as code using Terraform.

---

## How to Deploy

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.9.0
- Docker

### Step 1 — Create Terraform state backend (one-time)
```bash
aws s3 mb s3://cloud-assessment-tfstate --region ap-south-1
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### Step 2 — Build and push Docker image
```bash
cd app
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-south-1.amazonaws.com
docker build -t cloud-assessment-prod .
docker tag cloud-assessment-prod:latest <ecr_url>:latest
docker push <ecr_url>:latest
```

### Step 3 — Deploy infrastructure
```bash
cd terraform
terraform init
terraform plan -var="app_image=<ecr_url>:latest" -var="db_password=<your_password>"
terraform apply -var="app_image=<ecr_url>:latest" -var="db_password=<your_password>"
```

### Step 4 — CI/CD (automated after first deploy)
Add these secrets to GitHub repository settings:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Every push to `main` triggers a build → push to ECR → ECS rolling deploy.

---

## Design Decisions

**ECS Fargate over EC2**: Fargate eliminates node management, patching, and capacity planning. The tradeoff is slightly higher per-task cost, but for a team without a dedicated infra engineer, the operational savings are significant.

**ALB over NLB**: ALB provides HTTP/HTTPS layer-7 routing, path-based rules, and native health checks — all needed for a web application. NLB is better suited for TCP-level, ultra-low-latency workloads.

**Multi-stage Dockerfile**: The builder stage installs all dependencies and compiles assets. The production stage copies only the final artifact and installs only production dependencies, resulting in a smaller, more secure image.

**Private subnets for ECS and RDS**: Application containers and the database are never directly reachable from the internet. All inbound traffic flows through the ALB. Outbound traffic from private subnets routes through the NAT Gateway.

**ap-south-1 (Mumbai)**: Closest AWS region to South India, minimising latency for end users.

---

## Trade-offs Considered

| Decision | Trade-off |
|---|---|
| Single NAT Gateway | Saves ~$32/month vs one per AZ; single point of failure for outbound traffic |
| RDS t3.micro | Sufficient for assessment; needs upgrade to t3.medium+ for production load |
| `multi_az = false` on RDS | Reduces cost; add `multi_az = true` for production HA |
| `skip_final_snapshot = true` | Convenient for assessment teardown; must be `false` in production |
| Fargate CPU 256 / Memory 512 | Minimal for a Node.js app; scale up if response times degrade |

---

## Cost Awareness

Estimated monthly cost (ap-south-1):

| Resource | Cost |
|---|---|
| ECS Fargate (2 tasks, 0.25 vCPU, 0.5 GB) | ~$12 |
| ALB | ~$18 |
| NAT Gateway | ~$35 |
| RDS t3.micro | ~$15 |
| ECR storage | ~$1 |
| CloudWatch | ~$3 |
| **Total** | **~$84/month** |

### Optimisation approaches
- Use **Fargate Spot** for non-production environments (up to 70% savings)
- **Reserved Instances** for RDS if running beyond 1 year (up to 40% savings)
- Set **ECR lifecycle policy** to expire old images (already configured — keeps last 10)
- Set **CloudWatch log retention** to 7 days (already configured)
- Tear down NAT Gateway when not needed in dev/staging
