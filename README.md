# OgaFix Infrastructure as Code (Terraform)

This repository contains the Terraform configuration for provisioning the OgaFix MVP infrastructure on AWS using the Lightsail + RDS + S3 + CloudFront approach.

## Architecture Overview

The infrastructure includes:

- **Amazon VPC:** Custom VPC with public and private subnets across 2 availability zones
- **Amazon RDS (PostgreSQL):** Managed relational database in private subnets
- **Amazon S3:** Object storage for images and assets
- **Amazon CloudFront:** CDN for fast content delivery
- **Security Groups:** Network access control for Lightsail and RDS
- **AWS Lightsail:** Backend API server (provisioned manually after infrastructure setup)

## Prerequisites

1. **AWS Account:** Create an AWS account if you don't have one
2. **Terraform:** Install Terraform v1.0+ from https://www.terraform.io/downloads
3. **AWS CLI:** Install AWS CLI v2 from https://aws.amazon.com/cli/
4. **AWS Credentials:** Configure AWS credentials locally

## Setup Instructions

### Step 1: Configure AWS Credentials

```bash
aws configure
```

When prompted, enter:
- AWS Access Key ID: `AKIA3J2JKIWXIO4LQ657`
- AWS Secret Access Key: (the secret key provided)
- Default region: `eu-west-1`
- Default output format: `json`

### Step 2: Update terraform.tfvars

Edit `terraform.tfvars` and update the following values:

```hcl
db_password          = "YourSecurePassword123!" # Change this to a strong password
s3_bucket_name       = "ogafix-images-prod-eu-west-1" # Must be globally unique
```

**Important:** S3 bucket names must be globally unique across all AWS accounts. Consider adding a timestamp or random suffix.

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads the required AWS provider and initializes the Terraform working directory.

### Step 4: Plan the Infrastructure

```bash
terraform plan -out=tfplan
```

Review the output to ensure all resources are being created as expected.

### Step 5: Apply the Configuration

```bash
terraform apply tfplan
```

This will provision all AWS resources. The process typically takes 10-15 minutes.

### Step 6: Capture Outputs

After successful deployment, Terraform will display important outputs:

```
rds_endpoint = "ogafix-db.xxxxx.eu-west-1.rds.amazonaws.com:5432"
rds_address = "ogafix-db.xxxxx.eu-west-1.rds.amazonaws.com"
s3_bucket_name = "ogafix-images-prod-eu-west-1"
cloudfront_domain_name = "d123456.cloudfront.net"
vpc_id = "vpc-xxxxx"
security_group_lightsail_id = "sg-xxxxx"
```

**Save these outputs** - you'll need them for the website configuration.

## Provisioning AWS Lightsail Instance

After the Terraform infrastructure is created, you need to manually provision the Lightsail instance:

### Step 1: Create Lightsail Instance

1. Go to AWS Console → Lightsail
2. Click "Create Instance"
3. Select Region: **eu-west-1**
4. Select Blueprint: **Node.js 18**
5. Select Plan: **$5/month** (512 MB RAM, 1 vCPU, 20 GB SSD)
6. Name: `ogafix-api`
7. Click "Create Instance"

### Step 2: Configure Lightsail Instance

1. Once the instance is running, click on it to open the console
2. Create a new user for deployment:

```bash
sudo useradd -m -s /bin/bash ogafix
sudo usermod -aG sudo ogafix
sudo su - ogafix
```

3. Generate SSH key for deployment:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ogafix-deploy
```

4. Save the private key locally for future deployments

### Step 3: Connect Lightsail to VPC (Optional but Recommended)

1. In Lightsail console, go to Networking
2. Attach the instance to the VPC created by Terraform
3. Assign a static IP address

## Database Connection String

Use the RDS endpoint from Terraform outputs to create your connection string:

```
postgresql://ogafixadmin:YourSecurePassword123!@ogafix-db.xxxxx.eu-west-1.rds.amazonaws.com:5432/ogafix
```

## S3 and CloudFront Configuration

The S3 bucket is automatically configured with:
- Public read access for images
- CloudFront CDN distribution for fast delivery
- Versioning enabled for backup

Upload images to S3 using the AWS CLI or SDK:

```bash
aws s3 cp image.jpg s3://ogafix-images-prod-eu-west-1/portfolios/
```

Access images via CloudFront:

```
https://d123456.cloudfront.net/portfolios/image.jpg
```

## Destroying Infrastructure

To remove all AWS resources (use with caution):

```bash
terraform destroy
```

This will delete all resources created by Terraform.

## Troubleshooting

### Issue: S3 bucket name already exists

**Solution:** S3 bucket names are globally unique. Change the bucket name in `terraform.tfvars` to something unique.

### Issue: RDS creation fails

**Solution:** Ensure your AWS account has sufficient quota for RDS instances. Check AWS Service Quotas in the console.

### Issue: VPC CIDR conflict

**Solution:** If you have existing VPCs with overlapping CIDR blocks, modify the VPC CIDR in `main.tf` (currently 10.0.0.0/16).

## Security Considerations

1. **Database Password:** Change the default password in `terraform.tfvars` to a strong, unique password
2. **AWS Credentials:** Never commit AWS credentials to the repository
3. **Security Groups:** Review and restrict security group rules as needed
4. **RDS Backups:** Enable automated backups (already configured for 7 days)
5. **S3 Bucket Policy:** Review the S3 bucket policy to ensure it meets your security requirements

## Next Steps

1. Provision the Lightsail instance (see instructions above)
2. Deploy the OgaFix backend API to Lightsail
3. Configure DNS records in GoDaddy to point to Lightsail and CloudFront
4. Deploy the frontend to GoDaddy hosting

## Support

For issues or questions, refer to:
- Terraform Documentation: https://www.terraform.io/docs
- AWS Documentation: https://docs.aws.amazon.com
- OgaFix Project Plan: See the main project documentation