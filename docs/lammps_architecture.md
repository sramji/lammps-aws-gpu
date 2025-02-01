# LAMMPS Molecular Simulation Architecture

## Infrastructure Overview (US-East-2)

### Compute Resources
- **Instance Type**: p4d.24xlarge (utilizing single A100 GPU)
- **Provisioning**: AWS Batch with Spot instances
- **Failover Strategy**: 
  - 2-minute Spot interruption warning
  - Automatic checkpoint save on interruption
  - Failover to On-Demand if Spot unavailable

### Storage Architecture
- **Primary Storage**: S3 bucket (10TB capacity)
  - Checkpoint retention: Latest 3 checkpoints only
  - Standard S3 durability (99.999999999%)
- **Instance Storage**: 
  - 1TB gp3 EBS volume for temporary files
  - IOPS optimized for checkpoint writes (10-minute intervals)

### Container Infrastructure
- **Registry**: Amazon ECR
- **Base Image**: nvidia/cuda:12.0.1-devel-ubuntu22.04
- **LAMMPS Build**:
  - Version: stable_23Jun2022
  - GPU acceleration enabled
  - All accelerator packages included
  - CUDA-aware MPI optimization

### Networking
- **VPC Configuration**:
  - Private subnet for compute instances
  - Public subnet for bastion host
  - S3 Gateway Endpoint
- **Access**:
  - SSH access via bastion host
  - Security groups limited to required ports
  - VPC Flow Logs enabled

## Cost Analysis

### Compute Costs (100 hours/week)
- **Spot Instance**: ~$32.77/hour × 100 hours = $3,277/week
  - Potential savings: 60-90% off On-Demand
  - Weekly cost with spot: $327.70 - $1,310.80
- **On-Demand Failover**: ~$32.77/hour (used only during spot interruptions)
  - Estimated 5% usage: $163.85/week

### Storage Costs
- **S3 Storage**: 
  - 10TB at $0.023/GB/month = $230/month
  - Data transfer: ~$0.09/GB (out)
- **EBS Volume**: 
  - 1TB gp3: $0.08/GB/month = $80/month
  - IOPS: Included in base price

### Additional Costs
- **ECR Storage**: ~$0.10/GB/month
- **Data Transfer**: 
  - S3 to EC2: Free
  - EC2 to Internet: $0.09/GB

### Total Monthly Cost Estimate
- **Best Case** (90% spot savings): $2,100 - $2,500
- **Worst Case** (60% spot savings): $4,000 - $4,500

## Implementation Details

### Container Configuration
```dockerfile
FROM nvidia/cuda:12.0.1-devel-ubuntu22.04

ENV LAMMPS_VERSION stable_23Jun2022
ENV CUDA_ARCH sm_80

RUN apt-get update && apt-get install -y \
    cmake \
    git \
    python3-dev \
    python3-pip \
    libfftw3-dev \
    openmpi-bin \
    libopenmpi-dev \
    awscli

RUN git clone -b ${LAMMPS_VERSION} https://github.com/lammps/lammps.git /opt/lammps

WORKDIR /opt/lammps/cmake
RUN mkdir build && cd build && cmake ../cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_MPI=yes \
    -D BUILD_OMP=yes \
    -D PKG_GPU=yes \
    -D PKG_KOKKOS=yes \
    -D Kokkos_ENABLE_CUDA=yes \
    -D Kokkos_ARCH_AMPERE80=yes \
    -D PKG_MOLECULE=yes \
    -D PKG_KSPACE=yes \
    -D PKG_MANYBODY=yes \
    && make -j$(nproc)

COPY scripts/checkpoint.sh /opt/scripts/
COPY scripts/spot-termination-handler.sh /opt/scripts/
```

### Checkpoint Management
```bash
#!/bin/bash
# checkpoint.sh
timestamp=$(date +%Y%m%d_%H%M%S)
aws s3 cp /simulation/checkpoint.* s3://bucket/checkpoints/${timestamp}/
find /simulation -name "checkpoint.*" -mtime +1 -delete

# Keep only last 3 checkpoints
checkpoints=$(aws s3 ls s3://bucket/checkpoints/ | sort -r | awk '{print $2}')
count=0
for cp in $checkpoints; do
    ((count++))
    if [ $count -gt 3 ]; then
        aws s3 rm s3://bucket/checkpoints/$cp --recursive
    fi
done
```

### AWS Batch Job Definition
```json
{
  "jobDefinitionName": "LAMMPS-Simulation",
  "type": "container",
  "containerProperties": {
    "image": "ACCOUNT.dkr.ecr.us-east-2.amazonaws.com/lammps:latest",
    "vcpus": 96,
    "memory": 1152000,
    "command": [
      "lmp",
      "-in",
      "input.lammps",
      "-sf",
      "gpu",
      "-pk",
      "gpu 1"
    ],
    "resourceRequirements": [
      {
        "type": "GPU",
        "value": "1"
      }
    ]
  }
}
```

## Performance Considerations

### GPU Optimization
- Single A100 GPU utilization
- CUDA-aware MPI for optimal performance
- Regular checkpointing (10-minute intervals)
- Memory optimization for 50K-200K atom simulations

### Simulation Times
- 50K atoms: ~2 days per 100ns simulation
- 200K atoms: ~7 days per 100ns simulation
- Checkpoint overhead: ~1-2 minutes per checkpoint

### Spot Instance Strategy
- Primary: US-East-2 p4d.24xlarge spot instances
- Backup: Automatic failover to on-demand
- Checkpoint-based recovery on interruption
- Multiple availability zones for better spot availability

## Security Measures

### Access Control
- IAM roles with least privilege
- Security groups limited to required ports
- SSH access via bastion host only
- VPC endpoints for AWS services

### Data Protection
- S3 bucket encryption enabled
- EBS volume encryption enabled
- Network traffic restricted to VPC
- Regular security patches via container updates

## Monitoring and Logging

### AWS CloudWatch
- GPU utilization metrics
- Memory usage tracking
- Spot instance interruption monitoring
- Cost tracking and alerts

### Application Logging
- LAMMPS output logs to CloudWatch
- Checkpoint success/failure monitoring
- Performance metrics collection
- Error tracking and alerting

## Disaster Recovery

### Backup Strategy
- S3 standard durability
- Latest 3 checkpoints retained
- Cross-AZ resilience
- Automated recovery from spot interruptions

### Recovery Procedures
1. Spot interruption detected
2. Final checkpoint saved
3. New instance provisioned
4. Latest checkpoint restored
5. Simulation resumed

## Future Optimizations

### Potential Improvements
- Implementation of AWS Graviton instances when available
- Auto-scaling based on simulation queue
- Cross-region backup strategy if needed
- Performance optimization based on usage patterns

### Cost Optimization
- Spot fleet with multiple instance types
- Reserved instances for baseline capacity
- S3 Intelligent Tiering for cold data
- Auto-shutdown of idle resources