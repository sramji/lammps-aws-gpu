# LAMMPS AWS Infrastructure Project

This repository contains the infrastructure code and documentation for running LAMMPS molecular simulations on AWS using GPU acceleration. The project is currently in the implementation phase with completed infrastructure code and documentation, pending deployment and testing.

## Project Status

- ✅ Infrastructure code complete
- ✅ Documentation complete
- ❌ Deployment pending
- ❌ Testing pending

See [Implementation Status](docs/implementation_status.md) for detailed progress tracking.

## Repository Structure

```
.
├── docs/
│   ├── lammps_architecture.md  - Detailed architecture documentation
│   ├── plans.md               - Implementation plans and timeline
│   ├── memories.md            - Project decisions and requirements
│   └── implementation_status.md - Current progress tracking
├── scripts/
│   ├── checkpoint.sh          - Checkpoint management
│   └── spot-termination-handler.sh - Spot instance handling
├── examples/
│   ├── README.md              - Example usage documentation
│   └── polymer_simulation.lammps - Sample simulation config
├── test/
│   └── test_setup.sh          - Setup validation script
├── Dockerfile                 - LAMMPS container configuration
├── deploy.sh                  - AWS deployment script
└── LICENSE                    - MIT License
```

## Features

- GPU-accelerated LAMMPS container (NVIDIA A100)
- AWS Batch integration with spot instance support
- Automated checkpoint management (10-minute intervals)
- Spot interruption handling
- S3 integration for result storage
- SSH access support

## Requirements

- AWS Account with appropriate permissions
- Docker with NVIDIA container toolkit
- AWS CLI v2
- Local GPU for testing (recommended)

## Next Steps

1. **Local Testing**
   - Build container
   - Validate GPU acceleration
   - Test checkpoint system

2. **AWS Deployment**
   - Configure VPC and networking
   - Set up S3 storage
   - Deploy AWS Batch infrastructure

3. **Production Setup**
   - Implement security controls
   - Configure monitoring
   - Set up alerting

See [Implementation Plans](docs/plans.md) for detailed steps.

## Documentation

- [Architecture Documentation](docs/lammps_architecture.md)
- [Implementation Plans](docs/plans.md)
- [Project Memories](docs/memories.md)
- [Implementation Status](docs/implementation_status.md)
- [Example Usage](examples/README.md)

## Getting Started

**Note: Implementation in progress. These steps will be validated during testing phase.**

1. Clone this repository
2. Review the architecture documentation
3. Follow deployment instructions in deploy.sh
4. Run test_setup.sh to validate the installation

## Cost Estimates

- Spot Instance (p4d.24xlarge): 60-90% savings off on-demand
- Monthly cost range: $2,100 - $4,500
- Based on 100 hours/week usage

## Support

This project is currently in implementation phase. For questions or issues:
1. Review the documentation
2. Check implementation status
3. Create a GitHub issue for questions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.