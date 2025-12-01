# Workflow détaillé - Étape 1

## 🎯 Vue d'ensemble du workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRÉPARATION (Local)                          │
└───────────────────────┬─────────────────────────────────────────┘
                        │
    ┌───────────────────┼───────────────────┐
    │                   │                   │
    ▼                   ▼                   ▼
[Éditer]          [Vérifier]          [Uploader]
config.sh         verify_setup.sh     upload_scripts.sh
    │                   │                   │
    └───────────────────┴───────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CRÉATION CLUSTER (AWS)                        │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
                create_cluster.sh
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
  [AWS EMR API]                  [Surveiller]
  Créer cluster               monitor_cluster.sh
        │                               │
        ├─► STARTING                    │
        ├─► BOOTSTRAPPING ─────────────►│
        │   (install_dependencies.sh)   │
        ├─► RUNNING                     │
        └─► WAITING ◄───────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  EXÉCUTION JOB (AWS EMR)                        │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
                  submit_job.sh
                        │
                        ▼
              [Spark Submit Step]
                        │
        ┌───────────────┴────────────────┐
        │                                │
        ▼                                ▼
  read_fruits_data.py            [Spark Cluster]
        │                                │
        ├─► Read S3 images               │
        ├─► Extract metadata ───────────►│
        ├─► Calculate stats              │
        └─► Write CSV to S3              │
                        │
                        ▼
                 Step COMPLETED
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   RÉCUPÉRATION (Local)                          │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
              [Download from S3]
              aws s3 cp ...
                        │
                        ▼
                Analyse des résultats
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NETTOYAGE (AWS)                              │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
              terminate_cluster.sh
                        │
                        ▼
              Cluster TERMINATED
```

## 📋 Étapes détaillées

### 1. PRÉPARATION

#### 1.1 Configuration initiale

```bash
cd traitement/etape_1
nano config/config.sh
```

**Variables à modifier** :
- `S3_BUCKET` : Nom de votre bucket S3
- `EC2_KEY_NAME` : Nom de votre clé SSH EC2
- `MASTER_SECURITY_GROUP` : ID du security group master
- `SLAVE_SECURITY_GROUP` : ID du security group slave
- `EC2_SUBNET` : ID du subnet VPC
- `IAM_SERVICE_ROLE` : ARN du rôle EMR_DefaultRole
- `IAM_INSTANCE_PROFILE` : Nom du instance profile
- `IAM_AUTOSCALING_ROLE` : ARN du rôle d'auto-scaling

#### 1.2 Vérification de la configuration

```bash
./scripts/verify_setup.sh
```

**Vérifications effectuées** :
1. ✅ Région AWS (Europe pour GDPR)
2. ✅ Credentials AWS valides
3. ✅ Bucket S3 existe et accessible
4. ✅ Données d'entrée présentes (fichiers .jpg)
5. ✅ Clé SSH existe dans EC2
6. ✅ Rôles IAM configurés

#### 1.3 Upload des scripts

```bash
./scripts/upload_scripts.sh
```

**Fichiers uploadés** :
1. `install_dependencies.sh` → `s3://bucket/scripts/`
2. `read_fruits_data.py` → `s3://bucket/scripts/`

---

### 2. CRÉATION DU CLUSTER

#### 2.1 Lancement de la création

```bash
./scripts/create_cluster.sh
```

**Paramètres du cluster** :
- Nom : `p11-fruits-etape1`
- Version EMR : `7.11.0`
- Applications : Spark, Hadoop
- Master : 1x m5.xlarge
- Core : 2x m5.xlarge
- Bootstrap : `install_dependencies.sh`
- Auto-terminaison : 4h

**Sortie** :
```
📋 Cluster ID: j-XXXXXXXXXXXXX
💾 Cluster ID sauvegardé dans: cluster_id.txt
```

#### 2.2 Surveillance du démarrage

```bash
./scripts/monitor_cluster.sh
```

**États du cluster** :
```
[08:00:00] 🟡 STARTING - Démarrage des instances EC2...
[08:05:00] 🟡 BOOTSTRAPPING - Installation des dépendances Python...
[08:10:00] 🟢 RUNNING - Configuration en cours...
[08:15:00] ✅ WAITING - Cluster prêt à l'emploi !
```

**Durée totale** : ~10-15 minutes

---

### 3. EXÉCUTION DU JOB PYSPARK

#### 3.1 Soumission du step

```bash
./scripts/submit_job.sh
```

**Commande Spark Submit** :
```bash
spark-submit \
  --deploy-mode cluster \
  --master yarn \
  --conf spark.executorEnv.PYTHONHASHSEED=0 \
  s3://bucket/scripts/read_fruits_data.py \
  s3://bucket/data/fruits-360/ \
  s3://bucket/output/etape_1/
```

**Sortie** :
```
📋 Step ID: s-XXXXXXXXXXXXX
💾 Step ID sauvegardé dans: step_id.txt
```

#### 3.2 Exécution distribuée

**Sur le Master (Driver)** :
1. Télécharge `read_fruits_data.py` depuis S3
2. Initialise SparkSession
3. Coordonne les Executors

**Sur les Core Nodes (Executors)** :
1. Lisent les partitions d'images depuis S3
2. Exécutent les transformations (map, filter, groupBy)
3. Écrivent les résultats partitionnés

**Pipeline de traitement** :
```python
# 1. Lecture (binaryFile)
df_files = spark.read.format("binaryFile").load("s3://...")

# 2. Extraction métadonnées (regex)
df_metadata = df_files.select(
    regexp_extract(col("path"), r"/([^/]+)/[^/]+\.jpg$", 1).alias("label"),
    ...
)

# 3. Statistiques (groupBy)
df_stats = df_metadata.groupBy("split", "label").count()

# 4. Sauvegarde (CSV)
df_metadata.coalesce(1).write.csv("s3://...")
```

#### 3.3 Surveillance de l'exécution

```bash
# Option 1 : Surveillance continue
watch -n 10 'aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query "Step.Status.State" --output text'

# Option 2 : Vérification ponctuelle
aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1
```

**États du step** :
```
PENDING → RUNNING → COMPLETED (ou FAILED)
```

**Durée** : 2-5 minutes

---

### 4. RÉCUPÉRATION DES RÉSULTATS

#### 4.1 Lister les résultats

```bash
aws s3 ls s3://bucket/output/etape_1/ --recursive --region eu-west-1
```

**Résultats attendus** :
```
metadata_202(1118_083045/
├── _SUCCESS
└── part-00000-xxx.csv

stats_20251118_083045/
├── _SUCCESS
└── part-00000-xxx.csv
```

#### 4.2 Télécharger les résultats

```bash
mkdir -p results
aws s3 cp s3://bucket/output/etape_1/ ./results/ --recursive --region eu-west-1
```

#### 4.3 Analyse des résultats

**metadata CSV** :
```csv
s3_path,label,filename,split,modification_time,file_size_bytes
s3://.../Training/Apple_Braeburn/image_001_100.jpg,Apple_Braeburn,image_001_100.jpg,Training,2025-01-15 10:23:45,5432
...
```

**stats CSV** :
```csv
split,label,count
Training,Apple_Braeburn,492
Training,Banana,1000
Test,Apple_Braeburn,164
...
```

---

### 5. NETTOYAGE

#### 5.1 Terminaison du cluster

```bash
./scripts/terminate_cluster.sh
# Confirmer avec: oui
```

**Important** : Toujours terminer le cluster pour éviter des frais !

#### 5.2 Nettoyage complet (optionnel)

```bash
./scripts/cleanup.sh
```

**Options proposées** :
1. Terminer le cluster (si actif)
2. Supprimer les données de sortie S3
3. Supprimer les logs EMR S3
4. Supprimer les fichiers locaux de tracking

---

## 🔄 Workflow alternatifs

### Workflow de développement (itératif)

```bash
# 1. Modifier le script PySpark
nano scripts/read_fruits_data.py

# 2. Uploader la nouvelle version
./scripts/upload_scripts.sh

# 3. Soumettre un nouveau step (cluster déjà actif)
./scripts/submit_job.sh

# 4. Vérifier les résultats
aws s3 ls s3://bucket/output/etape_1/ --recursive

# 5. Répéter 1-4 jusqu'à satisfaction
```

### Workflow de debugging

```bash
# 1. Job échoué (FAILED)
aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1

# 2. Consulter les logs
aws s3 ls s3://bucket/logs/emr/containers/$(cat cluster_id.txt)/ --recursive

# 3. Télécharger les logs
aws s3 cp s3://bucket/logs/emr/containers/$(cat cluster_id.txt)/ ./logs/ --recursive

# 4. Analyser stderr et stdout
grep -r "ERROR" logs/
grep -r "Exception" logs/

# 5. Corriger le script et re-tester
```

### Workflow de production (automatisé)

```bash
# Script bash complet pour automatisation
#!/bin/bash
set -e

cd traitement/etape_1

# 1. Vérification
./scripts/verify_setup.sh || exit 1

# 2. Upload
./scripts/upload_scripts.sh

# 3. Création cluster
./scripts/create_cluster.sh

# 4. Attente (polling)
while [ "$(aws emr describe-cluster --cluster-id $(cat cluster_id.txt) --region eu-west-1 --query 'Cluster.Status.State' --output text)" != "WAITING" ]; do
    sleep 30
done

# 5. Soumission job
./scripts/submit_job.sh

# 6. Attente job
while [ "$(aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query 'Step.Status.State' --output text)" == "RUNNING" ]; do
    sleep 30
done

# 7. Vérification succès
STEP_STATE=$(aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query 'Step.Status.State' --output text)
if [ "$STEP_STATE" != "COMPLETED" ]; then
    echo "Job failed!"
    exit 1
fi

# 8. Téléchargement résultats
mkdir -p results
aws s3 cp s3://bucket/output/etape_1/ ./results/ --recursive

# 9. Terminaison cluster
./scripts/terminate_cluster.sh

echo "Pipeline completed successfully!"
```

---

## 📊 Métriques et KPIs

### Performance

- **Temps de création cluster** : 10-15 min
- **Temps d'exécution job** : 2-5 min (155k images)
- **Débit lecture S3** : ~1000 images/sec
- **Débit écriture S3** : ~500 MB/sec

### Coûts

- **Coût cluster/heure** : ~0.52€
- **Coût d'un run complet** : ~0.17€ (20 min)
- **Stockage S3** : ~0.02€/mois (1 GB)

### Fiabilité

- **Taux de succès** : >95% (si configuration correcte)
- **Causes d'échec** :
  - Bootstrap échoue (5%)
  - Erreur dans le script PySpark (3%)
  - Timeout réseau S3 (2%)

---

## 🎓 Best Practices

1. **Toujours vérifier la configuration** avant de créer le cluster (`verify_setup.sh`)
2. **Utiliser l'auto-terminaison** pour éviter les oublis
3. **Surveiller les coûts** régulièrement (AWS Cost Explorer)
4. **Logs** : Toujours activer et consulter en cas d'échec
5. **Versionning** : Garder l'historique des scripts sur Git
6. **Tests locaux** : Tester PySpark localement avant EMR (si possible)
7. **Sauvegardes S3** : Toujours sauvegarder les résultats critiques
8. **Documentation** : Mettre à jour la doc après chaque modification

---

## 📚 Ressources supplémentaires

- [README.md](../README.md) : Documentation complète
- [QUICKSTART.md](QUICKSTART.md) : Guide de démarrage rapide
- [ARCHITECTURE.md](ARCHITECTURE.md) : Architecture technique détaillée
