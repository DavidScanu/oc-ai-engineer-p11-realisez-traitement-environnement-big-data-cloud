# Résumé de la configuration AWS - Projet P11

**Date de génération** : 2025-11-18
**Compte AWS** : 461506913677
**Région** : eu-west-1 (Europe - Irlande)

---

## ✅ Configuration validée

### 🪣 Bucket S3

| Paramètre | Valeur |
|-----------|--------|
| **Nom du bucket** | `oc-p11-fruits-david-scanu` |
| **Région** | eu-west-1 |
| **Accès** | ✅ Vérifié |

### 📂 Structure S3

```
s3://oc-p11-fruits-david-scanu/
│
├── data/
│   └── raw/                           # ✅ Données d'entrée
│       ├── Training/
│       │   ├── Apple Braeburn/
│       │   │   └── 0_100.jpg
│       │   ├── Apple Crimson Snow/
│       │   └── ... (224 classes)
│       └── Test/
│           └── ... (224 classes)
│
└── read_fruits_data/                  # 📁 Dossier du projet Étape 1
    │
    ├── scripts/                       # Scripts PySpark et bootstrap
    │   ├── install_dependencies.sh
    │   └── read_fruits_data.py
    │
    ├── output/                        # Résultats des jobs
    │   └── etape_1/
    │       ├── metadata_YYYYMMDD_HHMMSS/
    │       └── stats_YYYYMMDD_HHMMSS/
    │
    └── logs/                          # Logs EMR
        └── emr/
            └── j-CLUSTERID/
                ├── node/
                ├── containers/
                └── steps/
```

### 🔑 Clés SSH EC2

| Nom de la clé | Statut |
|---------------|--------|
| `emr-p11-fruits-key-codespace` | ✅ Active (utilisée dans config) |
| `emr-p11-fruits-key` | ✅ Active (disponible) |

### 🌐 Réseau (VPC)

| Paramètre | Valeur | Zone |
|-----------|--------|------|
| **Subnet** | `subnet-037413c77aa8d5ebb` | eu-west-1c |
| **CIDR** | 172.31.32.0/20 | - |
| **Security Groups** | Créés automatiquement par EMR | - |

**Subnets disponibles** :
- `subnet-0bb5d10e55f0a8896` (eu-west-1a) - 172.31.0.0/20
- `subnet-05ed1606475d889a7` (eu-west-1b) - 172.31.16.0/20
- `subnet-037413c77aa8d5ebb` (eu-west-1c) - 172.31.32.0/20 ✅ **Utilisé**

### 👤 Rôles IAM

| Rôle | ARN | Statut |
|------|-----|--------|
| **EMR Service Role** | `arn:aws:iam::461506913677:role/EMR_DefaultRole` | ✅ Actif |
| **EMR EC2 Instance Profile** | `EMR_EC2_DefaultRole` | ✅ Actif |
| **EMR AutoScaling Role** | `arn:aws:iam::461506913677:role/EMR_AutoScaling_DefaultRole` | ✅ Actif |

**Autres rôles EMR disponibles** :
- AmazonEMRStudio_RuntimeRole_1763129307644
- AmazonEMRStudio_ServiceRole_1763129307644
- EMRStudio_Service_Role
- EMRStudio_User_Role

---

## 📋 Configuration dans config.sh

Le fichier [config/config.sh](../config/config.sh) a été mis à jour avec les valeurs suivantes :

```bash
# AWS Configuration
export AWS_REGION="eu-west-1"
export S3_BUCKET="oc-p11-fruits-david-scanu"

# Chemins S3
export S3_DATA_INPUT="s3://oc-p11-fruits-david-scanu/data/raw/"
export S3_DATA_OUTPUT="s3://oc-p11-fruits-david-scanu/read_fruits_data/output/etape_1/"
export S3_LOGS="s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/"
export S3_SCRIPTS="s3://oc-p11-fruits-david-scanu/read_fruits_data/scripts/"
export S3_CONFIG="s3://oc-p11-fruits-david-scanu/read_fruits_data/config/"

# Cluster EMR
export CLUSTER_NAME="p11-fruits-etape1"
export EMR_RELEASE="emr-7.11.0"
export MASTER_INSTANCE_TYPE="m5.xlarge"
export CORE_INSTANCE_TYPE="m5.xlarge"
export CORE_INSTANCE_COUNT="2"

# Réseau
export EC2_KEY_NAME="emr-p11-fruits-key-codespace"
export EC2_SUBNET="subnet-037413c77aa8d5ebb"

# Rôles IAM
export IAM_SERVICE_ROLE="arn:aws:iam::461506913677:role/EMR_DefaultRole"
export IAM_INSTANCE_PROFILE="EMR_EC2_DefaultRole"
export IAM_AUTOSCALING_ROLE="arn:aws:iam::461506913677:role/EMR_AutoScaling_DefaultRole"
```

---

## 🚀 Prochaines étapes

### 1. Créer les dossiers sur S3

Les dossiers seront créés automatiquement lors de l'upload des scripts, mais vous pouvez les créer manuellement si besoin :

```bash
# Créer la structure de dossiers
aws s3api put-object --bucket oc-p11-fruits-david-scanu --key read_fruits_data/config/ --region eu-west-1
aws s3api put-object --bucket oc-p11-fruits-david-scanu --key read_fruits_data/scripts/ --region eu-west-1
aws s3api put-object --bucket oc-p11-fruits-david-scanu --key read_fruits_data/output/etape_1/ --region eu-west-1
aws s3api put-object --bucket oc-p11-fruits-david-scanu --key read_fruits_data/logs/emr/ --region eu-west-1
```

### 2. Uploader les scripts

```bash
cd traitement/etape_1
./scripts/upload_scripts.sh
```

### 3. Vérifier la configuration

```bash
./scripts/verify_setup.sh
```

### 4. Créer le cluster

```bash
./scripts/create_cluster.sh
```

---

## ⚠️ Points d'attention

1. **Security Groups** : Ils seront créés automatiquement par EMR avec les noms :
   - `ElasticMapReduce-master-<timestamp>`
   - `ElasticMapReduce-slave-<timestamp>`

2. **Données d'entrée** : Le chemin `s3://oc-p11-fruits-david-scanu/data/raw/` contient :
   - ✅ Training/ (avec 224 classes de fruits)
   - Vérifier que Test/ existe aussi

3. **Nom des fichiers** : Les images ont des espaces dans les noms de dossiers (ex: "Apple Braeburn")
   - Le script PySpark gère automatiquement cela

4. **Coûts** :
   - Cluster : ~0.52€/heure
   - Stockage S3 : ~0.02€/mois (pour 1 GB)
   - **Toujours terminer le cluster après usage !**

---

## 🔒 Sécurité et conformité

- ✅ **GDPR** : Toutes les ressources dans la région eu-west-1 (Europe)
- ✅ **IAM** : Rôles préconfigurés avec les bonnes permissions
- ✅ **VPC** : Subnet isolé dans eu-west-1c
- ✅ **Encryption** : S3 utilise le chiffrement par défaut (SSE-S3)

---

## 📞 Support

En cas de problème, vérifier dans l'ordre :

1. **Configuration** : `./scripts/verify_setup.sh`
2. **Logs locaux** : Messages d'erreur dans le terminal
3. **Logs S3** : `s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/`
4. **Console AWS EMR** : https://eu-west-1.console.aws.amazon.com/emr/

---

**Dernière mise à jour** : 2025-11-18
