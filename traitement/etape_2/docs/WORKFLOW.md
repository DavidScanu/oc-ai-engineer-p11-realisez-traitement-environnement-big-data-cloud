# Workflow Complet - Étape 2

Ce document décrit le workflow détaillé pour exécuter le pipeline de feature extraction et PCA sur AWS EMR.

---

## 📋 Table des matières

1. [Préparation](#1-préparation)
2. [Création du cluster](#2-création-du-cluster)
3. [Soumission du job](#3-soumission-du-job)
4. [Surveillance](#4-surveillance)
5. [Récupération des résultats](#5-récupération-des-résultats)
6. [Nettoyage](#6-nettoyage)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Préparation

### 1.1 Vérifier les prérequis

```bash
cd traitement/etape_2

# Vérifier la configuration AWS
aws sts get-caller-identity
# → Doit afficher votre Account ID

# Vérifier l'accès au bucket
aws s3 ls s3://oc-p11-fruits-david-scanu/data/raw/Training/ | head
# → Doit lister des dossiers de fruits
```

### 1.2 Éditer la configuration (optionnel)

```bash
# Ouvrir le fichier de configuration
vim config/config.sh

# Paramètres modifiables:
# - PCA_COMPONENTS (défaut: 50)
# - MINI_IMAGES_COUNT (défaut: 300)
# - SPARK_EXECUTOR_MEMORY (défaut: 8g)
# - Etc.
```

### 1.3 Vérification pré-vol

```bash
./scripts/verify_setup.sh
```

**Sortie attendue:**

```
==================================================
🔍 VÉRIFICATION DE LA CONFIGURATION - ÉTAPE 2
==================================================

🌍 [1/7] Vérification de la région AWS...
   ✅ Région: eu-west-1 (Europe - Conforme GDPR)

🔑 [2/7] Vérification des credentials AWS...
   ✅ Credentials valides (Account: 461506913677)

🪣 [3/7] Vérification du bucket S3...
   ✅ Bucket existe: oc-p11-fruits-david-scanu
   ✅ Région du bucket: eu-west-1

📂 [4/7] Vérification des données d'entrée...
   ✅ Données trouvées: des fichiers .jpg sont présents

📜 [5/7] Vérification des scripts sur S3...
   ❌ install_dependencies.sh manquant
   ❌ process_fruits_data.py manquant

   💡 Pour uploader les scripts:
      ./scripts/upload_scripts.sh

...
```

### 1.4 Upload des scripts sur S3

```bash
./scripts/upload_scripts.sh
```

**Sortie attendue:**

```
==================================================
📤 UPLOAD DES SCRIPTS SUR S3 - ÉTAPE 2
==================================================

📤 Upload de install_dependencies.sh...
✅ install_dependencies.sh uploadé

📤 Upload de process_fruits_data.py...
✅ process_fruits_data.py uploadé

📋 Vérification des fichiers sur S3:
2024-01-15 10:30:00    5.2 KiB install_dependencies.sh
2024-01-15 10:30:01   25.8 KiB process_fruits_data.py
```

**Vérification manuelle:**

```bash
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/scripts/
```

---

## 2. Création du cluster

### 2.1 Créer le cluster EMR

```bash
./scripts/create_cluster.sh
```

**Étapes du script:**

1. Affichage de la configuration
2. Estimation des coûts (~0.80€/h)
3. Demande de confirmation
4. Création du cluster AWS EMR
5. Sauvegarde du Cluster ID

**Sortie attendue:**

```
==================================================
🚀 CRÉATION DU CLUSTER EMR - ÉTAPE 2
==================================================
📋 CONFIGURATION P11 - ÉTAPE 2
===================================================
🌍 Région AWS: eu-west-1
🪣 Bucket S3: oc-p11-fruits-david-scanu
...
===================================================

💰 Coût estimé: ~0.80€/heure
⚠️  Auto-terminaison après 4h d'inactivité
⚠️  Pensez à terminer le cluster après usage !

Continuer ? (oui/non): oui

🔧 Création du cluster...

==================================================
✅ Cluster créé avec succès !
==================================================
📋 Cluster ID: j-2AXXXXXXXXXX

💾 Cluster ID sauvegardé dans: cluster_id.txt

🔍 Surveiller l'état du cluster:
   ./scripts/monitor_cluster.sh

🌐 Console AWS:
   https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/j-2AXXXXXXXXXX

⏰ Attendre ~10-15 minutes que l'état passe à 'WAITING'
==================================================
```

### 2.2 Surveiller le démarrage (optionnel)

```bash
./scripts/monitor_cluster.sh
```

**Progression typique:**

```
==================================================
🔍 SURVEILLANCE DU CLUSTER EMR - ÉTAPE 2
==================================================
📋 Cluster ID: j-2AXXXXXXXXXX
🌍 Région: eu-west-1

Appuyez sur Ctrl+C pour arrêter
==================================================

[10:32:15] 🟡 STARTING - Démarrage des instances EC2...
[10:32:45] 🟡 STARTING - Démarrage des instances EC2...
[10:33:15] 🟡 BOOTSTRAPPING - Installation TensorFlow, scikit-learn...
[10:33:45] 🟡 BOOTSTRAPPING - Installation TensorFlow, scikit-learn...
[10:34:15] 🟡 BOOTSTRAPPING - Installation TensorFlow, scikit-learn...
[10:34:45] 🟢 RUNNING - Configuration Spark en cours...
[10:35:15] 🟢 RUNNING - Configuration Spark en cours...
[10:35:45] ✅ WAITING - Cluster prêt à l'emploi !

==================================================
🎉 CLUSTER OPÉRATIONNEL
==================================================
📡 Master DNS: ec2-XX-XXX-XXX-XX.eu-west-1.compute.amazonaws.com

Prochaine étape:
   ./scripts/submit_job.sh

🌐 Console AWS:
   https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/j-2AXXXXXXXXXX
==================================================
```

**Durée typique:**
- STARTING → BOOTSTRAPPING : ~2-3 min
- BOOTSTRAPPING → RUNNING : ~5-8 min (installation TensorFlow)
- RUNNING → WAITING : ~2-3 min
- **Total : 10-15 minutes**

### 2.3 Vérification manuelle

```bash
# Vérifier l'état du cluster
aws emr describe-cluster \
  --cluster-id $(cat cluster_id.txt) \
  --region eu-west-1 \
  --query 'Cluster.Status.State' \
  --output text

# Doit afficher: WAITING
```

---

## 3. Soumission du job

### 3.1 Soumettre le job PySpark

```bash
./scripts/submit_job.sh
```

**Interaction:**

```
==================================================
🚀 SOUMISSION DU JOB PYSPARK - ÉTAPE 2
==================================================
📋 Cluster ID: j-2AXXXXXXXXXX
🐍 Script: process_fruits_data.py

🎯 Choisir le mode de traitement:
   1) mini   - 300 images (test rapide, ~2-5 min)
   2) apples - ~6,400 images de pommes (~15-30 min)
   3) full   - ~67,000 images complètes (~2-3h)

Mode [1-3, défaut=1]: 1
✅ Mode sélectionné: mini

🔍 Vérification de l'état du cluster...
📊 État du cluster: WAITING
✅ Cluster prêt à recevoir des jobs

📤 Soumission du step PySpark...
   - Input: s3://oc-p11-fruits-david-scanu/data/raw/
   - Output: s3://oc-p11-fruits-david-scanu/process_fruits_data/output/
   - Mode: mini
   - PCA Components: 50

==================================================
✅ JOB SOUMIS AVEC SUCCÈS
==================================================
📋 Step ID: s-3VXXXXXXXXXX

💾 Step ID sauvegardé dans: step_id.txt

🔍 Surveiller l'exécution:
   watch -n 10 'aws emr describe-step --cluster-id j-2AXXXXXXXXXX --step-id s-3VXXXXXXXXXX --region eu-west-1 --query "Step.Status"'

📊 État du step:
   aws emr describe-step --cluster-id j-2AXXXXXXXXXX --step-id s-3VXXXXXXXXXX --region eu-west-1 --query 'Step.Status.State' --output text

⏰ Durée estimée: 2-5 minutes
==================================================
```

### 3.2 Choix du mode

| Mode   | Commande rapide                    | Durée     |
|--------|------------------------------------|-----------|
| mini   | `echo "1" \| ./scripts/submit_job.sh` | 2-5 min   |
| apples | `echo "2" \| ./scripts/submit_job.sh` | 15-30 min |
| full   | `echo "3" \| ./scripts/submit_job.sh` | 2-3h      |

---

## 4. Surveillance

### 4.1 Surveiller l'état du step

```bash
# Commande simple
aws emr describe-step \
  --cluster-id $(cat cluster_id.txt) \
  --step-id $(cat step_id.txt) \
  --region eu-west-1 \
  --query 'Step.Status.State' \
  --output text

# Surveillance en temps réel (rafraîchissement toutes les 10s)
watch -n 10 'aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query "Step.Status"'
```

**États possibles:**

- `PENDING` : Step en attente
- `RUNNING` : Step en cours d'exécution
- `COMPLETED` : ✅ Step terminé avec succès
- `FAILED` : ❌ Step échoué
- `CANCELLED` : Step annulé

### 4.2 Logs en temps réel (après quelques minutes)

```bash
# Télécharger et inspecter les logs
./scripts/download_and_inspect_logs.sh
```

### 4.3 Console AWS

Ouvrir le lien fourni lors de la soumission:

```
https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/j-XXXX/steps/s-XXXX
```

**Onglets à consulter:**
- **Status** : État actuel
- **Logs** : Liens vers S3
- **Monitoring** : Métriques Spark

---

## 5. Récupération des résultats

### 5.1 Attendre la fin du job

```bash
# Vérifier que le step est COMPLETED
aws emr describe-step \
  --cluster-id $(cat cluster_id.txt) \
  --step-id $(cat step_id.txt) \
  --region eu-west-1 \
  --query 'Step.Status.State' \
  --output text
```

### 5.2 Télécharger les résultats

```bash
./scripts/download_results.sh
```

**Sortie attendue:**

```
==================================================
📥 TÉLÉCHARGEMENT DES RÉSULTATS - ÉTAPE 2
==================================================
☁️  Source S3: s3://oc-p11-fruits-david-scanu/process_fruits_data/output/
💾 Destination: /path/to/traitement/etape_2/output

🔍 Vérification des fichiers disponibles sur S3...
✅ Résultats trouvés sur S3

📂 Contenu disponible:
2024-01-15 10:45:00  features/parquet/features_20240115_104500/
2024-01-15 10:45:01  features/csv/features_20240115_104500/
2024-01-15 10:45:02  pca/parquet/pca_20240115_104500/
2024-01-15 10:45:03  pca/csv/pca_20240115_104500/
2024-01-15 10:45:04  metadata/metadata_20240115_104500/
2024-01-15 10:45:05  model_info/model_info_20240115_104500/

📥 Téléchargement en cours...

==================================================
✅ TÉLÉCHARGEMENT TERMINÉ
==================================================
📊 456 fichier(s) téléchargé(s)

📁 Structure du dossier output/:
Features (1280D):
  output/features/parquet/features_20240115_104500/
  output/features/csv/features_20240115_104500/

PCA (50D):
  output/pca/parquet/pca_20240115_104500/
  output/pca/csv/pca_20240115_104500/

💡 Emplacements importants:
   🎨 Features (1280D): output/features/
   📊 PCA (50D): output/pca/
   📋 Metadata: output/metadata/
   🤖 Model Info: output/model_info/
   ⚠️  Errors: output/errors/

🤖 Informations du modèle PCA:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "timestamp": "20240115_104500",
  "pca_components": 50,
  "original_dimensions": 1280,
  "reduced_dimensions": 50,
  "total_variance_explained": 0.8542,
  "num_images_processed": 300
}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

==================================================
📂 Résultats sauvegardés dans:
   /path/to/traitement/etape_2/output
==================================================
```

### 5.3 Explorer les résultats

```bash
# Voir la structure
tree output/ -L 3

# Lire les infos PCA
cat output/model_info/model_info_*/part-00000* | head -30

# Voir la variance par composante
cat output/model_info/variance_*/part-00000*.csv | head -20

# Compter les erreurs (si présent)
wc -l output/errors/errors_*/part-00000*.csv
```

---

## 6. Nettoyage

### 6.1 Arrêter le cluster (IMPORTANT!)

```bash
./scripts/terminate_cluster.sh
```

**Sortie attendue:**

```
==================================================
🛑 TERMINAISON DU CLUSTER EMR - ÉTAPE 2
==================================================
📋 Cluster ID: j-2AXXXXXXXXXX
🌍 Région: eu-west-1

📊 État actuel: WAITING

⚠️  ATTENTION: Cette action va arrêter le cluster et toutes les instances EC2
💰 Économie: ~0.80€/heure

Confirmer la terminaison ? (oui/non): oui

🛑 Envoi de la commande d'arrêt...

==================================================
✅ COMMANDE ENVOYÉE
==================================================

⏰ Le cluster sera terminé dans 2-5 minutes

🔍 Surveiller la terminaison:
   watch -n 10 'aws emr describe-cluster --cluster-id j-2AXXXXXXXXXX --region eu-west-1 --query "Cluster.Status.State"'
```

### 6.2 Vérifier la terminaison

```bash
# Vérifier l'état du cluster
aws emr describe-cluster \
  --cluster-id $(cat cluster_id.txt) \
  --region eu-west-1 \
  --query 'Cluster.Status.State' \
  --output text

# Doit afficher: TERMINATED ou TERMINATING

# Vérifier qu'aucune instance EC2 ne tourne
aws ec2 describe-instances \
  --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" \
  --output table
```

### 6.3 Nettoyage complet (optionnel)

```bash
./scripts/cleanup.sh
```

**Options proposées:**
1. Terminer le cluster (si actif)
2. Supprimer les données de sortie S3
3. Supprimer les logs EMR S3
4. Supprimer les fichiers locaux de tracking

---

## 7. Troubleshooting

### 7.1 Le cluster ne démarre pas

**Symptôme:** État bloqué sur `STARTING` ou `TERMINATED_WITH_ERRORS`

**Solution:**

```bash
# Vérifier les détails de l'erreur
aws emr describe-cluster \
  --cluster-id $(cat cluster_id.txt) \
  --region eu-west-1 \
  --query 'Cluster.Status'

# Vérifier les logs bootstrap
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/$(cat cluster_id.txt)/ --recursive

# Problèmes courants:
# - IAM roles invalides → Recréer avec: aws emr create-default-roles
# - Subnet invalide → Vérifier config.sh
# - Quota EC2 dépassé → Demander augmentation
```

### 7.2 Le job échoue (FAILED)

**Symptôme:** Step status = `FAILED`

**Solution:**

```bash
# Télécharger et inspecter les logs
./scripts/download_and_inspect_logs.sh

# Chercher les erreurs
cat logs/stderr | grep -i "error\|exception\|traceback" | head -50

# Problèmes courants:
# - TensorFlow non installé → Vérifier bootstrap logs
# - Mémoire insuffisante → Augmenter SPARK_EXECUTOR_MEMORY
# - Fichiers S3 inaccessibles → Vérifier IAM roles
```

### 7.3 Erreurs TensorFlow

**Symptôme:** `ModuleNotFoundError: No module named 'tensorflow'`

**Solution:**

```bash
# Vérifier que le bootstrap a réussi
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/$(cat cluster_id.txt)/node/

# Télécharger les logs bootstrap
aws s3 cp s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/$(cat cluster_id.txt)/node/i-XXXX/bootstrap-actions/1/ . --recursive

# Vérifier install_dependencies.sh sur S3
aws s3 cp s3://oc-p11-fruits-david-scanu/process_fruits_data/scripts/install_dependencies.sh - | cat
```

### 7.4 Out of Memory (OOM)

**Symptôme:** `java.lang.OutOfMemoryError` ou `Container killed by YARN`

**Solution:**

```bash
# Éditer config.sh
vim config/config.sh

# Augmenter la mémoire:
SPARK_EXECUTOR_MEMORY="12g"  # Au lieu de 8g
SPARK_DRIVER_MEMORY="12g"
SPARK_EXECUTOR_MEMORY_OVERHEAD="3g"  # Au lieu de 2g

# Ou passer à des instances plus grandes:
MASTER_INSTANCE_TYPE="m5.4xlarge"
CORE_INSTANCE_TYPE="m5.4xlarge"

# Recréer le cluster
./scripts/create_cluster.sh
```

### 7.5 Pas de résultats sur S3

**Symptôme:** `download_results.sh` ne trouve rien

**Solution:**

```bash
# Vérifier l'état du step
aws emr describe-step \
  --cluster-id $(cat cluster_id.txt) \
  --step-id $(cat step_id.txt) \
  --region eu-west-1 \
  --query 'Step.Status'

# Si FAILED, voir 7.2
# Si COMPLETED, vérifier manuellement S3:
aws s3 ls s3://oc-p11-fruits-david-scanu/process_fruits_data/output/ --recursive

# Vérifier les permissions IAM
aws iam get-role-policy \
  --role-name EMR_EC2_DefaultRole \
  --policy-name EMR_EC2_DefaultRole_Policy
```

---

## 📊 Résumé du workflow

```
┌─────────────────────────────────────────────────────┐
│  1. verify_setup.sh                                 │  < 1 min
│  2. upload_scripts.sh                               │  < 1 min
│  3. create_cluster.sh                               │  10-15 min
│  4. monitor_cluster.sh (optionnel)                  │  -
│  5. submit_job.sh                                   │  < 1 min
│     → Attendre exécution                            │  2-180 min (selon mode)
│  6. download_results.sh                             │  1-5 min
│  7. terminate_cluster.sh                            │  2-5 min
└─────────────────────────────────────────────────────┘

Total (mode mini) : ~20-30 minutes
Total (mode full) : ~3-4 heures
```

---

## 📞 Support

**En cas de problème:**

1. Vérifier les logs : `./scripts/download_and_inspect_logs.sh`
2. Consulter la console AWS : liens fournis dans chaque script
3. Vérifier la configuration : `source config/config.sh && show_config`

**Commandes de diagnostic:**

```bash
# Voir tous les clusters
aws emr list-clusters --region eu-west-1 --active

# Voir les steps d'un cluster
aws emr list-steps --cluster-id j-XXXX --region eu-west-1

# Voir les instances EC2
aws ec2 describe-instances --region eu-west-1 --output table
```
