#!/bin/bash
# Configuration centralisée pour le projet P11 - Étape 1

# ==========================================
# CONFIGURATION AWS
# ==========================================

# Région (OBLIGATOIRE: zone européenne pour GDPR)
export AWS_REGION="eu-west-1"

# Bucket S3 principal
export S3_BUCKET="oc-p11-fruits-david-scanu"

# Chemins S3
export S3_DATA_INPUT="s3://${S3_BUCKET}/data/raw/"
export S3_DATA_OUTPUT="s3://${S3_BUCKET}/read_fruits_data/output/etape_1/"
export S3_LOGS="s3://${S3_BUCKET}/read_fruits_data/logs/emr/"
export S3_SCRIPTS="s3://${S3_BUCKET}/read_fruits_data/scripts/"
export S3_CONFIG="s3://${S3_BUCKET}/read_fruits_data/config/"

# ==========================================
# CONFIGURATION EMR CLUSTER
# ==========================================

# Nom du cluster
export CLUSTER_NAME="p11-fruits-etape1"

# Version EMR
export EMR_RELEASE="emr-7.11.0"

# Type d'instances (coût réduit pour tests)
export MASTER_INSTANCE_TYPE="m5.xlarge"
export CORE_INSTANCE_TYPE="m5.xlarge"
export CORE_INSTANCE_COUNT="2"

# Stockage EBS par instance (GB)
export EBS_VOLUME_SIZE="32"

# ==========================================
# CONFIGURATION RÉSEAU
# ==========================================

# Clé SSH
export EC2_KEY_NAME="emr-p11-fruits-key-codespace"

# Subnet (VPC eu-west-1c)
export EC2_SUBNET="subnet-037413c77aa8d5ebb"

# Note: Les Security Groups seront créés automatiquement par EMR

# ==========================================
# RÔLES IAM
# ==========================================

export IAM_SERVICE_ROLE="arn:aws:iam::461506913677:role/EMR_DefaultRole"
export IAM_INSTANCE_PROFILE="EMR_EC2_DefaultRole"
export IAM_AUTOSCALING_ROLE="arn:aws:iam::461506913677:role/EMR_AutoScaling_DefaultRole"

# ==========================================
# CONFIGURATION SPARK
# ==========================================

export SPARK_EXECUTOR_MEMORY="4g"
export SPARK_DRIVER_MEMORY="4g"
export SPARK_EXECUTOR_MEMORY_OVERHEAD="1g"

# ==========================================
# TIMEOUTS ET LIMITES
# ==========================================

# Auto-terminaison après inactivité (secondes) - 4 heures
export IDLE_TIMEOUT="14400"

# Timeout pour attendre que le cluster soit prêt (secondes) - 20 minutes
export CLUSTER_READY_TIMEOUT="1200"

# ==========================================
# AFFICHAGE DE LA CONFIGURATION
# ==========================================

show_config() {
    echo "=================================================="
    echo "📋 CONFIGURATION P11 - ÉTAPE 1"
    echo "=================================================="
    echo "🌍 Région AWS: ${AWS_REGION}"
    echo "🪣 Bucket S3: ${S3_BUCKET}"
    echo "📂 Input data: ${S3_DATA_INPUT}"
    echo "📂 Output: ${S3_DATA_OUTPUT}"
    echo "🖥️  Cluster: ${CLUSTER_NAME}"
    echo "📦 EMR Release: ${EMR_RELEASE}"
    echo "💻 Master: ${MASTER_INSTANCE_TYPE}"
    echo "💻 Core: ${CORE_INSTANCE_COUNT}x ${CORE_INSTANCE_TYPE}"
    echo "=================================================="
}
