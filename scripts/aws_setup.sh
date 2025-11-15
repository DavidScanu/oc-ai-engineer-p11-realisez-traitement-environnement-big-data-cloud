#!/bin/bash

################################################################################
# Script Helper - Configuration et Déploiement AWS EMR
# Projet P11 - Big Data Fruits
#
# Ce script automatise les étapes de configuration AWS
# Utilisation: ./scripts/aws_setup.sh [commande]
################################################################################

set -e  # Arrêter en cas d'erreur

# Configuration centralisée
CONFIG_DIR=".aws"
CONFIG_FILE="${CONFIG_DIR}/config.env"

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

# Initialiser le fichier de configuration
init_config() {
    mkdir -p "${CONFIG_DIR}"
    if [ ! -f "${CONFIG_FILE}" ]; then
        cat > "${CONFIG_FILE}" << 'EOF'
# Configuration AWS EMR - Projet P11
# Ce fichier est généré automatiquement par scripts/aws_setup.sh
# NE PAS COMMITTER (ajouté à .gitignore)

EOF
    fi
}

# Sauvegarder une variable dans le fichier de configuration
save_config() {
    local key="$1"
    local value="$2"
    init_config

    # Supprimer l'ancienne ligne si elle existe
    sed -i "/^${key}=/d" "${CONFIG_FILE}" 2>/dev/null || true

    # Ajouter la nouvelle valeur
    echo "${key}=${value}" >> "${CONFIG_FILE}"
}

# Charger une variable depuis le fichier de configuration
load_config() {
    local key="$1"
    if [ -f "${CONFIG_FILE}" ]; then
        grep "^${key}=" "${CONFIG_FILE}" 2>/dev/null | cut -d'=' -f2-
    fi
}

# Vérifier qu'une variable existe dans la configuration
check_config() {
    local key="$1"
    local value=$(load_config "$key")
    if [ -z "$value" ]; then
        return 1
    fi
    return 0
}

# Migrer les anciens fichiers cachés vers la nouvelle configuration
migrate_old_config() {
    if [ -f ".bucket_name" ]; then
        save_config "BUCKET_NAME" "$(cat .bucket_name)"
        log_info "Migration: .bucket_name → ${CONFIG_FILE}"
    fi
    if [ -f ".cluster_id" ]; then
        save_config "CLUSTER_ID" "$(cat .cluster_id)"
        log_info "Migration: .cluster_id → ${CONFIG_FILE}"
    fi
    if [ -f ".key_name" ]; then
        save_config "KEY_NAME" "$(cat .key_name)"
        log_info "Migration: .key_name → ${CONFIG_FILE}"
    fi
    if [ -f ".master_dns" ]; then
        save_config "MASTER_DNS" "$(cat .master_dns)"
        log_info "Migration: .master_dns → ${CONFIG_FILE}"
    fi
}

# Vérifier que AWS CLI est installé
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

    # Demander le nom du bucket (ou générer un nom par défaut)
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

    # Sauvegarder le nom du bucket dans la configuration centralisée
    save_config "BUCKET_NAME" "${BUCKET_NAME}"
    save_config "REGION" "${REGION}"

    log_success "Bucket créé: s3://${BUCKET_NAME}"
    log_info "Configuration sauvegardée dans ${CONFIG_FILE}"
    echo ""
    echo "Pour uploader le dataset:"
    echo "  ./scripts/aws_setup.sh upload-dataset"
}

# Uploader le dataset
upload_dataset() {
    # Migrer les anciens fichiers si nécessaire
    migrate_old_config

    # Charger la configuration
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé. Créez d'abord le bucket avec: ./scripts/aws_setup.sh create-bucket"
        exit 1
    fi

    REGION=$(load_config "REGION")
    REGION="${REGION:-eu-west-1}"

    log_info "Upload du dataset vers s3://${BUCKET_NAME}..."
    log_warning "Cela peut prendre 10-30 minutes selon votre connexion"

    # Vérifier que le dataset existe
    if [ ! -d "data/raw/fruits-360_dataset/fruits-360/Training" ]; then
        log_error "Dataset non trouvé dans data/raw/fruits-360_dataset/"
        exit 1
    fi

    # Upload Training
    aws s3 sync data/raw/fruits-360_dataset/fruits-360/Training/ \
        s3://${BUCKET_NAME}/data/raw/Training/ \
        --region ${REGION} \
        --exclude "*.DS_Store"

    # Vérifier
    COUNT=$(aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ --recursive | wc -l)
    log_success "Upload terminé: $COUNT fichiers"

    # Afficher la taille
    aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ --recursive --human-readable --summarize | tail -2
}

# Créer une paire de clés SSH
create_keypair() {
    KEY_NAME="${1:-emr-p11-fruits-key}"
    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    log_info "Création de la paire de clés SSH: ${KEY_NAME}"

    # Vérifier si la clé existe déjà
    if [ -f ~/.ssh/${KEY_NAME}.pem ]; then
        log_warning "La clé ~/.ssh/${KEY_NAME}.pem existe déjà"
        read -p "Écraser? (y/N): " OVERWRITE
        if [ "$OVERWRITE" != "y" ]; then
            log_info "Annulé"
            return
        fi
    fi

    # Créer la clé
    aws ec2 create-key-pair \
        --key-name ${KEY_NAME} \
        --query 'KeyMaterial' \
        --output text \
        --region ${REGION} > ~/.ssh/${KEY_NAME}.pem

    # Sécuriser la clé
    chmod 400 ~/.ssh/${KEY_NAME}.pem

    # Sauvegarder le nom de la clé
    save_config "KEY_NAME" "${KEY_NAME}"

    log_success "Clé créée: ~/.ssh/${KEY_NAME}.pem"
}

# Créer le cluster EMR
create_cluster() {
    migrate_old_config
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé. Créez d'abord le bucket avec: ./scripts/aws_setup.sh create-bucket"
        exit 1
    fi

    migrate_old_config
    KEY_NAME=$(load_config "KEY_NAME")
    if [ -z "$KEY_NAME" ]; then
        log_warning "Clé SSH non trouvée. Création automatique..."
        create_keypair
    fi

    BUCKET_NAME=$(load_config "BUCKET_NAME")
    KEY_NAME=$(load_config "KEY_NAME")
    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    CLUSTER_NAME="P11-Fruits-BigData-$(date +%Y%m%d-%H%M%S)"
    EMR_RELEASE="emr-7.5.0"
    INSTANCE_TYPE="${1:-m5.xlarge}"

    log_warning "⚠️  ATTENTION: Le cluster va coûter ~2-3€/heure"
    read -p "Continuer? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Annulé"
        exit 0
    fi

    log_info "Création du cluster EMR..."
    log_info "Nom: ${CLUSTER_NAME}"
    log_info "Release: ${EMR_RELEASE}"
    log_info "Instance: ${INSTANCE_TYPE} (1 master + 2 core)"

    CLUSTER_ID=$(aws emr create-cluster \
        --name "${CLUSTER_NAME}" \
        --region ${REGION} \
        --release-label ${EMR_RELEASE} \
        --applications Name=Spark Name=JupyterHub Name=Hadoop \
        --instance-groups \
            InstanceGroupType=MASTER,InstanceCount=1,InstanceType=${INSTANCE_TYPE} \
            InstanceGroupType=CORE,InstanceCount=2,InstanceType=${INSTANCE_TYPE} \
        --ec2-attributes KeyName=${KEY_NAME} \
        --use-default-roles \
        --log-uri s3://${BUCKET_NAME}/logs/ \
        --enable-debugging \
        --configurations '[
            {
                "Classification": "spark",
                "Properties": {
                    "maximizeResourceAllocation": "true"
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
    echo "  ./scripts/aws_setup.sh status"
    echo ""
    echo "Pour se connecter une fois prêt:"
    echo "  ./scripts/aws_setup.sh connect"
}

# Afficher le statut du cluster
status() {
    migrate_old_config
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -z "$CLUSTER_ID" ]; then
        log_error "Cluster ID non trouvé. Créez d'abord un cluster."
        exit 1
    fi

    CLUSTER_ID=$(load_config "CLUSTER_ID")

    STATE=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State' --output text)

    echo ""
    log_info "Cluster ID: ${CLUSTER_ID}"

    case "$STATE" in
        "WAITING")
            log_success "État: ${STATE} - Prêt à recevoir des jobs ✓"
            echo ""
            echo "Pour vous connecter:"
            echo "  ./scripts/aws_setup.sh connect"
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
    echo ""
}

# Se connecter au cluster
connect() {
    migrate_old_config
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -z "$CLUSTER_ID" ]; then
        log_error "Cluster ID non trouvé"
        exit 1
    fi

    migrate_old_config
    KEY_NAME=$(load_config "KEY_NAME")
    if [ -z "$KEY_NAME" ]; then
        log_error "Clé SSH non trouvée"
        exit 1
    fi

    CLUSTER_ID=$(load_config "CLUSTER_ID")
    KEY_NAME=$(load_config "KEY_NAME")
    REGION=$(load_config "REGION")
    REGION="${REGION:-eu-west-1}"

    # Vérifier l'état du cluster
    STATE=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State' --output text)

    if [ "$STATE" != "WAITING" ] && [ "$STATE" != "RUNNING" ]; then
        log_error "Le cluster n'est pas prêt. État actuel: ${STATE}"
        exit 1
    fi

    # Récupérer le DNS du master et le security group
    MASTER_DNS=$(aws emr describe-cluster \
        --cluster-id ${CLUSTER_ID} \
        --query 'Cluster.MasterPublicDnsName' \
        --output text)

    SECURITY_GROUP=$(aws emr describe-cluster \
        --cluster-id ${CLUSTER_ID} \
        --query 'Cluster.Ec2InstanceAttributes.EmrManagedMasterSecurityGroup' \
        --output text)

    save_config "MASTER_DNS" "${MASTER_DNS}"

    log_success "Master DNS: ${MASTER_DNS}"

    # Vérifier et configurer l'accès SSH
    log_info "Vérification de l'accès SSH..."

    # Récupérer l'IP publique
    MY_IP=$(curl -s https://checkip.amazonaws.com)

    # Vérifier si la règle SSH existe déjà
    EXISTING_RULE=$(aws ec2 describe-security-groups \
        --group-ids ${SECURITY_GROUP} \
        --region ${REGION} \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\`].IpRanges[?CidrIp==\`${MY_IP}/32\`]" \
        --output text 2>/dev/null)

    if [ -z "$EXISTING_RULE" ]; then
        log_warning "Ajout de votre IP (${MY_IP}) au Security Group..."
        aws ec2 authorize-security-group-ingress \
            --group-id ${SECURITY_GROUP} \
            --protocol tcp \
            --port 22 \
            --cidr ${MY_IP}/32 \
            --region ${REGION} 2>/dev/null || log_warning "La règle SSH existe peut-être déjà"
        log_success "Accès SSH autorisé"
    else
        log_success "Accès SSH déjà configuré"
    fi

    echo ""
    log_info "Création du tunnel SSH vers JupyterHub..."
    echo ""
    echo "⚠️  Ce terminal va rester bloqué (tunnel actif)"
    echo "   Pour accéder à JupyterHub: https://localhost:9443"
    echo "   Username: jovyan"
    echo "   Password: jupyter"
    echo ""
    echo "Appuyez sur Ctrl+C pour arrêter le tunnel"
    echo ""

    # Créer le tunnel SSH
    ssh -i ~/.ssh/${KEY_NAME}.pem \
        -o StrictHostKeyChecking=no \
        -N -L 9443:${MASTER_DNS}:9443 \
        hadoop@${MASTER_DNS}
}

# Arrêter le cluster
terminate() {
    migrate_old_config
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -z "$CLUSTER_ID" ]; then
        log_error "Cluster ID non trouvé"
        exit 1
    fi

    CLUSTER_ID=$(load_config "CLUSTER_ID")

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
    echo "  ./scripts/aws_setup.sh status"
}

# Télécharger les résultats
download_results() {
    migrate_old_config
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket non trouvé"
        exit 1
    fi

    BUCKET_NAME=$(load_config "BUCKET_NAME")
    REGION="${AWS_DEFAULT_REGION:-eu-west-1}"

    log_info "Téléchargement des résultats depuis s3://${BUCKET_NAME}..."

    # Créer les dossiers locaux
    mkdir -p data/emr_output/features
    mkdir -p data/emr_output/pca

    # Télécharger features
    log_info "Téléchargement des features..."
    aws s3 sync s3://${BUCKET_NAME}/data/features/ \
        data/emr_output/features/ \
        --region ${REGION}

    # Télécharger PCA
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
    echo "  - Supprimer le bucket S3 et toutes les données"
    echo "  - Supprimer la paire de clés SSH"
    echo "  - Supprimer le fichier de configuration local"
    echo ""
    read -p "Confirmer le nettoyage? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Annulé"
        exit 0
    fi

    # Migrer les anciens fichiers si nécessaire
    migrate_old_config

    # Arrêter le cluster si actif
    CLUSTER_ID=$(load_config "CLUSTER_ID")
    if [ -n "$CLUSTER_ID" ]; then
        log_info "Arrêt du cluster ${CLUSTER_ID}..."
        aws emr terminate-clusters --cluster-ids ${CLUSTER_ID} || true
    fi

    # Supprimer le bucket S3
    BUCKET_NAME=$(load_config "BUCKET_NAME")
    if [ -n "$BUCKET_NAME" ]; then
        log_info "Suppression du bucket s3://${BUCKET_NAME}..."
        aws s3 rm s3://${BUCKET_NAME}/ --recursive || true
        aws s3 rb s3://${BUCKET_NAME} || true
    fi

    # Supprimer la clé SSH AWS
    KEY_NAME=$(load_config "KEY_NAME")
    if [ -n "$KEY_NAME" ]; then
        REGION=$(load_config "REGION")
        REGION="${REGION:-eu-west-1}"
        log_info "Suppression de la clé SSH ${KEY_NAME} sur AWS..."
        aws ec2 delete-key-pair --key-name ${KEY_NAME} --region ${REGION} || true

        # Supprimer aussi la clé locale
        if [ -f ~/.ssh/${KEY_NAME}.pem ]; then
            log_info "Suppression de la clé locale ~/.ssh/${KEY_NAME}.pem..."
            rm -f ~/.ssh/${KEY_NAME}.pem
        fi
    fi

    # Supprimer le fichier de configuration
    if [ -f "${CONFIG_FILE}" ]; then
        log_info "Suppression du fichier de configuration ${CONFIG_FILE}..."
        rm -f "${CONFIG_FILE}"
    fi

    # Supprimer les anciens fichiers cachés (pour compatibilité)
    rm -f .bucket_name .cluster_id .key_name .master_dns

    log_success "Nettoyage terminé"
}

# Menu d'aide
show_help() {
    echo ""
    echo "Script Helper - AWS EMR pour Projet P11"
    echo ""
    echo "Usage: ./scripts/aws_setup.sh [commande]"
    echo ""
    echo "Commandes disponibles:"
    echo ""
    echo "  Configuration initiale:"
    echo "    create-bucket          Créer le bucket S3"
    echo "    upload-dataset         Uploader le dataset sur S3"
    echo "    create-keypair [nom]   Créer une paire de clés SSH"
    echo ""
    echo "  Gestion du cluster:"
    echo "    create-cluster [type]  Créer le cluster EMR (défaut: m5.xlarge)"
    echo "    status                 Afficher le statut du cluster"
    echo "    connect                Se connecter au cluster (tunnel SSH)"
    echo "    terminate              Arrêter le cluster"
    echo ""
    echo "  Récupération des résultats:"
    echo "    download-results       Télécharger les résultats depuis S3"
    echo ""
    echo "  Nettoyage:"
    echo "    cleanup                Tout nettoyer (cluster + S3 + clés)"
    echo ""
    echo "  Utilitaires:"
    echo "    check                  Vérifier la configuration AWS"
    echo "    help                   Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  ./scripts/aws_setup.sh create-bucket"
    echo "  ./scripts/aws_setup.sh upload-dataset"
    echo "  ./scripts/aws_setup.sh create-cluster m5.xlarge"
    echo "  ./scripts/aws_setup.sh status"
    echo "  ./scripts/aws_setup.sh connect"
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
    create-keypair)
        check_aws_cli
        check_aws_config
        create_keypair "$2"
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
    connect)
        check_aws_cli
        check_aws_config
        connect
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