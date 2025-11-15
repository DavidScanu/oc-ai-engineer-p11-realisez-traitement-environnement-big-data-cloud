#!/bin/bash

################################################################################
# Script Helper - Configuration et Déploiement AWS EMR Studio
# Projet P11 - Big Data Fruits
#
# Ce script automatise la configuration d'EMR Studio (nouvelle approche)
# Utilisation: ./scripts/aws_emr_studio_setup.sh [commande]
################################################################################

set -e  # Arrêter en cas d'erreur

# Configuration centralisée
CONFIG_DIR=".aws"
CONFIG_FILE="${CONFIG_DIR}/emr_studio_config.env"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ============================================================
# GESTION DE LA CONFIGURATION CENTRALISÉE
# ============================================================

init_config() {
    mkdir -p "${CONFIG_DIR}"
    if [ ! -f "${CONFIG_FILE}" ]; then
        cat > "${CONFIG_FILE}" << 'EOF'
# Configuration AWS EMR Studio - Projet P11
# Ce fichier est généré automatiquement
# NE PAS COMMITTER (ajouté à .gitignore)

EOF
    fi
}

save_config() {
    local key="$1"
    local value="$2"
    init_config
    sed -i "/^${key}=/d" "${CONFIG_FILE}" 2>/dev/null || true
    echo "${key}=${value}" >> "${CONFIG_FILE}"
}

load_config() {
    local key="$1"
    if [ -f "${CONFIG_FILE}" ]; then
        grep "^${key}=" "${CONFIG_FILE}" 2>/dev/null | cut -d'=' -f2-
    fi
}

# Vérifier qu'AWS CLI est installé
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI n'est pas installé"
        echo ""
        echo "Pour installer AWS CLI v2:"
        echo "  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
        echo "  unzip awscliv2.zip"
        echo "  sudo ./aws/install"
        exit 1
    fi
    log_success "AWS CLI installé: $(aws --version)"
}

# Vérifier la configuration AWS
check_aws_config() {
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI n'est pas configuré"
        echo ""
        echo "Pour configurer AWS CLI:"
        echo "  aws configure"
        exit 1
    fi
    log_success "AWS configuré pour: $(aws sts get-caller-identity --query 'Arn' --output text)"
}

# Créer le bucket S3
create_bucket() {
    log_info "Création du bucket S3..."

    read -p "Nom du bucket (laisser vide pour générer): " BUCKET_INPUT

    if [ -z "$BUCKET_INPUT" ]; then
        BUCKET_NAME="oc-p11-fruits-$(date +%Y%m%d-%H%M%S)"
    else
        BUCKET_NAME="$BUCKET_INPUT"
    fi

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    log_info "Bucket: $BUCKET_NAME"
    log_info "Region: $REGION"

    # Créer le bucket
    if [ "$REGION" == "us-east-1" ]; then
        aws s3 mb s3://${BUCKET_NAME}
    else
        aws s3 mb s3://${BUCKET_NAME} --region ${REGION}
    fi

    # Bloquer l'accès public
    aws s3api put-public-access-block \
        --bucket ${BUCKET_NAME} \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Créer la structure
    aws s3api put-object --bucket ${BUCKET_NAME} --key data/raw/
    aws s3api put-object --bucket ${BUCKET_NAME} --key data/features/
    aws s3api put-object --bucket ${BUCKET_NAME} --key data/pca/
    aws s3api put-object --bucket ${BUCKET_NAME} --key logs/
    aws s3api put-object --bucket ${BUCKET_NAME} --key emr-studio-workspaces/

    save_config "BUCKET_NAME" "${BUCKET_NAME}"
    save_config "REGION" "${REGION}"

    log_success "Bucket créé: s3://${BUCKET_NAME}"
    log_info "Configuration sauvegardée dans ${CONFIG_FILE}"
    echo ""
    echo "Pour uploader le dataset:"
    echo "  ./scripts/aws_emr_studio_setup.sh upload-dataset"
}

# Uploader le dataset
upload_dataset() {
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé. Créez d'abord le bucket avec: ./scripts/aws_emr_studio_setup.sh create-bucket"
        exit 1
    fi

    REGION=$(load_config "REGION")
    REGION="${REGION:-eu-west-1}"

    log_info "Upload du dataset vers s3://${BUCKET_NAME}..."
    log_warning "Cela peut prendre 10-30 minutes selon votre connexion"

    if [ ! -d "data/raw/fruits-360_dataset/fruits-360/Training" ]; then
        log_error "Dataset non trouvé dans data/raw/fruits-360_dataset/"
        exit 1
    fi

    # Upload Training
    aws s3 sync data/raw/fruits-360_dataset/fruits-360/Training/ \
        s3://${BUCKET_NAME}/data/raw/Training/ \
        --region ${REGION} \
        --exclude "*.DS_Store"

    COUNT=$(aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ --recursive | wc -l)
    log_success "Upload terminé: $COUNT fichiers"

    aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ --recursive --human-readable --summarize | tail -2
}

# Créer les rôles IAM pour EMR Studio
create_iam_roles() {
    log_info "Création des rôles IAM pour EMR Studio..."

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

    # 1. Service Role pour EMR Studio
    SERVICE_ROLE_NAME="EMRStudio_Service_Role"

    log_info "Création du Service Role: ${SERVICE_ROLE_NAME}"

    # Trust policy pour EMR Studio
    cat > /tmp/emr-studio-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Créer le role
    aws iam create-role \
        --role-name ${SERVICE_ROLE_NAME} \
        --assume-role-policy-document file:///tmp/emr-studio-trust-policy.json \
        --region ${REGION} 2>/dev/null || log_warning "Role ${SERVICE_ROLE_NAME} existe déjà"

    # Attacher les policies managées
    aws iam attach-role-policy \
        --role-name ${SERVICE_ROLE_NAME} \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole 2>/dev/null || true

    # Policy EC2 pour EMR Studio (nécessaire pour network interfaces)
    cat > /tmp/emr-studio-ec2-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DeleteNetworkInterface",
        "ec2:DeleteNetworkInterfacePermission",
        "ec2:DescribeNetworkInterfaces",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name ${SERVICE_ROLE_NAME} \
        --policy-name EMRStudioEC2Policy \
        --policy-document file:///tmp/emr-studio-ec2-policy.json

    rm -f /tmp/emr-studio-ec2-policy.json

    # Policy S3 pour EMR Studio (nécessaire pour le workspace storage)
    BUCKET_NAME=$(load_config "BUCKET_NAME")

    cat > /tmp/emr-studio-service-s3-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}"
      ]
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name ${SERVICE_ROLE_NAME} \
        --policy-name EMRStudioServiceS3Policy \
        --policy-document file:///tmp/emr-studio-service-s3-policy.json

    SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"
    save_config "SERVICE_ROLE_ARN" "${SERVICE_ROLE_ARN}"

    # 2. User Role pour EMR Studio
    USER_ROLE_NAME="EMRStudio_User_Role"

    log_info "Création du User Role: ${USER_ROLE_NAME}"

    cat > /tmp/emr-studio-user-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:SetContext"
      ]
    }
  ]
}
EOF

    aws iam create-role \
        --role-name ${USER_ROLE_NAME} \
        --assume-role-policy-document file:///tmp/emr-studio-user-trust-policy.json \
        --region ${REGION} 2>/dev/null || log_warning "Role ${USER_ROLE_NAME} existe déjà"

    # Policy pour les utilisateurs
    BUCKET_NAME=$(load_config "BUCKET_NAME")

    cat > /tmp/emr-studio-user-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticmapreduce:CreateEditor",
        "elasticmapreduce:DescribeEditor",
        "elasticmapreduce:ListEditors",
        "elasticmapreduce:StartEditor",
        "elasticmapreduce:StopEditor",
        "elasticmapreduce:DeleteEditor",
        "elasticmapreduce:OpenEditorInConsole",
        "elasticmapreduce:AttachEditor",
        "elasticmapreduce:DetachEditor",
        "elasticmapreduce:CreateRepository",
        "elasticmapreduce:DescribeRepository",
        "elasticmapreduce:DeleteRepository",
        "elasticmapreduce:ListRepositories",
        "elasticmapreduce:LinkRepository",
        "elasticmapreduce:UnlinkRepository",
        "elasticmapreduce:DescribeCluster",
        "elasticmapreduce:ListInstanceGroups",
        "elasticmapreduce:ListBootstrapActions",
        "elasticmapreduce:ListClusters",
        "elasticmapreduce:ListSteps",
        "elasticmapreduce:CreatePersistentAppUI",
        "elasticmapreduce:DescribePersistentAppUI",
        "elasticmapreduce:GetPersistentAppUIPresignedURL",
        "elasticmapreduce:GetOnClusterAppUIPresignedURL"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "${SERVICE_ROLE_ARN}"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name ${USER_ROLE_NAME} \
        --policy-name EMRStudioUserPolicy \
        --policy-document file:///tmp/emr-studio-user-policy.json

    USER_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${USER_ROLE_NAME}"
    save_config "USER_ROLE_ARN" "${USER_ROLE_ARN}"

    log_success "Rôles IAM créés:"
    log_success "  Service Role: ${SERVICE_ROLE_ARN}"
    log_success "  User Role: ${USER_ROLE_ARN}"

    # Nettoyage
    rm -f /tmp/emr-studio-*.json
}

# Créer EMR Studio
create_studio() {
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé. Créez d'abord le bucket."
        exit 1
    fi

    SERVICE_ROLE_ARN=$(load_config "SERVICE_ROLE_ARN")
    if [ -z "$SERVICE_ROLE_ARN" ]; then
        log_warning "Rôles IAM non trouvés. Création automatique..."
        create_iam_roles
        SERVICE_ROLE_ARN=$(load_config "SERVICE_ROLE_ARN")
    fi

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
    STUDIO_NAME="P11-Fruits-Studio-$(date +%Y%m%d-%H%M%S)"

    log_info "Récupération du VPC par défaut..."
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region ${REGION})

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        log_error "VPC par défaut non trouvé. Créez un VPC manuellement."
        exit 1
    fi

    log_info "Récupération des subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region ${REGION} | tr '\t' ' ')

    log_info "Création d'EMR Studio..."
    log_info "Nom: ${STUDIO_NAME}"
    log_info "VPC: ${VPC_ID}"
    log_info "Subnets: ${SUBNET_IDS}"

    STUDIO_ID=$(aws emr create-studio \
        --name "${STUDIO_NAME}" \
        --auth-mode IAM \
        --vpc-id ${VPC_ID} \
        --subnet-ids ${SUBNET_IDS} \
        --service-role ${SERVICE_ROLE_ARN} \
        --workspace-security-group-id $(aws ec2 create-security-group \
            --group-name "emr-studio-workspace-sg-$(date +%s)" \
            --description "EMR Studio Workspace Security Group" \
            --vpc-id ${VPC_ID} \
            --region ${REGION} \
            --query 'GroupId' \
            --output text) \
        --engine-security-group-id $(aws ec2 create-security-group \
            --group-name "emr-studio-engine-sg-$(date +%s)" \
            --description "EMR Studio Engine Security Group" \
            --vpc-id ${VPC_ID} \
            --region ${REGION} \
            --query 'GroupId' \
            --output text) \
        --default-s3-location s3://${BUCKET_NAME}/emr-studio-workspaces/ \
        --region ${REGION} \
        --query 'StudioId' \
        --output text)

    save_config "STUDIO_ID" "${STUDIO_ID}"
    save_config "STUDIO_NAME" "${STUDIO_NAME}"

    # Récupérer l'URL du studio
    STUDIO_URL=$(aws emr describe-studio \
        --studio-id ${STUDIO_ID} \
        --region ${REGION} \
        --query 'Studio.Url' \
        --output text)

    save_config "STUDIO_URL" "${STUDIO_URL}"

    log_success "EMR Studio créé: ${STUDIO_ID}"
    log_success "URL: ${STUDIO_URL}"
    echo ""
    echo "Pour créer un cluster pour le Studio:"
    echo "  ./scripts/aws_emr_studio_setup.sh create-cluster"
}

# Créer un cluster EMR pour Studio
create_cluster() {
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    STUDIO_ID=$(load_config "STUDIO_ID")

    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé."
        exit 1
    fi

    if [ -z "$STUDIO_ID" ]; then
        log_error "Studio ID non trouvé. Créez d'abord le studio avec: create-studio"
        exit 1
    fi

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
    CLUSTER_NAME="P11-Fruits-Cluster-$(date +%Y%m%d-%H%M%S)"
    EMR_RELEASE="emr-7.5.0"
    INSTANCE_TYPE="${1:-m5.xlarge}"

    # Récupérer le VPC et les subnets du studio
    log_info "Récupération de la configuration du studio..."
    VPC_ID=$(aws emr describe-studio \
        --studio-id ${STUDIO_ID} \
        --region ${REGION} \
        --query 'Studio.VpcId' \
        --output text)

    SUBNET_ID=$(aws emr describe-studio \
        --studio-id ${STUDIO_ID} \
        --region ${REGION} \
        --query 'Studio.SubnetIds[0]' \
        --output text)

    log_info "VPC: ${VPC_ID}"
    log_info "Subnet: ${SUBNET_ID}"

    log_warning "⚠️  ATTENTION: Le cluster va coûter ~2-3€/heure"
    read -p "Continuer? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Annulé"
        exit 0
    fi

    log_info "Création du cluster EMR pour Studio..."
    log_info "Nom: ${CLUSTER_NAME}"
    log_info "Release: ${EMR_RELEASE}"
    log_info "Instance: ${INSTANCE_TYPE} (1 master + 2 core)"

    # Créer le Runtime Role si nécessaire
    RUNTIME_ROLE_NAME="EMR_EC2_DefaultRole"
    RUNTIME_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/${RUNTIME_ROLE_NAME}"

    # Vérifier si le role existe, sinon le créer
    if ! aws iam get-role --role-name ${RUNTIME_ROLE_NAME} &>/dev/null; then
        log_info "Création du Runtime Role: ${RUNTIME_ROLE_NAME}"

        cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

        aws iam create-role \
            --role-name ${RUNTIME_ROLE_NAME} \
            --assume-role-policy-document file:///tmp/ec2-trust-policy.json 2>/dev/null || true

        aws iam attach-role-policy \
            --role-name ${RUNTIME_ROLE_NAME} \
            --policy-arn arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role 2>/dev/null || true

        # Créer l'instance profile
        aws iam create-instance-profile \
            --instance-profile-name ${RUNTIME_ROLE_NAME} 2>/dev/null || true

        aws iam add-role-to-instance-profile \
            --instance-profile-name ${RUNTIME_ROLE_NAME} \
            --role-name ${RUNTIME_ROLE_NAME} 2>/dev/null || true

        rm -f /tmp/ec2-trust-policy.json

        log_info "Attente de 10 secondes pour la propagation IAM..."
        sleep 10
    fi

    CLUSTER_ID=$(aws emr create-cluster \
        --name "${CLUSTER_NAME}" \
        --region ${REGION} \
        --release-label ${EMR_RELEASE} \
        --applications Name=Spark Name=Livy Name=JupyterEnterpriseGateway \
        --ec2-attributes SubnetId=${SUBNET_ID},InstanceProfile=${RUNTIME_ROLE_NAME} \
        --instance-groups \
            InstanceGroupType=MASTER,InstanceCount=1,InstanceType=${INSTANCE_TYPE} \
            InstanceGroupType=CORE,InstanceCount=2,InstanceType=${INSTANCE_TYPE} \
        --service-role EMR_DefaultRole \
        --log-uri s3://${BUCKET_NAME}/logs/ \
        --enable-debugging \
        --tags "for-use-with-amazon-emr-managed-policies=true" \
        --configurations '[
            {
                "Classification": "spark",
                "Properties": {
                    "maximizeResourceAllocation": "true"
                }
            },
            {
                "Classification": "livy-conf",
                "Properties": {
                    "livy.server.session.timeout": "2h"
                }
            }
        ]' \
        --query 'ClusterId' \
        --output text)

    save_config "CLUSTER_ID" "${CLUSTER_ID}"

    log_success "Cluster créé: ${CLUSTER_ID}"
    echo ""
    log_info "Le cluster démarre... (10-15 minutes)"
    echo ""
    echo "Pour suivre le statut:"
    echo "  ./scripts/aws_emr_studio_setup.sh status"
    echo ""
    echo "Une fois prêt, attachez-le à votre workspace dans EMR Studio"

    STUDIO_URL=$(load_config "STUDIO_URL")
    if [ -n "$STUDIO_URL" ]; then
        echo ""
        echo "URL EMR Studio: ${STUDIO_URL}"
    fi
}

# Afficher le statut
status() {
    STUDIO_ID=$(load_config "STUDIO_ID")
    CLUSTER_ID=$(load_config "CLUSTER_ID")

    echo ""
    log_info "=== EMR Studio Status ==="

    if [ -n "$STUDIO_ID" ]; then
        REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
        STUDIO_NAME=$(aws emr describe-studio \
            --studio-id ${STUDIO_ID} \
            --region ${REGION} \
            --query 'Studio.Name' \
            --output text 2>/dev/null || echo "N/A")

        STUDIO_URL=$(load_config "STUDIO_URL")

        log_success "Studio ID: ${STUDIO_ID}"
        log_success "Studio Name: ${STUDIO_NAME}"
        log_success "Studio URL: ${STUDIO_URL}"
    else
        log_warning "Aucun studio créé"
    fi

    echo ""
    log_info "=== EMR Cluster Status ==="

    if [ -n "$CLUSTER_ID" ]; then
        STATE=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State' --output text)

        log_info "Cluster ID: ${CLUSTER_ID}"

        case "$STATE" in
            "WAITING")
                log_success "État: ${STATE} - Prêt ✓"
                ;;
            "RUNNING"|"BOOTSTRAPPING")
                log_warning "État: ${STATE} - En cours..."
                ;;
            "STARTING")
                log_info "État: ${STATE} - Démarrage..."
                ;;
            "TERMINATING"|"TERMINATED")
                log_info "État: ${STATE}"
                ;;
            *)
                log_info "État: ${STATE}"
                ;;
        esac
    else
        log_warning "Aucun cluster créé"
    fi
    echo ""
}

# Arrêter le cluster
terminate() {
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -z "$CLUSTER_ID" ]; then
        log_error "Cluster ID non trouvé"
        exit 1
    fi

    log_warning "⚠️  Vous allez arrêter le cluster: ${CLUSTER_ID}"
    read -p "Confirmer l'arrêt? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Annulé"
        exit 0
    fi

    log_info "Arrêt du cluster..."
    aws emr terminate-clusters --cluster-ids ${CLUSTER_ID}

    log_success "Commande d'arrêt envoyée"
    echo ""
    echo "Vérifier le statut:"
    echo "  ./scripts/aws_emr_studio_setup.sh status"
}

# Télécharger les résultats
download_results() {
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé"
        exit 1
    fi

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    log_info "Téléchargement des résultats depuis s3://${BUCKET_NAME}..."

    mkdir -p data/emr_output/features
    mkdir -p data/emr_output/pca

    log_info "Téléchargement des features..."
    aws s3 sync s3://${BUCKET_NAME}/data/features/ \
        data/emr_output/features/ \
        --region ${REGION}

    log_info "Téléchargement des résultats PCA..."
    aws s3 sync s3://${BUCKET_NAME}/data/pca/ \
        data/emr_output/pca/ \
        --region ${REGION}

    log_success "Téléchargement terminé"
    echo ""
    echo "Résultats disponibles dans:"
    echo "  data/emr_output/features/"
    echo "  data/emr_output/pca/"
}

# Nettoyage complet
cleanup() {
    log_warning "⚠️  Nettoyage complet AWS"
    echo ""
    echo "Cette opération va:"
    echo "  - Arrêter le cluster EMR (si actif)"
    echo "  - Supprimer EMR Studio"
    echo "  - Supprimer le bucket S3 et toutes les données"
    echo "  - Supprimer les rôles IAM"
    echo "  - Supprimer le fichier de configuration local"
    echo ""
    read -p "Confirmer le nettoyage? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Annulé"
        exit 0
    fi

    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    # Arrêter le cluster
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -n "$CLUSTER_ID" ]; then
        log_info "Arrêt du cluster ${CLUSTER_ID}..."
        aws emr terminate-clusters --cluster-ids ${CLUSTER_ID} 2>/dev/null || true
        sleep 5
    fi

    # Supprimer EMR Studio
    STUDIO_ID=$(load_config "STUDIO_ID")
    if [ -n "$STUDIO_ID" ]; then
        log_info "Suppression d'EMR Studio ${STUDIO_ID}..."
        aws emr delete-studio --studio-id ${STUDIO_ID} --region ${REGION} 2>/dev/null || true
    fi

    # Supprimer le bucket S3
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -n "$BUCKET_NAME" ]; then
        log_info "Suppression du bucket s3://${BUCKET_NAME}..."
        aws s3 rm s3://${BUCKET_NAME}/ --recursive 2>/dev/null || true
        aws s3 rb s3://${BUCKET_NAME} 2>/dev/null || true
    fi

    # Supprimer les rôles IAM (optionnel, commenté par sécurité)
    # log_info "Suppression des rôles IAM..."
    # aws iam delete-role --role-name EMRStudio_Service_Role 2>/dev/null || true
    # aws iam delete-role --role-name EMRStudio_User_Role 2>/dev/null || true

    # Supprimer le fichier de configuration
    if [ -f "${CONFIG_FILE}" ]; then
        log_info "Suppression du fichier de configuration ${CONFIG_FILE}..."
        rm -f "${CONFIG_FILE}"
    fi

    log_success "Nettoyage terminé"
}

# Menu d'aide
show_help() {
    echo ""
    echo "Script Helper - AWS EMR Studio pour Projet P11"
    echo ""
    echo "Usage: ./scripts/aws_emr_studio_setup.sh [commande]"
    echo ""
    echo "Commandes disponibles:"
    echo ""
    echo "  Configuration initiale:"
    echo "    create-bucket          Créer le bucket S3"
    echo "    upload-dataset         Uploader le dataset sur S3"
    echo "    create-iam-roles       Créer les rôles IAM pour EMR Studio"
    echo ""
    echo "  EMR Studio:"
    echo "    create-studio          Créer EMR Studio"
    echo "    create-cluster [type]  Créer un cluster EMR (défaut: m5.xlarge)"
    echo "    status                 Afficher le statut"
    echo "    terminate              Arrêter le cluster"
    echo ""
    echo "  Récupération des résultats:"
    echo "    download-results       Télécharger les résultats depuis S3"
    echo ""
    echo "  Nettoyage:"
    echo "    cleanup                Tout nettoyer (cluster + studio + S3)"
    echo ""
    echo "  Utilitaires:"
    echo "    check                  Vérifier la configuration AWS"
    echo "    help                   Afficher cette aide"
    echo ""
    echo "Workflow complet:"
    echo "  1. ./scripts/aws_emr_studio_setup.sh create-bucket"
    echo "  2. ./scripts/aws_emr_studio_setup.sh upload-dataset"
    echo "  3. ./scripts/aws_emr_studio_setup.sh create-studio"
    echo "  4. ./scripts/aws_emr_studio_setup.sh create-cluster"
    echo "  5. Ouvrir EMR Studio URL et créer un Workspace"
    echo "  6. Attacher le cluster au Workspace"
    echo "  7. Uploader et exécuter le notebook"
    echo ""
}

# Commande principale
case "${1:-help}" in
    check)
        check_aws_cli
        check_aws_config
        ;;
    create-bucket)
        check_aws_cli
        check_aws_config
        create_bucket
        ;;
    upload-dataset)
        check_aws_cli
        check_aws_config
        upload_dataset
        ;;
    create-iam-roles)
        check_aws_cli
        check_aws_config
        create_iam_roles
        ;;
    create-studio)
        check_aws_cli
        check_aws_config
        create_studio
        ;;
    create-cluster)
        check_aws_cli
        check_aws_config
        create_cluster "$2"
        ;;
    status)
        check_aws_cli
        check_aws_config
        status
        ;;
    terminate)
        check_aws_cli
        check_aws_config
        terminate
        ;;
    download-results)
        check_aws_cli
        check_aws_config
        download_results
        ;;
    cleanup)
        check_aws_cli
        check_aws_config
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac