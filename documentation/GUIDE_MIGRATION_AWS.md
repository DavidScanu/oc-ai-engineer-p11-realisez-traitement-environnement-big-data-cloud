# Guide de Migration AWS - Projet Big Data Fruits

**Date de création** : 7 novembre 2025
**Objectif** : Migrer le pipeline PySpark validé localement vers AWS EMR

---

## Vue d'ensemble

Ce guide vous accompagne étape par étape pour :
1. Installer et configurer AWS CLI
2. Créer un bucket S3 dans une région européenne (RGPD)
3. Uploader le dataset sur S3
4. Créer un cluster EMR avec les bonnes configurations
5. Exécuter le pipeline PySpark sur EMR
6. Récupérer les résultats et arrêter le cluster

**⏱️ Temps estimé** : 2-3 heures
**💰 Coût estimé** : 6-10€

---

## Prérequis

- ✅ Compte AWS actif
- ✅ Pipeline PySpark validé localement (`notebooks/p11-david-scanu-local-development.ipynb`)
- ✅ Dataset Fruits-360 local (`data/raw/fruits-360_dataset/`)
- 🔲 AWS CLI (sera installé dans ce guide)
- 🔲 Clés d'accès AWS IAM (seront générées dans ce guide)

---

## 📦 Étape 1 : Installation et Configuration AWS CLI

### 1.1 Installation AWS CLI v2

```bash
# Télécharger AWS CLI v2 pour Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Extraire l'archive
unzip awscliv2.zip

# Installer (peut nécessiter sudo)
sudo ./aws/install

# Vérifier l'installation
aws --version
```

**Résultat attendu** : `aws-cli/2.x.x Python/3.x.x Linux/x.x.x`

### 1.2 Création des clés d'accès AWS IAM

**Via la console AWS** :

1. Connectez-vous à la console AWS : https://console.aws.amazon.com
2. Naviguez vers **IAM** > **Utilisateurs** > Votre utilisateur
3. Onglet **"Informations d'identification de sécurité"**
4. Cliquez sur **"Créer une clé d'accès"**
5. Sélectionnez le cas d'utilisation : **"Interface de ligne de commande (CLI)"**
6. **IMPORTANT** : Notez la clé d'accès et la clé secrète (elles ne seront plus affichées)

**Permissions requises** :
- `AmazonS3FullAccess` (pour gérer S3)
- `AmazonEMRFullAccess` (pour gérer EMR)
- `AmazonEC2FullAccess` (pour les instances EMR)

### 1.3 Configuration AWS CLI

```bash
# Configurer AWS CLI avec vos identifiants
aws configure

# Vous serez invité à entrer :
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: eu-west-1
# Default output format [None]: json
```

**⚠️ Région importante** : Utilisez **`eu-west-1`** (Irlande) ou **`eu-central-1`** (Francfort) pour la conformité RGPD.

### 1.4 Vérification de la configuration

```bash
# Vérifier l'identité AWS
aws sts get-caller-identity

# Vérifier l'accès S3
aws s3 ls
```

**Résultat attendu** : Affichage de votre ID utilisateur et compte AWS

---

## 🪣 Étape 2 : Création du Bucket S3

### 2.1 Créer le bucket S3

```bash
# Définir les variables
BUCKET_NAME="oc-p11-fruits-$(date +%Y%m%d)"
REGION="eu-west-1"

# Créer le bucket
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

# Vérifier la création
aws s3 ls
```

**⚠️ Note** : Le nom du bucket doit être unique globalement. Si le nom est déjà pris, modifiez-le.

### 2.2 Configurer le bucket pour RGPD

```bash
# Bloquer l'accès public (bonne pratique)
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Vérifier la configuration
aws s3api get-bucket-location --bucket ${BUCKET_NAME}
```

**Résultat attendu** : `"LocationConstraint": "eu-west-1"`

### 2.3 Créer la structure de dossiers S3

```bash
# Créer les dossiers (en créant des fichiers placeholder)
aws s3api put-object --bucket ${BUCKET_NAME} --key data/raw/
aws s3api put-object --bucket ${BUCKET_NAME} --key data/features/
aws s3api put-object --bucket ${BUCKET_NAME} --key data/pca/
aws s3api put-object --bucket ${BUCKET_NAME} --key logs/

# Vérifier la structure
aws s3 ls s3://${BUCKET_NAME}/ --recursive
```

---

## 📤 Étape 3 : Upload du Dataset sur S3

### 3.1 Upload du dataset Training

**⚠️ Important** : L'upload de ~1.5 GB peut prendre 10-30 minutes selon votre connexion.

```bash
# Se placer à la racine du projet
cd /home/david/projects/openclassrooms/projets/oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud

# Upload du dataset Training (avec barre de progression)
aws s3 sync data/raw/fruits-360_dataset/fruits-360/Training/ \
    s3://${BUCKET_NAME}/data/raw/Training/ \
    --region ${REGION} \
    --exclude "*.DS_Store"

# Vérifier l'upload
aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ | head -20
```

### 3.2 Vérifier le nombre d'images uploadées

```bash
# Compter les fichiers uploadés
aws s3 ls s3://${BUCKET_NAME}/data/raw/Training/ --recursive | wc -l

# Devrait afficher environ 67,692 lignes (+ dossiers)
```

### 3.3 Upload du dataset Test (optionnel)

```bash
# Upload du dataset Test (si nécessaire pour tests)
aws s3 sync data/raw/fruits-360_dataset/fruits-360/Test/ \
    s3://${BUCKET_NAME}/data/raw/Test/ \
    --region ${REGION} \
    --exclude "*.DS_Store"
```

### 3.4 Vérifier la taille totale sur S3

```bash
# Afficher la taille du bucket
aws s3 ls s3://${BUCKET_NAME}/data/raw/ --recursive --human-readable --summarize
```

**Résultat attendu** : `Total Size: ~1.5 GB`

---

## 🖥️ Étape 4 : Création du Cluster EMR

### 4.1 Créer une paire de clés SSH

```bash
# Créer une paire de clés pour SSH
KEY_NAME="emr-p11-fruits-key"

aws ec2 create-key-pair \
    --key-name ${KEY_NAME} \
    --query 'KeyMaterial' \
    --output text \
    --region ${REGION} > ~/.ssh/${KEY_NAME}.pem

# Sécuriser la clé
chmod 400 ~/.ssh/${KEY_NAME}.pem

# Vérifier
ls -l ~/.ssh/${KEY_NAME}.pem
```

### 4.2 Créer le cluster EMR

**⚠️ ATTENTION : Cette commande va lancer un cluster qui coûte ~2-3€/heure**

```bash
# Définir les variables du cluster
CLUSTER_NAME="P11-Fruits-BigData-$(date +%Y%m%d)"
EMR_RELEASE="emr-7.5.0"  # Version stable avec Spark 3.5.x et TensorFlow 2.16.x
INSTANCE_TYPE="m5.xlarge"

# Créer le cluster
CLUSTER_ID=$(aws emr create-cluster \
    --name "${CLUSTER_NAME}" \
    --region ${REGION} \
    --release-label ${EMR_RELEASE} \
    --applications Name=Spark Name=JupyterHub Name=Hadoop Name=TensorFlow \
    --instance-groups \
        InstanceGroupType=MASTER,InstanceCount=1,InstanceType=${INSTANCE_TYPE} \
        InstanceGroupType=CORE,InstanceCount=2,InstanceType=${INSTANCE_TYPE} \
    --ec2-attributes KeyName=${KEY_NAME} \
    --use-default-roles \
    --log-uri s3://${BUCKET_NAME}/logs/ \
    --enable-debugging \
    --configurations '[
        {
            "Classification": "spark",
            "Properties": {
                "maximizeResourceAllocation": "true"
            }
        }
    ]' \
    --query 'ClusterId' \
    --output text)

echo "Cluster créé avec l'ID: ${CLUSTER_ID}"
echo "Sauvegarde de l'ID dans un fichier..."
echo ${CLUSTER_ID} > cluster_id.txt
```

**📝 Note** : Le cluster met environ 10-15 minutes à démarrer.

### 4.3 Suivre le statut du cluster

```bash
# Afficher le statut du cluster
aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State'

# Suivre les logs en temps réel (à répéter toutes les 30 secondes)
watch -n 30 "aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State'"

# Attendre que le statut soit "WAITING"
```

**États possibles** :
- `STARTING` : Cluster en cours de démarrage
- `BOOTSTRAPPING` : Installation des applications
- `RUNNING` : Cluster en cours d'exécution
- `WAITING` : ✅ **Prêt à recevoir des jobs**
- `TERMINATING` : Cluster en cours d'arrêt
- `TERMINATED` : Cluster arrêté

### 4.4 Récupérer l'adresse du Master Node

```bash
# Une fois le cluster en état WAITING, récupérer l'IP publique du master
MASTER_DNS=$(aws emr describe-cluster \
    --cluster-id ${CLUSTER_ID} \
    --query 'Cluster.MasterPublicDnsName' \
    --output text)

echo "Master DNS: ${MASTER_DNS}"
echo ${MASTER_DNS} > master_dns.txt
```

---

## 🔐 Étape 5 : Connexion SSH et Tunnel

### 5.1 Configurer le tunnel SSH vers JupyterHub

```bash
# Créer le tunnel SSH (port 9443 pour JupyterHub sur EMR 7.x)
ssh -i ~/.ssh/${KEY_NAME}.pem \
    -N -L 9443:${MASTER_DNS}:9443 \
    hadoop@${MASTER_DNS}
```

**⚠️ Cette commande ne retourne pas** : Le tunnel reste actif. Laissez ce terminal ouvert.

**En cas d'erreur de permission** :
```bash
# Ouvrir le security group pour SSH
SECURITY_GROUP=$(aws emr describe-cluster \
    --cluster-id ${CLUSTER_ID} \
    --query 'Cluster.Ec2InstanceAttributes.EmrManagedMasterSecurityGroup' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 22 \
    --cidr $(curl -s https://checkip.amazonaws.com)/32
```

### 5.2 Accéder à JupyterHub

1. **Ouvrir un navigateur** : https://localhost:9443
2. **Accepter le certificat SSL** (auto-signé, c'est normal)
3. **Se connecter avec** :
   - Username : `jovyan`
   - Password : `jupyter`

**Alternative - Via la console AWS** :
- Console AWS > EMR > Clusters > Votre cluster
- Onglet "Application User Interfaces"
- Cliquer sur "JupyterHub"

---

## 📓 Étape 6 : Création et Exécution du Notebook sur EMR

### 6.1 Créer un nouveau notebook PySpark

Dans JupyterHub :
1. Cliquer sur **"New"** > **"PySpark"**
2. Renommer le notebook : `P11_David_Scanu_Production_EMR.ipynb`

### 6.2 Adapter le code local pour EMR

**Principales modifications** :

#### A) Pas besoin de créer la SparkSession

```python
# ❌ LOCAL - Ne PAS utiliser sur EMR
# spark = SparkSession.builder.appName("...").master("local[*]").getOrCreate()

# ✅ EMR - La SparkSession existe déjà
# Vérifier simplement qu'elle existe
print(f"Spark version: {spark.version}")
print(f"SparkContext: {spark.sparkContext.master}")
sc = spark.sparkContext
```

#### B) Modifier les chemins pour S3

```python
# ❌ LOCAL
# image_path = "file:///path/to/Training/Apple*/*.jpg"

# ✅ EMR - Utiliser S3
BUCKET_NAME = "oc-p11-fruits-20251107"  # Remplacer par votre bucket
image_path = f"s3://{BUCKET_NAME}/data/raw/Training/Apple*/*.jpg"

# Pour le dataset complet
# image_path = f"s3://{BUCKET_NAME}/data/raw/Training/*/*.jpg"
```

#### C) Installer TensorFlow et Pillow (si nécessaire)

```python
# Installer les dépendances dans le notebook
import sys
import subprocess

def install_package(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Installer TensorFlow et Pillow
install_package("tensorflow==2.16.1")
install_package("pillow")

print("✅ Packages installés")
```

#### D) Adapter les chemins de sauvegarde

```python
# ❌ LOCAL
# features_output = "/local/path/features"

# ✅ EMR - Sauvegarder sur S3
features_output = f"s3://{BUCKET_NAME}/data/features/mobilenetv2_features"
pca_output = f"s3://{BUCKET_NAME}/data/pca/pca_results"
```

### 6.3 Copier le code du notebook local

**Option A - Copier-coller** :
1. Ouvrir le notebook local : `notebooks/p11-david-scanu-local-development.ipynb`
2. Copier le code cellule par cellule dans le notebook EMR
3. Appliquer les modifications ci-dessus

**Option B - Upload direct** (recommandé) :
```bash
# Depuis votre machine locale, uploader le notebook vers S3
aws s3 cp notebooks/p11-david-scanu-local-development.ipynb \
    s3://${BUCKET_NAME}/notebooks/

# Puis le télécharger depuis JupyterHub via l'interface web
```

### 6.4 Exécuter le pipeline complet

**🎯 Stratégie d'exécution recommandée** :

#### Phase 1 : Test rapide (100 images)
```python
# Tester d'abord avec un petit subset
TEST_MODE = "mini"
MAX_IMAGES = 100
image_path = f"s3://{BUCKET_NAME}/data/raw/Training/Apple*/*.jpg"
df_images = spark.read.format("binaryFile").load(image_path).limit(MAX_IMAGES)
```

**Temps estimé** : 5-10 minutes

#### Phase 2 : Dataset complet (67,692 images)
```python
# Une fois le test validé, lancer le dataset complet
TEST_MODE = "full"
image_path = f"s3://{BUCKET_NAME}/data/raw/Training/*/*.jpg"
df_images = spark.read.format("binaryFile").load(image_path)
```

**Temps estimé** : 2-4 heures (selon la configuration du cluster)

### 6.5 Monitorer l'exécution via Spark UI

**Accéder à Spark UI** :

1. **Via le tunnel SSH** (recommandé) :
```bash
# Dans un nouveau terminal, créer un tunnel pour Spark UI
ssh -i ~/.ssh/${KEY_NAME}.pem \
    -N -L 18080:${MASTER_DNS}:18080 \
    hadoop@${MASTER_DNS}
```
Puis ouvrir : http://localhost:18080

2. **Via la console AWS** :
   - Console AWS > EMR > Clusters > Votre cluster
   - Onglet "Application User Interfaces"
   - Cliquer sur "Spark History Server"

**Métriques à surveiller** :
- Nombre de tâches en cours
- Temps d'exécution des stages
- Utilisation mémoire
- Erreurs éventuelles

---

## 📥 Étape 7 : Récupération des Résultats

### 7.1 Vérifier les résultats sur S3

```bash
# Lister les fichiers de features
aws s3 ls s3://${BUCKET_NAME}/data/features/ --recursive --human-readable

# Lister les fichiers PCA
aws s3 ls s3://${BUCKET_NAME}/data/pca/ --recursive --human-readable

# Afficher la taille totale
aws s3 ls s3://${BUCKET_NAME}/data/ --recursive --human-readable --summarize
```

### 7.2 Télécharger les résultats localement

```bash
# Télécharger les features
aws s3 sync s3://${BUCKET_NAME}/data/features/ \
    data/emr_output/features/ \
    --region ${REGION}

# Télécharger les résultats PCA
aws s3 sync s3://${BUCKET_NAME}/data/pca/ \
    data/emr_output/pca/ \
    --region ${REGION}

# Vérifier
ls -lh data/emr_output/
```

### 7.3 Inspecter les résultats PCA (optionnel)

```python
# Dans un notebook local ou JupyterHub
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("Inspect-Results").getOrCreate()

# Charger les résultats PCA depuis S3
df_pca = spark.read.parquet(f"s3://{BUCKET_NAME}/data/pca/pca_results")

# Afficher les statistiques
print(f"Nombre de lignes: {df_pca.count()}")
df_pca.printSchema()
df_pca.show(10, truncate=60)
```

---

## 🛑 Étape 8 : Arrêt du Cluster EMR

**⚠️ CRITIQUE : NE PAS OUBLIER D'ARRÊTER LE CLUSTER**

### 8.1 Vérifier que les données sont bien sur S3

```bash
# Vérifier une dernière fois
aws s3 ls s3://${BUCKET_NAME}/data/pca/ --recursive
```

### 8.2 Arrêter le cluster

```bash
# Arrêter le cluster
aws emr terminate-clusters --cluster-ids ${CLUSTER_ID}

# Vérifier le statut
aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query 'Cluster.Status.State'
```

**État attendu** : `TERMINATING` puis `TERMINATED`

### 8.3 Vérifier l'arrêt dans la console AWS

1. Console AWS > EMR > Clusters
2. Vérifier que le cluster est en état **"Terminated"**
3. ✅ Plus de facturation

---

## 💰 Étape 9 : Gestion des Coûts

### 9.1 Vérifier les coûts

**Console AWS** :
1. AWS Console > Billing > Bills
2. Filtrer par service : EMR, S3, EC2
3. Vérifier les coûts du mois en cours

### 9.2 Estimation des coûts

| Service | Ressource | Durée | Coût unitaire | Total |
|---------|-----------|-------|---------------|-------|
| EMR | 1 master m5.xlarge | 3h | 0.23€/h | ~0.70€ |
| EMR | 2 core m5.xlarge | 3h | 0.23€/h × 2 | ~1.40€ |
| EMR | EMR surcharge | 3h | 0.07€/h × 3 | ~0.20€ |
| S3 | Stockage 2 GB | 1 mois | 0.023€/GB | ~0.05€ |
| S3 | Transfert 1.5 GB upload | - | Gratuit | 0€ |
| **TOTAL** | | | | **~2.35€** |

**⚠️ Note** : Si le dataset complet prend 4h à traiter, prévoir ~3-4€

### 9.3 Nettoyage S3 (après projet)

**Supprimer le bucket S3** (après validation du projet) :

```bash
# Supprimer tous les fichiers du bucket
aws s3 rm s3://${BUCKET_NAME}/ --recursive

# Supprimer le bucket
aws s3 rb s3://${BUCKET_NAME}

# Vérifier
aws s3 ls
```

---

## 📋 Checklist Complète

### Avant de commencer
- [ ] Compte AWS actif
- [ ] Carte de crédit configurée sur AWS
- [ ] Pipeline local validé
- [ ] Dataset local disponible

### Installation et configuration (30 min)
- [ ] AWS CLI installé
- [ ] Clés IAM créées
- [ ] AWS CLI configuré avec région EU
- [ ] Identité AWS vérifiée

### Bucket S3 (30 min)
- [ ] Bucket S3 créé en région EU
- [ ] Accès public bloqué
- [ ] Structure de dossiers créée
- [ ] Dataset uploadé (67,692 images)
- [ ] Upload vérifié

### Cluster EMR (15 min création + 3h exécution)
- [ ] Paire de clés SSH créée
- [ ] Cluster EMR lancé
- [ ] Cluster en état WAITING
- [ ] DNS du master récupéré

### Exécution (3-4h)
- [ ] Tunnel SSH créé
- [ ] JupyterHub accessible
- [ ] Notebook créé sur EMR
- [ ] Code adapté pour S3
- [ ] Test sur 100 images réussi
- [ ] Dataset complet traité
- [ ] Résultats vérifiés sur S3

### Résultats et nettoyage (30 min)
- [ ] Features téléchargées
- [ ] Résultats PCA téléchargés
- [ ] Cluster EMR arrêté (TERMINATED)
- [ ] Coûts vérifiés

### Après le projet
- [ ] Bucket S3 supprimé (optionnel)
- [ ] Clés IAM désactivées (si non réutilisées)

---

## 🚨 Dépannage

### Problème : AWS CLI non trouvé après installation

```bash
# Vérifier le PATH
echo $PATH

# Ajouter au PATH si nécessaire
export PATH=$PATH:/usr/local/bin

# Ou relancer le terminal
```

### Problème : Connexion SSH refusée

```bash
# Vérifier que le security group autorise votre IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Votre IP publique: ${MY_IP}"

# Ouvrir le port SSH pour votre IP
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32
```

### Problème : Import TensorFlow échoue sur EMR

```python
# Installer TensorFlow dans une cellule du notebook
import sys
!{sys.executable} -m pip install tensorflow==2.16.1

# Redémarrer le kernel après installation
```

### Problème : Out of Memory sur EMR

```python
# Réduire le nombre d'images traitées en parallèle
spark.conf.set("spark.sql.execution.arrow.maxRecordsPerBatch", "512")

# Ou augmenter la mémoire des executors via la configuration du cluster
```

### Problème : Cluster bloqué en état STARTING

```bash
# Vérifier les logs du cluster
aws emr describe-cluster --cluster-id ${CLUSTER_ID}

# Si bloqué > 20 min, arrêter et recréer
aws emr terminate-clusters --cluster-ids ${CLUSTER_ID}
```

---

## 📚 Ressources Complémentaires

**Documentation AWS** :
- [AWS CLI Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [EMR Getting Started](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-gs.html)
- [EMR avec JupyterHub](https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-jupyterhub.html)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)

**Pricing** :
- [EMR Pricing Calculator](https://aws.amazon.com/emr/pricing/)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)

**Support** :
- [AWS Forums](https://forums.aws.amazon.com/)
- [Stack Overflow - aws-emr](https://stackoverflow.com/questions/tagged/amazon-emr)

---

## 🎯 Prochaines Étapes

Après avoir terminé la migration AWS :

1. **Documentation** :
   - Finaliser le notebook avec commentaires
   - Exporter le notebook en HTML
   - Documenter les résultats et performances

2. **Présentation** :
   - Créer le support de présentation
   - Préparer les schémas d'architecture
   - Screenshots du code clé et de l'exécution EMR

3. **Livrables finaux** :
   - `David_Scanu_1_notebook_112025.ipynb`
   - `David_Scanu_2_images_112025.pdf` (lien S3 + screenshots)
   - `David_Scanu_3_presentation_112025.pdf`

---

**Dernière mise à jour** : 7 Novembre 2025
**Auteur** : Guide créé pour le Projet 11 OpenClassrooms