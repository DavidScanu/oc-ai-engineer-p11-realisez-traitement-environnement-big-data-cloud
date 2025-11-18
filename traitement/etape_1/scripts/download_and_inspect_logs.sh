#!/bin/bash
# Script automatisé pour télécharger et inspecter les logs EMR
# Usage: ./scripts/download_and_inspect_logs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=================================================="
echo "📋 TÉLÉCHARGEMENT ET INSPECTION DES LOGS"
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
    --region eu-west-1 \
    --query 'Step.Status.State' \
    --output text)

echo -e "État actuel: ${YELLOW}${STEP_STATE}${NC}"
echo ""

# Créer le dossier logs
mkdir -p logs

# Télécharger les logs
echo "📥 Téléchargement des logs depuis S3..."
aws s3 sync s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/ \
    logs/ --region eu-west-1 --quiet

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
    EMOJIS=$(grep "🍎\|📂\|✅\|❌\|📊\|💾\|⏰" logs/stderr 2>/dev/null || true)
    if [ -n "${EMOJIS}" ]; then
        echo "${EMOJIS}"
    else
        echo "⚠️  Pas de prints trouvés dans stderr (normal en mode cluster)"
    fi
    
    echo ""
    echo "=================================================="
    echo "📈 DERNIÈRES LIGNES STDERR (50)"
    echo "=================================================="
    tail -50 logs/stderr
    
    echo ""
    echo "=================================================="
    echo "❌ ERREURS ET WARNINGS"
    echo "=================================================="
    
    # Chercher les erreurs
    ERRORS=$(grep -i "error\|exception\|failed\|traceback" logs/stderr 2>/dev/null || true)
    if [ -n "${ERRORS}" ]; then
        echo -e "${RED}${ERRORS}${NC}"
    else
        echo -e "${GREEN}✅ Aucune erreur détectée${NC}"
    fi
    
    # Chercher les warnings
    WARNINGS=$(grep -i "warning\|warn" logs/stderr 2>/dev/null || true)
    if [ -n "${WARNINGS}" ]; then
        echo ""
        echo -e "${YELLOW}Warnings trouvés:${NC}"
        echo "${WARNINGS}"
    fi
    
    echo ""
    echo "=================================================="
    echo "📊 STATISTIQUES EXTRAITES"
    echo "=================================================="
    
    # Chercher les compteurs
    grep -i "fichiers\|images\|count\|training\|test\|classes" logs/stderr 2>/dev/null || echo "Pas de stats trouvées"
    
else
    echo -e "${RED}❌ Fichier stderr non trouvé${NC}"
fi

# Télécharger et analyser les logs YARN (où sont les prints du script)
echo ""
echo "=================================================="
echo "📦 LOGS YARN - OUTPUTS DU SCRIPT PYSPARK"
echo "=================================================="

echo "🔍 Recherche de l'Application ID..."
APP_ID=$(grep -o "application_[0-9_]*" logs/stderr 2>/dev/null | head -1 || true)

if [ -n "${APP_ID}" ]; then
    echo -e "${GREEN}✅ Application ID trouvé: ${APP_ID}${NC}"
    echo ""
    
    # Télécharger les logs YARN
    echo "📥 Téléchargement des logs YARN..."
    mkdir -p logs/yarn
    
    aws s3 sync s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/containers/${APP_ID}/ \
        logs/yarn/${APP_ID}/ --region eu-west-1 --quiet 2>/dev/null || true
    
    # Chercher les prints avec emojis dans tous les containers
    echo ""
    echo "📊 OUTPUTS DU SCRIPT (avec emojis) :"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    YARN_OUTPUTS=$(find logs/yarn -name "*.gz" -exec zcat {} \; 2>/dev/null | grep "🍎\|📂\|✅\|❌\|📊\|💾\|⏰" || true)
    
    if [ -n "${YARN_OUTPUTS}" ]; then
        echo -e "${GREEN}${YARN_OUTPUTS}${NC}"
    else
        echo "⚠️  Aucun output trouvé dans les logs YARN"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Statistiques extraites
    echo ""
    echo "📈 Statistiques extraites du job:"
    STATS=$(find logs/yarn -name "*.gz" -exec zcat {} \; 2>/dev/null | \
        grep -i "fichiers\|images\|count\|training\|test\|classes" | \
        grep "✅\|📊" || true)
    
    if [ -n "${STATS}" ]; then
        echo "${STATS}"
    else
        echo "Pas de statistiques trouvées"
    fi
    
else
    echo -e "${YELLOW}⚠️  Application ID non trouvé dans stderr${NC}"
    echo "Les logs YARN ne peuvent pas être téléchargés automatiquement"
fi

# Analyse du controller
if [ -f "logs/controller" ]; then
    echo ""
    echo "=================================================="
    echo "🎛️  CONTROLLER - INFO D'EXÉCUTION"
    echo "=================================================="
    head -20 logs/controller
fi

# Résumé
echo ""
echo "=================================================="
echo "📁 FICHIERS DE LOGS DISPONIBLES"
echo "=================================================="
echo "📄 Logs du driver (stderr, controller):"
ls -lh logs/*.{stderr,controller} 2>/dev/null || ls -lh logs/

if [ -d "logs/yarn" ] && [ -n "$(ls -A logs/yarn 2>/dev/null)" ]; then
    echo ""
    echo "📦 Logs YARN téléchargés:"
    du -sh logs/yarn
    echo "   Containers: $(find logs/yarn -type d -name "container_*" | wc -l)"
fi

echo ""
echo "=================================================="
echo "💡 COMMANDES UTILES"
echo "=================================================="
echo "Voir tout le stderr du driver:"
echo "  cat logs/stderr"
echo ""
echo "Chercher dans les logs du driver:"
echo "  grep -i 'mot_clé' logs/stderr"
echo ""
echo "Voir les outputs du script (YARN):"
echo "  find logs/yarn -name '*.gz' -exec zcat {} \; | grep '🍎\|📂\|✅\|📊'"
echo ""
echo "Chercher dans tous les logs YARN:"
echo "  find logs/yarn -name '*.gz' -exec zcat {} \; | grep -i 'mot_clé'"
echo ""
echo "Voir le controller:"
echo "  cat logs/controller"
echo ""
echo "Surveiller l'état du job:"
echo "  watch -n 10 'aws emr describe-step --cluster-id ${CLUSTER_ID} --step-id ${STEP_ID} --region eu-west-1 --query \"Step.Status.State\"'"
echo ""
echo "=================================================="