# Démarrage Rapide - Étape 2

## 🚀 Pipeline complet en 7 commandes

```bash
cd traitement/etape_2

# 1. Vérifier la configuration
./scripts/verify_setup.sh

# 2. Uploader les scripts sur S3
./scripts/upload_scripts.sh

# 3. Créer le cluster EMR (~10-15 min)
./scripts/create_cluster.sh

# 4. Attendre que le cluster soit prêt
./scripts/monitor_cluster.sh

# 5. Soumettre le job (choisir mode: mini/apples/full)
./scripts/submit_job.sh

# 6. Télécharger les résultats
./scripts/download_results.sh

# 7. Télécharger et inspécter les logs
./scripts/download_and_inspect_logs.sh

# 8. ⚠️ IMPORTANT: Arrêter le cluster !
./scripts/terminate_cluster.sh
```

---

## 📁 Structure du projet

```
traitement/etape_2/
├── config/
│   └── config.sh              # Configuration centralisée
├── scripts/
│   ├── verify_setup.sh        # Vérifications pré-vol
│   ├── upload_scripts.sh      # Upload sur S3
│   ├── create_cluster.sh      # Création cluster EMR
│   ├── monitor_cluster.sh     # Surveillance démarrage
│   ├── submit_job.sh          # Soumission job PySpark
│   ├── download_results.sh    # Téléchargement résultats
│   ├── terminate_cluster.sh   # Arrêt du cluster
│   ├── cleanup.sh             # Nettoyage complet
│   ├── download_and_inspect_logs.sh  # Inspection logs
│   ├── install_dependencies.sh       # Bootstrap (TensorFlow, etc.)
│   └── process_fruits_data.py        # Script PySpark principal
├── docs/
│   ├── README.md              # Documentation complète
│   ├── WORKFLOW.md            # Workflow détaillé
│   └── ARCHITECTURE.md        # Architecture technique
├── output/                    # Résultats téléchargés (local)
└── logs/                      # Logs téléchargés (local)
```

---

## ⚙️ Configuration

Éditer [config/config.sh](config/config.sh) si nécessaire:

```bash
# Paramètres principaux
S3_BUCKET="oc-p11-fruits-david-scanu"
CLUSTER_NAME="p11-fruits-etape2"
MASTER_INSTANCE_TYPE="m5.2xlarge"
CORE_INSTANCE_COUNT="2"
PCA_COMPONENTS="50"
DEFAULT_MODE="mini"
```

---

## 🎯 Modes de traitement

Lors de `submit_job.sh`, choisir:

- **1) mini** : 300 images → ~2-5 min
- **2) apples** : ~6,400 images → ~15-30 min
- **3) full** : ~67,000 images → ~2-3h

---

## 💰 Coûts

- **Cluster EMR** : ~0.80-1.00 €/h
- **Auto-terminaison** : 4h d'inactivité
- ⚠️ **TOUJOURS** terminer manuellement après usage !

---

## 📊 Résultats

Après `download_results.sh`, vérifier:

```bash
tree output/ -L 2

# Structure attendue:
output/
├── features/
│   ├── parquet/    # Features 1280D (Parquet)
│   └── csv/        # Features 1280D (CSV)
├── pca/
│   ├── parquet/    # PCA 50D (Parquet)
│   └── csv/        # PCA 50D (CSV)
├── metadata/       # path, label
├── model_info/     # Variance PCA, stats
└── errors/         # Rapport d'erreurs (si présent)
```

---

## 🐛 Troubleshooting

### Problème : Job échoue

```bash
# Télécharger et inspecter les logs
./scripts/download_and_inspect_logs.sh

# Chercher les erreurs
cat logs/stderr | grep -i "error"
```

### Problème : Cluster ne démarre pas

```bash
# Vérifier l'état
aws emr describe-cluster --cluster-id $(cat cluster_id.txt) --region eu-west-1

# Vérifier les logs bootstrap
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/
```

### Problème : Coûts élevés

```bash
# Vérifier les instances EC2 actives
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" \
  --output table

# Terminer immédiatement
./scripts/terminate_cluster.sh
```

---

## 📚 Documentation complète

- **[docs/README.md](docs/README.md)** : Documentation détaillée
- **[docs/WORKFLOW.md](docs/WORKFLOW.md)** : Workflow pas-à-pas
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** : Architecture technique

---

## 🔧 Commandes utiles

```bash
# Voir la configuration
source config/config.sh && show_config

# État du cluster
aws emr describe-cluster --cluster-id $(cat cluster_id.txt) --region eu-west-1

# État du job
aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1

# Lister les résultats S3
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/output/ --recursive --human-readable

# Console AWS
echo "https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/$(cat cluster_id.txt)"
```

---

**Projet** : OpenClassrooms AI Engineer P11
**Objectif** : Feature Extraction (MobileNetV2) + PCA sur AWS EMR
**Dataset** : Fruits-360 (~67,000 images)
