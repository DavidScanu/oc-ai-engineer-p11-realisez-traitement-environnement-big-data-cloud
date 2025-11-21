#!/bin/bash
# Script de terminaison du cluster EMR - Étape 2

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

if [ ! -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    echo "❌ Fichier cluster_id.txt introuvable"
    exit 1
fi

CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")

echo "=================================================="
echo "🛑 TERMINAISON DU CLUSTER EMR - ÉTAPE 2"
echo "=================================================="
echo "📋 Cluster ID: ${CLUSTER_ID}"
echo "🌍 Région: ${AWS_REGION}"
echo ""

# Vérifier l'état du cluster
CLUSTER_STATE=$(aws emr describe-cluster \
    --cluster-id "${CLUSTER_ID}" \
    --region "${AWS_REGION}" \
    --query 'Cluster.Status.State' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${CLUSTER_STATE}" == "NOT_FOUND" ]; then
    echo "❌ Cluster introuvable"
    exit 1
fi

if [ "${CLUSTER_STATE}" == "TERMINATED" ] || [ "${CLUSTER_STATE}" == "TERMINATED_WITH_ERRORS" ]; then
    echo "ℹ️  Cluster déjà terminé (état: ${CLUSTER_STATE})"
    exit 0
fi

echo "📊 État actuel: ${CLUSTER_STATE}"
echo ""
echo "⚠️  ATTENTION: Cette action va arrêter le cluster et toutes les instances EC2"
echo "💰 Économie: ~0.80€/heure"
echo ""
read -p "Confirmer la terminaison ? (oui/non): " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "❌ Annulé"
    exit 0
fi

echo ""
echo "🛑 Envoi de la commande d'arrêt..."

aws emr terminate-clusters \
    --cluster-ids "${CLUSTER_ID}" \
    --region "${AWS_REGION}"

echo ""
echo "=================================================="
echo "✅ COMMANDE ENVOYÉE"
echo "=================================================="
echo ""
echo "⏰ Le cluster sera terminé dans 2-5 minutes"
echo ""
echo "🔍 Surveiller la terminaison:"
echo "   watch -n 10 'aws emr describe-cluster --cluster-id ${CLUSTER_ID} --region ${AWS_REGION} --query \"Cluster.Status.State\"'"
echo ""
echo "🌐 Console AWS:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}"
echo ""
echo "💡 Après terminaison complète, vérifier qu'aucune instance EC2 ne tourne:"
echo "   aws ec2 describe-instances --region ${AWS_REGION} --filters \"Name=instance-state-name,Values=running\" --output table"
echo "=================================================="
