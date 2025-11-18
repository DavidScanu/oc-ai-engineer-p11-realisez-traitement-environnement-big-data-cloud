#!/bin/bash
# Script pour uploader les scripts et fichiers de configuration sur S3

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

echo "=================================================="
echo "📤 UPLOAD DES SCRIPTS SUR S3 - ÉTAPE 1"
echo "=================================================="
echo "🪣 Bucket: ${S3_BUCKET}"
echo "🌍 Région: ${AWS_REGION}"
echo ""

# Vérifier que le bucket existe
if ! aws s3 ls "s3://${S3_BUCKET}" --region "${AWS_REGION}" &>/dev/null; then
    echo "❌ ERREUR: Bucket ${S3_BUCKET} introuvable"
    echo ""
    read -p "Créer le bucket ${S3_BUCKET} dans ${AWS_REGION} ? (oui/non): " CREATE_BUCKET

    if [ "$CREATE_BUCKET" == "oui" ]; then
        echo "🪣 Création du bucket..."
        aws s3 mb "s3://${S3_BUCKET}" --region "${AWS_REGION}"
        echo "✅ Bucket créé"
    else
        echo "❌ Annulé"
        exit 1
    fi
    echo ""
fi

# 2. Upload install_dependencies.sh
echo "🔧 [1/2] Upload du script d'installation des dépendances..."
aws s3 cp "${SCRIPT_DIR}/install_dependencies.sh" "${S3_SCRIPTS}install_dependencies.sh" --region "${AWS_REGION}"
echo "   ✅ ${S3_SCRIPTS}install_dependencies.sh"
echo ""

# 3. Upload read_fruits_data.py
echo "🐍 [2/2] Upload du script PySpark..."
aws s3 cp "${SCRIPT_DIR}/read_fruits_data.py" "${S3_SCRIPTS}read_fruits_data.py" --region "${AWS_REGION}"
echo "   ✅ ${S3_SCRIPTS}read_fruits_data.py"
echo ""

echo "=================================================="
echo "✅ UPLOAD TERMINÉ AVEC SUCCÈS"
echo "=================================================="
echo ""
echo "📋 Fichiers uploadés:"
echo "   - ${S3_SCRIPTS}install_dependencies.sh"
echo "   - ${S3_SCRIPTS}read_fruits_data.py"
echo ""
echo "🔍 Vérifier les fichiers:"
echo "   aws s3 ls ${S3_SCRIPTS} --region ${AWS_REGION}"
echo "   aws s3 ls ${S3_CONFIG} --region ${AWS_REGION}"
echo ""
echo "Prochaine étape:"
echo "   ./scripts/verify_setup.sh"
echo ""
