#!/bin/bash
# Script pour uploader les scripts sur S3 - Étape 2

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

echo "=================================================="
echo "📤 UPLOAD DES SCRIPTS SUR S3 - ÉTAPE 2"
echo "=================================================="
echo ""

show_config

echo ""
echo "📂 Scripts à uploader:"
echo "   - install_dependencies.sh (bootstrap action)"
echo "   - process_fruits_data.py (script PySpark principal)"
echo ""

# Vérifier que les fichiers existent localement
if [ ! -f "${SCRIPT_DIR}/install_dependencies.sh" ]; then
    echo "❌ ERREUR: install_dependencies.sh introuvable"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/process_fruits_data.py" ]; then
    echo "❌ ERREUR: process_fruits_data.py introuvable"
    exit 1
fi

# Vérifier si le bucket existe
if ! aws s3 ls "s3://${S3_BUCKET}" --region "${AWS_REGION}" &>/dev/null; then
    echo "⚠️  Le bucket ${S3_BUCKET} n'existe pas."
    echo ""
    read -p "Voulez-vous le créer ? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔨 Création du bucket ${S3_BUCKET} dans ${AWS_REGION}..."
        aws s3 mb "s3://${S3_BUCKET}" --region "${AWS_REGION}"
        echo "✅ Bucket créé"
    else
        echo "❌ Abandon"
        exit 1
    fi
fi

# Upload des scripts
echo "📤 Upload de install_dependencies.sh..."
aws s3 cp "${SCRIPT_DIR}/install_dependencies.sh" "${S3_SCRIPTS}install_dependencies.sh" --region "${AWS_REGION}"
echo "✅ install_dependencies.sh uploadé"

echo ""
echo "📤 Upload de process_fruits_data.py..."
aws s3 cp "${SCRIPT_DIR}/process_fruits_data.py" "${S3_SCRIPTS}process_fruits_data.py" --region "${AWS_REGION}"
echo "✅ process_fruits_data.py uploadé"

echo ""
echo "=================================================="
echo "✅ UPLOAD TERMINÉ"
echo "=================================================="
echo ""
echo "📋 Vérification des fichiers sur S3:"
aws s3 ls "${S3_SCRIPTS}" --region "${AWS_REGION}" --human-readable

echo ""
echo "Prochaines étapes:"
echo "  1. ./scripts/verify_setup.sh       # Vérifier la configuration"
echo "  2. ./scripts/create_cluster.sh     # Créer le cluster EMR"
echo ""
