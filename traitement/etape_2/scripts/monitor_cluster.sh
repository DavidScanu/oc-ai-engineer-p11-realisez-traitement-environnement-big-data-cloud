#!/bin/bash
# Script de surveillance de l'état du cluster EMR - Étape 2

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

if [ ! -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    echo "❌ Fichier cluster_id.txt introuvable"
    echo "Veuillez d'abord créer le cluster avec: ./scripts/create_cluster.sh"
    exit 1
fi

CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")

echo "=================================================="
echo "🔍 SURVEILLANCE DU CLUSTER EMR - ÉTAPE 2"
echo "=================================================="
echo "📋 Cluster ID: ${CLUSTER_ID}"
echo "🌍 Région: ${AWS_REGION}"
echo ""
echo "Appuyez sur Ctrl+C pour arrêter"
echo "=================================================="
echo ""

while true; do
    STATE=$(aws emr describe-cluster \
        --cluster-id "${CLUSTER_ID}" \
        --region "${AWS_REGION}" \
        --query 'Cluster.Status.State' \
        --output text)

    TIMESTAMP=$(date '+%H:%M:%S')

    case $STATE in
        "STARTING")
            echo "[$TIMESTAMP] 🟡 STARTING - Démarrage des instances EC2..."
            ;;
        "BOOTSTRAPPING")
            echo "[$TIMESTAMP] 🟡 BOOTSTRAPPING - Installation TensorFlow, scikit-learn..."
            ;;
        "RUNNING")
            echo "[$TIMESTAMP] 🟢 RUNNING - Configuration Spark en cours..."
            ;;
        "WAITING")
            echo "[$TIMESTAMP] ✅ WAITING - Cluster prêt à l'emploi !"
            echo ""

            # Récupérer le DNS du Master
            MASTER_DNS=$(aws emr describe-cluster \
                --cluster-id "${CLUSTER_ID}" \
                --region "${AWS_REGION}" \
                --query 'Cluster.MasterPublicDnsName' \
                --output text)

            echo "=================================================="
            echo "🎉 CLUSTER OPÉRATIONNEL"
            echo "=================================================="
            echo "📡 Master DNS: ${MASTER_DNS}"
            echo ""
            echo "Prochaine étape:"
            echo "   ./scripts/submit_job.sh"
            echo ""
            echo "🌐 Console AWS:"
            echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}"
            echo "=================================================="

            # Sauvegarder le Master DNS (à la racine pour compatibilité)
            echo "${MASTER_DNS}" > "${SCRIPT_DIR}/../master_dns.txt"

            # Sauvegarder aussi dans le dossier de métadonnées si mode.txt existe
            if [ -f "${SCRIPT_DIR}/../mode.txt" ]; then
                MODE=$(cat "${SCRIPT_DIR}/../mode.txt")
                METADATA_DIR=$(get_metadata_dir "${MODE}" "${SCRIPT_DIR}/..")
                mkdir -p "${METADATA_DIR}"
                echo "${MASTER_DNS}" > "${METADATA_DIR}/master_dns.txt"
            fi

            exit 0
            ;;
        "TERMINATING"|"TERMINATED")
            echo "[$TIMESTAMP] 🔴 $STATE - Cluster arrêté"
            exit 1
            ;;
        "TERMINATED_WITH_ERRORS")
            echo "[$TIMESTAMP] ❌ TERMINATED_WITH_ERRORS"
            echo ""
            echo "Vérifier les logs:"
            echo "  aws emr describe-cluster --cluster-id ${CLUSTER_ID} --region ${AWS_REGION}"
            exit 1
            ;;
        *)
            echo "[$TIMESTAMP] ⚪ $STATE"
            ;;
    esac

    sleep 30
done
