#!/bin/bash
# Script automatisé pour télécharger et inspecter les logs EMR - Étape 2
# Usage: ./scripts/download_and_inspect_logs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

cd "${SCRIPT_DIR}/.."

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=================================================="
echo "📋 TÉLÉCHARGEMENT ET INSPECTION DES LOGS - ÉTAPE 2"
echo "=================================================="

# Chercher les fichiers d'ID (à la racine ou dans outputs/)
if [ -f "cluster_id.txt" ]; then
    CLUSTER_ID=$(cat cluster_id.txt)
    STEP_ID=$(cat step_id.txt 2>/dev/null || echo "")
    if [ -z "$STEP_ID" ]; then
        echo -e "${RED}❌ Fichier step_id.txt introuvable${NC}"
        exit 1
    fi
else
    # Chercher dans le dossier de métadonnées
    if [ -f "mode.txt" ]; then
        MODE=$(cat mode.txt)
        METADATA_DIR=$(get_metadata_dir "${MODE}" ".")
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

echo -e "${BLUE}Cluster ID: ${CLUSTER_ID}${NC}"
echo -e "${BLUE}Step ID: ${STEP_ID}${NC}"
echo ""

# Déterminer le mode depuis mode.txt ou step name
if [ -f "mode.txt" ]; then
    MODE=$(cat mode.txt)
else
    # Essayer d'extraire depuis le step name
    STEP_NAME=$(aws emr describe-step \
        --cluster-id "${CLUSTER_ID}" \
        --step-id "${STEP_ID}" \
        --region "${AWS_REGION}" \
        --query 'Step.Name' \
        --output text)

    # Extraire le mode du nom du step (format: P11-Etape2-ProcessFruitsData-{mode})
    MODE=$(echo "${STEP_NAME}" | grep -oP '(?<=-)[^-]+$' || echo "unknown")
fi

echo -e "${BLUE}Mode: ${MODE}${NC}"
echo ""

# Vérifier l'état du step
echo "🔍 Vérification de l'état du job..."
STEP_STATE=$(aws emr describe-step \
    --cluster-id "${CLUSTER_ID}" \
    --step-id "${STEP_ID}" \
    --region "${AWS_REGION}" \
    --query 'Step.Status.State' \
    --output text)

echo -e "État actuel: ${YELLOW}${STEP_STATE}${NC}"
echo ""

# Créer le dossier logs avec sous-dossier par mode
mkdir -p "logs/${MODE}"

# Télécharger les logs
echo "📥 Téléchargement des logs depuis S3..."
aws s3 sync "${S3_LOGS}${CLUSTER_ID}/steps/${STEP_ID}/" \
    "logs/${MODE}/" --region "${AWS_REGION}" --quiet

# Décompresser
echo "📦 Décompression des fichiers..."
gunzip "logs/${MODE}/"*.gz 2>/dev/null || true

echo -e "${GREEN}✅ Logs téléchargés dans: logs/${MODE}/${NC}"
echo ""

# Analyse du stderr
if [ -f "logs/${MODE}/stderr" ]; then
    echo "=================================================="
    echo "📊 STDERR - LOGS DU DRIVER"
    echo "=================================================="

    # Chercher les étapes avec emojis
    EMOJIS=$(grep "🍎\|📂\|✅\|❌\|📊\|💾\|⏰\|🤖\|🎨" "logs/${MODE}/stderr" 2>/dev/null || true)
    if [ -n "${EMOJIS}" ]; then
        echo "${EMOJIS}"
    else
        echo "⚠️  Pas de prints trouvés dans stderr (normal en mode cluster)"
    fi

    echo ""

    # Chercher les erreurs
    ERRORS=$(grep -i "error\|exception\|failed" "logs/${MODE}/stderr" 2>/dev/null | head -20 || true)
    if [ -n "${ERRORS}" ]; then
        echo -e "${RED}⚠️  ERREURS DÉTECTÉES:${NC}"
        echo "${ERRORS}"
    fi

    echo ""
    echo "📄 Fichier complet: logs/${MODE}/stderr"
else
    echo "⚠️  Fichier stderr non trouvé"
fi

echo ""

# Analyse du controller
if [ -f "logs/${MODE}/controller" ]; then
    echo "=================================================="
    echo "🎮 CONTROLLER - LOGS D'ORCHESTRATION"
    echo "=================================================="

    # Dernières lignes
    tail -30 "logs/${MODE}/controller"

    echo ""
    echo "📄 Fichier complet: logs/${MODE}/controller"
else
    echo "⚠️  Fichier controller non trouvé"
fi

echo ""
echo "=================================================="
echo "💡 COMMANDES UTILES"
echo "=================================================="
echo ""
echo "📊 Voir l'état complet du step:"
echo "   aws emr describe-step --cluster-id ${CLUSTER_ID} --step-id ${STEP_ID} --region ${AWS_REGION}"
echo ""
echo "📄 Lire stderr complet:"
echo "   cat logs/${MODE}/stderr"
echo ""
echo "📄 Lire controller complet:"
echo "   cat logs/${MODE}/controller"
echo ""
echo "🔍 Chercher des erreurs TensorFlow:"
echo "   grep -i 'tensorflow\|mobilenet' logs/${MODE}/stderr"
echo ""
echo "🔍 Chercher des erreurs PCA:"
echo "   grep -i 'pca\|variance' logs/${MODE}/stderr"
echo ""
echo "=================================================="
