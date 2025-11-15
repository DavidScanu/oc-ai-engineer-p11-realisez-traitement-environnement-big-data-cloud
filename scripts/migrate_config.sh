#!/bin/bash

################################################################################
# Script de Migration - Fichiers de configuration AWS
# Migre les fichiers cachés (.bucket_name, etc.) vers .aws/config.env
################################################################################

CONFIG_DIR=".aws"
CONFIG_FILE="${CONFIG_DIR}/config.env"

# Créer le dossier .aws
mkdir -p "${CONFIG_DIR}"

# Créer le fichier de configuration
cat > "${CONFIG_FILE}" << 'EOF'
# Configuration AWS EMR - Projet P11
# Ce fichier est généré automatiquement
# NE PAS COMMITTER (ajouté à .gitignore)

EOF

# Migrer les fichiers
echo "🔄 Migration des fichiers de configuration..."

if [ -f ".bucket_name" ]; then
    BUCKET_NAME=$(cat .bucket_name)
    echo "BUCKET_NAME=${BUCKET_NAME}" >> "${CONFIG_FILE}"
    echo "✅ .bucket_name → ${CONFIG_FILE}"
fi

if [ -f ".cluster_id" ]; then
    CLUSTER_ID=$(cat .cluster_id)
    echo "CLUSTER_ID=${CLUSTER_ID}" >> "${CONFIG_FILE}"
    echo "✅ .cluster_id → ${CONFIG_FILE}"
fi

if [ -f ".key_name" ]; then
    KEY_NAME=$(cat .key_name)
    echo "KEY_NAME=${KEY_NAME}" >> "${CONFIG_FILE}"
    echo "✅ .key_name → ${CONFIG_FILE}"
fi

if [ -f ".master_dns" ]; then
    MASTER_DNS=$(cat .master_dns)
    echo "MASTER_DNS=${MASTER_DNS}" >> "${CONFIG_FILE}"
    echo "✅ .master_dns → ${CONFIG_FILE}"
fi

# Ajouter la région par défaut
echo "REGION=eu-west-1" >> "${CONFIG_FILE}"

echo ""
echo "📄 Fichier de configuration créé: ${CONFIG_FILE}"
echo ""
cat "${CONFIG_FILE}"

echo ""
echo "🗑️  Nettoyage des anciens fichiers cachés..."
read -p "Supprimer les fichiers .bucket_name, .cluster_id, etc. ? (y/N): " CONFIRM

if [ "$CONFIRM" = "y" ]; then
    rm -f .bucket_name .cluster_id .key_name .master_dns
    echo "✅ Anciens fichiers supprimés"
else
    echo "ℹ️  Fichiers conservés (vous pouvez les supprimer manuellement plus tard)"
fi

echo ""
echo "✅ Migration terminée!"