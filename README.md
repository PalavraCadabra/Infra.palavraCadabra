# Infra.palavraCadabra

Infrastructure as Code for the palavraCadabra platform using Terraform and AWS.

## Structure

```
terraform/
├── environments/     # Environment-specific configurations
│   ├── dev/          # Development environment
│   └── prod/         # Production environment
└── modules/          # Reusable Terraform modules
    ├── networking/   # VPC, subnets, security groups
    ├── database/     # RDS PostgreSQL + ElastiCache Redis
    ├── compute/      # ECS Fargate services
    ├── storage/      # S3 buckets + CloudFront distributions
    └── auth/         # Cognito user pools
```

## Usage

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## CI/CD

- **Pull Requests**: Automatically runs `terraform plan` and posts the output as a PR comment.
- **Merge to main**: Triggers `terraform apply` with manual approval gate.
