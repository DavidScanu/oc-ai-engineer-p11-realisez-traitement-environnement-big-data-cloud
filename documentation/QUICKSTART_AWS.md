# Quick Start - Migration AWS (5 étapes)

**Guide complet** : Voir [GUIDE_MIGRATION_AWS.md](GUIDE_MIGRATION_AWS.md)

---

## 📋 Prérequis

- ✅ Compte AWS actif
- ✅ Pipeline local validé (100 images testées)
- ✅ Dataset local disponible

---

## 🚀 Démarrage Rapide (30 minutes setup + 3h exécution)

### Étape 1 : Installer AWS CLI (5 min)

```bash
# Télécharger et installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Vérifier
aws --version
```

### Étape 2 : Configurer AWS CLI (5 min)

1. **Créer les clés IAM** :
   - Console AWS → IAM → Utilisateurs → Votre user → Sécurité
   - "Créer une clé d'accès" → CLI
   - **Noter** : Access Key + Secret Key

2. **Configurer** :
```bash
aws configure
# AWS Access Key ID: VOTRE_CLE
# AWS Secret Access Key: VOTRE_CLE_SECRETE
# Default region: eu-west-1
# Default output format: json
```

### Étape 3 : Créer le bucket S3 et uploader le dataset (30 min)

**Option A - Script automatique (recommandé)** :
```bash
# Créer le bucket
./scripts/aws_setup.sh create-bucket

# Uploader le dataset (10-30 min)
./scripts/aws_setup.sh upload-dataset
```

**Option B - Commandes manuelles** :
```bash
# Créer le bucket
BUCKET_NAME="oc-p11-fruits-$(date +%Y%m%d)"
aws s3 mb s3://${BUCKET_NAME} --region eu-west-1

# Uploader
aws s3 sync data/raw/fruits-360_dataset/fruits-360/Training/ \
    s3://${BUCKET_NAME}/data/raw/Training/
```

### Étape 4 : Créer et lancer le cluster EMR (15 min)

**Option A - Script automatique (recommandé)** :
```bash
# Créer le cluster (coût: ~2-3€/h)
./scripts/aws_setup.sh create-cluster

# Suivre le démarrage
./scripts/aws_setup.sh status
```

**Option B - Commande manuelle** :
```bash
# Créer la clé SSH
aws ec2 create-key-pair --key-name emr-key \
    --query 'KeyMaterial' --output text > ~/.ssh/emr-key.pem
chmod 400 ~/.ssh/emr-key.pem

# Créer le cluster
aws emr create-cluster \
    --name "P11-Fruits-BigData" \
    --region eu-west-1 \
    --release-label emr-7.5.0 \
    --applications Name=Spark Name=JupyterHub Name=Hadoop \
    --instance-groups \
        InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m5.xlarge \
        InstanceGroupType=CORE,InstanceCount=2,InstanceType=m5.xlarge \
    --ec2-attributes KeyName=emr-key \
    --use-default-roles
```

### Étape 5 : Générer le notebook EMR et l'uploader (5 min)

1. **Générer le notebook EMR adapté** :
```bash
# Convertir automatiquement le notebook local pour EMR
python3 scripts/convert_notebook_to_emr.py
```

Cela crée `notebooks/p11-david-scanu-EMR-production.ipynb` avec :
- ✅ Chemins S3 au lieu de chemins locaux
- ✅ Configuration Spark pour EMR (pas de `.master("local[*]")`)
- ✅ Sauvegardes vers S3 au lieu du disque local

2. **Créer le tunnel SSH** :
```bash
./scripts/aws_setup.sh connect
```

3. **Accéder à JupyterHub** :
   - Navigateur : https://localhost:9443
   - Username : `jovyan`
   - Password : `jupyter`

4. **Uploader le notebook EMR** :
   - Clic sur "Upload" dans JupyterHub
   - Sélectionner `notebooks/p11-david-scanu-EMR-production.ipynb`
   - Clic sur "Upload" pour confirmer

5. **Installer TensorFlow sur le cluster** (dans le notebook EMR, cellule 1) :
```python
import sys
!{sys.executable} -m pip install tensorflow==2.16.1 pillow --quiet
```

6. **Exécuter le pipeline** :
   - **Test rapide** : 100 images (~10 min) - MODE MINI activé par défaut
   - **Dataset complet** : 67,692 images (~3-4h) - Changer `TEST_MODE = "full"`

---

## 📥 Récupérer les Résultats et Arrêter

### Télécharger les résultats

```bash
# Via le script
./scripts/aws_setup.sh download-results

# Ou manuellement
aws s3 sync s3://${BUCKET_NAME}/data/pca/ data/emr_output/pca/
```

### ⚠️ IMPORTANT : Arrêter le cluster

```bash
# Via le script
./scripts/aws_setup.sh terminate

# Vérifier l'arrêt
./scripts/aws_setup.sh status
```

**🔴 NE PAS OUBLIER** sinon facturation continue !

---

## 💰 Coûts Estimés

| Ressource | Durée | Coût |
|-----------|-------|------|
| EMR (1 master + 2 workers m5.xlarge) | 3h | ~2.30€ |
| S3 stockage 2 GB | 1 mois | ~0.05€ |
| **TOTAL** | | **~2.35€** |

---

## 🆘 Dépannage Rapide

### AWS CLI non trouvé après installation
```bash
export PATH=$PATH:/usr/local/bin
# Ou relancer le terminal
```

### Connexion SSH refusée
```bash
# Ouvrir le port SSH pour votre IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp --port 22 \
    --cidr ${MY_IP}/32
```

### TensorFlow manquant sur EMR
```python
# Dans le notebook EMR
import sys
!{sys.executable} -m pip install tensorflow==2.16.1
```

---

## 📚 Ressources

- **Guide complet** : [GUIDE_MIGRATION_AWS.md](GUIDE_MIGRATION_AWS.md)
- **Notebook local** : [notebooks/p11-david-scanu-local-development.ipynb](../notebooks/p11-david-scanu-local-development.ipynb)
- **Script helper** : [scripts/aws_setup.sh](../scripts/aws_setup.sh)

---

## 🎯 Checklist Rapide

### Setup (30 min)
- [ ] AWS CLI installé et configuré
- [ ] Bucket S3 créé en région EU
- [ ] Dataset uploadé sur S3

### Exécution (3-4h)
- [ ] Cluster EMR lancé
- [ ] Tunnel SSH créé
- [ ] JupyterHub accessible
- [ ] Notebook créé avec code adapté
- [ ] Pipeline exécuté avec succès

### Finalisation (30 min)
- [ ] Résultats téléchargés
- [ ] Cluster EMR arrêté ⚠️
- [ ] Coûts vérifiés

---

**Dernière mise à jour** : 7 Novembre 2025