#!/bin/bash
# Script pour télécharger les résultats de l'Étape 1 depuis S3
# Sauvegarde dans: traitement/etape_1/output/

set -e  # Arrêter en cas d'erreur

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

# Créer le dossier output local s'il n'existe pas
LOCAL_OUTPUT="${SCRIPT_DIR}/../output"
mkdir -p "${LOCAL_OUTPUT}"

echo "=================================================="
echo "📥 TÉLÉCHARGEMENT DES RÉSULTATS - ÉTAPE 1"
echo "=================================================="
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

# Lister les fichiers
echo "📂 Contenu disponible:"
aws s3 ls "${S3_DATA_OUTPUT}" --recursive --region "${AWS_REGION}" --human-readable

echo ""
echo "📥 Téléchargement en cours..."

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
tree -L 3 "${LOCAL_OUTPUT}" 2>/dev/null || find "${LOCAL_OUTPUT}" -type f -print | head -20

echo ""
echo "💡 Emplacements importants:"
echo "   📄 Métadonnées: ${LOCAL_OUTPUT}/metadata_*/"
echo "   📊 Statistiques: ${LOCAL_OUTPUT}/stats_*/"
echo ""

# Chercher et afficher le CSV des métadonnées
METADATA_CSV=$(find "${LOCAL_OUTPUT}" -name "*.csv" -path "*/metadata_*" | head -1)
if [ -n "${METADATA_CSV}" ]; then
    echo "🔍 Aperçu des métadonnées (10 premières lignes):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -11 "${METADATA_CSV}" | column -t -s,
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    TOTAL_LINES=$(wc -l < "${METADATA_CSV}")
    echo "📊 Total: $((TOTAL_LINES - 1)) images indexées"
fi

echo ""

# Chercher et afficher les statistiques
STATS_CSV=$(find "${LOCAL_OUTPUT}" -name "*.csv" -path "*/stats_*" | head -1)
if [ -n "${STATS_CSV}" ]; then
    echo "📈 Statistiques par classe (échantillon):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -21 "${STATS_CSV}" | column -t -s,
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   (... voir ${STATS_CSV} pour la liste complète)"
fi

echo ""
echo "=================================================="
echo "📂 Résultats sauvegardés dans:"
echo "   ${LOCAL_OUTPUT}"
echo "=================================================="