# Étape 2 : Feature Extraction + PCA avec AWS EMR

## 📋 Vue d'ensemble

Cette étape implémente un pipeline PySpark distribué pour:
1. **Extraire des features** des images de fruits avec **MobileNetV2** (Transfer Learning)
2. **Réduire les dimensions** avec **PCA** (1280 → 50 composantes)
3. **Sauvegarder les résultats** sur S3 (Parquet + CSV)

### Architecture

```
┌─────────────┐
│   Images    │  S3: s3://bucket/data/raw/Training/
│   JPG       │  ~67,000 images de fruits (100x100px)
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│     AWS EMR Cluster (PySpark)           │
│  ┌────────────────────────────────────┐ │
│  │  MobileNetV2 (Broadcast Weights)   │ │  Features: 1280D
│  │  → Pandas UDF (distributed)        │ │
│  └────────────┬───────────────────────┘ │
│               ▼                          │
│  ┌────────────────────────────────────┐ │
│  │  PCA (PySpark MLlib)               │ │  Reduced: 50D
│  │  → Variance Analysis               │ │
│  └────────────┬───────────────────────┘ │
└───────────────┼──────────────────────────┘
                │
                ▼
      ┌─────────────────┐
      │  S3 Output      │  s3://bucket/process_fruits_data/output/
      │  - features/    │  (1280D: Parquet + CSV)
      │  - pca/         │  (50D: Parquet + CSV)
      │  - metadata/    │  (path, label)
      │  - model_info/  │  (variance, stats)
      │  - errors/      │  (rapport d'erreurs)
      └─────────────────┘
```

---

## 🚀 Démarrage rapide

### Prérequis

- AWS CLI configuré avec credentials valides
- Accès S3 au bucket: `oc-p11-fruits-david-scanu`
- Clé SSH EMR: `emr-p11-fruits-key-codespace`
- Région AWS: `eu-west-1` (GDPR)

### Workflow complet (5 étapes)

```bash
cd traitement/etape_2

# 1. Vérifier la configuration
./scripts/verify_setup.sh

# 2. Uploader les scripts sur S3
./scripts/upload_scripts.sh

# 3. Créer le cluster EMR (~10-15 min)
./scripts/create_cluster.sh

# 4. Surveiller le démarrage (optionnel)
./scripts/monitor_cluster.sh

# 5. Soumettre le job PySpark
./scripts/submit_job.sh
# → Choisir le mode: mini (300 images) / apples (~6,400) / full (~67,000)

# 6. Télécharger les résultats
./scripts/download_results.sh

# 7. Arrêter le cluster (IMPORTANT pour les coûts !)
./scripts/terminate_cluster.sh
```

---

## ⚙️ Configuration

### Fichier: [config/config.sh](../config/config.sh)

Variables clés:

```bash
# S3
S3_BUCKET="oc-p11-fruits-david-scanu"
S3_DATA_INPUT="s3://${S3_BUCKET}/data/raw/"
S3_DATA_OUTPUT="s3://${S3_BUCKET}/process_fruits_data/output/"

# EMR Cluster
CLUSTER_NAME="p11-fruits-etape2"
MASTER_INSTANCE_TYPE="m5.2xlarge"   # 8 vCPU, 32 GB RAM
CORE_INSTANCE_TYPE="m5.2xlarge"
CORE_INSTANCE_COUNT="2"

# Spark Memory
SPARK_EXECUTOR_MEMORY="8g"
SPARK_DRIVER_MEMORY="8g"

# PCA
PCA_COMPONENTS="50"
DEFAULT_MODE="mini"
MINI_IMAGES_COUNT="300"
```

---

## 📂 Structure des outputs S3

```
s3://oc-p11-fruits-david-scanu/process_fruits_data/output/
├── features/
│   ├── parquet/features_YYYYMMDD_HHMMSS/    # Features 1280D (Parquet)
│   └── csv/features_YYYYMMDD_HHMMSS/        # Features 1280D (CSV)
├── pca/
│   ├── parquet/pca_YYYYMMDD_HHMMSS/         # PCA 50D (Parquet)
│   └── csv/pca_YYYYMMDD_HHMMSS/             # PCA 50D (CSV)
├── metadata/metadata_YYYYMMDD_HHMMSS/       # path, label
├── model_info/
│   ├── model_info_YYYYMMDD_HHMMSS/          # JSON: variance, stats
│   └── variance_YYYYMMDD_HHMMSS/            # CSV: variance par composante
└── errors/errors_YYYYMMDD_HHMMSS/           # Rapport d'erreurs (si présent)
```

---

## 🎯 Modes de traitement

| Mode   | Images     | Classes       | Durée estimée | Usage                      |
|--------|------------|---------------|---------------|----------------------------|
| **mini**   | 300        | Pommes (3-4)  | 2-5 min       | Tests rapides, validation  |
| **apples** | ~6,400     | Pommes (~29)  | 15-30 min     | Tests intermédiaires       |
| **full**   | ~67,000    | Tous (224)    | 2-3 heures    | Production complète        |

---

## 💰 Coûts AWS

### Cluster EMR (m5.2xlarge)

- **1 Master** : ~0.384 $/h
- **2 Core** : ~0.768 $/h
- **Total** : ~1.15 $/h (≈ 0.80-1.00 €/h)

### Auto-terminaison

- **Timeout** : 4 heures d'inactivité
- **Important** : Toujours terminer manuellement après usage !

```bash
./scripts/terminate_cluster.sh
```

---

## 📊 Pipeline PySpark

### 1. Chargement des images

```python
df_images = spark.read.format("binaryFile").load(s3_path)
```

### 2. Extraction des features (MobileNetV2)

```python
# Broadcast des poids du modèle
model_weights = model.get_weights()
broadcast_weights = sc.broadcast(model_weights)

# Pandas UDF pour extraction distribuée
@pandas_udf(ArrayType(FloatType()))
def extract_features_udf(content_series: pd.Series) -> pd.Series:
    local_model = MobileNetV2(weights=None, include_top=False, pooling='avg')
    local_model.set_weights(broadcast_weights.value)
    # Process images...
    return features
```

### 3. PCA (PySpark MLlib)

```python
from pyspark.ml.feature import PCA

pca = PCA(k=50, inputCol="features_vector", outputCol="pca_features")
pca_model = pca.fit(df_features)
df_pca = pca_model.transform(df_features)
```

### 4. Sauvegarde multi-format

- **Parquet** : Format optimisé pour big data
- **CSV** : Lisibilité et compatibilité

---

## 🔍 Scripts disponibles

| Script                            | Description                                      |
|-----------------------------------|--------------------------------------------------|
| `verify_setup.sh`                 | Vérifications pré-vol (AWS, S3, IAM, SSH)       |
| `upload_scripts.sh`               | Upload des scripts sur S3                        |
| `create_cluster.sh`               | Création du cluster EMR                          |
| `monitor_cluster.sh`              | Surveillance du démarrage (STARTING → WAITING)   |
| `submit_job.sh`                   | Soumission du job PySpark (choix du mode)        |
| `download_results.sh`             | Téléchargement des résultats depuis S3           |
| `download_and_inspect_logs.sh`    | Téléchargement et inspection des logs EMR        |
| `terminate_cluster.sh`            | Arrêt du cluster                                 |
| `cleanup.sh`                      | Nettoyage complet (cluster + S3 + fichiers)      |

---

## 🐛 Troubleshooting

### Le cluster ne démarre pas

```bash
# Vérifier l'état
aws emr describe-cluster --cluster-id j-XXXXXXXXXXXX --region eu-west-1

# Vérifier les logs
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/
```

### Le job échoue

```bash
# Télécharger et inspecter les logs
./scripts/download_and_inspect_logs.sh

# Vérifier stderr
cat logs/stderr | grep -i "error"
```

### Problèmes TensorFlow

```bash
# Vérifier l'installation dans les logs bootstrap
aws s3 ls s3://bucket/process_fruits_data/logs/emr/j-XXXX/node/*/bootstrap-actions/
```

### Coûts élevés

```bash
# Vérifier les instances EC2 actives
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" \
  --output table

# Terminer le cluster immédiatement
./scripts/terminate_cluster.sh
```

---

## 📚 Documentation complète

- **[WORKFLOW.md](WORKFLOW.md)** : Workflow détaillé étape par étape
- **[ARCHITECTURE.md](ARCHITECTURE.md)** : Architecture technique complète

---

## 🎓 Points clés du projet

### ✅ Optimisations Big Data

1. **Broadcast des poids** : Distribution efficace du modèle TensorFlow
2. **Pandas UDF** : Traitement distribué avec Arrow serialization
3. **PySpark MLlib** : PCA scalable sur cluster
4. **Multi-format** : Parquet (performance) + CSV (lisibilité)

### ✅ Conformité GDPR

- Région AWS: `eu-west-1` (Irlande)
- Toutes les données restent en Europe

### ✅ Gestion des coûts

- Auto-terminaison (4h idle)
- Alertes de coûts
- Scripts de nettoyage

---

## 📞 Support

### Vérifier la configuration

```bash
./scripts/verify_setup.sh
```

### Voir la configuration actuelle

```bash
source config/config.sh
show_config
```

### Logs AWS EMR

```bash
# Console web
https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1

# Logs S3
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/ --recursive
```

---

## 🏆 Résultats attendus

Après exécution complète (mode `full`):

- **Features brutes** : ~67,000 images × 1280 dimensions
- **Features PCA** : ~67,000 images × 50 dimensions
- **Variance expliquée** : Information dans `model_info/`
- **Taux d'erreur** : < 1% (images corrompues/invalides)

---

**Projet** : OpenClassrooms AI Engineer P11
**Environnement** : AWS EMR 7.11.0, Spark 3.x, TensorFlow 2.16.1
**Dataset** : Fruits-360 (Kaggle)
