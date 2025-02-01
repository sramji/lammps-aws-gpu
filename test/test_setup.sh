#!/bin/bash

# Configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="us-east-2"
ECR_REPO_NAME="lammps-simulation"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to log messages
log_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

log_error() {
    echo -e "${RED}[✗] $1${NC}"
    exit 1
}

# Function to check command existence
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is not installed"
    fi
    log_success "$1 is installed"
}

echo "Starting LAMMPS Setup Verification"
echo "================================="

# Check required tools
echo "Checking required tools..."
check_command docker
check_command aws
check_command curl

# Check AWS configuration
echo -e "\nChecking AWS configuration..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
fi
log_success "AWS credentials configured"

# Check AWS region
configured_region=$(aws configure get region)
if [ "$configured_region" != "$AWS_REGION" ]; then
    log_error "AWS region mismatch. Expected: $AWS_REGION, Got: $configured_region"
fi
log_success "AWS region correctly configured"

# Create test directory
echo -e "\nPreparing test environment..."
mkdir -p "$TEST_DIR/output"

# Create minimal LAMMPS test input
cat > "$TEST_DIR/output/test.lammps" << 'EOF'
units           real
atom_style      full
boundary        p p p

region          box block 0 10 0 10 0 10
create_box      1 box
create_atoms    1 random 100 12345 box

mass            1 1.0
pair_style      lj/cut 2.5
pair_coeff      1 1 1.0 1.0 2.5

minimize        1.0e-4 1.0e-6 1000 10000

package         gpu 1
suffix          gpu

thermo          100
run             0
EOF

# Test Docker build
echo -e "\nTesting Docker build..."
if ! docker build -t "$ECR_REPO_NAME:test" ..; then
    log_error "Docker build failed"
fi
log_success "Docker build successful"

# Test LAMMPS GPU support
echo -e "\nTesting LAMMPS GPU support..."
docker run --rm --gpus all "$ECR_REPO_NAME:test" nvidia-smi &> /dev/null
if [ $? -ne 0 ]; then
    log_error "GPU access in container failed"
fi
log_success "GPU access in container verified"

# Test LAMMPS execution
echo -e "\nTesting LAMMPS execution..."
docker run --rm --gpus all \
    -v "$TEST_DIR/output:/simulation" \
    "$ECR_REPO_NAME:test" \
    lmp -in /simulation/test.lammps
if [ $? -ne 0 ]; then
    log_error "LAMMPS test simulation failed"
fi
log_success "LAMMPS test simulation successful"

# Test AWS Batch access
echo -e "\nTesting AWS Batch access..."
if ! aws batch describe-compute-environments &> /dev/null; then
    log_error "AWS Batch access failed"
fi
log_success "AWS Batch access verified"

# Test S3 access
echo -e "\nTesting S3 access..."
test_bucket="lammps-simulations-$(aws sts get-caller-identity --query Account --output text)"
if ! aws s3api head-bucket --bucket "$test_bucket" 2>/dev/null; then
    log_error "S3 bucket access failed"
fi
log_success "S3 bucket access verified"

# Test ECR access
echo -e "\nTesting ECR access..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" &> /dev/null; then
    log_error "ECR repository access failed"
fi
log_success "ECR repository access verified"

# Cleanup
echo -e "\nCleaning up test environment..."
rm -rf "$TEST_DIR/output"

echo -e "\n${GREEN}All tests completed successfully!${NC}"
echo "You can now proceed with deploying your LAMMPS simulations."
exit 0