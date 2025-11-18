#!/bin/bash
# Script simplifié de création du cluster EMR pour l'étape 1

set -e  # Arrêter en cas d'erreur

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

echo "=================================================="
echo "🚀 CRÉATION DU CLUSTER EMR - ÉTAPE 1"
echo "=================================================="
show_config
echo ""
echo "⚠️  Ce cluster coûtera environ 0.50€/heure"
echo "⚠️  Auto-terminaison après 4h d'inactivité"
echo ""
read -p "Continuer ? (oui/non): " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "❌ Annulé"
    exit 0
fi

echo ""
echo "🔧 Création du cluster..."

CLUSTER_ID=$(aws emr create-cluster \
  --name "${CLUSTER_NAME}" \
  --release-label "${EMR_RELEASE}" \
  --region "${AWS_REGION}" \
  --log-uri "${S3_LOGS}" \
  --applications Name=Spark Name=Hadoop \
  --service-role "${IAM_SERVICE_ROLE}" \
  --ec2-attributes "{
    \"InstanceProfile\":\"${IAM_INSTANCE_PROFILE}\",
    \"KeyName\":\"${EC2_KEY_NAME}\",
    \"SubnetIds\":[\"${EC2_SUBNET}\"]
  }" \
  --instance-groups "[
    {
      \"InstanceCount\":${CORE_INSTANCE_COUNT},
      \"InstanceGroupType\":\"CORE\",
      \"Name\":\"Core\",
      \"InstanceType\":\"${CORE_INSTANCE_TYPE}\",
      \"EbsConfiguration\":{
        \"EbsBlockDeviceConfigs\":[{
          \"VolumeSpecification\":{
            \"VolumeType\":\"gp3\",
            \"SizeInGB\":${EBS_VOLUME_SIZE}
          },
          \"VolumesPerInstance\":1
        }]
      }
    },
    {
      \"InstanceCount\":1,
      \"InstanceGroupType\":\"MASTER\",
      \"Name\":\"Primary\",
      \"InstanceType\":\"${MASTER_INSTANCE_TYPE}\",
      \"EbsConfiguration\":{
        \"EbsBlockDeviceConfigs\":[{
          \"VolumeSpecification\":{
            \"VolumeType\":\"gp3\",
            \"SizeInGB\":${EBS_VOLUME_SIZE}
          },
          \"VolumesPerInstance\":1
        }]
      }
    }
  ]" \
  --configurations "[
    {
      \"Classification\":\"spark-defaults\",
      \"Properties\":{
        \"spark.executor.memory\":\"${SPARK_EXECUTOR_MEMORY}\",
        \"spark.driver.memory\":\"${SPARK_DRIVER_MEMORY}\",
        \"spark.executor.memoryOverhead\":\"${SPARK_EXECUTOR_MEMORY_OVERHEAD}\",
        \"spark.sql.execution.arrow.pyspark.enabled\":\"true\"
      }
    }
  ]" \
  --bootstrap-actions "[{
    \"Name\":\"InstallPythonDeps\",
    \"Path\":\"${S3_SCRIPTS}install_dependencies.sh\"
  }]" \
  --auto-scaling-role "${IAM_AUTOSCALING_ROLE}" \
  --scale-down-behavior "TERMINATE_AT_TASK_COMPLETION" \
  --auto-termination-policy "{\"IdleTimeout\":${IDLE_TIMEOUT}}" \
  --output text \
  --query 'ClusterId')

echo ""
echo "=================================================="
echo "✅ Cluster créé avec succès !"
echo "=================================================="
echo "📋 Cluster ID: ${CLUSTER_ID}"
echo ""
echo "💾 Cluster ID sauvegardé dans: cluster_id.txt"
echo "${CLUSTER_ID}" > "${SCRIPT_DIR}/../cluster_id.txt"
echo ""
echo "🔍 Surveiller l'état du cluster:"
echo "   ./scripts/monitor_cluster.sh"
echo ""
echo "🌐 Console AWS:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}"
echo ""
echo "⏰ Attendre ~10-15 minutes que l'état passe à 'WAITING'"
echo "=================================================="
