# LAMMPS Cost Analysis Verification

## Base Information
- Instance Type: p4d.24xlarge
- Base Rate: $32.77/hour
- Weekly Usage: 100 hours
- Monthly Conversion: 4.3 weeks/month (52 weeks/12 months)

## Detailed Calculations

### 1. Compute Costs (Weekly)

#### Base Computation
- Full rate: $32.77/hour × 100 hours = $3,277/week

#### Spot Instance Costs
- 90% savings scenario: $3,277 × 0.1 = $327.70/week
- 60% savings scenario: $3,277 × 0.4 = $1,310.80/week

#### On-Demand Failover (5% usage)
- Weekly hours: 100 hours × 0.05 = 5 hours
- Weekly cost: $32.77 × 5 = $163.85/week

### 2. Storage Costs (Monthly)

#### S3 Storage
- Capacity: 10TB = 10,240GB
- Rate: $0.023/GB/month
- Monthly cost: 10,240GB × $0.023 = $235.52/month
- Data transfer out: $0.09/GB (as needed)

#### EBS Volume
- Capacity: 1TB = 1,024GB
- Rate: $0.08/GB/month
- Monthly cost: 1,024GB × $0.08 = $81.92/month
- IOPS: Included in base price

### 3. Additional Costs (Monthly)
- ECR Storage: ~$0.10/GB/month (varies with image size)
- Data Transfer:
  * S3 to EC2: Free
  * EC2 to Internet: $0.09/GB
- Estimated monthly overhead: ~$100 (depends on actual usage)

### 4. Monthly Total Calculation

#### Best Case Scenario (90% spot savings)
1. Compute:
   - Spot: $327.70/week × 4.3 weeks = $1,409.11
   - Failover: $163.85/week × 4.3 weeks = $704.56
   - Total Compute: $2,113.67

2. Storage:
   - S3: $235.52
   - EBS: $81.92
   - Total Storage: $317.44

3. Additional Costs: ~$100

**Total Best Case: $2,531.11**
Rounded Range: $2,300 - $2,600

#### Worst Case Scenario (60% spot savings)
1. Compute:
   - Spot: $1,310.80/week × 4.3 weeks = $5,636.44
   - Failover: $163.85/week × 4.3 weeks = $704.56
   - Total Compute: $6,341.00

2. Storage:
   - S3: $235.52
   - EBS: $81.92
   - Total Storage: $317.44

3. Additional Costs: ~$100

**Total Worst Case: $6,758.44**
Rounded Range: $6,300 - $6,800

## Discrepancies from Original Document

1. Storage Costs:
   - Original S3: $230/month → Corrected to: $235.52/month
   - Original EBS: $80/month → Corrected to: $81.92/month

2. Monthly Totals:
   - Original Best Case: $2,100 - $2,500 → Corrected to: $2,300 - $2,600
   - Original Worst Case: $4,000 - $4,500 → Corrected to: $6,300 - $6,800

The most significant discrepancy is in the worst-case scenario calculation, which was substantially underestimated in the original document. The correct calculation shows that with only 60% spot savings, the monthly costs could be much higher than originally estimated.