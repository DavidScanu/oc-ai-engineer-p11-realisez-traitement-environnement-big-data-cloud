# Architecture Technique - Étape 2

Ce document décrit l'architecture technique détaillée du pipeline de feature extraction et PCA sur AWS EMR.

---

## 📋 Table des matières

1. [Architecture globale](#1-architecture-globale)
2. [Infrastructure AWS](#2-infrastructure-aws)
3. [Pipeline PySpark](#3-pipeline-pyspark)
4. [Optimisations Big Data](#4-optimisations-big-data)
5. [Formats de données](#5-formats-de-données)
6. [Gestion des erreurs](#6-gestion-des-erreurs)

---

## 1. Architecture globale

### 1.1 Vue d'ensemble

```
┌──────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (eu-west-1)                    │
│                                                                   │
│  ┌────────────────────┐                                          │
│  │   S3 Bucket        │                                          │
│  │   oc-p11-fruits    │                                          │
│  ├────────────────────┤                                          │
│  │ /data/raw/         │ ← Input : ~67,000 images JPG            │
│  │   Training/        │   (100x100px, RGB)                       │
│  │     Apple*/        │                                          │
│  │     Banana*/       │                                          │
│  │     ...            │                                          │
│  └─────────┬──────────┘                                          │
│            │                                                      │
│            ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │           EMR Cluster (Spark 3.x)                       │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │    │
│  │  │   Master     │  │    Core 1    │  │    Core 2    │  │    │
│  │  │  m5.2xlarge  │  │  m5.2xlarge  │  │  m5.2xlarge  │  │    │
│  │  │  8 vCPU      │  │  8 vCPU      │  │  8 vCPU      │  │    │
│  │  │  32 GB RAM   │  │  32 GB RAM   │  │  32 GB RAM   │  │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │    │
│  │         │                 │                 │           │    │
│  │         └─────────────────┴─────────────────┘           │    │
│  │                      YARN                                │    │
│  │                                                          │    │
│  │  ┌────────────────────────────────────────────────┐    │    │
│  │  │  PySpark Application                           │    │    │
│  │  │                                                 │    │    │
│  │  │  1. Load Images (binaryFile)                   │    │    │
│  │  │  2. Extract Features (MobileNetV2 broadcast)   │    │    │
│  │  │  3. Apply PCA (MLlib)                          │    │    │
│  │  │  4. Save Results (Parquet + CSV)               │    │    │
│  │  └────────────────────────────────────────────────┘    │    │
│  └──────────────────────────┬───────────────────────────────┘    │
│                             │                                     │
│                             ▼                                     │
│  ┌────────────────────────────────────────┐                      │
│  │   S3 Bucket (Output)                   │                      │
│  │   /process_fruits_data/output/         │                      │
│  ├────────────────────────────────────────┤                      │
│  │ /features/parquet/  (1280D)            │                      │
│  │ /features/csv/      (1280D)            │                      │
│  │ /pca/parquet/       (50D)              │                      │
│  │ /pca/csv/           (50D)              │                      │
│  │ /metadata/          (path, label)      │                      │
│  │ /model_info/        (variance, stats)  │                      │
│  │ /errors/            (error report)     │                      │
│  └────────────────────────────────────────┘                      │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### 1.2 Flux de données

```
Images (S3)
    │
    ├─> [Spark Read binaryFile]
    │       │
    │       ▼
    │   DataFrame[path, content, modificationTime, length]
    │       │
    │       ├─> [Extract Labels]
    │       │       │
    │       │       ▼
    │       │   DataFrame[path, content, label]
    │       │       │
    │       │       ├─> [MobileNetV2 Pandas UDF] (Broadcast weights)
    │       │       │       │
    │       │       │       ▼
    │       │       │   DataFrame[path, label, features[1280]]
    │       │       │       │
    │       │       │       ├─> Save Features (Parquet + CSV)
    │       │       │       │
    │       │       │       ├─> [PCA Transform]
    │       │       │       │       │
    │       │       │       │       ▼
    │       │       │       │   DataFrame[path, label, pca_features[50]]
    │       │       │       │       │
    │       │       │       │       ├─> Save PCA (Parquet + CSV)
    │       │       │       │       ├─> Save Metadata
    │       │       │       │       └─> Save Model Info
    │       │       │       │
    │       │       │       └─> [Error Handling]
    │       │       │               │
    │       │       │               └─> Save Error Report
    │       │       │
    │       │       └─> [End]
```

---

## 2. Infrastructure AWS

### 2.1 EMR Cluster

**Configuration:**

| Composant       | Type         | vCPU | RAM   | Stockage |
|-----------------|--------------|------|-------|----------|
| Master Node     | m5.2xlarge   | 8    | 32 GB | 32 GB    |
| Core Node 1     | m5.2xlarge   | 8    | 32 GB | 32 GB    |
| Core Node 2     | m5.2xlarge   | 8    | 32 GB | 32 GB    |
| **Total**       | **3 nodes**  | **24** | **96 GB** | **96 GB** |

**Logiciels:**

- EMR Release: `emr-7.11.0`
- Spark: `3.5.x`
- Hadoop: `3.3.x`
- Python: `3.10+`

**Configurations Spark:**

```json
{
  "spark.executor.memory": "8g",
  "spark.driver.memory": "8g",
  "spark.executor.memoryOverhead": "2g",
  "spark.sql.execution.arrow.pyspark.enabled": "true",
  "spark.sql.execution.arrow.pyspark.fallback.enabled": "true"
}
```

### 2.2 Bootstrap Action

**Script:** `install_dependencies.sh`

Installé sur **tous les nœuds** au démarrage:

```bash
# Packages Python critiques
- tensorflow==2.16.1         # MobileNetV2
- scikit-learn==1.4.0        # Comparaison PCA
- pillow==10.4.0             # Traitement d'images
- pandas==2.2.0              # Pandas UDF
- numpy==1.26.4              # Calculs numériques
- pyarrow==15.0.0            # Sérialisation Arrow
- matplotlib, seaborn        # Visualisation
- boto3                      # AWS SDK
```

### 2.3 IAM Roles

**Service Role:** `arn:aws:iam::461506913677:role/EMR_DefaultRole`
- Permissions: Gestion du cluster EMR
- Actions: CreateCluster, TerminateCluster, AddSteps

**Instance Profile:** `EMR_EC2_DefaultRole`
- Permissions: Accès S3 (read/write)
- Actions: s3:GetObject, s3:PutObject, s3:ListBucket

**AutoScaling Role:** `arn:aws:iam::461506913677:role/EMR_AutoScaling_DefaultRole`
- Permissions: Gestion auto-scaling (si activé)

### 2.4 Réseau

- **Région:** `eu-west-1` (GDPR-compliant)
- **VPC:** Default VPC
- **Subnet:** `subnet-037413c77aa8d5ebb` (eu-west-1c)
- **Security Groups:** Auto-créés par EMR
  - Master SG: SSH (22), HTTPS (443)
  - Core SG: Communication inter-nœuds

### 2.5 S3 Structure

```
s3://oc-p11-fruits-david-scanu/
├── data/raw/Training/                    # Input data (immutable)
│   ├── Apple Braeburn/
│   │   ├── 0_100.jpg
│   │   ├── 1_100.jpg
│   │   └── ...
│   ├── Apple Golden 1/
│   └── ...
│
└── process_fruits_data/
    ├── scripts/                          # Scripts PySpark
    │   ├── install_dependencies.sh
    │   └── process_fruits_data.py
    │
    ├── logs/emr/                         # Logs EMR
    │   └── j-CLUSTERID/
    │       ├── steps/
    │       ├── node/
    │       └── containers/
    │
    └── output/                           # Résultats
        ├── features/
        │   ├── parquet/
        │   └── csv/
        ├── pca/
        │   ├── parquet/
        │   └── csv/
        ├── metadata/
        ├── model_info/
        └── errors/
```

---

## 3. Pipeline PySpark

### 3.1 Étape 1: Chargement des images

**Code:**

```python
# Load images with binaryFile format
df_images = spark.read.format("binaryFile").load(s3_path)

# Schema:
# root
#  |-- path: string
#  |-- modificationTime: timestamp
#  |-- length: long
#  |-- content: binary
```

**Optimisations:**

- Format `binaryFile` : Lecture efficace des fichiers binaires
- Pas de décompression automatique (JPG déjà compressé)
- Distribution automatique par Spark

**Modes de filtrage:**

```python
if mode == "mini":
    df_images = df_images.limit(300)
elif mode == "apples":
    image_path = f"{input_path}Training/Apple*/*.jpg"
elif mode == "full":
    image_path = f"{input_path}Training/*/*.jpg"
```

### 3.2 Étape 2: Extraction des labels

**Code:**

```python
# Extract label from path
# s3://bucket/data/raw/Training/Apple Braeburn/0_100.jpg
# → label: "Apple Braeburn"

df_with_labels = df_images.withColumn(
    "label",
    element_at(split(col("path"), "/"), -2)
)
```

**Résultat:**

```
+--------------------+-------------+
|                path|        label|
+--------------------+-------------+
|s3://.../Apple Br...|Apple Braeburn|
|s3://.../Banana/0...|      Banana |
+--------------------+-------------+
```

### 3.3 Étape 3: Feature Extraction (MobileNetV2)

#### 3.3.1 Broadcast des poids

**Objectif:** Éviter de télécharger le modèle sur chaque executor

```python
# Driver: Load model once
model = MobileNetV2(weights='imagenet', include_top=False, pooling='avg')
model_weights = model.get_weights()

# Broadcast to all workers (distributed memory)
sc = spark.sparkContext
broadcast_weights = sc.broadcast(model_weights)

# Size: ~14 MB
print(f"Broadcasted {len(model_weights)} tensors")
print(f"Total size: {sum(w.nbytes for w in model_weights) / 1024 / 1024:.2f} MB")
```

**Avantage:**

- ❌ **Sans broadcast** : 14 MB × N executors × N tasks = Giga-octets transférés
- ✅ **Avec broadcast** : 14 MB × N executors = ~42 MB total (3 executors)

#### 3.3.2 Pandas UDF

**Architecture:**

```
┌─────────────────────────────────────────────────────────┐
│                    Spark Driver                         │
│  ┌────────────────────────────────────────────────┐    │
│  │  Broadcast: model_weights (14 MB)              │    │
│  └────────────────────────────────────────────────┘    │
└───────────────────┬────────────────────────┬────────────┘
                    │                        │
        ┌───────────┴────────┐   ┌───────────┴────────┐
        │   Executor 1       │   │   Executor 2       │
        │                    │   │                    │
        │  ┌──────────────┐  │   │  ┌──────────────┐  │
        │  │ Pandas UDF   │  │   │  │ Pandas UDF   │  │
        │  │              │  │   │  │              │  │
        │  │ 1. Rebuild   │  │   │  │ 1. Rebuild   │  │
        │  │    model     │  │   │  │    model     │  │
        │  │ 2. Load      │  │   │  │ 2. Load      │  │
        │  │    weights   │  │   │  │    weights   │  │
        │  │ 3. Process   │  │   │  │ 3. Process   │  │
        │  │    batch     │  │   │  │    batch     │  │
        │  └──────────────┘  │   │  └──────────────┘  │
        └────────────────────┘   └────────────────────┘
```

**Code:**

```python
@pandas_udf(ArrayType(FloatType()))
def extract_features_udf(content_series: pd.Series) -> pd.Series:
    """
    UDF executed on each Spark executor.
    Processes a batch of images in parallel.
    """
    # Reconstruct model on worker (lightweight operation)
    local_model = MobileNetV2(weights=None, include_top=False, pooling='avg')

    # Load broadcasted weights (from local cache)
    local_model.set_weights(broadcast_weights.value)

    def process_image(content):
        try:
            # Decode JPG
            img = Image.open(io.BytesIO(content))

            # Ensure RGB
            if img.mode != 'RGB':
                img = img.convert('RGB')

            # Resize to 224x224 (MobileNetV2 input)
            img = img.resize((224, 224))

            # Convert to array
            img_array = img_to_array(img)
            img_array = np.expand_dims(img_array, axis=0)
            img_array = preprocess_input(img_array)

            # Extract features (1280D vector)
            features = local_model.predict(img_array, verbose=0)

            return features[0].tolist()

        except Exception:
            # Return None on error (filtered later)
            return None

    # Apply to all images in batch
    return content_series.apply(process_image)
```

**Performances:**

- **Batch size** : Automatique (contrôlé par Spark)
- **Parallelism** : N executors × M cores = 3 × 8 = 24 cores
- **Throughput** : ~5-10 images/seconde/core (selon CPU)
- **Exemple** : 300 images en ~2-3 minutes

#### 3.3.3 Application de l'UDF

```python
df_features = df_with_labels.withColumn(
    "features",
    extract_features_udf(col("content"))
)

# Filter errors (where features is NULL)
df_features = df_features.filter(col("features").isNotNull())
df_errors = df_features.filter(col("features").isNull())
```

**Résultat:**

```
+--------------------+-------------+--------------------+
|                path|        label|            features|
+--------------------+-------------+--------------------+
|s3://.../0_100.jpg  |Apple Braeburn|[0.123, 0.456, ...]| (1280 floats)
+--------------------+-------------+--------------------+
```

### 3.4 Étape 4: PCA (Réduction de dimension)

#### 3.4.1 Préparation des données

```python
from pyspark.ml.linalg import Vectors, VectorUDT

# Convert Array[Float] → Vector (required by MLlib)
array_to_vector = udf(lambda a: Vectors.dense(a), VectorUDT())

df_for_pca = df_features.withColumn(
    "features_vector",
    array_to_vector(col("features"))
)
```

#### 3.4.2 Application PCA

**Code:**

```python
from pyspark.ml.feature import PCA

# Create PCA model
pca = PCA(
    k=50,                          # Number of components
    inputCol="features_vector",    # Input: 1280D
    outputCol="pca_features"       # Output: 50D
)

# Fit PCA on data
pca_model = pca.fit(df_for_pca)

# Transform data
df_pca = pca_model.transform(df_for_pca)
```

**Algorithme:**

1. **Standardisation** : Centre et réduit les features
2. **Calcul SVD** : Décomposition en valeurs singulières
3. **Sélection** : Garde les K=50 premières composantes
4. **Projection** : Transforme les données

**Complexité:**

- **Temps** : O(n × m × k) où n=images, m=1280, k=50
- **Espace** : O(m × k) = ~256 KB (matrice de projection)

#### 3.4.3 Analyse de la variance

```python
explained_variance = pca_model.explainedVariance

print(f"Total variance: {sum(explained_variance):.4f}")
# Exemple: 0.8542 → 85.42% de variance conservée avec 50 composantes

# Variance cumulée
cumsum_variance = np.cumsum(explained_variance)
print(f"50 components: {cumsum_variance[-1]:.4f}")
```

**Interprétation:**

- **PC1** : ~20-30% de variance (orientation, luminosité)
- **PC2-10** : ~30-40% de variance (formes, couleurs)
- **PC11-50** : ~20-30% de variance (détails fins)

### 3.5 Étape 5: Sauvegarde des résultats

#### 3.5.1 Features brutes (1280D)

**Parquet:**

```python
df_features.select("path", "label", "features") \
    .write.mode("overwrite") \
    .parquet(f"{output}/features/parquet/features_{timestamp}")
```

**CSV:**

```python
# Convert Array → String for CSV
array_to_string = udf(lambda a: ",".join([str(float(x)) for x in a]), StringType())

df_csv = df_features.withColumn("features_string", array_to_string(col("features")))

df_csv.select("path", "label", "features_string") \
    .write.mode("overwrite") \
    .option("header", "true") \
    .csv(f"{output}/features/csv/features_{timestamp}")
```

#### 3.5.2 Features PCA (50D)

Même logique que 3.5.1, avec `pca_features` au lieu de `features`.

#### 3.5.3 Model Info (Variance PCA)

**JSON:**

```python
model_info = {
    "timestamp": timestamp,
    "pca_components": 50,
    "original_dimensions": 1280,
    "reduced_dimensions": 50,
    "total_variance_explained": float(sum(explained_variance)),
    "variance_by_component": [float(v) for v in explained_variance],
    "cumulative_variance": [float(v) for v in cumsum_variance],
    "num_images_processed": df_pca.count()
}

# Save as text (JSON string)
df_json = spark.createDataFrame([Row(json_content=json.dumps(model_info))])
df_json.write.mode("overwrite").text(f"{output}/model_info/model_info_{timestamp}")
```

**CSV (variance par composante):**

```python
variance_data = [
    (i+1, float(explained_variance[i]), float(cumsum_variance[i]))
    for i in range(len(explained_variance))
]

df_variance = spark.createDataFrame(
    variance_data,
    ["component", "variance_explained", "cumulative_variance"]
)

df_variance.write.mode("overwrite") \
    .option("header", "true") \
    .csv(f"{output}/model_info/variance_{timestamp}")
```

---

## 4. Optimisations Big Data

### 4.1 Broadcast Variables

**Problème:** Télécharger le modèle sur chaque task = gaspillage réseau

```
Sans broadcast:
Driver → Executor 1 (Task 1): 14 MB
Driver → Executor 1 (Task 2): 14 MB
...
Total: 14 MB × N_tasks = Giga-octets

Avec broadcast:
Driver → Executor 1: 14 MB (cached)
Driver → Executor 2: 14 MB (cached)
Driver → Executor 3: 14 MB (cached)
Total: 14 MB × 3 = 42 MB
```

### 4.2 Pandas UDF avec Arrow

**Avantage:** Sérialisation efficace entre JVM (Spark) et Python

```
Sans Arrow (Pickle):
JVM → Python: Slow serialization (row-by-row)
Python → JVM: Slow deserialization

Avec Arrow:
JVM ←→ Python: Zero-copy (columnar format)
Speed: ~10-100x faster
```

### 4.3 Caching stratégique

```python
# Cache des DataFrames réutilisés
df_features.cache()   # Utilisé pour: PCA + sauvegarde
df_pca.cache()        # Utilisé pour: sauvegarde multi-format

# Libération de la mémoire
df_features.unpersist()
df_pca.unpersist()
```

### 4.4 Partitioning

**Stratégie:**

- **Input** : Auto-partitionné par Spark (1 partition ≈ 128 MB)
- **Processing** : Repartitionnement si nécessaire (`repartition(N)`)
- **Output** : `coalesce(1)` pour un fichier unique (metadata, model_info)

### 4.5 Parquet vs CSV

| Format  | Taille | Lecture | Écriture | Compression | Schéma |
|---------|--------|---------|----------|-------------|--------|
| Parquet | +++    | +++     | ++       | ✅ Snappy   | ✅     |
| CSV     | --     | -       | +        | ❌          | ❌     |

**Recommandation:**
- **Parquet** : Traitement ultérieur (ML, analytics)
- **CSV** : Inspection manuelle, compatibilité

---

## 5. Formats de données

### 5.1 Features (1280D)

**Parquet Schema:**

```
root
 |-- path: string
 |-- label: string
 |-- features: array
 |    |-- element: float
```

**CSV Format:**

```
path,label,features_string
s3://.../0_100.jpg,Apple Braeburn,"0.123,0.456,0.789,..."
```

### 5.2 PCA (50D)

**Parquet Schema:**

```
root
 |-- path: string
 |-- label: string
 |-- pca_features: vector (ML)
```

**CSV Format:**

```
path,label,pca_features_string
s3://.../0_100.jpg,Apple Braeburn,"1.234,5.678,9.012,..."
```

### 5.3 Model Info

**JSON:**

```json
{
  "timestamp": "20250115_104500",
  "pca_components": 50,
  "original_dimensions": 1280,
  "reduced_dimensions": 50,
  "total_variance_explained": 0.8542,
  "variance_by_component": [0.2134, 0.1523, ...],
  "cumulative_variance": [0.2134, 0.3657, ...],
  "num_images_processed": 300
}
```

**Variance CSV:**

```
component,variance_explained,cumulative_variance
1,0.213400,0.213400
2,0.152300,0.365700
3,0.089500,0.455200
...
```

---

## 6. Gestion des erreurs

### 6.1 Erreurs d'images

**Causes:**
- Image corrompue
- Format invalide (non-RGB)
- Taille incorrecte
- Erreur réseau S3

**Handling:**

```python
def process_image(content):
    try:
        img = Image.open(io.BytesIO(content))
        # ... process ...
        return features
    except Exception as e:
        # Log error silently, return None
        return None

# Filter errors
df_features = df.filter(col("features").isNotNull())
df_errors = df.filter(col("features").isNull())

# Save error report
df_errors.select("path", "label") \
    .write.csv(f"{output}/errors/errors_{timestamp}")
```

### 6.2 Out of Memory (OOM)

**Symptômes:**
- `java.lang.OutOfMemoryError`
- `Container killed by YARN`

**Solutions:**

1. **Augmenter la mémoire:**
   ```bash
   SPARK_EXECUTOR_MEMORY="12g"
   SPARK_EXECUTOR_MEMORY_OVERHEAD="3g"
   ```

2. **Augmenter les instances:**
   ```bash
   CORE_INSTANCE_TYPE="m5.4xlarge"  # 16 vCPU, 64 GB
   ```

3. **Réduire le batch size:**
   ```python
   # Dans Pandas UDF: traiter par petits lots
   ```

### 6.3 Échec du bootstrap

**Symptôme:** Cluster passe à `TERMINATED_WITH_ERRORS`

**Solution:**

1. Vérifier les logs bootstrap:
   ```bash
   aws s3 ls s3://bucket/logs/emr/j-XXX/node/i-XXX/bootstrap-actions/
   ```

2. Tester le script bootstrap localement:
   ```bash
   bash scripts/install_dependencies.sh
   ```

3. Vérifier la connexion réseau (PyPI accessible?)

---

## 📊 Résumé des performances

### Mode MINI (300 images)

| Étape                | Durée    | Résultat                  |
|----------------------|----------|---------------------------|
| Chargement           | ~5s      | 300 images loaded         |
| Feature extraction   | ~1-2 min | 300 × 1280 floats         |
| PCA                  | ~10s     | 300 × 50 floats           |
| Sauvegarde           | ~20s     | Multi-format output       |
| **Total**            | **2-5 min** | Pipeline complet       |

### Mode FULL (67,000 images)

| Étape                | Durée    | Résultat                  |
|----------------------|----------|---------------------------|
| Chargement           | ~1 min   | 67,000 images loaded      |
| Feature extraction   | ~90 min  | 67,000 × 1280 floats      |
| PCA                  | ~10 min  | 67,000 × 50 floats        |
| Sauvegarde           | ~10 min  | Multi-format output       |
| **Total**            | **~2h**  | Pipeline complet          |

---

## 🏗️ Évolutions futures

### Optimisations possibles

1. **Auto-scaling** : Ajouter des nœuds dynamiquement
2. **GPU** : Utiliser des instances g4dn pour TensorFlow
3. **Caching S3** : Utiliser EMRFS avec cache local
4. **Modèle custom** : Fine-tuner MobileNetV2 sur les fruits

### Métriques à ajouter

1. **Monitoring Spark** : Temps par stage
2. **Monitoring TensorFlow** : Temps d'inférence par image
3. **Monitoring S3** : Throughput read/write

---

**Projet** : OpenClassrooms AI Engineer P11
**Architecture** : AWS EMR + PySpark + TensorFlow + MLlib
**Dataset** : Fruits-360 (67,000 images, 224 classes)
