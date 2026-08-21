# AWS Deployment Guide for IQ Games

Complete guide to deploy IQ Games on AWS with DynamoDB, Lambda, API Gateway, and Cognito.

## Architecture Overview

```
┌─────────────┐
│  Flutter    │
│   App       │
└──────┬──────┘
       │
       ├─────────────────────┬──────────────────────┐
       │                     │                      │
   ┌───▼───┐            ┌───▼────┐          ┌──────▼──┐
   │Cognito│            │API GW  │          │   S3    │
   │ Auth  │            │(Lambda)│          │ Assets  │
   └───┬───┘            └───┬────┘          └─────────┘
       │                    │
       └────────┬───────────┘
                │
           ┌────▼─────┐
           │ DynamoDB  │
           │  Tables   │
           └───────────┘
           
Tables:
- Users
- Scores (with GSI for gameId)
- Leaderboards (with GSI for userId)
```

---

## 🚀 Quick Start (5 Steps)

### Step 1: Create AWS Account

1. Go to [AWS Console](https://aws.amazon.com)
2. Click "Create an AWS Account"
3. Complete sign-up (free tier available for 1 year)
4. Verify email and add payment method
5. Complete identity verification

### Step 2: Create IAM User for Terraform

Go to [IAM Console](https://console.aws.amazon.com/iam):

```bash
1. Go to Users > Create User
2. Name: terraform-deployer
3. Attach Policy: AdministratorAccess (for simplicity)
4. Click Create
5. Go to Security Credentials tab
6. Create Access Key
7. Copy Access Key ID and Secret Access Key
```

### Step 3: Add GitHub Secrets

Go to your GitHub repository:

1. **Settings** > **Secrets and variables** > **Actions**
2. Add these secrets:

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your access key from Step 2 |
| `AWS_SECRET_ACCESS_KEY` | Your secret access key from Step 2 |
| `SLACK_WEBHOOK` | (Optional) Slack notification webhook |

### Step 4: Enable AWS Free Tier Services

Ensure these are in your AWS free tier:
- ✅ DynamoDB: 25 GB free storage
- ✅ Lambda: 1 million free requests/month
- ✅ API Gateway: 1 million free requests/month
- ✅ S3: 5 GB free storage
- ✅ CloudWatch: First 10 alarms free

### Step 5: Deploy Infrastructure

```bash
# Push your code to GitHub main branch
git add .
git commit -m "Deploy to AWS"
git push origin main

# GitHub Actions will automatically:
# 1. Run Terraform plan
# 2. Deploy DynamoDB tables
# 3. Create Lambda function
# 4. Set up API Gateway
# 5. Build and deploy Flutter app
```

---

## 🔐 AWS Credentials Setup

### Create Access Keys Securely

```bash
# In AWS Console (IAM):
1. Go to Users
2. Select terraform-deployer (or your user)
3. Security Credentials tab
4. Create Access Key
5. Select "Application running outside AWS"
6. Download CSV file
7. Base64 encode the secret:
   cat credentials.csv | base64
```

**DO NOT:**
- ❌ Commit access keys to GitHub
- ❌ Share access keys via email
- ❌ Use root account keys
- ❌ Create permanent keys for temporary needs

**DO:**
- ✅ Use IAM users with specific permissions
- ✅ Rotate keys every 90 days
- ✅ Use temporary credentials when possible
- ✅ Enable MFA on your AWS account

---

## 📋 Terraform Configuration

### Edit aws_terraform.tfvars

```hcl
aws_region       = "ap-south-1"  # Mumbai (closest to India)
environment      = "dev"          # dev, staging, or prod
lambda_timeout   = 30            # seconds
lambda_memory    = 256           # MB
```

### DynamoDB Tables Created

**Users Table:**
```
Primary Key: userId (String)
Attributes:
  - displayName: String
  - totalScore: Number
  - gamesPlayed: Number
  - createdAt: Number (timestamp)
```

**Scores Table:**
```
Primary Key: userId (String) + timestamp (Number)
Attributes:
  - gameId: String
  - score: Number
  - difficulty: String
  - duration: Number (seconds)

Global Secondary Index:
  - gameId + timestamp (for querying by game)
```

**Leaderboards Table:**
```
Primary Key: gameId (String) + score (Number, descending)
Attributes:
  - userId: String
  - displayName: String
  - timestamp: Number

Global Secondary Index:
  - userId + score (for user lookups)
```

---

## 🔧 Local Development

### Install Required Tools

```bash
# AWS CLI
pip install awscli

# Terraform
# Download from https://www.terraform.io/downloads

# Configure AWS credentials
aws configure
# Enter Access Key ID
# Enter Secret Access Key
# Enter default region: ap-south-1
# Enter default output format: json
```

### Plan Terraform Changes Locally

```bash
cd infrastructure

# Initialize Terraform
terraform init -backend=false

# Plan changes
terraform plan -var-file=aws_terraform.tfvars

# If satisfied, apply:
terraform apply -var-file=aws_terraform.tfvars
```

### Deploy Lambda Function Locally

```bash
# Package Lambda
cd infrastructure
zip -j lambda_function.zip lambda_function.py

# Deploy via Terraform
terraform apply -var-file=aws_terraform.tfvars
```

---

## 🧪 Testing the Deployment

### Test API Gateway Endpoint

```bash
# Get the API endpoint from Terraform output
API_ENDPOINT=$(terraform output -raw api_endpoint)

# Test leaderboard endpoint
curl -X GET "$API_ENDPOINT/leaderboard/memory_game?gameId=memory_game&limit=10"

# Expected response:
# {
#   "gameId": "memory_game",
#   "leaderboard": [...],
#   "count": 0
# }
```

### Test DynamoDB Connection from Flutter

```dart
// In your Flutter app
final awsService = AWSService();
await awsService.initialize(
  region: 'ap-south-1',
  accessKeyId: 'YOUR_ACCESS_KEY',
  secretAccessKey: 'YOUR_SECRET_KEY',
  usersTable: 'iq-games-dev-users',
  scoresTable: 'iq-games-dev-scores',
  leaderboardsTable: 'iq-games-dev-leaderboards',
  assetsBucket: 'iq-games-dev-assets-123456789',
  apiEndpoint: 'https://xxxxx.execute-api.ap-south-1.amazonaws.com/dev',
);

// Create user
await awsService.createUserProfile(
  userId: 'user123',
  displayName: 'John Doe',
);

// Submit score
await awsService.submitGameScore(
  userId: 'user123',
  gameId: 'memory_game',
  score: 1500,
  duration: 120,
);

// Get leaderboard
final leaderboard = await awsService.getGameLeaderboard('memory_game');
print(leaderboard);
```

---

## 📊 Monitor Your Deployment

### View CloudWatch Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/iq-games-leaderboard-api --follow

# API Gateway logs
aws logs tail /aws/apigateway/iq-games --follow
```

### Check DynamoDB Usage

```bash
# View table size and item count
aws dynamodb describe-table --table-name iq-games-dev-scores

# Get cost estimate
# AWS Console > DynamoDB > Tables > Metrics
```

### Monitor Free Tier Usage

Go to [AWS Billing Console](https://console.aws.amazon.com/billing):
1. **Billing Dashboard** - See free tier usage
2. **Cost Explorer** - Track spending
3. **Budgets** - Set alerts for overspending

---

## 💰 Cost Monitoring

### Free Tier Limits (Monthly)

| Service | Free Tier | Your Game |
|---------|-----------|-----------|
| **DynamoDB** | 25 GB storage, 25 WCU, 100 RCU | Shared storage, pay-per-request ✅ |
| **Lambda** | 1 million requests, 3.15M seconds | ~10K requests/day = ✅ |
| **API Gateway** | 1 million requests | ~10K requests/day = ✅ |
| **S3** | 5 GB | Small game assets = ✅ |
| **CloudWatch** | 10 custom metrics, 1GB logs | ✅ |
| **Cognito** | 50K monthly active users | ✅ |

### Estimated Costs When Free Tier Ends

**Scenario: 10,000 DAU, 100,000 API calls/month**

- DynamoDB (pay-per-request): $1-3/month
- Lambda: $0.50/month
- API Gateway: $0.35/month
- S3: $0.50/month
- Data transfer: $0-1/month
- **Total: ~$3-5/month**

### Cost Optimization Tips

1. **Use pay-per-request** for DynamoDB (already configured)
2. **Enable S3 lifecycle policies** (deletes old files)
3. **Set CloudWatch log retention** (default: infinite)
4. **Use AWS Lambda reserved concurrency** to limit scaling
5. **Monitor with CloudWatch Budgets** to prevent surprises

---

## 🆘 Troubleshooting

### Terraform Errors

```bash
# "InvalidClientTokenId" - Credentials expired or invalid
aws configure
# Re-enter access keys

# "AccessDenied" - IAM user lacks permissions
# Add AdministratorAccess policy to IAM user

# "ResourceInUseException" - Table already exists
# Run: terraform import aws_dynamodb_table.users iq-games-dev-users
```

### Lambda Deployment Fails

```bash
# Check Lambda function
aws lambda get-function --function-name iq-games-leaderboard-api

# View errors
aws logs tail /aws/lambda/iq-games-leaderboard-api --follow

# Redeploy
terraform apply -var-file=aws_terraform.tfvars -replace='aws_lambda_function.leaderboard_api'
```

### DynamoDB Connection Issues

```dart
// Check credentials
print(AWSService._dynamodb);

// Check table names match
const usersTable = 'iq-games-dev-users';
// Verify in AWS Console > DynamoDB > Tables

// Check IAM permissions
// User must have dynamodb:* on these tables
```

### API Gateway Not Working

```bash
# Check API endpoint
terraform output api_endpoint

# Test endpoint
curl -v https://xxxxx.execute-api.ap-south-1.amazonaws.com/dev/leaderboard/memory_game

# Check API logs
aws logs tail /aws/apigateway/iq-games --follow
```

---

## 🔄 Updating Infrastructure

### Add New DynamoDB Table

1. Edit `infrastructure/aws_main.tf`
2. Add new `aws_dynamodb_table` resource
3. Push to GitHub → Terraform applies changes
4. Update Flutter code to use new table

### Change Lambda Code

1. Edit `infrastructure/lambda_function.py`
2. Push to GitHub → GitHub Actions rebuilds and deploys
3. No downtime during deployment

### Increase Lambda Memory/Timeout

1. Edit `infrastructure/aws_terraform.tfvars`:
   ```hcl
   lambda_memory    = 512  # Increase from 256
   lambda_timeout   = 60   # Increase from 30
   ```
2. Push to GitHub → Terraform applies changes

---

## 📚 Useful AWS Commands

```bash
# DynamoDB
aws dynamodb list-tables
aws dynamodb scan --table-name iq-games-dev-users
aws dynamodb delete-table --table-name iq-games-dev-scores

# Lambda
aws lambda list-functions
aws lambda get-function-concurrency --function-name iq-games-leaderboard-api
aws lambda delete-function --function-name iq-games-leaderboard-api

# API Gateway
aws apigatewayv2 get-apis
aws apigatewayv2 get-stages --api-id xxxxx

# IAM
aws iam list-access-keys
aws iam delete-access-key --user-name terraform-deployer --access-key-id XXXXX

# CloudWatch
aws logs describe-log-groups
aws logs tail /aws/lambda/iq-games-leaderboard-api --follow
```

---

## 🚀 Next Steps

1. ✅ Create AWS account and IAM user
2. ✅ Add GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
3. ✅ Push code to GitHub main branch
4. ✅ Wait for GitHub Actions to deploy infrastructure
5. ✅ Test API endpoint with curl
6. ✅ Test from Flutter app
7. ✅ Monitor DynamoDB usage in AWS Console
8. ✅ Monitor costs in Billing Console

---

## 📖 AWS Documentation

- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/)
- [Cognito Developer Guide](https://docs.aws.amazon.com/cognito/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

---

**Last Updated:** 2026-08-21  
**Status:** Production Ready ✅

