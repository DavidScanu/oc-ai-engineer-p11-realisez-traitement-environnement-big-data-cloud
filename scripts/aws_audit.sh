#!/usr/bin/env bash
# AWS quick-audit script
# Usage: ./scripts/aws_audit.sh [--region eu-west-1] [--all-regions] [--costs]
# Requires: AWS CLI configured. Cost Explorer (--costs) requires permissions and CE enabled.

set -euo pipefail
IFS=$'\n\t'

REGION=eu-west-1
ALL_REGIONS=false
INCLUDE_COSTS=false
QUIET=false

print_usage() {
  cat <<'EOF'
Usage: aws_audit.sh [options]
Options:
  --region REGION     Region to scan (default eu-west-1)
  --all-regions       Scan all AWS regions (overrides --region)
  --costs             Query Cost Explorer for last 30 days (requires permissions)
  --quiet             Less verbose output
  -h, --help          Show this help
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2;;
    --all-regions) ALL_REGIONS=true; shift;;
    --costs) INCLUDE_COSTS=true; shift;;
    --quiet) QUIET=true; shift;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Veuillez installer '$1' et le mettre dans le PATH" >&2; exit 1; }
}

check_cmd aws
# jq is optional but recommended for Cost Explorer parsing
if ! command -v jq >/dev/null 2>&1; then
  echo "Note: 'jq' non trouvé — certaines sorties (Cost Explorer) seront moins lisibles."
fi

echo "AWS Audit - démarrage: $(date)"

regions_to_scan=()
if [ "$ALL_REGIONS" = true ]; then
  echo "Récupération de la liste des régions..."
  regions_to_scan=( $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text) )
else
  regions_to_scan=("$REGION")
fi

echo "Régions analysées: ${regions_to_scan[*]}"

# helpers
run_ec2_checks() {
  local r=$1
  echo "\n== EC2 (region: $r) =="
  echo "Instances (running):"
  aws ec2 describe-instances --region "$r" --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]' --output table || true
  echo "All instances (summary):"
  aws ec2 describe-instances --region "$r" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime,Tags[?Key==`Name`]|[0].Value]' --output table || true
}

run_ebs_checks() {
  local r=$1
  echo "\n== EBS / Volumes (region: $r) =="
  aws ec2 describe-volumes --region "$r" --query 'Volumes[].[VolumeId,Size,State,Attachments[0].InstanceId]' --output table || true
}

run_snapshot_checks() {
  local r=$1
  echo "\n== Snapshots (region: $r) =="
  aws ec2 describe-snapshots --owner-ids self --region "$r" \
    --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]' --output table || true
}

run_amis_checks() {
  local r=$1
  echo "\n== AMIs privées (region: $r) =="
  aws ec2 describe-images --owners self --region "$r" --query 'Images[].[ImageId,Name,State,CreationDate]' --output table || true
}

run_addresses_checks() {
  local r=$1
  echo "\n== Elastic IPs (region: $r) =="
  aws ec2 describe-addresses --region "$r" --query 'Addresses[].[PublicIp,AllocationId,InstanceId]' --output table || true
}

run_elbv2_checks() {
  local r=$1
  echo "\n== Load Balancers (ELBv2) (region: $r) =="
  aws elbv2 describe-load-balancers --region "$r" --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code,DNSName]' --output table || true
}

run_nat_checks() {
  local r=$1
  echo "\n== NAT Gateways (region: $r) =="
  aws ec2 describe-nat-gateways --region "$r" --query 'NatGateways[].[NatGatewayId,State,SubnetId,NatGatewayAddresses]' --output table || true
}

run_rds_checks() {
  local r=$1
  echo "\n== RDS Instances (region: $r) =="
  aws rds describe-db-instances --region "$r" --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,Endpoint.Address]' --output table || true
}

run_eks_checks() {
  local r=$1
  echo "\n== EKS Clusters (region: $r) =="
  aws eks list-clusters --region "$r" --output table || true
}

run_efs_checks() {
  local r=$1
  echo "\n== EFS File Systems (region: $r) =="
  aws efs describe-file-systems --region "$r" --query 'FileSystems[].[FileSystemId,LifeCycleState,Name]' --output table || true
}

run_emr_checks() {
  local r=$1
  echo "\n== EMR Clusters (region: $r) =="
  aws emr list-clusters --cluster-states STARTING,RUNNING,WAITING,BOOTSTRAPPING --region "$r" --query 'Clusters[].[Id,Name,Status.State]' --output table || true
}

# S3 sizes (note: can be slow for large buckets)
run_s3_checks() {
  echo "\n== S3 Buckets and approximate sizes =="
  buckets=( $(aws s3api list-buckets --query 'Buckets[].Name' --output text) )
  if [ ${#buckets[@]} -eq 0 ]; then
    echo "Aucun bucket S3 trouvé."
    return
  fi
  for b in "${buckets[@]}"; do
    echo "- Bucket: $b"
    # Try fast method using s3 ls (may be slow for large buckets)
    echo "  - Calculating size (this may take time for large buckets)..."
    out=$(aws s3 ls s3://"$b" --recursive --summarize 2>/dev/null || true)
    if [ -z "$out" ]; then
      echo "    (error listing bucket or no objects)"
      continue
    fi
    total_line=$(printf "%s" "$out" | awk '/Total Size/ {print $3; exit}')
    if [ -n "$total_line" ]; then
      bytes=$total_line
      # human readable
      hr=$(numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || printf "%s bytes" "$bytes")
      echo "    Total bytes: $bytes (~ $hr)"
    else
      echo "    Couldn't parse total size (bucket may be empty)."
    fi
  done
}

run_costs() {
  echo "\n== Cost Explorer (last 30 days by service) =="
  if ! aws ce get-cost-and-usage --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics "UnblendedCost" --group-by Type=DIMENSION,Key=SERVICE --region us-east-1 >/tmp/ce.json 2>/dev/null; then
    echo "  Could not call Cost Explorer. Ensure Cost Explorer is enabled and you have permissions."
    return
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r '.ResultsByTime[0].Groups[] | [.Keys[0], .Metrics.UnblendedCost.Amount] | @tsv' /tmp/ce.json | column -t
  else
    cat /tmp/ce.json
    echo "(Install 'jq' for a nicer formatted output)"
  fi
}

# Main loop over regions
for r in "${regions_to_scan[@]}"; do
  run_ec2_checks "$r"
  run_ebs_checks "$r"
  run_snapshot_checks "$r"
  run_amis_checks "$r"
  run_addresses_checks "$r"
  run_elbv2_checks "$r"
  run_nat_checks "$r"
  run_rds_checks "$r"
  run_eks_checks "$r"
  run_efs_checks "$r"
  run_emr_checks "$r"
done

# S3 (global)
run_s3_checks

# Costs
if [ "$INCLUDE_COSTS" = true ]; then
  run_costs
fi

echo "\nAWS Audit - terminé: $(date)"

exit 0
