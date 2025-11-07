# Comprendre les Fichiers Générés par PySpark

## 📊 Vue d'ensemble

PySpark génère des noms de fichiers qui peuvent sembler inhabituels, mais cette structure est parfaitement normale et suit les conventions Apache Spark pour le traitement distribué.

---

## 📁 Structure des Dossiers du Projet

### **data/features/mobilenetv2_features/**

**Format** : Parquet (format distribué Apache)

| Fichier | Type | Taille | Explication |
|---------|------|--------|-------------|
| `_SUCCESS` | Marqueur | 0 B | ✅ Indique que l'écriture s'est terminée avec succès |
| `._SUCCESS.crc` | Checksum | 8 B | Fichier de vérification d'intégrité |
| `part-00000-*.snappy.parquet` | Données | ~918 KB | 🎯 **Fichier principal** contenant les features MobileNetV2 (1280 dimensions) |
| `.part-00000-*.crc` | Checksum | ~7.2 KB | Vérification d'intégrité du fichier parquet |

---

### **data/pca/pca_results/**

**Format** : Parquet (recommandé pour PySpark)

| Fichier | Type | Taille | Explication |
|---------|------|--------|-------------|
| `_SUCCESS` | Marqueur | 0 B | ✅ Écriture réussie |
| `._SUCCESS.crc` | Checksum | 8 B | Vérification d'intégrité |
| `part-00000-*.snappy.parquet` | Données | ~139 KB | 🎯 **Résultats PCA** (images × 200 dimensions) |
| `.part-00000-*.crc` | Checksum | ~1.1 KB | Vérification d'intégrité |

**Contenu** : Vecteurs PCA denses (format natif PySpark)

---

### **data/pca/pca_results_csv/**

**Format** : CSV (pour inspection humaine)

| Fichier | Type | Taille | Explication |
|---------|------|--------|-------------|
| `_SUCCESS` | Marqueur | 0 B | ✅ Écriture réussie |
| `._SUCCESS.crc` | Checksum | 8 B | Vérification d'intégrité |
| `part-00000-*.csv` | Données | ~407 KB | 🎯 **CSV avec header** (path, label, pca_features_string) |
| `.part-00000-*.crc` | Checksum | ~3.2 KB | Vérification d'intégrité |

**Contenu** : Features PCA au format string (valeurs séparées par virgules)

**Colonnes** :
- `path` : Chemin complet vers l'image source
- `label` : Classe de l'image (ex: "Apple Golden 1")
- `pca_features_string` : 200 valeurs PCA séparées par virgules

---

## 🔍 Décryptage du Format de Nommage

### Anatomie d'un Nom de Fichier PySpark

```
part-00000-4338336c-81f1-4258-9db4-82f13649b008-c000.snappy.parquet
 │     │                    │                      │      │        │
 │     │                    │                      │      │        └─ Extension (.parquet, .csv)
 │     │                    │                      │      └─ Compression (snappy, gzip, none)
 │     │                    │                      └─ Partition chunk ID (c000, c001, etc.)
 │     │                    └─ UUID unique du job Spark
 │     └─ Numéro de partition (00000 = première partition)
 └─ Préfixe standard PySpark
```

### Pourquoi cette structure ?

PySpark génère ces noms pour plusieurs raisons importantes :

1. **Distribution des données** 🌐
   - Les données sont divisées en partitions pour le traitement parallèle
   - Chaque partition = 1 fichier `part-XXXXX`
   - Permet de traiter des téraoctets de données

2. **Unicité et traçabilité** 🔐
   - UUID unique évite les collisions de fichiers
   - Permet de tracer quel job Spark a créé le fichier
   - Essentiel pour les environnements multi-utilisateurs (AWS EMR)

3. **Optimisation** ⚡
   - Compression Snappy pour gain d'espace (~3-5x)
   - Format columnaire Parquet pour lectures rapides
   - Chunks permettent le streaming de gros datasets

---

## 📖 Fichiers Spéciaux

### `_SUCCESS`

- **Rôle** : Marqueur de succès
- **Taille** : 0 bytes (fichier vide)
- **Signification** : L'opération d'écriture s'est terminée **sans erreur**
- **Important** : Si ce fichier est absent → l'écriture a échoué ou est incomplète

### Fichiers `.crc`

- **Rôle** : Checksum CRC32
- **But** : Vérifier l'intégrité des données
- **Utilisé par** : Hadoop/Spark pour détecter les corruptions
- **Note** : Peuvent être ignorés pour l'utilisation manuelle

---

## 💻 Utilisation des Fichiers

### Recharger en PySpark

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("Reload").getOrCreate()

# Charger les features MobileNetV2
df_features = spark.read.parquet("data/features/mobilenetv2_features")
print(f"Features chargées: {df_features.count()} images")

# Charger les résultats PCA (format Parquet)
df_pca = spark.read.parquet("data/pca/pca_results")
print(f"PCA chargées: {df_pca.count()} images")

# Charger les résultats PCA (format CSV)
df_pca_csv = spark.read.csv("data/pca/pca_results_csv", header=True)
print(f"PCA CSV chargées: {df_pca_csv.count()} images")

# Afficher le schéma
df_pca.printSchema()
df_pca.show(5)
```

### Lire avec Pandas

```python
import pandas as pd
import glob

# Lire le CSV (plus simple pour pandas)
csv_files = glob.glob("data/pca/pca_results_csv/part-*.csv")
df = pd.read_csv(csv_files[0])

print(f"Shape: {df.shape}")
print(df.head())

# Convertir la colonne pca_features_string en array numpy
import numpy as np

def string_to_array(s):
    return np.array([float(x) for x in s.split(',')])

df['pca_features'] = df['pca_features_string'].apply(string_to_array)
```

### Lire avec PyArrow (recommandé pour Parquet)

```python
import pyarrow.parquet as pq
import pandas as pd

# Lire un fichier Parquet avec PyArrow
table = pq.read_table("data/pca/pca_results")
df = table.to_pandas()

print(df.head())
```

---

## 🚀 Migration vers AWS S3

### Différences Local vs Cloud

| Aspect | Local | AWS EMR + S3 |
|--------|-------|--------------|
| **Chemin** | `file:///path/to/data` | `s3://bucket/path/` |
| **Partitions** | 1-2 fichiers | Dizaines/centaines selon cluster |
| **Compression** | Optionnelle | **Recommandée** (coût S3) |
| **`_SUCCESS`** | Important | **Critique** (indicateur de succès) |

### Exemple de Chemins S3

```python
# Lecture depuis S3
df = spark.read.parquet("s3://mon-bucket-fruits/data/features/mobilenetv2_features/")

# Écriture vers S3
df_pca.write.mode("overwrite").parquet("s3://mon-bucket-fruits/data/pca/pca_results/")

# Écriture CSV vers S3
df_pca_csv.write.mode("overwrite") \
    .option("header", "true") \
    .csv("s3://mon-bucket-fruits/data/pca/pca_results_csv/")
```

### Bonnes Pratiques S3

1. **Toujours utiliser Parquet** sur S3 (plus économique que CSV)
2. **Activer la compression** (Snappy par défaut)
3. **Vérifier `_SUCCESS`** après chaque écriture
4. **Partitionner intelligemment** pour gros datasets :
   ```python
   df.write.partitionBy("label").parquet("s3://bucket/data/")
   ```

---

## 🔧 Gestion des Fichiers

### Lister tous les fichiers d'un dataset

```bash
# Local
ls -lah data/pca/pca_results/

# AWS S3
aws s3 ls s3://mon-bucket-fruits/data/pca/pca_results/
```

### Compter les partitions

```python
import os
import glob

# Compter les fichiers part-*
parquet_files = glob.glob("data/pca/pca_results/part-*.parquet")
print(f"Nombre de partitions: {len(parquet_files)}")

# En PySpark
df = spark.read.parquet("data/pca/pca_results")
print(f"Nombre de partitions: {df.rdd.getNumPartitions()}")
```

### Fusionner les partitions (coalesce)

```python
# Réduire le nombre de partitions (utile pour petits datasets)
df_pca.coalesce(1).write.mode("overwrite").parquet("data/pca/pca_single_file/")

# Vérification
# ⚠️ Attention: coalesce(1) crée un seul fichier (peut être lent pour gros datasets)
```

---

## ⚠️ Problèmes Courants

### Problème 1 : Fichier `_SUCCESS` manquant

**Cause** : L'écriture a échoué ou été interrompue

**Solution** :
```python
# Vérifier l'existence de _SUCCESS
import os
if os.path.exists("data/pca/pca_results/_SUCCESS"):
    print("✅ Écriture réussie")
else:
    print("❌ Écriture incomplète - relancer le job")
```

### Problème 2 : Trop de petits fichiers

**Cause** : Trop de partitions pour un petit dataset

**Solution** :
```python
# Repartitionner avant sauvegarde
df.coalesce(4).write.parquet("data/output/")  # 4 fichiers au lieu de 200
```

### Problème 3 : Fichiers CRC causent des erreurs

**Cause** : Certains outils ne supportent pas les fichiers `.crc`

**Solution** :
```bash
# Supprimer les fichiers .crc (optionnel, ils se régénèrent)
find data/pca/ -name "*.crc" -delete
```

### Problème 4 : Impossible de lire avec pandas

**Cause** : Pandas ne supporte pas nativement les dossiers Parquet

**Solution** :
```python
# Option 1: Utiliser PyArrow
import pyarrow.parquet as pq
table = pq.read_table("data/pca/pca_results")
df = table.to_pandas()

# Option 2: Lire un fichier spécifique
import glob
parquet_file = glob.glob("data/pca/pca_results/part-*.parquet")[0]
df = pd.read_parquet(parquet_file)
```

---

## 📊 Comparaison des Formats

### Parquet vs CSV

| Critère | Parquet | CSV |
|---------|---------|-----|
| **Taille** | 🟢 Compressé (3-10x plus petit) | 🔴 Non compressé |
| **Vitesse lecture** | 🟢 Très rapide (columnaire) | 🔴 Lent (ligne par ligne) |
| **Compatibilité** | 🟡 Nécessite PyArrow/Spark | 🟢 Universel |
| **Types de données** | 🟢 Préservés (int, float, vector) | 🔴 Tout en string |
| **Inspection humaine** | 🔴 Binaire (illisible) | 🟢 Texte lisible |
| **Recommandation** | ⭐ Production/Cloud | 📝 Debug/Inspection |

### Quand utiliser quoi ?

- **Parquet** :
  - ✅ Production sur AWS EMR/S3
  - ✅ Gros datasets (>1 GB)
  - ✅ Réutilisation dans PySpark
  - ✅ Performance critique

- **CSV** :
  - ✅ Inspection manuelle
  - ✅ Partage avec non-data scientists
  - ✅ Import dans Excel/Google Sheets
  - ✅ Petit datasets (<100 MB)

---

## 🎯 Checklist de Validation

Après chaque opération PySpark d'écriture, vérifier :

- [ ] Fichier `_SUCCESS` présent
- [ ] Au moins un fichier `part-*.{parquet|csv}` existe
- [ ] Taille des fichiers cohérente (pas de 0 bytes)
- [ ] Possibilité de recharger les données avec `spark.read`
- [ ] Nombre de lignes cohérent avec le dataset source

```python
# Script de validation automatique
import os
import glob

def validate_pyspark_output(path):
    """Valide qu'un dossier PySpark est correct."""

    # Vérifier _SUCCESS
    success_file = os.path.join(path, "_SUCCESS")
    if not os.path.exists(success_file):
        print(f"❌ Fichier _SUCCESS manquant dans {path}")
        return False

    # Vérifier présence de fichiers part-*
    part_files = glob.glob(os.path.join(path, "part-*"))
    if len(part_files) == 0:
        print(f"❌ Aucun fichier part-* trouvé dans {path}")
        return False

    # Vérifier que les fichiers ne sont pas vides
    for f in part_files:
        if os.path.getsize(f) == 0:
            print(f"❌ Fichier vide: {f}")
            return False

    print(f"✅ {path} est valide ({len(part_files)} partitions)")
    return True

# Utilisation
validate_pyspark_output("data/pca/pca_results")
validate_pyspark_output("data/features/mobilenetv2_features")
```

---

## 📚 Ressources

- [Apache Parquet Documentation](https://parquet.apache.org/docs/)
- [PySpark SQL Guide](https://spark.apache.org/docs/latest/sql-programming-guide.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html)
- [Snappy Compression](https://github.com/google/snappy)

---

## 💡 Résumé

**Les noms de fichiers PySpark sont normaux et suivent les conventions Spark !**

- ✅ Structure conforme aux standards Apache Spark
- ✅ Fichiers `_SUCCESS` = indicateur de succès critique
- ✅ UUID dans les noms = unicité garantie
- ✅ Format Parquet + Snappy = optimal pour production
- ✅ CSV disponible pour inspection manuelle

**Ne pas renommer manuellement ces fichiers** - PySpark s'attend à cette structure exacte pour les lectures futures.