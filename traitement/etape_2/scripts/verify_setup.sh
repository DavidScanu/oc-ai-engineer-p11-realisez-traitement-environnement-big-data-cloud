#!/bin/bash
# Script de vérification de la configuration avant création du cluster - Étape 2

set -e

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

echo "=================================================="
echo "🔍 VÉRIFICATION DE LA CONFIGURATION - ÉTAPE 2"
echo "=================================================="
echo ""

ERROR_COUNT=0

# 1. Vérifier la région AWS (GDPR)
echo "🌍 [1/7] Vérification de la région AWS..."
if [[ "${AWS_REGION}" == eu-* ]]; then
    echo "   ✅ Région: ${AWS_REGION} (Europe - Conforme GDPR)"
else
    echo "   ❌ ERREUR: Région ${AWS_REGION} n'est pas en Europe !"
    echo "      Pour GDPR, utilisez: eu-west-1, eu-west-2, eu-west-3, eu-central-1, etc."
    ((ERROR_COUNT++))
fi
echo ""

# 2. Vérifier les credentials AWS
echo "🔑 [2/7] Vérification des credentials AWS..."
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    echo "   ✅ Credentials valides (Account: ${ACCOUNT_ID})"
else
    echo "   ❌ ERREUR: Credentials AWS non configurés ou invalides"
    echo "      Configurer avec: aws configure"
    ((ERROR_COUNT++))
fi
echo ""

# 3. Vérifier l'existence du bucket S3
echo "🪣 [3/7] Vérification du bucket S3..."
if aws s3 ls "s3://${S3_BUCKET}" --region "${AWS_REGION}" &>/dev/null; then
    echo "   ✅ Bucket existe: ${S3_BUCKET}"

    # Vérifier la région du bucket
    BUCKET_REGION=$(aws s3api get-bucket-location --bucket "${S3_BUCKET}" --query 'LocationConstraint' --output text)
    if [ "${BUCKET_REGION}" == "None" ]; then
        BUCKET_REGION="us-east-1"
    fi

    if [ "${BUCKET_REGION}" == "${AWS_REGION}" ]; then
        echo "   ✅ Région du bucket: ${BUCKET_REGION}"
    else
        echo "   ⚠️  WARNING: Bucket dans une autre région (${BUCKET_REGION} != ${AWS_REGION})"
        echo "      Cela peut causer des frais de transfert inter-régions"
    fi
else
    echo "   ❌ ERREUR: Bucket ${S3_BUCKET} introuvable ou inaccessible"
    ((ERROR_COUNT++))
fi
echo ""

# 4. Vérifier les données d'entrée
echo "📂 [4/7] Vérification des données d'entrée..."
SAMPLE_COUNT=$(aws s3 ls "${S3_DATA_INPUT}Training/" --recursive --region "${AWS_REGION}" | grep "\.jpg$" | head -100 | wc -l)
if [ "${SAMPLE_COUNT}" -gt 0 ]; then
    echo "   ✅ Données trouvées: des fichiers .jpg sont présents"
    echo "      (échantillon vérifié: ${SAMPLE_COUNT} fichiers)"
else
    echo "   ⚠️  WARNING: Aucun fichier .jpg trouvé dans ${S3_DATA_INPUT}Training/"
    echo "      Vérifier que les données sont bien uploadées"
fi
echo ""

# 5. Vérifier les scripts sur S3
echo "📜 [5/7] Vérification des scripts sur S3..."
MISSING_SCRIPTS=0

if aws s3 ls "${S3_SCRIPTS}install_dependencies.sh" --region "${AWS_REGION}" &>/dev/null; then
    echo "   ✅ install_dependencies.sh présent"
else
    echo "   ❌ install_dependencies.sh manquant"
    ((MISSING_SCRIPTS++))
fi

if aws s3 ls "${S3_SCRIPTS}process_fruits_data.py" --region "${AWS_REGION}" &>/dev/null; then
    echo "   ✅ process_fruits_data.py présent"
else
    echo "   ❌ process_fruits_data.py manquant"
    ((MISSING_SCRIPTS++))
fi

if [ "${MISSING_SCRIPTS}" -gt 0 ]; then
    echo ""
    echo "   💡 Pour uploader les scripts:"
    echo "      ./scripts/upload_scripts.sh"
    ((ERROR_COUNT++))
fi
echo ""

# 6. Vérifier la clé SSH
echo "🔐 [6/7] Vérification de la clé SSH..."
KEY_EXISTS=$(aws ec2 describe-key-pairs --key-names "${EC2_KEY_NAME}" --region "${AWS_REGION}" --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${KEY_EXISTS}" == "${EC2_KEY_NAME}" ]; then
    echo "   ✅ Clé SSH existe: ${EC2_KEY_NAME}"
else
    echo "   ❌ ERREUR: Clé SSH ${EC2_KEY_NAME} introuvable"
    echo "      Créer la clé dans EC2 ou mettre à jour config.sh"
    ((ERROR_COUNT++))
fi
echo ""

# 7. Vérifier les rôles IAM
echo "👤 [7/7] Vérification des rôles IAM..."
ROLE_ERRORS=0

# Extraire le nom du rôle depuis l'ARN
SERVICE_ROLE_NAME=$(echo "${IAM_SERVICE_ROLE}" | awk -F'/' '{print $2}')
if aws iam get-role --role-name "${SERVICE_ROLE_NAME}" &>/dev/null; then
    echo "   ✅ Service Role: ${SERVICE_ROLE_NAME}"
else
    echo "   ❌ Service Role manquant: ${SERVICE_ROLE_NAME}"
    ((ROLE_ERRORS++))
fi

# Vérifier l'instance profile
if aws iam get-instance-profile --instance-profile-name "${IAM_INSTANCE_PROFILE}" &>/dev/null; then
    echo "   ✅ Instance Profile: ${IAM_INSTANCE_PROFILE}"
else
    echo "   ❌ Instance Profile manquant: ${IAM_INSTANCE_PROFILE}"
    ((ROLE_ERRORS++))
fi

if [ "${ROLE_ERRORS}" -gt 0 ]; then
    echo ""
    echo "   💡 Pour créer les rôles IAM par défaut:"
    echo "      aws emr create-default-roles --region ${AWS_REGION}"
    ((ERROR_COUNT++))
fi
echo ""

# Résumé final
echo "=================================================="
if [ "${ERROR_COUNT}" -eq 0 ]; then
    echo "✅ VÉRIFICATION RÉUSSIE"
    echo "=================================================="
    echo ""
    echo "🎉 Tout est prêt pour créer le cluster !"
    echo ""
    echo "📊 Configuration de l'étape 2:"
    echo "   - Instances: ${CORE_INSTANCE_COUNT}x ${CORE_INSTANCE_TYPE}"
    echo "   - Spark Memory: Executor ${SPARK_EXECUTOR_MEMORY}, Driver ${SPARK_DRIVER_MEMORY}"
    echo "   - PCA Components: ${PCA_COMPONENTS}"
    echo "   - Mode par défaut: ${DEFAULT_MODE} (${MINI_IMAGES_COUNT} images)"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. ./scripts/create_cluster.sh     # Créer le cluster EMR"
    echo "  2. ./scripts/monitor_cluster.sh    # Surveiller le démarrage"
    echo "  3. ./scripts/submit_job.sh         # Soumettre le job PySpark"
    echo ""
    exit 0
else
    echo "❌ VÉRIFICATION ÉCHOUÉE"
    echo "=================================================="
    echo ""
    echo "Nombre d'erreurs: ${ERROR_COUNT}"
    echo ""
    echo "Veuillez corriger les erreurs ci-dessus avant de continuer."
    echo ""
    exit 1
fi
