#!/bin/bash

# Configuration
AWS_REGION="us-east-2"
ECR_REPO_NAME="lammps-simulation"
BATCH_COMPUTE_ENV="LammpsComputeEnv"
BATCH_JOB_QUEUE="LammpsJobQueue"
BATCH_JOB_DEFINITION="LammpsJobDef"
S3_BUCKET_NAME="lammps-simulations-$(aws sts get-caller-identity --query Account --output text)"

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Check AWS CLI installation
if ! command -v aws &> /dev/null; then
    handle_error "AWS CLI is not installed"
fi

# Check Docker installation
if ! command -v docker &> /dev/null; then
    handle_error "Docker is not installed"
fi

# Create ECR repository
log_message "Creating ECR repository..."
aws ecr create-repository \
    --repository-name "$ECR_REPO_NAME" \
    --region "$AWS_REGION" \
    || handle_error "Failed to create ECR repository"

# Get ECR repository URI
ECR_REPO_URI=$(aws ecr describe-repositories \
    --repository-names "$ECR_REPO_NAME" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text)

# Login to ECR
log_message "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO_URI" \
    || handle_error "Failed to login to ECR"

# Build Docker image
log_message "Building Docker image..."
docker build -t "$ECR_REPO_NAME" . \
    || handle_error "Failed to build Docker image"

# Tag and push image
log_message "Pushing image to ECR..."
docker tag "$ECR_REPO_NAME:latest" "$ECR_REPO_URI:latest"
docker push "$ECR_REPO_URI:latest" \
    || handle_error "Failed to push image to ECR"

# Create S3 bucket
log_message "Creating S3 bucket..."
aws s3api create-bucket \
    --bucket "$S3_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" \
    || handle_error "Failed to create S3 bucket"

# Enable encryption on S3 bucket
aws s3api put-bucket-encryption \
    --bucket "$S3_BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Create AWS Batch compute environment
log_message "Creating Batch compute environment..."
aws batch create-compute-environment \
    --compute-environment-name "$BATCH_COMPUTE_ENV" \
    --type MANAGED \
    --state ENABLED \
    --compute-resources '{
        "type": "SPOT",
        "allocationStrategy": "SPOT_CAPACITY_OPTIMIZED",
        "maxvCpus": 96,
        "minvCpus": 0,
        "desiredvCpus": 0,
        "instanceTypes": ["p4d.24xlarge"],
        "subnets": ["SUBNET_ID_PLACEHOLDER"],
        "securityGroupIds": ["SECURITY_GROUP_ID_PLACEHOLDER"],
        "instanceRole": "ecsInstanceRole",
        "spotIamFleetRole": "AWSServiceRoleForEC2SpotFleet"
    }' \
    --service-role "AWSServiceRoleForBatch" \
    || handle_error "Failed to create compute environment"

# Create job queue
log_message "Creating job queue..."
aws batch create-job-queue \
    --job-queue-name "$BATCH_JOB_QUEUE" \
    --state ENABLED \
    --priority 1 \
    --compute-environment-order order=1,computeEnvironment="$BATCH_COMPUTE_ENV" \
    || handle_error "Failed to create job queue"

# Create job definition
log_message "Creating job definition..."
aws batch register-job-definition \
    --job-definition-name "$BATCH_JOB_DEFINITION" \
    --type container \
    --container-properties '{
        "image": "'$ECR_REPO_URI':latest",
        "vcpus": 96,
        "memory": 1152000,
        "command": ["lmp", "-in", "input.lammps", "-sf", "gpu", "-pk", "gpu 1"],
        "jobRoleArn": "JOB_ROLE_ARN_PLACEHOLDER",
        "volumes": [
            {
                "host": {
                    "sourcePath": "/dev/nvidia0"
                },
                "name": "nvidia0"
            }
        ],
        "mountPoints": [
            {
                "containerPath": "/dev/nvidia0",
                "readOnly": false,
                "sourceVolume": "nvidia0"
            }
        ],
        "resourceRequirements": [
            {
                "type": "GPU",
                "value": "1"
            }
        ]
    }' \
    || handle_error "Failed to create job definition"

log_message "Deployment completed successfully!"
log_message "Next steps:"
log_message "1. Update the compute environment with your subnet and security group IDs"
log_message "2. Update the job definition with your IAM role ARN"
log_message "3. Configure your LAMMPS input files"
log_message "4. Submit jobs using: aws batch submit-job --job-name <name> --job-queue $BATCH_JOB_QUEUE --job-definition $BATCH_JOB_DEFINITION"

exit 0