# Projet 11 : Réalisez un traitement dans un environnement Big Data sur le Cloud

# Projet Big Data - Classification de Fruits

[![Python](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python&logoColor=white)](https://www.python.org/)
[![PySpark](https://img.shields.io/badge/PySpark-3.x-E25A1C?logo=apachespark&logoColor=white)](https://spark.apache.org/)
[![AWS](https://img.shields.io/badge/AWS-EMR%20%7C%20S3-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.16-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/)
[![Dataset](https://img.shields.io/badge/Dataset-Fruits--360-green?logo=kaggle&logoColor=white)](https://www.kaggle.com/datasets/moltean/fruits)

> 🎓 OpenClassrooms • Parcours [AI Engineer](https://openclassrooms.com/fr/paths/795-ai-engineer) | 👋 *Étudiant* : [David Scanu](https://www.linkedin.com/in/davidscanu14/)

---

<p align="center">
  <img src="images/p11-cover-large-01.jpg" alt="Couverture : Pipeline Big Data Fruits - MobileNetV2 + PCA" style="max-width:100%;height:auto;">
</p>

## 📋 Description

Projet de mise en place d'une **architecture Big Data dans le cloud** pour le traitement d'images de fruits. Développé pour **"Fruits!"**, une start-up AgriTech qui développe des robots cueilleurs intelligents pour préserver la biodiversité des fruits.

Ce projet implémente un **pipeline PySpark distribué dans le cloud** sur **AWS EMR** pour :
- Extraire des features d'images avec **MobileNetV2** (Transfer Learning)
- Réduire les dimensions avec **PCA** (1280 → 50 composantes)
- Traiter jusqu'à **~67,000 images** en mode distribué

---

## 🎯 Livrables finaux

### ✅ Code & Scripts

| Livrable | Localisation | Description |
|----------|--------------|-------------|
| **Présentation** | [Google Slides](https://docs.google.com/presentation/d/1YH2OK8qeV0dBRjcsCU09T9dZZ977ExN2fQvkeF7-Iv0/edit?usp=sharing) | Support de présentation du projet |
| **Notebook local corrigé et fonctionnel** | [p11-david-scanu-local-development.ipynb](notebooks/p11-david-scanu-local-development.ipynb) | Développement local du pipeline PySpark avec broadcast TensorFlow et PCA |
| **Script PySpark** | [process_fruits_data.py](traitement/etape_2/scripts/process_fruits_data.py) | Pipeline PySpark production-ready (MobileNetV2 + PCA) |
| **Échantillon Résultats PCA** | [pca_sample_results.csv](traitement/etape_2/outputs/output-full/pca_sample_results.csv) | Chemins S3, Labels, Arrays PCA (320 images) |

### 📦 Stockage S3

#### Structure des données

```
s3://oc-p11-fruits-david-scanu/
│
├── data/raw/Training/            # Images source (67,000 images)
│   ├── Apple Braeburn/
│   │   ├── 0_100.jpg
│   │   ├── 1_100.jpg
│   │   └── ...
│   ├── Banana/
│   └── ... (224 classes)
│
├── read_fruits_data/              # Outputs Étape 1
│   ├── scripts/                   # Scripts uploadés
│   ├── logs/emr/                  # Logs EMR
│   └── output/etape_1/            # Métadonnées + stats
│
└── process_fruits_data/           # Outputs Étape 2 ⭐
    ├── scripts/                   # Scripts uploadés
    ├── logs/emr/                  # Logs EMR
    └── outputs/                   # Résultats (features, PCA, etc.)
        ├── output-mini/
        ├── output-apples/
        └── output-full/
            ├── features/          # Features 1280D
            ├── pca/               # PCA 50D
            ├── metadata/          # Labels
            └── model_info/        # Variance PCA
```

#### Exemples de chemins

- **Image** : `s3://oc-p11-fruits-david-scanu/data/raw/Training/Apple Braeburn/0_100.jpg`
- **Features** : `s3://oc-p11-fruits-david-scanu/process_fruits_data/outputs/output-full/features/`
- **PCA** : `s3://oc-p11-fruits-david-scanu/process_fruits_data/outputs/output-full/pca/`

### Architecture GDPR-compliant

- Région `eu-west-1`

---

## 📊 Jeu de données

**Fruits-360 Dataset**

- **Créateur** : Mihai Oltean (2017-)
- **Taille** : 155,491 images réparties en 226 classes (version 100x100)
- **Format** : JPG, 100x100 pixels (standardisé)
- **Contenu** : Fruits, légumes, noix et graines avec de multiples variétés
  - 29 types de pommes
  - 12 variétés de cerises
  - 19 types de tomates
  - Et bien d'autres...
- **Méthode de capture** : Images capturées par rotation (20s à 3 rpm) sur fond blanc
- **Licence** : CC BY-SA 4.0

**Sources** :
- [Kaggle](https://www.kaggle.com/datasets/moltean/fruits)
- [Téléchargement direct](https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip)

---

## 📖 Étapes du projet

Ce projet a été développé en plusieurs étapes pour migrer progressivement le traitement des données du local vers le cloud AWS EMR.

### 🔬 Étape 0 : Développement local et amélioration du notebook de l'alternant

**Objectif** : Comprendre et améliorer le code de base avant la migration cloud

- 📓 **Notebook local fonctionnel créé** : [p11-david-scanu-local-development.ipynb](notebooks/p11-david-scanu-local-development.ipynb)
- ✅ **Analyse du travail de l'alternant** : Étude du notebook PySpark existant : [P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb](notebooks/alternant/P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb)
- ✅ **Corrections et améliorations** :
  - Ajout du broadcast des poids TensorFlow (absent dans le notebook de l'alternant)
  - Implémentation de la réduction PCA avec MLlib (manquante)
  - Tests locaux du pipeline complet
  - Validation de la logique avant déploiement cloud
- 🎯 **Livrable** : Notebook fonctionnel avec pipeline end-to-end testé localement

> 💡 **Approche** : Cette étape a permis de valider la logique métier en local (Spark standalone) avant de passer à l'infrastructure cloud coûteuse.

---

### ✅ Étape 1 : Validation de l'infrastructure cloud

**Objectif** : Valider la lecture/écriture S3 et tester le cluster EMR avec un pipeline simple

- ✅ **Pipeline de test** :
  - Lecture de ~67,000 images depuis S3
  - Extraction des métadonnées (path, label, classe)
  - Calcul de statistiques par classe
  - Écriture des résultats sur S3 (CSV)
- 🏗️ **Infrastructure AWS déployée** :
  - Création du cluster EMR (Master + 2 Core nodes)
  - Configuration S3 (bucket, IAM roles, security groups)
  - Scripts d'automatisation bash (11 scripts)
  - Bootstrap action pour installer les dépendances Python
- 🎯 **Validation** :
  - ✅ Lecture/écriture S3 fonctionnelle
  - ✅ PySpark distribué opérationnel
  - ✅ Bootstrap action testée
  - ✅ Gestion des coûts (auto-terminaison)

**Résultats** :
- Durée : ~2-5 min (67,000 images)
- Output : Métadonnées + statistiques CSV
- Coût : ~0.05€

> 💡 **Importance** : Cette étape a validé l'infrastructure AWS avant d'ajouter la complexité du traitement TensorFlow + PCA.

**Documentation** : [traitement/etape_1/docs](traitement/etape_1/docs)

---

### 🎯 Étape 2 : Pipeline complet Feature Extraction + PCA

**Objectif** : Implémenter le **pipeline big data complet** avec TensorFlow et réduction de dimensions PCA

- 🧠 **Feature Extraction** :
  - MobileNetV2 pré-entraîné (Transfer Learning)
  - Broadcast des poids TensorFlow (~14 MB) vers tous les workers
  - Pandas UDF pour traitement distribué
  - Extraction de 1280 features par image
- 📉 **Réduction PCA** :
  - PCA avec MLlib (1280 → 50 dimensions)
  - Variance conservée : **83-93%** (selon le mode)
  - Sauvegarde du modèle PCA pour réutilisation
- 🎯 **Modes de traitement validés** :
  - **MINI** (300 images) : 3min 34s, 92.93% variance, ~0.50€
  - **APPLES** (6,404 images) : ~20-25 min, 83.40% variance, ~0.40€
  - **FULL** (67,692 images) : 83 min (1h23), 71.88% variance, ~1.60€ ✅

#### Architecture du pipeline

```
Images S3 (JPG)
    │
    ├─> [1] Chargement (binaryFile)
    │
    ├─> [2] MobileNetV2 Feature Extraction
    │       • Broadcast des poids (~14 MB)
    │       • Pandas UDF (traitement distribué)
    │       • Output: 1280 features par image
    │
    ├─> [3] PCA (MLlib)
    │       • Réduction: 1280 → 50 dimensions
    │       • Variance conservée: 92.93%
    │
    └─> [4] Sauvegarde S3 (Parquet + CSV)
            • features/ (1280D)
            • pca/ (50D)
            • metadata/ (labels)
            • model_info/ (variance)
```

#### Optimisations appliquées

- ✅ **Broadcast TensorFlow** : -90% transferts réseau
- ✅ **Pandas UDF + Arrow** : 10-100× plus rapide
- ✅ **Parquet** : -50% stockage vs CSV
- ✅ **PCA 50D** : -96% dimensions (1280 → 50)

#### Documentation 

- **Documentation complète** : [traitement/etape_2/docs](traitement/etape_2/docs)
- **Quickstart** : [QUICKSTART.md](traitement/etape_2/QUICKSTART.md)
- **Readme** : [README.md](traitement/etape_2/docs/README.md)
- **Workflow** : [WORKFLOW.md](traitement/etape_2/docs/WORKFLOW.md)
- **Architecture** : [ARCHITECTURE.md](traitement/etape_2/docs/ARCHITECTURE.md)

---

## Résultats validés

### 🎯 Démarche incrémentale

Le pipeline a été validé avec une approche progressive en 3 modes :

- **MINI** (300 images) : Validation rapide du pipeline (~3-5 min, ~0.50€)
- **APPLES** (6,404 images) : Test sur un sous-ensemble homogène (~20-25 min, ~0.40€)
- **FULL** (67,000 images) : Production complète avec tous les fruits (~2-3h, ~1.60€)

Cette démarche permet de :
- Valider rapidement les modifications (mode MINI)
- Tester la scalabilité sur des données réelles (mode APPLES)
- Passer en production en toute confiance (mode FULL)

### 📦 Outputs générés

Le pipeline PySpark génère plusieurs types de fichiers structurés :

```
s3://oc-p11-fruits-david-scanu/process_fruits_data/outputs/output-{mode}/
├── features/          # Features brutes (1280D) - MobileNetV2
│   ├── parquet/       # Format optimisé pour Spark
│   └── csv/           # Format lisible
├── pca/               # Features réduites (50D) - PCA
│   ├── parquet/       # Compression ~92-96% vs features brutes
│   └── csv/
├── metadata/          # Chemins S3 + labels des images
├── model_info/        # Informations PCA et variance par composante
│   ├── model_info_*   # JSON avec variance totale et config
│   └── variance_*     # CSV avec variance de chaque composante
└── errors/            # Log des erreurs (absent si 100% succès)
```

**Tailles typiques** :
- **MINI** : ~6.4 MB total (features: 5.9 MB, pca: 456 KB)
- **APPLES** : ~125-145 MB total (features: 115-130 MB, pca: 8-10 MB)
- **FULL** : ~1.7-2.0 GB total (features: 1.5-1.8 GB, pca: 150-200 MB) ✅

### 💾 Téléchargement des résultats

Pour récupérer les résultats en local :

```bash
cd traitement/etape_2
./scripts/download_results.sh [mode]
```

**Exemples** :
```bash
./scripts/download_results.sh mini     # Télécharge résultats MINI
./scripts/download_results.sh apples   # Télécharge résultats APPLES
./scripts/download_results.sh          # Utilise le dernier mode exécuté
```

Les résultats sont sauvegardés dans `traitement/etape_2/outputs/output-{mode}/` avec la même structure qu'en S3.

### 📊 Comparaison des modes

| Métrique | MINI | APPLES | FULL |
|----------|------|--------|------|
| **Images traitées** | 300 (100%) | 6,404 (100%) | **67,692 (100%)** ✅ |
| **Classes traitées** | ~3-5 variétés | ~29 variétés pommes | **131 classes** ✅ |
| **Temps d'exécution** | 3min 34s | ~20-25 min | **83 min (1h23)** ✅ |
| **Débit** | ~84 img/min | ~260-320 img/min | **~814 img/min** ✅ |
| **Variance PCA (50 comp.)** | **92.93%** | **83.40%** | **71.88%** ✅ |
| **Taux d'erreur** | 0% | 0% | **0%** ✅ |
| **Coût estimé** | ~0.50€ | ~0.40€ | **~1.60€** ✅ |
| **Documentation des résultats** | [MINI](traitement/etape_2/outputs/output-mini/RESULTATS-MINI.md) | [APPLES](traitement/etape_2/outputs/output-apples/RESULTATS-APPLES.md) | **[FULL](traitement/etape_2/outputs/output-full/RESULTATS-FULL.md)** ✅ |
| **Notebook** | [Notebook](traitement/etape_2/outputs/output-mini/resultats-mini.ipynb) | [Notebook](traitement/etape_2/outputs/output-apples/resultats-apples.ipynb) | **[Notebook](traitement/etape_2/outputs/output-full/resultats-full.ipynb)** ✅ |

**Observations** :
- **Scalabilité exceptionnelle** : 226× plus d'images (vs MINI) mais seulement 23× plus de temps
- **Débit impressionnant** : ×9.7 entre MINI et FULL grâce au parallélisme Spark
- La variance PCA est plus faible sur FULL (71.88%) car **diversité maximale** avec 131 classes de fruits
- **Pipeline production-ready validé** : 0 erreur sur 67,692 images en 83 minutes
- Coût très raisonnable : ~1.60€ pour traiter l'ensemble complet du dataset

> 🚀 **Accomplissement majeur** : Pipeline production-ready avec support multi-mode, toutes les optimisations Big Data et conformité GDPR.

---

## 🎯 Objectifs réalisés

- ✅ **Pipeline PySpark complet** avec broadcast des poids TensorFlow
- ✅ **Réduction de dimension PCA** implémentée avec MLlib
- ✅ **Migration cloud AWS** (EMR + S3)
- ✅ **Conformité GDPR** (région eu-west-1)
- ✅ **Architecture production-ready** avec scripts d'automatisation

> ⚠️ **Note** : Pas d'entraînement de modèle. L'objectif est de mettre en place les briques de traitement **scalables**.

## 🛠️ Stack technique

| Technologie | Version | Usage |
|-------------|---------|-------|
| **PySpark** | 3.5.x | Traitement distribué |
| **AWS EMR** | 7.11.0 | Cluster Spark managé |
| **AWS S3** | - | Stockage cloud (GDPR) |
| **TensorFlow** | 2.16.1 | MobileNetV2 (features) |
| **Python** | 3.10+ | Scripting & PySpark |
| **scikit-learn** | 1.4.0 | Validation PCA |

## 📁 Structure du projet

```
oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/
│
├── traitement/                    # 🎯 Pipeline de traitement (PRINCIPAL)
│   ├── etape_1/                   # Étape 1: Read & Validate Data
│   │   ├── config/                # Configuration centralisée
│   │   ├── scripts/               # Scripts bash + PySpark
│   │   ├── docs/                  # Documentation complète
│   │   └── README.md
│   │
│   └── etape_2/                   # Étape 2: Feature Extraction + PCA ⭐
│       ├── config/                # Configuration (m5.2xlarge, PCA 50)
│       ├── scripts/               # 11 scripts bash + process_fruits_data.py
│       ├── docs/                  # README, WORKFLOW, ARCHITECTURE, RESULTATS
│       ├── outputs/               # Résultats téléchargés (local)
│       ├── logs/                  # Logs EMR téléchargés (local)
│       └── QUICKSTART.md          # Démarrage rapide
│
├── notebooks/                     # Notebooks de développement local
│   ├── p11-emr-fruits-pca.ipynb   # Notebook fonctionnel (base étape 2)
│   └── alternant/                 # Travail de l'alternant (référence)
│
├── scripts/                       # Scripts utilitaires
│   └── aws_audit.sh               # Audit coûts AWS
│
└── README.md                      # Ce fichier
```

### 🗂️ Navigation rapide

| Dossier | Description | Liens |
|---------|-------------|-------|
| **[traitement/etape_1/](traitement/etape_1/)** | Pipeline de lecture S3 (validation) | [README](traitement/etape_1/docs/README.md) |
| **[traitement/etape_2/](traitement/etape_2/)** | Pipeline MobileNetV2 + PCA ⭐ | [README](traitement/etape_2/docs/README.md) • [QUICKSTART](traitement/etape_2/QUICKSTART.md) |
| **[notebooks/](notebooks/)** | Dev local + référence alternant | [Notebook PCA](notebooks/p11-emr-fruits-pca.ipynb) |

---

## ⚡ Démarrage rapide

### Prérequis

- AWS CLI configuré
- Accès S3 : `oc-p11-fruits-david-scanu`
- Clé SSH EMR : `emr-p11-fruits-key-codespace`

### Exécution Étape 2 (7 commandes)

```bash
cd traitement/etape_2

# 1. Vérifications
./scripts/verify_setup.sh

# 2. Upload scripts S3
./scripts/upload_scripts.sh

# 3. Créer cluster (~10-15 min)
./scripts/create_cluster.sh

# 4. Surveiller
./scripts/monitor_cluster.sh

# 5. Soumettre job
./scripts/submit_job.sh  # Choisir mode: mini/apples/full

# 6. Télécharger résultats
./scripts/download_results.sh

# 7. ⚠️ ARRÊTER LE CLUSTER
./scripts/terminate_cluster.sh
```

**Détails** : [QUICKSTART.md](traitement/etape_2/docs/QUICKSTART.md)

> ⚠️ **Gestion des coûts** : Toujours terminer le cluster après usage !

---


## 💰 Coûts AWS (réels)

### Coûts totaux du projet (24 octobre - 30 novembre 2025)

**Total : $17.39 (~16.00€)**

| Service | Coût | % |
|---------|------|---|
| **Compute (EMR + EC2)** | $12.31 (~11.33€) | 70.8% |
| - EC2 Instances | $9.90 (~9.11€) | 56.9% |
| - Elastic MapReduce | $2.41 (~2.22€) | 13.9% |
| **Storage (S3)** | $1.63 (~1.50€) | 9.4% |
| **Networking (VPC)** | $0.20 (~0.18€) | 1.1% |
| **Other (EC2-Other)** | $0.28 (~0.25€) | 1.6% |
| **Tax** | $2.88 (~2.65€) | 16.6% |
| **Monitoring** | $0.09 (~0.08€) | 0.5% |

### Répartition par phase du projet

| Phase | Durée | Coût estimé |
|-------|-------|-------------|
| **Étape 1** (validation) | ~5 min | ~$0.06 (~0.05€) |
| **Étape 2 (MINI)** | ~30 min | ~$0.54 (~0.50€) |
| **Étape 2 (APPLES)** | ~30 min | ~$0.43 (~0.40€) |
| **Étape 2 (FULL)** | ~1h40 | ~$1.74 (~1.60€) |
| **Développement & tests** | - | ~$14.65 (~13.50€) |
| **TOTAL projet** | - | **$17.39 (~16.00€)** |

**Auto-terminaison** : 4h idle timeout (sécurité anti-coûts)

> 💡 **Insight** : Les coûts de production (mode FULL) ne représentent que ~10% des coûts totaux. La majorité des dépenses provient du développement et des tests, ce qui démontre l'efficacité de l'approche itérative et de l'optimisation du pipeline final.

### Script d'analyse des coûts AWS

Un script Python d'analyse des coûts est disponible pour analyser les exports CSV du Cost Explorer AWS.

**Fichier** : [aws/analyze_costs.py](aws/analyze_costs.py)

**Usage** :

```bash
# Analyser le fichier CSV le plus récent dans aws/
python3 aws/analyze_costs.py

# Ou spécifier un fichier CSV
python3 aws/analyze_costs.py aws/2025-12-01-aws-costs-report-from-2025-10-24-to-2025-11-30.csv
```

**Fonctionnalités** :
- Analyse détaillée des coûts par service AWS
- Répartition quotidienne des dépenses
- Calcul automatique des pourcentages
- Conversion USD → EUR approximative
- Insights sur les postes de coûts principaux

**Export Cost Explorer** : Pour obtenir un nouveau rapport CSV, utilisez la console AWS Cost Explorer ou l'API.

---

## 📚 Ressources & Documentation

### Documentation du projet

| Resource | Lien |
|----------|------|
| **Documentation** | [traitement/etape_2/docs/](traitement/etape_2/docs/) |
| **Quickstart** | [traitement/etape_2/QUICKSTART.md](traitement/etape_2/QUICKSTART.md) |
| **Résultats validés** | [traitement/etape_2/docs/RESULTATS.md](traitement/etape_2/docs/RESULTATS.md) |

| Document | Lien | Contenu |
|----------|------|---------|
| **README Étape 2** | [README.md](traitement/etape_2/docs/README.md) | Documentation complète |
| **Quickstart** | [QUICKSTART.md](traitement/etape_2/docs/QUICKSTART.md) | Démarrage en 7 commandes |
| **Workflow** | [WORKFLOW.md](traitement/etape_2/docs/WORKFLOW.md) | Procédure détaillée |
| **Architecture** | [ARCHITECTURE.md](traitement/etape_2/docs/ARCHITECTURE.md) | Architecture technique |

### Références externes

- [AWS EMR Getting Started](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-gs.html)
- [Troubleshoot Python Libraries on EMR](https://repost.aws/fr/knowledge-center/emr-troubleshoot-python-libraries)
- [Notebook alternant (référence)](https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/P8_Mode_ope%CC%81ratoire.zip)
- [Fruits-360 Dataset (Kaggle)](https://www.kaggle.com/datasets/moltean/fruits)

---

## 📅 Dates

- **Début** : 24 Octobre 2025
- **Étape 1 validée** : 13 Novembre 2025
- **Mode FULL validé** : 25 Novembre 2025
- **Soutenance validée** : 30 novembre 2025

---

## 🏆 Accomplissements

- ✅ **Pipeline PySpark** complet et scalable
- ✅ **Architecture AWS** production-ready (EMR + S3)
- ✅ **Broadcast TensorFlow** pour optimisation réseau
- ✅ **PCA MLlib** avec 92.93% de variance conservée
- ✅ **Scripts d'automatisation** (11 scripts bash)
- ✅ **Documentation exhaustive** (4 documents techniques)
- ✅ **Conformité GDPR** (région eu-west-1)
- ✅ **Gestion des coûts** (< 3€ total projet)

**🚀 Production-ready | 📊 Big Data optimisé | 🔐 GDPR compliant**

---

## 👤 Auteur

> 🎓 OpenClassrooms • Parcours [AI Engineer](https://openclassrooms.com/fr/paths/795-ai-engineer) | 👋 *Étudiant* : [David Scanu](https://www.linkedin.com/in/davidscanu14/)
