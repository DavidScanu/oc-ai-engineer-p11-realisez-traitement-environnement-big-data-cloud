# AWS Cost Analysis

This directory contains tools and data for analyzing AWS costs for Project P11.

## 📁 Contents

- **`analyze_costs.py`** - Python script for analyzing AWS Cost Explorer CSV exports
- **`*.csv`** - AWS Cost Explorer export files

## 🔧 Usage

### Analyze costs

```bash
# Auto-detect and analyze the most recent CSV file
python3 aws/analyze_costs.py

# Or specify a specific CSV file
python3 aws/analyze_costs.py aws/2025-12-01-aws-costs-report-from-2025-10-24-to-2025-11-30.csv
```

### Output

The script provides:
- **Total costs** with USD to EUR conversion
- **Breakdown by AWS service** with percentages
- **Daily cost breakdown**
- **Key insights** (compute, storage, networking costs)
- **Estimated costs by project phase**

Example output:

```
================================================================================
AWS COST ANALYSIS - PROJECT P11
================================================================================

📊 TOTAL COSTS: $17.39 (~16.00€)

💰 BREAKDOWN BY SERVICE:
--------------------------------------------------------------------------------
  • Compute (EMR + EC2)       $12.31 (~11.33€)  70.8%
  • Storage (S3)               $1.63 (~1.50€)   9.4%
  • Tax                        $2.88 (~2.65€)  16.6%
  ...
```

## 📤 Exporting cost data from AWS

To generate a new CSV file:

1. **Via AWS Console**:
   - Go to AWS Cost Explorer
   - Select date range
   - Group by "Service"
   - Download as CSV

2. **Via AWS CLI**:
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2025-10-24,End=2025-11-30 \
     --granularity MONTHLY \
     --metrics UnblendedCost \
     --group-by Type=DIMENSION,Key=SERVICE \
     --region us-east-1 \
     --output json > costs.json
   ```

## 📊 Project costs summary

**Total costs (24 Oct - 30 Nov 2025): $17.39 (~16.00€)**

| Phase | Duration | Cost |
|-------|----------|------|
| Étape 1 (validation) | ~5 min | ~$0.06 (~0.05€) |
| Étape 2 (MINI) | ~30 min | ~$0.54 (~0.50€) |
| Étape 2 (APPLES) | ~30 min | ~$0.43 (~0.40€) |
| Étape 2 (FULL) | ~1h40 | ~$1.74 (~1.60€) |
| Development & testing | - | ~$14.65 (~13.50€) |

**Key insight**: Production runs (FULL mode) represent only ~10% of total costs, demonstrating efficient pipeline optimization.
