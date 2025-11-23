#!/bin/bash
# Script de soumission du job PySpark sur le cluster EMR - Étape 2

set -e  # Arrêter en cas d'erreur

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

# Vérifier que le cluster existe
# Chercher d'abord à la racine (ancienne localisation) puis dans outputs/
if [ -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")
elif [ -f "${SCRIPT_DIR}/../outputs/output-mini/cluster_id.txt" ]; then
    CLUSTER_ID=$(cat "${SCRIPT_DIR}/../outputs/output-mini/cluster_id.txt")
else
    echo "❌ Fichier cluster_id.txt introuvable"
    echo "Veuillez d'abord créer le cluster avec: ./scripts/create_cluster.sh"
    exit 1
fi

echo "=================================================="
echo "🚀 SOUMISSION DU JOB PYSPARK - ÉTAPE 2"
echo "=================================================="
echo "📋 Cluster ID: ${CLUSTER_ID}"
echo "🐍 Script: process_fruits_data.py"
echo ""

# Demander le mode de traitement
echo "🎯 Choisir le mode de traitement:"
echo "   1) mini   - 300 images (test rapide, ~2-5 min)"
echo "   2) apples - ~6,400 images de pommes (~15-30 min)"
echo "   3) full   - ~67,000 images complètes (~2-3h)"
echo ""
read -p "Mode [1-3, défaut=1]: " MODE_CHOICE

case $MODE_CHOICE in
    2)
        MODE="apples"
        ;;
    3)
        MODE="full"
        ;;
    *)
        MODE="mini"
        ;;
esac

echo "✅ Mode sélectionné: ${MODE}"
echo ""

# Créer le dossier de métadonnées pour ce mode
METADATA_DIR=$(get_metadata_dir "${MODE}" "${SCRIPT_DIR}/..")
mkdir -p "${METADATA_DIR}"

# Sauvegarder le mode pour référence future
echo "${MODE}" > "${SCRIPT_DIR}/../mode.txt"
echo "${MODE}" > "${METADATA_DIR}/mode.txt"

# Définir le chemin de sortie S3 selon le mode
set_output_path "${MODE}"

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
echo "   - Input: ${S3_DATA_INPUT}"
echo "   - Output: ${S3_DATA_OUTPUT}"
echo "   - Mode: ${MODE}"
echo "   - PCA Components: ${PCA_COMPONENTS}"
echo ""

# Format EMR correct: Type=Spark indique déjà à EMR d'utiliser spark-submit
STEP_ID=$(aws emr add-steps \
    --cluster-id "${CLUSTER_ID}" \
    --region "${AWS_REGION}" \
    --steps Type=Spark,Name="P11-Etape2-ProcessFruitsData-${MODE}",ActionOnFailure=CONTINUE,Args=[--deploy-mode,cluster,--master,yarn,--conf,spark.executorEnv.PYTHONHASHSEED=0,--conf,spark.executor.memory=${SPARK_EXECUTOR_MEMORY},--conf,spark.driver.memory=${SPARK_DRIVER_MEMORY},${S3_SCRIPTS}process_fruits_data.py,${S3_DATA_INPUT},${S3_DATA_OUTPUT},${MODE},${PCA_COMPONENTS}] \
    --output text \
    --query 'StepIds[0]')

echo ""
echo "=================================================="
echo "✅ JOB SOUMIS AVEC SUCCÈS"
echo "=================================================="
echo "📋 Step ID: ${STEP_ID}"
echo ""
echo "💾 Métadonnées sauvegardées dans: ${METADATA_DIR}/"
echo "${STEP_ID}" > "${METADATA_DIR}/step_id.txt"
echo "${CLUSTER_ID}" > "${METADATA_DIR}/cluster_id.txt"
# Copier aussi à la racine pour compatibilité
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
case $MODE in
    "mini")
        echo "⏰ Durée estimée: 2-5 minutes"
        ;;
    "apples")
        echo "⏰ Durée estimée: 15-30 minutes"
        ;;
    "full")
        echo "⏰ Durée estimée: 2-3 heures"
        ;;
esac
echo "=================================================="
