#!/bin/bash
# Script de soumission du job PySpark sur le cluster EMR
# VERSION CORRIGÉE - Format EMR correct

set -e  # Arrêter en cas d'erreur

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

# Vérifier que le cluster existe
if [ ! -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    echo "❌ Fichier cluster_id.txt introuvable"
    echo "Veuillez d'abord créer le cluster avec: ./scripts/create_cluster.sh"
    exit 1
fi

CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")

echo "=================================================="
echo "🚀 SOUMISSION DU JOB PYSPARK - ÉTAPE 1"
echo "=================================================="
echo "📋 Cluster ID: ${CLUSTER_ID}"
echo "🐍 Script: read_fruits_data.py"
echo ""

# Vérifier l'état du cluster
echo "🔍 Vérification de l'état du cluster..."
CLUSTER_STATE=$(aws emr describe-cluster \
    --cluster-id "${CLUSTER_ID}" \
    --region "${AWS_REGION}" \
    --query 'Cluster.Status.State' \
    --output text)

echo "📊 État du cluster: ${CLUSTER_STATE}"

if [ "${CLUSTER_STATE}" != "WAITING" ] && [ "${CLUSTER_STATE}" != "RUNNING" ]; then
    echo "❌ Le cluster n'est pas prêt (état: ${CLUSTER_STATE})"
    echo "Attendre que l'état soit 'WAITING' avant de soumettre le job"
    echo ""
    echo "Pour surveiller: ./scripts/monitor_cluster.sh"
    exit 1
fi

echo "✅ Cluster prêt à recevoir des jobs"
echo ""

# Soumettre le step PySpark
echo "📤 Soumission du step PySpark..."

# CORRECTION: Format EMR correct sans "spark-submit" dans Args
# Le Type=Spark indique déjà à EMR d'utiliser spark-submit
STEP_ID=$(aws emr add-steps \
    --cluster-id "${CLUSTER_ID}" \
    --region "${AWS_REGION}" \
    --steps Type=Spark,Name="P11-Etape1-ReadFruitsData",ActionOnFailure=CONTINUE,Args=[--deploy-mode,cluster,--master,yarn,--conf,spark.executorEnv.PYTHONHASHSEED=0,${S3_SCRIPTS}read_fruits_data.py,${S3_DATA_INPUT},${S3_DATA_OUTPUT}] \
    --output text \
    --query 'StepIds[0]')

echo ""
echo "=================================================="
echo "✅ JOB SOUMIS AVEC SUCCÈS"
echo "=================================================="
echo "📋 Step ID: ${STEP_ID}"
echo ""
echo "💾 Step ID sauvegardé dans: step_id.txt"
echo "${STEP_ID}" > "${SCRIPT_DIR}/../step_id.txt"
echo ""
echo "🔍 Surveiller l'exécution:"
echo "   watch -n 10 'aws emr describe-step --cluster-id ${CLUSTER_ID} --step-id ${STEP_ID} --region ${AWS_REGION} --query \"Step.Status\"'"
echo ""
echo "📊 État du step:"
echo "   aws emr describe-step --cluster-id ${CLUSTER_ID} --step-id ${STEP_ID} --region ${AWS_REGION} --query 'Step.Status.State' --output text"
echo ""
echo "📄 Logs du step (après exécution):"
echo "   aws s3 ls ${S3_LOGS}containers/${CLUSTER_ID}/containers/ --recursive | grep ${STEP_ID}"
echo ""
echo "🌐 Console AWS:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}/steps/${STEP_ID}"
echo ""
echo "⏰ Durée estimée: 2-5 minutes"
echo "=================================================="