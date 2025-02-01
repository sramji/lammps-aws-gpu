#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Starting LAMMPS Container and AWS Environment Validation"
echo "======================================================="

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed${NC}"
    exit 1
fi

# Validate Docker image
echo "Validating Docker configuration..."
docker run --rm --gpus all lammps-container nvidia-smi
if [ $? -ne 0 ]; then
    echo -e "${RED}GPU access in container failed${NC}"
    exit 1
fi

# Test LAMMPS installation and accelerator packages
echo "Validating LAMMPS installation and accelerator packages..."
docker run --rm lammps-container lmp -h | grep -E "GPU package|KOKKOS package|OPT package"
if [ $? -ne 0 ]; then
    echo -e "${RED}Required LAMMPS packages not found${NC}"
    exit 1
fi

# Validate AWS configuration
echo "Validating AWS configuration..."
# Check if we're running on the correct instance type
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
if [[ $INSTANCE_TYPE != "p4d.24xlarge" && $INSTANCE_TYPE != "p4de.24xlarge" ]]; then
    echo -e "${RED}Not running on required A100 instance type${NC}"
    exit 1
fi

# Check GPU availability
nvidia-smi | grep "A100"
if [ $? -ne 0 ]; then
    echo -e "${RED}A100 GPUs not detected${NC}"
    exit 1
fi

# Run a simple benchmark
echo "Running LAMMPS benchmark..."
docker run --rm --gpus all lammps-container bash -c '
cd /opt/lammps/bench && \
lmp -in in.lj -sf gpu -pk gpu 1 -log bench.log'
if [ $? -ne 0 ]; then
    echo -e "${RED}Benchmark failed${NC}"
    exit 1
fi

# Check GPU utilization during benchmark
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{if ($1 < 50) exit 1}'
if [ $? -ne 0 ]; then
    echo -e "${RED}GPU utilization below 50%${NC}"
    exit 1
fi

# Validate storage
df -h | grep "/dev/xvda1" | awk '{if ($2 < 500) exit 1}'
if [ $? -ne 0 ]; then
    echo -e "${RED}Insufficient storage (less than 500GB)${NC}"
    exit 1
fi

echo -e "${GREEN}All validation checks passed successfully${NC}"
echo "Monthly cost estimates:"
echo "On-Demand: ~$24,220"
echo "1-year Savings Plan: ~$15,743"
echo "Spot Instance (if applicable): ~$9,831"
echo "Storage (500GB gp3): ~$50"

exit 0