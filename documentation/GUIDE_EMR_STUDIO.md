# Guide Complet : Migration vers AWS EMR Studio

**Projet** : OpenClassrooms P11 - Big Data Fruits
**Date** : 2025-11-14
**Objectif** : Migrer de JupyterHub (cluster EMR) vers EMR Studio

---

## 📋 Table des Matières

1. [Différences JupyterHub vs EMR Studio](#différences-jupyterhub-vs-emr-studio)
2. [Prérequis](#prérequis)
3. [Installation Étape par Étape](#installation-étape-par-étape)
4. [Utilisation du Notebook](#utilisation-du-notebook)
5. [Optimisations et Bonnes Pratiques](#optimisations-et-bonnes-pratiques)
6. [Dépannage](#dépannage)
7. [Coûts et Gestion](#coûts-et-gestion)

---

## 🔄 Différences JupyterHub vs EMR Studio

### Architecture

| Aspect | JupyterHub (ancien) | EMR Studio (nouveau) |
|--------|---------------------|----------------------|
| **Interface** | JupyterHub installé sur master node | Interface web AWS managée |
| **Connexion** | Tunnel SSH (port 9443) | Accès web direct (SSO/IAM) |
| **Kernel** | Installé sur cluster | Géré par Livy (remote) |
| **SparkSession** | Créée manuellement | Auto-créée via Livy |
| **Applications EMR** | JupyterHub + Spark + Hadoop | Livy + Spark |
| **Persistance** | Locale sur cluster | S3 (auto-sauvegarde) |
| **Collaboration** | Non | Oui (workspaces partagés) |
| **Gestion** | Manuelle | Managée par AWS |

### Avantages d'EMR Studio

✅ **Pas de tunnel SSH** : Accès direct via console AWS
✅ **Auto-sauvegarde S3** : Notebooks sauvegardés automatiquement
✅ **Multi-clusters** : Attacher différents clusters à un workspace
✅ **Collaboration** : Partage de workspaces entre équipes
✅ **Sécurité IAM** : Gestion fine des permissions
✅ **Git intégré** : Connexion directe à GitHub/GitLab
✅ **Debugging** : Meilleur suivi des jobs Spark

### Inconvénients

⚠️ **Setup initial plus complexe** : Nécessite VPC, IAM roles, security groups
⚠️ **Latence** : Communication via Livy (légèrement plus lent)
⚠️ **Dépendances** : Infrastructure AWS obligatoire (VPC, subnets)

---

## 📦 Prérequis

### 1. AWS CLI v2

```bash
# Vérifier l'installation
aws --version

# Si non installé
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configuration AWS

```bash
# Configurer les credentials
aws configure

# Vérifier
aws sts get-caller-identity
```

**IMPORTANT** : Utiliser une région européenne (RGPD) :
- `eu-west-1` (Irlande) - **recommandé**
- `eu-west-3` (Paris)
- `eu-central-1` (Francfort)

### 3. Dataset Fruits-360

```bash
# Télécharger le dataset (si non présent)
mkdir -p data/raw
cd data/raw
wget https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip
unzip fruits.zip
```

---

## 🚀 Installation Étape par Étape

### Étape 1 : Créer le bucket S3

```bash
./scripts/aws_emr_studio_setup.sh create-bucket
```

**Ce qui se passe** :
- Création d'un bucket S3 avec nom unique
- Configuration du blocage d'accès public
- Création de la structure de dossiers :
  - `data/raw/` - Données brutes
  - `data/features/` - Features extraites
  - `data/pca/` - Résultats PCA
  - `logs/` - Logs EMR
  - `emr-studio-workspaces/` - Notebooks

**Résultat** :
```
✅ Bucket créé: s3://oc-p11-fruits-YYYYMMDD-HHMMSS
Configuration sauvegardée dans .aws/emr_studio_config.env
```

### Étape 2 : Uploader le dataset

```bash
./scripts/aws_emr_studio_setup.sh upload-dataset
```

**Durée** : 10-30 minutes selon connexion internet
**Taille** : ~1.5 GB (67,692 images)

### Étape 3 : Créer les rôles IAM

```bash
./scripts/aws_emr_studio_setup.sh create-iam-roles
```

**Rôles créés** :
1. **EMRStudio_Service_Role** : Utilisé par EMR Studio pour gérer les clusters
2. **EMRStudio_User_Role** : Permissions pour les utilisateurs

### Étape 4 : Créer EMR Studio

```bash
./scripts/aws_emr_studio_setup.sh create-studio
```

**Ce qui se passe** :
- Détection automatique du VPC par défaut
- Création des security groups
- Création du studio EMR
- Récupération de l'URL d'accès

**Résultat** :
```
✅ EMR Studio créé: es-XXXXXXXXXXXXX
✅ URL: https://XXXXX.emrstudio-prod.eu-west-1.amazonaws.com
```

### Étape 5 : Créer le cluster EMR

```bash
./scripts/aws_emr_studio_setup.sh create-cluster m5.xlarge
```

**Configuration** :
- Release : `emr-7.5.0`
- Applications : Spark + Livy (pas JupyterHub !)
- Instances : 1 master + 2 core
- Type : `m5.xlarge` (par défaut)

**Coût estimé** : ~2-3€/heure

**Durée de démarrage** : 10-15 minutes

### Étape 6 : Vérifier le statut

```bash
./scripts/aws_emr_studio_setup.sh status
```

**Attendez l'état** : `WAITING` (prêt)

---

## 💻 Utilisation du Notebook

### 1. Accéder à EMR Studio

1. Ouvrir l'URL du studio (affichée lors de la création)
2. Se connecter avec IAM
3. Cliquer sur **"Create Workspace"**

**Configuration du workspace** :
- Name : `P11-Fruits-Workspace`
- Cluster : Sélectionner le cluster créé
- S3 location : Auto-configuré

### 2. Uploader le notebook

1. Dans le workspace, cliquer sur **"Upload"**
2. Sélectionner : `notebooks/p11-emr-studio-fruits-pca.ipynb`
3. Ouvrir le notebook

### 3. Configurer le bucket

**Modifier la cellule 1.5** :

```python
# ⚠️ ADAPTER LE NOM DU BUCKET
BUCKET_NAME = "oc-p11-fruits-VOTRE-BUCKET"
```

Remplacer par le nom de votre bucket (affiché lors de la création).

### 4. Exécuter le pipeline

**Recommandation** : Commencer en mode `mini` (100 images)

```python
# MODE 1: MINI TEST (100 images) - RECOMMANDÉ pour débuter
TEST_MODE = "mini"
MAX_IMAGES = 100
```

**Exécution** :
1. Exécuter les cellules séquentiellement
2. Vérifier les logs Spark
3. Surveiller les métriques (CPU, mémoire)

### 5. Modes de production

Une fois le test réussi, passer au mode production :

```python
# MODE 3: DATASET COMPLET (~67,000 images)
TEST_MODE = "full"
```

**Durée estimée** (full dataset) :
- Chargement : 2-5 min
- Feature extraction : 30-60 min (dépend du cluster)
- PCA : 5-10 min
- Sauvegarde : 2-5 min

**Total** : ~45-80 minutes

---

## ⚡ Optimisations et Bonnes Pratiques

### 1. Broadcast des poids TensorFlow

**✅ Implémenté dans le notebook** :

```python
# Broadcaster les poids à tous les workers
broadcast_weights = sc.broadcast(model_weights)
```

**Impact** :
- Sans broadcast : ~10 MB × nombre de workers × nombre de partitions
- Avec broadcast : ~10 MB × 1 (une seule fois)

### 2. Cache des DataFrames

```python
df_features.cache()
df_for_pca.cache()
```

**Libérer la mémoire après usage** :

```python
df_features.unpersist()
```

### 3. Configuration Spark optimale

Déjà configurée dans le script de création du cluster :

```json
{
  "Classification": "spark",
  "Properties": {
    "maximizeResourceAllocation": "true"
  }
}
```

### 4. Partitionnement

Pour le dataset complet, augmenter le nombre de partitions :

```python
df_images = spark.read.format("binaryFile") \
    .load(image_path) \
    .repartition(200)  # Adapter selon le cluster
```

### 5. Gestion de la session Livy

Augmenter le timeout si nécessaire (déjà configuré à 2h) :

```json
{
  "Classification": "livy-conf",
  "Properties": {
    "livy.server.session.timeout": "2h"
  }
}
```

---

## 🔧 Dépannage

### Problème : Session Livy timeout

**Symptôme** : `Session ... has been idle for more than ...`

**Solution** :
```python
# Ajouter des actions intermédiaires pour garder la session active
df.count()  # Action Spark
```

### Problème : TensorFlow non trouvé dans les workers

**Symptôme** : `ModuleNotFoundError: No module named 'tensorflow'`

**Solution** :
```python
# Réinstaller sur tous les workers
sc.install_pypi_package("tensorflow==2.16.1", reinstall=True)
```

### Problème : Mémoire insuffisante

**Symptôme** : `OutOfMemoryError` ou jobs qui échouent

**Solutions** :
1. Réduire la taille des batches dans Pandas UDF
2. Augmenter le type d'instance (ex: `m5.2xlarge`)
3. Augmenter le nombre de workers

### Problème : Broadcast trop gros

**Symptôme** : `Broadcast size exceeds ...`

**Solution** : Utiliser un modèle plus léger (ex: MobileNetV3-Small)

### Problème : Cluster non accessible

**Symptôme** : Cannot attach cluster

**Solution** :
```bash
# Vérifier l'état
./scripts/aws_emr_studio_setup.sh status

# Attendre l'état WAITING
```

---

## 💰 Coûts et Gestion

### Estimation des coûts

**Cluster 3 instances m5.xlarge (eu-west-1)** :
- Prix EMR : ~0.27€/h par instance
- Prix EC2 : ~0.23€/h par instance
- **Total** : ~1.50€/h (3 instances)

**Scénarios** :

| Durée | Coût estimé |
|-------|-------------|
| 1 heure (test) | 1.50€ |
| 2 heures (full dataset) | 3.00€ |
| Journée complète (8h) | 12.00€ |
| Oubli 1 semaine | ~250€ ⚠️ |

### 🚨 IMPORTANT : Arrêter le cluster

**Toujours arrêter le cluster après utilisation** :

```bash
./scripts/aws_emr_studio_setup.sh terminate
```

### Vérification finale

```bash
# Vérifier qu'aucun cluster ne tourne
aws emr list-clusters --active

# Vérifier les buckets S3 (les buckets coûtent peu)
aws s3 ls
```

### Télécharger les résultats avant arrêt

```bash
./scripts/aws_emr_studio_setup.sh download-results
```

**Résultats locaux** :
- `data/emr_output/features/` - Features extraites
- `data/emr_output/pca/` - Résultats PCA

### Nettoyage complet (fin de projet)

```bash
./scripts/aws_emr_studio_setup.sh cleanup
```

**⚠️ ATTENTION** : Supprime TOUT (cluster + studio + S3 + IAM roles)

---

## 📊 Comparaison des Approches

### JupyterHub (ancienne méthode)

**Workflow** :
1. Créer cluster avec `JupyterHub` application
2. Tunnel SSH vers port 9443
3. Connexion avec credentials
4. Notebook local sur master node

**Commandes** :
```bash
# Ancien script
./scripts/aws_setup.sh create-cluster
./scripts/aws_setup.sh connect  # Tunnel SSH
# Naviguer vers https://localhost:9443
```

### EMR Studio (nouvelle méthode)

**Workflow** :
1. Créer EMR Studio (une seule fois)
2. Créer cluster avec `Livy` application
3. Créer workspace dans EMR Studio
4. Attacher cluster au workspace
5. Uploader et exécuter notebook

**Commandes** :
```bash
# Nouveau script
./scripts/aws_emr_studio_setup.sh create-studio
./scripts/aws_emr_studio_setup.sh create-cluster
# Ouvrir EMR Studio URL dans navigateur
```

---

## 🎯 Checklist de Migration

### Avant de commencer

- [ ] AWS CLI v2 installé et configuré
- [ ] Région européenne sélectionnée (RGPD)
- [ ] Dataset Fruits-360 téléchargé localement
- [ ] Budget AWS confirmé (~10€)

### Configuration initiale

- [ ] Bucket S3 créé
- [ ] Dataset uploadé sur S3
- [ ] Rôles IAM créés
- [ ] EMR Studio créé
- [ ] URL du studio sauvegardée

### Exécution

- [ ] Cluster EMR créé avec Livy
- [ ] Cluster en état WAITING
- [ ] Workspace créé dans EMR Studio
- [ ] Cluster attaché au workspace
- [ ] Notebook uploadé
- [ ] Bucket name configuré dans le notebook
- [ ] Test mode `mini` exécuté avec succès
- [ ] Mode `full` exécuté (optionnel)

### Finalisation

- [ ] Résultats vérifiés sur S3
- [ ] Résultats téléchargés localement
- [ ] Cluster EMR arrêté ✅
- [ ] Coûts vérifiés dans AWS Cost Explorer

---

## 📚 Ressources

### Documentation AWS

- [EMR Studio User Guide](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-studio.html)
- [EMR Cluster Configuration](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-plan.html)
- [Livy REST API](https://livy.incubator.apache.org/docs/latest/rest-api.html)

### Scripts du projet

- `scripts/aws_emr_studio_setup.sh` - Setup EMR Studio
- `scripts/aws_setup.sh` - Setup JupyterHub (ancien, pour référence)
- `notebooks/p11-emr-studio-fruits-pca.ipynb` - Notebook EMR Studio
- `notebooks/p11-emr-fruits-pca.ipynb` - Notebook JupyterHub (ancien)

### Support

En cas de problème :
1. Vérifier les logs dans AWS EMR Console
2. Consulter cette documentation
3. Vérifier les security groups et IAM roles

---

## ✨ Conclusion

EMR Studio offre une expérience plus moderne et professionnelle pour le développement PySpark, au prix d'une complexité initiale plus élevée. Une fois configuré, l'environnement est plus stable, sécurisé et collaboratif que JupyterHub.

**Recommandation** : Utiliser EMR Studio pour les projets professionnels et collaboratifs, JupyterHub reste acceptable pour les prototypes rapides et tests individuels.