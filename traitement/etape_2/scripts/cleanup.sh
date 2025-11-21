#!/bin/bash
# Script de nettoyage des ressources AWS (cluster + données temporaires) - Étape 2

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

echo "=================================================="
echo "🧹 NETTOYAGE DES RESSOURCES - ÉTAPE 2"
echo "=================================================="
echo ""

# Vérifier si un cluster existe
if [ -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")

    echo "📋 Cluster trouvé: ${CLUSTER_ID}"

    # Vérifier l'état du cluster
    CLUSTER_STATE=$(aws emr describe-cluster \
        --cluster-id "${CLUSTER_ID}" \
        --region "${AWS_REGION}" \
        --query 'Cluster.Status.State' \
        --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "${CLUSTER_STATE}" != "NOT_FOUND" ] && [ "${CLUSTER_STATE}" != "TERMINATED" ] && [ "${CLUSTER_STATE}" != "TERMINATED_WITH_ERRORS" ]; then
        echo "⚠️  État du cluster: ${CLUSTER_STATE}"
        echo "💰 Économie potentielle: ~0.80€/heure"
        echo ""
        read -p "🛑 Terminer le cluster ? (oui/non): " TERMINATE_CLUSTER

        if [ "$TERMINATE_CLUSTER" == "oui" ]; then
            echo "🛑 Arrêt du cluster..."
            aws emr terminate-clusters \
                --cluster-ids "${CLUSTER_ID}" \
                --region "${AWS_REGION}"
            echo "✅ Commande d'arrêt envoyée"
            echo "⏰ Le cluster sera terminé dans quelques minutes"
        else
            echo "⏭️  Cluster non terminé"
        fi
    else
        echo "✅ Cluster déjà terminé (état: ${CLUSTER_STATE})"
    fi
    echo ""
else
    echo "ℹ️  Aucun cluster trouvé (cluster_id.txt absent)"
    echo ""
fi

# Proposer de nettoyer les données de sortie
echo "📂 Données de sortie: ${S3_DATA_OUTPUT}"
echo "   ⚠️  Cela inclut: features/, pca/, metadata/, model_info/, errors/"
echo ""
read -p "🗑️  Supprimer les données de sortie sur S3 ? (oui/non): " DELETE_OUTPUT

if [ "$DELETE_OUTPUT" == "oui" ]; then
    echo "🗑️  Suppression des données de sortie..."
    aws s3 rm "${S3_DATA_OUTPUT}" --recursive --region "${AWS_REGION}" 2>/dev/null || echo "   (Aucune donnée à supprimer)"
    echo "✅ Données de sortie supprimées"
else
    echo "⏭️  Données de sortie conservées"
fi
echo ""

# Proposer de nettoyer les logs
echo "📄 Logs EMR: ${S3_LOGS}"
echo ""
read -p "🗑️  Supprimer les logs EMR sur S3 ? (oui/non): " DELETE_LOGS

if [ "$DELETE_LOGS" == "oui" ]; then
    echo "🗑️  Suppression des logs..."
    aws s3 rm "${S3_LOGS}" --recursive --region "${AWS_REGION}" 2>/dev/null || echo "   (Aucun log à supprimer)"
    echo "✅ Logs supprimés"
else
    echo "⏭️  Logs conservés"
fi
echo ""

# Nettoyer les fichiers locaux
echo "📁 Fichiers locaux de tracking:"
FILES_TO_CLEAN=("${SCRIPT_DIR}/../cluster_id.txt" "${SCRIPT_DIR}/../step_id.txt" "${SCRIPT_DIR}/../master_dns.txt")

for file in "${FILES_TO_CLEAN[@]}"; do
    if [ -f "$file" ]; then
        echo "   - $(basename $file)"
    fi
done

if [ -f "${SCRIPT_DIR}/../cluster_id.txt" ] || [ -f "${SCRIPT_DIR}/../step_id.txt" ] || [ -f "${SCRIPT_DIR}/../master_dns.txt" ]; then
    echo ""
    read -p "🗑️  Supprimer les fichiers locaux de tracking ? (oui/non): " DELETE_LOCAL

    if [ "$DELETE_LOCAL" == "oui" ]; then
        rm -f "${SCRIPT_DIR}/../cluster_id.txt"
        rm -f "${SCRIPT_DIR}/../step_id.txt"
        rm -f "${SCRIPT_DIR}/../master_dns.txt"
        echo "✅ Fichiers locaux supprimés"
    else
        echo "⏭️  Fichiers locaux conservés"
    fi
else
    echo "ℹ️  Aucun fichier local à nettoyer"
fi

echo ""
echo "=================================================="
echo "✅ NETTOYAGE TERMINÉ"
echo "=================================================="
echo ""
echo "💡 Pour vérifier qu'aucune instance EC2 ne tourne:"
echo "   aws ec2 describe-instances --region ${AWS_REGION} --filters \"Name=instance-state-name,Values=running\" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key==\`Name\`].Value|[0]]' --output table"
echo ""
