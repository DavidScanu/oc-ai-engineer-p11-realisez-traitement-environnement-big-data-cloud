# Étape 1 : Lecture et indexation du dataset Fruits-360 avec PySpark sur AWS EMR

## 📋 Objectifs

Cette première étape valide la mise en place de l'infrastructure Big Data sur AWS :

1. **Lire les données depuis S3** : Charger le dataset Fruits-360 (images JPG)
2. **Créer un DataFrame PySpark** : Générer un index avec métadonnées (nom fichier, chemin S3, label, etc.)
3. **Sauvegarder en CSV sur S3** : Écrire les résultats traités
4. **Valider l'environnement** :
   - Installation correcte des packages Python via bootstrap action
   - Lecture/écriture S3 fonctionnelle
   - Exécution PySpark distribuée sur EMR

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud (eu-west-1)               │
│                                                             │
│  ┌──────────────┐         ┌─────────────────────────────┐  │
│  │              │         │     EMR Cluster             │  │
│  │   S3 Bucket  │◄────────┤                             │  │
│  │              │         │  Master (m5.xlarge)         │  │
│  │  - Input:    │         │  Core x2 (m5.xlarge)        │  │
│  │    Images    │         │                             │  │
│  │  - Scripts   │────────►│  Spark 3.x + PySpark        │  │
│  │  - Output:   │         │  + Bootstrap (Python deps)  │  │
│  │    CSV       │         └─────────────────────────────┘  │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Structure du projet

```
traitement/etape_1/
├── config/
│   ├── config.sh              # Configuration centralisée (S3, EMR, réseau)
│
├── scripts/
│   ├── install_dependencies.sh   # Bootstrap action (installation packages)
│   ├── read_fruits_data.py       # Script PySpark principal
│   ├── create_cluster.sh         # Création du cluster EMR
│   ├── monitor_cluster.sh        # Surveillance de l'état du cluster
│   ├── upload_scripts.sh         # Upload des scripts sur S3
│   ├── verify_setup.sh           # Vérification de la configuration
│   ├── submit_job.sh             # Soumission du job PySpark (step)
│   ├── terminate_cluster.sh      # Terminaison du cluster
│   └── cleanup.sh                # Nettoyage complet des ressources
│
├── docs/
│   └── (documentation supplémentaire)
│
├── cluster_id.txt    # Généré automatiquement (ID du cluster)
├── step_id.txt       # Généré automatiquement (ID du job)
└── README.md         # Ce fichier
```

## ⚙️ Configuration

### 1. Éditer la configuration

Ouvrir [config/config.sh](config/config.sh) et adapter les valeurs suivantes :

```bash
# À MODIFIER selon votre environnement AWS
export S3_BUCKET="votre-bucket-s3"
export EC2_KEY_NAME="votre-cle-ssh"
export MASTER_SECURITY_GROUP="sg-xxxxxxxxx"
export SLAVE_SECURITY_GROUP="sg-xxxxxxxxx"
export EC2_SUBNET="subnet-xxxxxxxxx"

# Rôles IAM (ARNs complets)
export IAM_SERVICE_ROLE="arn:aws:iam::ACCOUNT_ID:role/EMR_DefaultRole"
export IAM_INSTANCE_PROFILE="EMR_EC2_DefaultRole"
export IAM_AUTOSCALING_ROLE="arn:aws:iam::ACCOUNT_ID:role/EMR_AutoScaling_DefaultRole"
```

**Important** :
- La région par défaut est `eu-west-1` (conformité GDPR)
- Pour créer les rôles IAM par défaut : `aws emr create-default-roles`

### 2. Préparer les données

Uploader le dataset Fruits-360 sur S3 :

```bash
# Télécharger le dataset (si nécessaire)
wget https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip
unzip fruits.zip

# Uploader vers S3
aws s3 sync fruits/ s3://votre-bucket/data/fruits-360/ --region eu-west-1
```

Structure attendue sur S3 :
```
s3://votre-bucket/data/fruits-360/
├── Training/
│   ├── Apple_Braeburn/
│   │   ├── image_001_100.jpg
│   │   └── ...
│   ├── Banana/
│   └── ...
└── Test/
    ├── Apple_Braeburn/
    └── ...
```

## 🚀 Utilisation

### Workflow complet

#### 1️⃣ Vérifier la configuration

```bash
cd traitement/etape_1
chmod +x scripts/*.sh
./scripts/verify_setup.sh
```

Ce script vérifie :
- ✅ Région AWS (Europe pour GDPR)
- ✅ Credentials AWS configurés
- ✅ Bucket S3 existe
- ✅ Données d'entrée présentes
- ✅ Clé SSH existe
- ✅ Rôles IAM configurés

#### 2️⃣ Uploader les scripts sur S3

```bash
./scripts/upload_scripts.sh
```

Upload :
- `install_dependencies.sh` → `s3://bucket/scripts/`
- `read_fruits_data.py` → `s3://bucket/scripts/`

#### 3️⃣ Créer le cluster EMR

```bash
./scripts/create_cluster.sh
```

Cette commande :
- Crée un cluster EMR 7.11.0 avec Spark
- Configure 1 Master + 2 Core (m5.xlarge)
- Exécute le bootstrap action (installation Python)
- Active l'auto-terminaison après 4h d'inactivité
- Sauvegarde le Cluster ID dans `cluster_id.txt`

**Coût estimé** : ~0.50€/heure

#### 4️⃣ Surveiller le démarrage du cluster

```bash
./scripts/monitor_cluster.sh
```

Affiche l'état en temps réel :
- 🟡 STARTING → Démarrage EC2
- 🟡 BOOTSTRAPPING → Installation dépendances Python
- 🟢 RUNNING → Configuration Spark
- ✅ WAITING → Prêt à recevoir des jobs

**Durée** : 10-15 minutes

#### 5️⃣ Soumettre le job PySpark

Une fois le cluster en état `WAITING` :

```bash
./scripts/submit_job.sh
```

Cette commande :
- Vérifie que le cluster est prêt
- Soumet un step PySpark avec `spark-submit`
- Sauvegarde le Step ID dans `step_id.txt`

#### 6️⃣ Surveiller l'exécution du job

```bash
# Surveillance continue
watch -n 10 'aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query "Step.Status.State" --output text'

# Vérification ponctuelle
aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1
```

**Durée** : 2-5 minutes

#### 7️⃣ Récupérer les résultats

```bash
# Lister les résultats
aws s3 ls s3://votre-bucket/output/etape_1/ --recursive --region eu-west-1

# Télécharger les CSV
aws s3 cp s3://votre-bucket/output/etape_1/ ./results/ --recursive --region eu-west-1
```

Fichiers générés :
- `metadata_YYYYMMDD_HHMMSS/` : DataFrame avec toutes les images (chemin S3, label, taille, etc.)
- `stats_YYYYMMDD_HHMMSS/` : Statistiques par classe (Training/Test)

#### 8️⃣ Terminer le cluster

```bash
./scripts/terminate_cluster.sh
```

**⚠️ IMPORTANT** : Toujours terminer le cluster pour éviter des coûts inutiles !

### 🧹 Nettoyage complet

Pour nettoyer toutes les ressources (cluster + données + logs) :

```bash
./scripts/cleanup.sh
```

Ce script interactif propose de supprimer :
- Le cluster EMR (si actif)
- Les données de sortie sur S3
- Les logs EMR sur S3
- Les fichiers de tracking locaux (`cluster_id.txt`, etc.)

## 📊 Script PySpark : `read_fruits_data.py`

### Fonctionnement

1. **Lecture des images** : Utilise `binaryFile` pour lire tous les `.jpg` récursivement depuis S3
2. **Extraction des métadonnées** : Regex pour extraire label, split (Training/Test), nom de fichier
3. **Calcul de statistiques** : Comptage par classe et par split
4. **Sauvegarde en CSV** : Coalesce + write en mode overwrite

### Schéma du DataFrame de sortie

| Colonne            | Type      | Description                                  |
|--------------------|-----------|----------------------------------------------|
| `s3_path`          | String    | Chemin complet S3 de l'image                 |
| `label`            | String    | Nom de la classe (ex: "Apple_Braeburn")      |
| `filename`         | String    | Nom du fichier (ex: "image_001_100.jpg")     |
| `split`            | String    | "Training" ou "Test"                         |
| `modification_time`| Timestamp | Date de dernière modification                |
| `file_size_bytes`  | Long      | Taille du fichier en octets                  |

### Exemple de sortie

```
+------------------------------------------------+---------------+--------------------+--------+-------------------+----------------+
|s3_path                                         |label          |filename            |split   |modification_time  |file_size_bytes |
+------------------------------------------------+---------------+--------------------+--------+-------------------+----------------+
|s3://.../Training/Apple_Braeburn/image_001_100.jpg|Apple_Braeburn|image_001_100.jpg   |Training|2025-01-15 10:23:45|5432            |
|s3://.../Training/Apple_Braeburn/image_002_100.jpg|Apple_Braeburn|image_002_100.jpg   |Training|2025-01-15 10:23:45|5621            |
|s3://.../Test/Banana/r_image_042_100.jpg        |Banana         |r_image_042_100.jpg |Test    |2025-01-15 10:24:12|4892            |
+------------------------------------------------+---------------+--------------------+--------+-------------------+----------------+
```

## 🔧 Dépannage

### Problème : Cluster ne démarre pas (TERMINATED_WITH_ERRORS)

**Causes fréquentes** :
1. Bootstrap action échoue → Vérifier les logs dans `s3://bucket/logs/emr/`
2. Rôles IAM incorrects → Vérifier `config.sh` et les permissions
3. Subnet/Security Groups incompatibles → Vérifier la configuration réseau

**Solution** :
```bash
# Consulter les logs détaillés
aws emr describe-cluster --cluster-id $(cat cluster_id.txt) --region eu-west-1

# Logs du bootstrap
aws s3 ls s3://bucket/logs/emr/ --recursive | grep bootstrap
```

### Problème : Job PySpark échoue

**Vérifier les logs** :
```bash
# Logs du step
aws s3 ls s3://bucket/logs/emr/containers/ --recursive | grep $(cat step_id.txt)

# Télécharger les logs
aws s3 cp s3://bucket/logs/emr/containers/ ./logs/ --recursive
```

**Erreurs courantes** :
- `FileNotFoundError` : Vérifier que les données sont bien sur S3
- `ImportError` : Package Python manquant → Vérifier `install_dependencies.sh`
- `PermissionDenied` : Problème IAM → Vérifier le rôle `EMR_EC2_DefaultRole`

### Problème : Coûts élevés

**Vérifier les instances en cours** :
```bash
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

**Terminer toutes les instances EMR** :
```bash
# Lister tous les clusters actifs
aws emr list-clusters --active --region eu-west-1

# Terminer un cluster spécifique
aws emr terminate-clusters --cluster-ids j-XXXXXXXXXXXXX --region eu-west-1
```

## 📈 Prochaines étapes

Après validation de cette étape :

1. **Étape 2** : Extraction de features avec TensorFlow (MobileNetV2)
2. **Étape 3** : Broadcast des poids du modèle TensorFlow
3. **Étape 4** : PCA (réduction de dimensionnalité) en PySpark

## 📚 Ressources

- [Documentation AWS EMR](https://docs.aws.amazon.com/emr/)
- [Guide PySpark](https://spark.apache.org/docs/latest/api/python/)
- [Dataset Fruits-360](https://www.kaggle.com/datasets/moltean/fruits)
- [AWS EMR Getting Started](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-gs.html)

## 🔒 Conformité GDPR

- ✅ Région AWS Europe (`eu-west-1`)
- ✅ Stockage S3 en Europe
- ✅ Instances EMR en Europe
- ✅ Pas de transfert de données hors UE

## 📝 Notes importantes

1. **Auto-terminaison** : Le cluster s'arrête automatiquement après 4h d'inactivité
2. **Coûts** : ~0.50€/heure pour la configuration actuelle (1 Master + 2 Core m5.xlarge)
3. **Sécurité** : Ne jamais commiter de credentials AWS dans Git
4. **Logs** : Toujours activer les logs EMR pour faciliter le debugging

## ❓ Support

En cas de problème, vérifier dans l'ordre :

1. `./scripts/verify_setup.sh` → Configuration correcte ?
2. Logs EMR → `s3://bucket/logs/emr/`
3. Console AWS EMR → État détaillé du cluster
4. Documentation AWS → Messages d'erreur spécifiques
