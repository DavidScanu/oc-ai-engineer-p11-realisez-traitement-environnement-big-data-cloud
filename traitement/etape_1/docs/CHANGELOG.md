# Changelog - Configuration AWS P11 Étape 1

## 2024-11-18 - Adaptation à l'environnement AWS de l'utilisateur

### 🔧 Modifications de configuration

#### 1. Mise à jour des chemins S3 ([config/config.sh](config/config.sh))

**Avant** :
```bash
export S3_DATA_INPUT="s3://oc-p11-fruits-david-scanu/data/fruits-360/"
export S3_DATA_OUTPUT="s3://oc-p11-fruits-david-scanu/output/etape_1/"
export S3_LOGS="s3://oc-p11-fruits-david-scanu/logs/emr/"
export S3_SCRIPTS="s3://oc-p11-fruits-david-scanu/scripts/"
export S3_CONFIG="s3://oc-p11-fruits-david-scanu/config/"
```

**Après** :
```bash
export S3_DATA_INPUT="s3://oc-p11-fruits-david-scanu/data/raw/"
export S3_DATA_OUTPUT="s3://oc-p11-fruits-david-scanu/read_fruits_data/output/etape_1/"
export S3_LOGS="s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/"
export S3_SCRIPTS="s3://oc-p11-fruits-david-scanu/read_fruits_data/scripts/"
export S3_CONFIG="s3://oc-p11-fruits-david-scanu/read_fruits_data/config/"
```

**Raison** : Adapter aux dossiers existants sur le bucket S3 de l'utilisateur

---

#### 2. Suppression des Security Groups hardcodés

**Avant** :
```bash
export MASTER_SECURITY_GROUP="sg-0ee431c02c5bc7fc4"
export SLAVE_SECURITY_GROUP="sg-03b5c1607e57d5935"
```

**Après** :
```bash
# Note: Les Security Groups seront créés automatiquement par EMR
```

**Raison** : Les Security Groups spécifiés n'existent pas. EMR créera automatiquement les Security Groups nécessaires.

---

#### 3. Simplification du script create_cluster.sh

**Avant** :
```bash
--ec2-attributes "{
  \"InstanceProfile\":\"${IAM_INSTANCE_PROFILE}\",
  \"EmrManagedMasterSecurityGroup\":\"${MASTER_SECURITY_GROUP}\",
  \"EmrManagedSlaveSecurityGroup\":\"${SLAVE_SECURITY_GROUP}\",
  \"KeyName\":\"${EC2_KEY_NAME}\",
  \"SubnetIds\":[\"${EC2_SUBNET}\"]
}" \
```

**Après** :
```bash
--ec2-attributes "{
  \"InstanceProfile\":\"${IAM_INSTANCE_PROFILE}\",
  \"KeyName\":\"${EC2_KEY_NAME}\",
  \"SubnetIds\":[\"${EC2_SUBNET}\"]
}" \
```

**Raison** : Retrait des références aux Security Groups hardcodés

---

### ✅ Configuration validée

Les éléments suivants ont été vérifiés et validés :

| Élément | Valeur | Statut |
|---------|--------|--------|
| **Compte AWS** | 461506913677 | ✅ Vérifié |
| **Région** | eu-west-1 | ✅ Conforme GDPR |
| **Bucket S3** | oc-p11-fruits-david-scanu | ✅ Existe |
| **Données d'entrée** | s3://.../data/raw/Training/ | ✅ Présentes (224 classes) |
| **Clé SSH** | emr-p11-fruits-key-codespace | ✅ Existe |
| **Subnet** | subnet-037413c77aa8d5ebb (eu-west-1c) | ✅ Existe |
| **Rôles IAM** | EMR_DefaultRole, EMR_EC2_DefaultRole, EMR_AutoScaling_DefaultRole | ✅ Existent |

---

### 📚 Nouveaux documents créés

1. **[docs/AWS_CONFIG_SUMMARY.md](docs/AWS_CONFIG_SUMMARY.md)** : Résumé complet de la configuration AWS
2. **[docs/S3_STRUCTURE.md](docs/S3_STRUCTURE.md)** : Structure détaillée des dossiers S3
3. **[CHANGELOG.md](CHANGELOG.md)** : Ce fichier (historique des modifications)

---

### 📁 Structure S3 finale

```
s3://oc-p11-fruits-david-scanu/
│
├── data/
│   └── raw/                                    # ✅ Données d'entrée existantes
│       ├── Training/
│       │   ├── Apple Braeburn/
│       │   │   └── 0_100.jpg
│       │   └── ... (224 classes)
│       └── Test/
│           └── ...
│
└── read_fruits_data/                           # 📁 Nouveau dossier du projet
    │
    ├── scripts/                                # Scripts (à créer via upload)
    │   ├── install_dependencies.sh
    │   └── read_fruits_data.py
    │
    ├── output/                                 # Résultats (créé automatiquement)
    │   └── etape_1/
    │       ├── metadata_YYYYMMDD_HHMMSS/
    │       └── stats_YYYYMMDD_HHMMSS/
    │
    └── logs/                                   # Logs (créé automatiquement)
        └── emr/
            └── j-CLUSTERID/
```

---

### 🚀 Prochaines actions

1. **Vérifier la configuration** :
   ```bash
   cd traitement/etape_1
   ./scripts/verify_setup.sh
   ```

2. **Uploader les scripts sur S3** :
   ```bash
   ./scripts/upload_scripts.sh
   ```

3. **Créer le cluster EMR** :
   ```bash
   ./scripts/create_cluster.sh
   ```

4. **Surveiller le démarrage** :
   ```bash
   ./scripts/monitor_cluster.sh
   ```

5. **Soumettre le job PySpark** :
   ```bash
   ./scripts/submit_job.sh
   ```

---

### ⚠️ Points d'attention

1. **Espaces dans les noms de fichiers** : Les dossiers dans S3 contiennent des espaces (ex: "Apple Braeburn"). Le script PySpark utilise `binaryFile` qui gère automatiquement cela.

2. **Security Groups** : EMR créera automatiquement deux security groups :
   - `ElasticMapReduce-master-<timestamp>`
   - `ElasticMapReduce-slave-<timestamp>`

3. **Coûts** : Le cluster coûte ~0.52€/heure. **Toujours le terminer après usage !**

4. **Auto-terminaison** : Configurée à 4 heures d'inactivité (14400 secondes)

---

### 📊 Résumé des commandes AWS exécutées

```bash
# Vérification du bucket S3
aws s3 ls s3://oc-p11-fruits-david-scanu/ --region eu-west-1

# Vérification des données
aws s3 ls s3://oc-p11-fruits-david-scanu/data/raw/Training/ --region eu-west-1

# Identification du compte AWS
aws sts get-caller-identity

# Liste des clés SSH
aws ec2 describe-key-pairs --region eu-west-1

# Liste des subnets
aws ec2 describe-subnets --region eu-west-1

# Liste des rôles IAM EMR
aws iam list-roles --query 'Roles[?contains(RoleName, `EMR`)].RoleName'
```

---

### 🎯 Différences avec la configuration initiale

| Paramètre | Configuration initiale | Configuration adaptée | Raison |
|-----------|----------------------|---------------------|--------|
| **Chemin input** | `data/fruits-360/` | `data/raw/` | Correspond au bucket existant |
| **Dossier projet** | Racine du bucket | `read_fruits_data/` | Isolation du projet |
| **Security Groups** | Hardcodés | Auto-créés par EMR | SGs spécifiés n'existent pas |
| **Subnet** | Inchangé | Inchangé | Validé (subnet-037413c77aa8d5ebb) |
| **Rôles IAM** | Inchangé | Inchangé | Validés (existent déjà) |

---

**Version** : 1.1
**Date** : 2024-11-18
**Responsable** : Configuration automatisée via scripts
