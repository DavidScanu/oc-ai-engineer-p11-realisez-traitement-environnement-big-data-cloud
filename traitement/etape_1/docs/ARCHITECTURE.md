# Architecture technique - Étape 1

## 🏗️ Vue d'ensemble

Cette étape met en place une architecture Big Data cloud-native sur AWS pour le traitement distribué d'images.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (eu-west-1)                          │
│                                                                         │
│  ┌─────────────────────┐                                                │
│  │                     │                                                │
│  │    S3 Bucket        │                                                │
│  │  (Data Lake)        │                                                │
│  │                     │                                                │
│  │  ┌──────────────┐   │         ┌────────────────────────────────┐    │
│  │  │ Input Data   │   │         │     EMR Cluster                │    │
│  │  │ - Training/  │───┼────────►│                                │    │
│  │  │ - Test/      │   │  Read   │  ┌──────────────────────────┐  │    │
│  │  └──────────────┘   │         │  │   Master Node            │  │    │
│  │                     │         │  │   (m5.xlarge)            │  │    │
│  │  ┌──────────────┐   │         │  │                          │  │    │
│  │  │ Scripts      │   │         │  │  - Spark Driver          │  │    │
│  │  │ - Bootstrap  │───┼────┐    │  │  - Resource Manager      │  │    │
│  │  │ - PySpark    │   │    │    │  │  - NameNode (HDFS)       │  │    │
│  │  └──────────────┘   │    │    │  └──────────────────────────┘  │    │
│  │                     │    │    │              │                  │    │
│  │  ┌──────────────┐   │    │    │              ▼                  │    │
│  │  │ Config       │   │    │    │  ┌──────────────────────────┐  │    │
│  │  │ - requirements│  │    └───►│  │   Core Nodes (x2)        │  │    │
│  │  └──────────────┘   │         │  │   (m5.xlarge each)       │  │    │
│  │                     │         │  │                          │  │    │
│  │  ┌──────────────┐   │         │  │  - Spark Executors       │  │    │
│  │  │ Output       │◄──┼─────────│  │  - DataNode (HDFS)       │  │    │
│  │  │ - metadata/  │   │  Write  │  │  - Task execution        │  │    │
│  │  │ - stats/     │   │         │  └──────────────────────────┘  │    │
│  │  └──────────────┘   │         │                                │    │
│  │                     │         │  Applications:                 │    │
│  │  ┌──────────────┐   │         │  - Hadoop 3.3.x                │    │
│  │  │ Logs         │◄──┼─────────│  - Spark 3.5.x                 │    │
│  │  │ - EMR logs   │   │  Write  │  - PySpark 3.5.x               │    │
│  │  └──────────────┘   │         │                                │    │
│  └─────────────────────┘         └────────────────────────────────┘    │
│                                                                         │
│  ┌─────────────────────┐         ┌────────────────────────────────┐    │
│  │   IAM Roles         │         │    VPC / Networking            │    │
│  │                     │         │                                │    │
│  │  - EMR_DefaultRole  │◄────────│  - Subnet (eu-west-1a)         │    │
│  │  - EMR_EC2_Default  │         │  - Security Groups:            │    │
│  │  - EMR_AutoScaling  │         │    * Master SG                 │    │
│  └─────────────────────┘         │    * Slave SG                  │    │
│                                  │  - EC2 Key Pair (SSH)          │    │
│                                  └────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🔧 Composants techniques

### 1. AWS EMR Cluster

**Version** : EMR 7.11.0

**Configuration** :
- **Master Node** : 1x m5.xlarge (4 vCPU, 16 GB RAM, 32 GB EBS gp3)
- **Core Nodes** : 2x m5.xlarge (4 vCPU, 16 GB RAM, 32 GB EBS gp3)
- **Total** : 3 nœuds, 12 vCPU, 48 GB RAM

**Applications** :
- Hadoop 3.3.6
- Spark 3.5.1
- YARN (Resource Manager)

**Optimisations Spark** :
```yaml
spark.executor.memory: 4g
spark.driver.memory: 4g
spark.executor.memoryOverhead: 1g
spark.sql.execution.arrow.pyspark.enabled: true
```

**Auto-terminaison** : 4 heures d'inactivité

### 2. AWS S3 (Data Lake)

**Structure** :
```
s3://oc-p11-fruits-david-scanu/
├── data/
│   └── fruits-360/
│       ├── Training/
│       │   ├── Apple_Braeburn/
│       │   ├── Banana/
│       │   └── ... (224 classes)
│       └── Test/
│           └── ... (224 classes)
│
├── scripts/
│   ├── install_dependencies.sh
│   └── read_fruits_data.py
│
│
├── output/
│   └── etape_1/
│       ├── metadata_YYYYMMDD_HHMMSS/
│       │   └── part-00000-xxx.csv
│       └── stats_YYYYMMDD_HHMMSS/
│           └── part-00000-xxx.csv
│
└── logs/
    └── emr/
        ├── j-CLUSTERID/
        │   ├── node/
        │   ├── containers/
        │   └── steps/
        └── ...
```

### 3. IAM Roles et Permissions

**EMR_DefaultRole** (Service Role) :
- `AmazonEMRServicePolicy_v2`
- Permissions : Créer/gérer les ressources EMR

**EMR_EC2_DefaultRole** (Instance Profile) :
- `AmazonElasticMapReduceforEC2Role`
- Permissions : Accès S3, CloudWatch, EC2

**EMR_AutoScaling_DefaultRole** :
- `AmazonElasticMapReduceforAutoScalingRole`
- Permissions : Auto-scaling du cluster

### 4. VPC et Sécurité

**Subnet** : `subnet-037413c77aa8d5ebb` (eu-west-1a)

**Security Groups** :
- **Master SG** (`sg-0ee431c02c5bc7fc4`) :
  - Ports ouverts : 22 (SSH), 8088 (YARN), 9443 (JupyterHub)
  - Source : IP de l'utilisateur

- **Slave SG** (`sg-03b5c1607e57d5935`) :
  - Communication inter-nœuds
  - Ports Spark : 7077, 4040-4050

**EC2 Key Pair** : `emr-p11-fruits-key-codespace`

## 📊 Flux de données

### Phase 1 : Bootstrap (au démarrage du cluster)

```
1. EMR démarre les instances EC2
   └─► 2. Télécharge install_dependencies.sh depuis S3
        └─► 3. Installe les packages Python
            └─► 4. Cluster passe à l'état WAITING
```

### Phase 2 : Exécution du job PySpark

```
1. Soumission du step via submit_job.sh
   └─► 2. EMR télécharge read_fruits_data.py depuis S3
       └─► 3. spark-submit lance le job en mode cluster
           └─► 4. Driver (Master) coordonne les Executors (Core)
               │
               ├─► 5a. Lecture des images (binaryFile)
               │   └─► Spark lit s3://bucket/data/fruits-360/**/*.jpg
               │
               ├─► 5b. Transformation (regex, extraction métadonnées)
               │   └─► Parallélisation sur les 2 Core nodes
               │
               ├─► 5c. Agrégation (groupBy, count)
               │   └─► Calcul distribué des statistiques
               │
               └─► 5d. Écriture des résultats
                   └─► Sauvegarde CSV sur S3 (coalesce(1))
```

### Phase 3 : Finalisation

```
1. Step terminé (état: COMPLETED)
   └─► 2. Résultats disponibles sur S3
       └─► 3. Cluster retourne à l'état WAITING
           └─► 4. Auto-terminaison après 4h (si inactif)
```

## 🔄 Cycle de vie du cluster

```
CREATE ──► STARTING ──► BOOTSTRAPPING ──► RUNNING ──► WAITING
                                                        │
                                                        ▼
                                               ┌────────────────┐
                                               │  Submit Step   │
                                               └────────┬───────┘
                                                        │
                                                        ▼
                                                    RUNNING
                                                        │
                                                        ▼
                                              Step COMPLETED/FAILED
                                                        │
                                                        ▼
                                                    WAITING
                                                        │
                                                        ▼
                                               (4h idle timeout)
                                                        │
                                                        ▼
                                          TERMINATE ──► TERMINATING ──► TERMINATED
```

## 💾 Persistance des données

| Type de données | Emplacement | Durabilité |
|----------------|-------------|------------|
| Input (images) | S3 | ✅ Permanente |
| Scripts Python | S3 | ✅ Permanente |
| Configuration | S3 | ✅ Permanente |
| Output (CSV) | S3 | ✅ Permanente |
| Logs EMR | S3 | ✅ Permanente (configurable) |
| Données HDFS | Cluster (EBS) | ❌ Perdue à la terminaison |
| Spark cache | Mémoire cluster | ❌ Perdue à la terminaison |

**Important** : Toujours sauvegarder les résultats sur S3 avant de terminer le cluster !

## 🔒 Conformité GDPR

✅ **Région Europe** : `eu-west-1` (Irlande)
✅ **Stockage** : S3 dans `eu-west-1` (pas de réplication cross-région)
✅ **Compute** : EMR instances dans `eu-west-1`
✅ **Logs** : CloudWatch et S3 logs dans `eu-west-1`
✅ **Pas de transfert hors UE**

## 💰 Estimation des coûts (eu-west-1)

| Ressource | Quantité | Tarif unitaire | Coût/heure |
|-----------|----------|----------------|------------|
| EMR Master m5.xlarge | 1 | ~0.05€ + 0.12€ (EMR) | 0.17€ |
| EMR Core m5.xlarge | 2 | ~0.05€ + 0.12€ (EMR) | 0.34€ |
| EBS gp3 (32 GB) | 3 | ~0.10€/mois/GB | ~0.01€ |
| **Total** | | | **~0.52€/heure** |

**Coût d'un job typique** (15 min cluster + 5 min job) : ~0.17€

**S3 Storage** (100k images, ~1 GB) : ~0.02€/mois

**Remarque** : Les tarifs AWS varient, vérifier la [calculatrice AWS](https://calculator.aws/).

## 🚀 Scalabilité

### Scalabilité verticale (instances plus puissantes)

```bash
# Dans config/config.sh
export MASTER_INSTANCE_TYPE="m5.2xlarge"  # 8 vCPU, 32 GB RAM
export CORE_INSTANCE_TYPE="m5.2xlarge"
```

### Scalabilité horizontale (plus de nœuds)

```bash
# Dans config/config.sh
export CORE_INSTANCE_COUNT="4"  # Au lieu de 2
```

### Auto-scaling (dynamique)

Le cluster peut auto-scaler entre min et max instances selon la charge (déjà configuré avec `EMR_AutoScaling_DefaultRole`).

## 📈 Performances attendues

| Dataset | Taille | Nœuds | Durée estimée |
|---------|--------|-------|---------------|
| 155k images (Fruits-360 complet) | ~5 GB | 1M + 2C | 2-5 min |
| 1M images | ~30 GB | 1M + 4C | 10-15 min |
| 10M images | ~300 GB | 1M + 10C | 30-60 min |

**Facteurs influençant les performances** :
- Nombre de Core nodes (parallélisation)
- Type d'instance (vCPU, RAM)
- Bande passante réseau S3
- Taille des images
- Complexité des transformations

## 🔧 Monitoring et Debugging

### Logs EMR

```bash
# Logs principaux
s3://bucket/logs/emr/j-CLUSTERID/
├── node/                    # Logs système des nœuds
├── containers/              # Logs des conteneurs YARN
└── steps/                   # Logs des steps (jobs)
```

### Spark UI

Accessible pendant l'exécution du job :
- URL : `http://<master-dns>:4040`
- Nécessite tunnel SSH ou accès VPC

### CloudWatch

Métriques automatiques :
- CPU Utilization
- Memory Usage
- HDFS Utilization
- YARN Metrics

## 🎯 Limitations et contraintes

1. **Coût** : ~0.52€/heure → Toujours terminer le cluster après usage
2. **Idle timeout** : 4h d'inactivité → Cluster auto-terminé
3. **Bande passante S3** : Limitation selon la région et le tier
4. **EBS** : 32 GB par nœud → Pas de stockage local massif
5. **HDFS éphémère** : Données perdues à la terminaison

## 🔮 Évolutions futures (Étapes 2-4)

- **Étape 2** : Extraction de features avec TensorFlow (MobileNetV2)
- **Étape 3** : Broadcast des poids TensorFlow (`sc.broadcast()`)
- **Étape 4** : PCA distribué avec MLlib ou PySpark

**Modifications architecturales nécessaires** :
- Installation de TensorFlow 2.x (déjà fait)
- Augmentation mémoire executor (pour chargement modèle)
- Optimisation Pandas UDF pour feature extraction
