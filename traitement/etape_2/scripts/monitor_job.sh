#!/bin/bash
# Script de surveillance du job PySpark en cours d'exécution - Étape 2
# Usage: ./scripts/monitor_job.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Chercher les fichiers d'ID (à la racine ou dans outputs/)
if [ -f "${SCRIPT_DIR}/../cluster_id.txt" ]; then
    CLUSTER_ID=$(cat "${SCRIPT_DIR}/../cluster_id.txt")
    STEP_ID=$(cat "${SCRIPT_DIR}/../step_id.txt" 2>/dev/null || echo "")
    if [ -z "$STEP_ID" ]; then
        echo -e "${RED}❌ Fichier step_id.txt introuvable${NC}"
        exit 1
    fi
else
    # Chercher dans le dossier de métadonnées
    if [ -f "${SCRIPT_DIR}/../mode.txt" ]; then
        MODE_READ=$(cat "${SCRIPT_DIR}/../mode.txt")
        METADATA_DIR=$(get_metadata_dir "${MODE_READ}" "${SCRIPT_DIR}/..")
        if [ -f "${METADATA_DIR}/cluster_id.txt" ] && [ -f "${METADATA_DIR}/step_id.txt" ]; then
            CLUSTER_ID=$(cat "${METADATA_DIR}/cluster_id.txt")
            STEP_ID=$(cat "${METADATA_DIR}/step_id.txt")
        else
            echo -e "${RED}❌ Fichiers cluster_id.txt ou step_id.txt introuvables${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Fichier cluster_id.txt introuvable${NC}"
        exit 1
    fi
fi

# Déterminer le mode
if [ -f "${SCRIPT_DIR}/../mode.txt" ]; then
    MODE=$(cat "${SCRIPT_DIR}/../mode.txt")
else
    MODE="unknown"
fi

echo "=================================================="
echo "🔍 SURVEILLANCE DU JOB PYSPARK - ÉTAPE 2"
echo "=================================================="
echo -e "${BLUE}Cluster ID: ${CLUSTER_ID}${NC}"
echo -e "${BLUE}Step ID: ${STEP_ID}${NC}"
echo -e "${BLUE}Mode: ${MODE}${NC}"
echo ""
echo "Appuyez sur Ctrl+C pour arrêter la surveillance"
echo "=================================================="
echo ""

START_TIME=$(date +%s)

while true; do
    # Récupérer l'état du step
    STEP_INFO=$(aws emr describe-step \
        --cluster-id "${CLUSTER_ID}" \
        --step-id "${STEP_ID}" \
        --region "${AWS_REGION}" \
        --output json)

    STEP_STATE=$(echo "${STEP_INFO}" | jq -r '.Step.Status.State')
    STEP_STATE_REASON=$(echo "${STEP_INFO}" | jq -r '.Step.Status.StateChangeReason.Message // "N/A"')

    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))

    TIMESTAMP=$(date '+%H:%M:%S')

    # Clear screen (optionnel, commenté pour éviter le scintillement)
    # clear

    echo "=================================================="
    echo "⏰ ${TIMESTAMP} - Temps écoulé: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
    echo "=================================================="

    case $STEP_STATE in
        "PENDING")
            echo -e "${YELLOW}⏳ PENDING${NC} - En attente de démarrage..."
            ;;
        "RUNNING")
            echo -e "${BLUE}🔄 RUNNING${NC} - Traitement en cours..."

            # Afficher les estimations selon le mode
            case $MODE in
                "mini")
                    echo "   📊 Durée estimée: 2-5 minutes"
                    ;;
                "apples")
                    echo "   📊 Durée estimée: 15-30 minutes"
                    ;;
                "full")
                    echo "   📊 Durée estimée: 2-3 heures"
                    ;;
            esac
            ;;
        "COMPLETED")
            echo -e "${GREEN}✅ COMPLETED${NC} - Job terminé avec succès!"
            echo ""
            echo "=================================================="
            echo "🎉 TRAITEMENT RÉUSSI"
            echo "=================================================="
            echo "⏱️  Durée totale: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
            echo ""
            echo "📥 Prochaines étapes:"
            echo "   1. Télécharger les résultats:"
            echo "      ./scripts/download_results.sh ${MODE}"
            echo ""
            echo "   2. Télécharger les logs:"
            echo "      ./scripts/download_and_inspect_logs.sh"
            echo ""
            echo "   3. Consulter les outputs S3:"
            set_output_path "${MODE}"
            echo "      aws s3 ls ${S3_DATA_OUTPUT} --recursive --region ${AWS_REGION}"
            echo ""
            echo "🌐 Console AWS:"
            echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}/steps/${STEP_ID}"
            echo "=================================================="
            exit 0
            ;;
        "FAILED")
            echo -e "${RED}❌ FAILED${NC} - Le job a échoué"
            echo "   Raison: ${STEP_STATE_REASON}"
            echo ""
            echo "=================================================="
            echo "🔍 DIAGNOSTIC"
            echo "=================================================="
            echo "📥 Télécharger les logs pour plus de détails:"
            echo "   ./scripts/download_and_inspect_logs.sh"
            echo ""
            echo "📊 Vérifier l'état complet:"
            echo "   aws emr describe-step --cluster-id ${CLUSTER_ID} --step-id ${STEP_ID} --region ${AWS_REGION}"
            echo ""
            echo "🌐 Console AWS:"
            echo "   https://${AWS_REGION}.console.aws.amazon.com/emr/home?region=${AWS_REGION}#/clusters/${CLUSTER_ID}/steps/${STEP_ID}"
            echo "=================================================="
            exit 1
            ;;
        "CANCELLED"|"INTERRUPTED")
            echo -e "${YELLOW}⚠️  ${STEP_STATE}${NC} - Le job a été interrompu"
            echo "   Raison: ${STEP_STATE_REASON}"
            exit 1
            ;;
        *)
            echo -e "${YELLOW}⚪ ${STEP_STATE}${NC}"
            ;;
    esac

    echo ""
    echo "🔄 Rafraîchissement dans 10 secondes..."
    echo ""

    sleep 10
done
