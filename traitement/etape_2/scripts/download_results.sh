#!/bin/bash
# Script pour télécharger les résultats de l'Étape 2 depuis S3
# Sauvegarde dans: traitement/etape_2/outputs/output-{mode}/

set -e  # Arrêter en cas d'erreur

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

# Déterminer le mode
if [ -n "$1" ]; then
    MODE="$1"
else
    # Lire depuis mode.txt si pas d'argument
    if [ -f "${SCRIPT_DIR}/../mode.txt" ]; then
        MODE=$(cat "${SCRIPT_DIR}/../mode.txt")
    else
        MODE="mini"
        echo "⚠️  Aucun mode spécifié, utilisation du mode par défaut: mini"
    fi
fi

# Définir le chemin de sortie selon le mode
set_output_path "${MODE}"

# Créer le dossier output local s'il n'existe pas
LOCAL_OUTPUT="${SCRIPT_DIR}/../outputs/output-${MODE}"
mkdir -p "${LOCAL_OUTPUT}"

echo "=================================================="
echo "📥 TÉLÉCHARGEMENT DES RÉSULTATS - ÉTAPE 2"
echo "=================================================="
echo "🎯 Mode: ${MODE}"
echo "☁️  Source S3: ${S3_DATA_OUTPUT}"
echo "💾 Destination: ${LOCAL_OUTPUT}"
echo ""

# Vérifier si des résultats existent sur S3
echo "🔍 Vérification des fichiers disponibles sur S3..."
if ! aws s3 ls "${S3_DATA_OUTPUT}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "❌ Aucun résultat trouvé sur S3"
    echo "Vérifiez que le job s'est bien exécuté"
    exit 1
fi

echo "✅ Résultats trouvés sur S3"
echo ""

# Lister les fichiers (avec limite pour ne pas surcharger)
echo "📂 Contenu disponible:"
aws s3 ls "${S3_DATA_OUTPUT}" --recursive --region "${AWS_REGION}" --human-readable | head -50

echo ""
echo "📥 Téléchargement en cours..."
echo "   (Cela peut prendre plusieurs minutes selon la taille)"
echo ""

# Télécharger tous les résultats
aws s3 sync "${S3_DATA_OUTPUT}" "${LOCAL_OUTPUT}/" \
    --region "${AWS_REGION}" \
    --exclude "*.crc" \
    --exclude "_SUCCESS"

echo ""
echo "=================================================="
echo "✅ TÉLÉCHARGEMENT TERMINÉ"
echo "=================================================="

# Compter les fichiers téléchargés
FILE_COUNT=$(find "${LOCAL_OUTPUT}" -type f | wc -l)
echo "📊 ${FILE_COUNT} fichier(s) téléchargé(s)"
echo ""

# Afficher la structure
echo "📁 Structure du dossier output/:"
echo ""
tree -L 3 "${LOCAL_OUTPUT}" 2>/dev/null || {
    echo "Features (1280D):"
    find "${LOCAL_OUTPUT}/features" -type f 2>/dev/null | head -5
    echo ""
    echo "PCA (${PCA_COMPONENTS}D):"
    find "${LOCAL_OUTPUT}/pca" -type f 2>/dev/null | head -5
    echo ""
    echo "Metadata:"
    find "${LOCAL_OUTPUT}/metadata" -type f 2>/dev/null | head -5
    echo ""
    echo "Model Info:"
    find "${LOCAL_OUTPUT}/model_info" -type f 2>/dev/null | head -5
    echo ""
    echo "Errors (si présent):"
    find "${LOCAL_OUTPUT}/errors" -type f 2>/dev/null | head -5
}

echo ""
echo "💡 Emplacements importants:"
echo "   🎨 Features (1280D): ${LOCAL_OUTPUT}/features/"
echo "   📊 PCA (${PCA_COMPONENTS}D): ${LOCAL_OUTPUT}/pca/"
echo "   📋 Metadata: ${LOCAL_OUTPUT}/metadata/"
echo "   🤖 Model Info: ${LOCAL_OUTPUT}/model_info/"
echo "   ⚠️  Errors: ${LOCAL_OUTPUT}/errors/"
echo ""

# Afficher les infos du modèle PCA
MODEL_INFO=$(find "${LOCAL_OUTPUT}/model_info" -name "*.txt" | head -1)
if [ -n "${MODEL_INFO}" ]; then
    echo "🤖 Informations du modèle PCA:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "${MODEL_INFO}" | head -20
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Afficher les statistiques d'erreurs
ERROR_CSV=$(find "${LOCAL_OUTPUT}/errors" -name "*.csv" | head -1)
if [ -n "${ERROR_CSV}" ]; then
    ERROR_COUNT=$(tail -n +2 "${ERROR_CSV}" | wc -l)
    echo "⚠️  Rapport d'erreurs: ${ERROR_COUNT} images en erreur"
    echo "   Voir: ${ERROR_CSV}"
    echo ""
fi

echo "=================================================="
echo "📂 Résultats sauvegardés dans:"
echo "   ${LOCAL_OUTPUT}"
echo "=================================================="
