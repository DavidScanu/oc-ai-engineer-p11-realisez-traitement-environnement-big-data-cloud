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

# Vérifier les fichiers d'ID
if [ ! -f "cluster_id.txt" ]; then
    echo -e "${RED}❌ Fichier cluster_id.txt introuvable${NC}"
    exit 1
fi

if [ ! -f "step_id.txt" ]; then
    echo -e "${RED}❌ Fichier step_id.txt introuvable${NC}"
    exit 1
fi

CLUSTER_ID=$(cat cluster_id.txt)
STEP_ID=$(cat step_id.txt)

echo -e "${BLUE}Cluster ID: ${CLUSTER_ID}${NC}"
echo -e "${BLUE}Step ID: ${STEP_ID}${NC}"
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

# Créer le dossier logs
mkdir -p logs

# Télécharger les logs
echo "📥 Téléchargement des logs depuis S3..."
aws s3 sync "${S3_LOGS}${CLUSTER_ID}/steps/${STEP_ID}/" \
    logs/ --region "${AWS_REGION}" --quiet

# Décompresser
echo "📦 Décompression des fichiers..."
gunzip logs/*.gz 2>/dev/null || true

echo -e "${GREEN}✅ Logs téléchargés dans: logs/${NC}"
echo ""

# Analyse du stderr
if [ -f "logs/stderr" ]; then
    echo "=================================================="
    echo "📊 STDERR - LOGS DU DRIVER"
    echo "=================================================="

    # Chercher les étapes avec emojis
    EMOJIS=$(grep "🍎\|📂\|✅\|❌\|📊\|💾\|⏰\|🤖\|🎨" logs/stderr 2>/dev/null || true)
    if [ -n "${EMOJIS}" ]; then
        echo "${EMOJIS}"
    else
        echo "⚠️  Pas de prints trouvés dans stderr (normal en mode cluster)"
    fi

    echo ""

    # Chercher les erreurs
    ERRORS=$(grep -i "error\|exception\|failed" logs/stderr 2>/dev/null | head -20 || true)
    if [ -n "${ERRORS}" ]; then
        echo -e "${RED}⚠️  ERREURS DÉTECTÉES:${NC}"
        echo "${ERRORS}"
    fi

    echo ""
    echo "📄 Fichier complet: logs/stderr"
else
    echo "⚠️  Fichier stderr non trouvé"
fi

echo ""

# Analyse du controller
if [ -f "logs/controller" ]; then
    echo "=================================================="
    echo "🎮 CONTROLLER - LOGS D'ORCHESTRATION"
    echo "=================================================="

    # Dernières lignes
    tail -30 logs/controller

    echo ""
    echo "📄 Fichier complet: logs/controller"
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
echo "   cat logs/stderr"
echo ""
echo "📄 Lire controller complet:"
echo "   cat logs/controller"
echo ""
echo "🔍 Chercher des erreurs TensorFlow:"
echo "   grep -i 'tensorflow\|mobilenet' logs/stderr"
echo ""
echo "🔍 Chercher des erreurs PCA:"
echo "   grep -i 'pca\|variance' logs/stderr"
echo ""
echo "=================================================="
