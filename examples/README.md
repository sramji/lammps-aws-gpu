# LAMMPS Simulation Examples

This directory contains example LAMMPS input files and configurations optimized for polymer simulations on AWS with GPU acceleration.

## Files

- `polymer_simulation.lammps`: Base template for polymer simulations
  - Configured for GPU acceleration on A100
  - Includes checkpoint configuration
  - Optimized for 50K-200K atom systems

## Usage

1. Create your initial configuration file (`initial_config.data`)
2. Modify the simulation parameters in `polymer_simulation.lammps`:
   - Force field parameters
   - Temperature settings
   - Run duration
   - Output frequency

### Key Parameters to Adjust

```tcl
# System size and periodic boundary conditions
boundary        p p p    # Change if non-periodic boundaries needed

# Force field parameters
pair_coeff      1 1 0.2 2.5    # Adjust for your polymer type
bond_coeff      1 350.0 1.54   # Modify bond parameters
angle_coeff     1 60.0 109.5   # Modify angle parameters

# Temperature control
fix             1 all nvt temp 300.0 300.0 100.0  # Adjust temperature

# Simulation duration
timestep        1.0             # Adjust timestep size
run             100000000       # Adjust run length
```

### GPU Optimization

The script is pre-configured for optimal GPU performance:
```tcl
package         gpu 1
suffix          gpu
```

### Checkpoint Configuration

Checkpoints are configured to save every 10,000 steps:
```tcl
restart         10000 checkpoint.*.restart
```

This aligns with the AWS Batch spot instance handling strategy.

## Performance Considerations

- For 50K atom systems: ~2 days per 100ns
- For 200K atom systems: ~7 days per 100ns
- Checkpoint overhead: ~1-2 minutes per save

## Output Files

The simulation produces several output files:
- `checkpoint.*.restart`: Checkpoint files for restart
- `trajectory.*.lammpstrj`: Trajectory data
- `final.restart`: Final system state
- Standard output: Energy and temperature data

## AWS Batch Integration

To submit this simulation to AWS Batch:

```bash
aws batch submit-job \
    --job-name polymer-sim-1 \
    --job-queue LammpsJobQueue \
    --job-definition LammpsJobDef \
    --container-overrides command=["lmp","-in","polymer_simulation.lammps"]
```

## Monitoring

Monitor your simulation through:
- AWS Batch console
- CloudWatch Logs
- S3 bucket for checkpoint files

## Troubleshooting

Common issues and solutions:
1. GPU Performance
   - Check GPU utilization with `nvidia-smi`
   - Ensure proper CUDA version compatibility
   
2. Memory Usage
   - Monitor memory usage in CloudWatch
   - Adjust neighbor list parameters if needed

3. Checkpoint Issues
   - Verify S3 permissions
   - Check available disk space
   - Monitor checkpoint timing in logs

## Support

For issues or questions:
1. Check the main documentation
2. Review AWS Batch logs
3. Contact the infrastructure team

## References

- [LAMMPS GPU Package Documentation](https://docs.lammps.org/GPU.html)
- [LAMMPS Restart Commands](https://docs.lammps.org/restart.html)
- [AWS Batch Best Practices](https://docs.aws.amazon.com/batch/latest/userguide/best-practices.html)