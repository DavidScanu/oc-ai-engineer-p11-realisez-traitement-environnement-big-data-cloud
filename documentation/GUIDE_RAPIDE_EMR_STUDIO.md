# 🚀 Guide Rapide : AWS EMR Studio pour P11

**⏱️ Durée totale** : 30-45 minutes (setup) + 1-2h (exécution)

---

## 📌 Prérequis (5 min)

```bash
# Vérifier AWS CLI
aws --version  # Doit être v2.x

# Vérifier configuration
aws sts get-caller-identity

# Vérifier région (doit être EU pour RGPD)
aws configure get region  # Devrait être eu-west-1 ou eu-west-3
```

---

## 🏗️ Setup Initial (30 min) - À faire UNE SEULE FOIS

### 1. Créer le bucket S3 (2 min)

```bash
./scripts/aws_emr_studio_setup.sh create-bucket
```

**Résultat attendu** :
```
✅ Bucket créé: s3://oc-p11-fruits-20251114-143022
Configuration sauvegardée dans .aws/emr_studio_config.env
```

**⚠️ NOTER LE NOM DU BUCKET** : vous en aurez besoin dans le notebook

---

### 2. Uploader le dataset (15-30 min)

```bash
./scripts/aws_emr_studio_setup.sh upload-dataset
```

**Taille** : ~1.5 GB (~67,000 images)
**Durée** : Variable selon connexion internet

**Vérification** :
```bash
aws s3 ls s3://VOTRE-BUCKET/data/raw/Training/ --recursive | wc -l
# Devrait afficher ~67692
```

---

### 3. Créer les rôles IAM (2 min)

```bash
./scripts/aws_emr_studio_setup.sh create-iam-roles
```

**Résultat attendu** :
```
✅ Rôles IAM créés:
  Service Role: arn:aws:iam::123456789012:role/EMRStudio_Service_Role
  User Role: arn:aws:iam::123456789012:role/EMRStudio_User_Role
```

---

### 4. Créer EMR Studio (3 min)

```bash
./scripts/aws_emr_studio_setup.sh create-studio
```

**Résultat attendu** :
```
✅ EMR Studio créé: es-XXXXXXXXXXXXX
✅ URL: https://XXXXX.emrstudio-prod.eu-west-1.amazonaws.com
```

**📝 IMPORTANT** : Sauvegarder cette URL quelque part !

---

## 💻 Workflow de Travail (chaque session)

### 5. Créer un cluster EMR (10-15 min)

```bash
./scripts/aws_emr_studio_setup.sh create-cluster m5.xlarge
```

**Types d'instance disponibles** :
- `m5.xlarge` - Standard (4 vCPU, 16 GB RAM) - **Recommandé**
- `m5.2xlarge` - Performance (8 vCPU, 32 GB RAM) - Plus rapide mais 2x le coût
- `m5.large` - Économique (2 vCPU, 8 GB RAM) - Peut être lent

**Coût estimé** :
- m5.xlarge : ~1.50€/h (3 instances)
- m5.2xlarge : ~3.00€/h (3 instances)

**Confirmer** : Taper `y` quand demandé

**Résultat** :
```
✅ Cluster créé: j-XXXXXXXXXXXXX
Le cluster démarre... (10-15 minutes)
```

---

### 6. Attendre le démarrage (10-15 min)

**Vérifier le statut** :
```bash
./scripts/aws_emr_studio_setup.sh status
```

**Attendre cet état** :
```
✅ État: WAITING - Prêt ✓
```

**Pendant ce temps**, vous pouvez passer à l'étape 7.

---

### 7. Créer un Workspace dans EMR Studio (5 min)

1. **Ouvrir EMR Studio**
   - Aller sur l'URL notée à l'étape 4
   - OU : Console AWS → EMR → Studios → Cliquer sur votre studio

2. **Créer un Workspace**
   - Cliquer sur **"Create Workspace"**
   - Name : `P11-Fruits-Workspace`
   - Description : `Projet OpenClassrooms P11 - Classification Fruits`
   - Cliquer sur **"Create Workspace"**

3. **Attendre le workspace** (30 secondes)
   - Le workspace s'ouvre automatiquement

---

### 8. Attacher le cluster au Workspace (1 min)

**Dans le Workspace EMR Studio** :

1. Cliquer sur l'icône **"Compute"** (à gauche)
2. Cliquer sur **"Attach cluster"**
3. Sélectionner votre cluster (celui créé à l'étape 5)
4. Cliquer sur **"Attach"**

**Attendre** : ~30 secondes (connexion Livy)

**Résultat attendu** :
```
✅ Cluster attached: j-XXXXXXXXXXXXX
Kernel: PySpark
```

---

### 9. Uploader et configurer le notebook (2 min)

1. **Uploader le notebook**
   - Glisser-déposer `notebooks/p11-emr-studio-fruits-pca.ipynb`
   - OU : Cliquer sur l'icône upload

2. **Ouvrir le notebook**
   - Double-cliquer sur le fichier

3. **Configurer le bucket S3**
   - Aller à la cellule **1.5** (Configuration des chemins S3)
   - Modifier :
     ```python
     # ⚠️ ADAPTER LE NOM DU BUCKET
     BUCKET_NAME = "oc-p11-fruits-20251114-143022"  # Votre bucket !
     ```

---

### 10. Exécuter le pipeline (1-2h selon mode)

#### Mode MINI (recommandé pour test) - 5-10 min

```python
# Cellule de configuration du mode (garder par défaut)
TEST_MODE = "mini"
MAX_IMAGES = 100
```

**Exécuter toutes les cellules** : Cell → Run All

**Durée** : ~5-10 minutes
**Coût** : ~0.30€

---

#### Mode FULL (production) - 1-2h

```python
# Modifier la cellule de configuration
TEST_MODE = "full"
# MAX_IMAGES n'est pas utilisé en mode full
```

**Exécuter toutes les cellules** : Cell → Run All

**Durée** : ~1-2 heures
**Coût** : ~2-4€

**📊 Progression attendue** :

| Étape | Durée | Cellules |
|-------|-------|----------|
| Setup et imports | 2-5 min | 1-13 |
| Chargement images | 5 min | 15-17 |
| Feature extraction | 30-60 min | 19-25 |
| PCA | 5-10 min | 27-31 |
| Sauvegarde S3 | 2-5 min | 33-35 |
| **TOTAL** | **45-85 min** | |

---

### 11. Vérifier les résultats (2 min)

**Dans le notebook** (cellule 6.1) :
```bash
%%bash
aws s3 ls s3://VOTRE-BUCKET/data/pca/pca_results/ --human-readable
```

**En ligne de commande** :
```bash
./scripts/aws_emr_studio_setup.sh download-results
```

**Résultats téléchargés dans** :
- `data/emr_output/features/` - Features (1280 dimensions)
- `data/emr_output/pca/` - PCA (200 dimensions)

---

### 12. 🚨 ARRÊTER LE CLUSTER (CRITIQUE !)

```bash
./scripts/aws_emr_studio_setup.sh terminate
```

**Confirmer** : Taper `y`

**⚠️ TRÈS IMPORTANT** :
- Le cluster coûte ~1.50€/heure
- Si oublié pendant 1 semaine : ~250€ de facture !
- **Toujours vérifier** :
  ```bash
  aws emr list-clusters --active
  ```

**Vos notebooks sont conservés** ✅
- EMR Studio sauvegarde automatiquement sur S3
- Vous pouvez recréer un cluster plus tard
- Le workspace reste accessible

---

## 📊 Checklist Complète

### Setup Initial (une fois)

- [ ] AWS CLI v2 installé
- [ ] Credentials AWS configurés
- [ ] Région EU sélectionnée (RGPD)
- [ ] Bucket S3 créé
- [ ] Dataset uploadé sur S3
- [ ] Rôles IAM créés
- [ ] EMR Studio créé
- [ ] URL Studio sauvegardée

### Chaque Session de Travail

- [ ] Cluster EMR créé
- [ ] Cluster en état WAITING
- [ ] Workspace créé (première fois seulement)
- [ ] Cluster attaché au workspace
- [ ] Notebook uploadé
- [ ] Bucket name configuré
- [ ] Pipeline exécuté
- [ ] Résultats vérifiés sur S3
- [ ] Résultats téléchargés localement
- [ ] **🚨 CLUSTER ARRÊTÉ** ✅

---

## 🆘 Dépannage Rapide

### "Session timeout"

**Problème** : Session Livy expirée après inactivité

**Solution** : Redémarrer le kernel
1. Kernel → Restart Kernel
2. Re-exécuter les cellules de setup (1-13)

---

### "TensorFlow not found"

**Problème** : TensorFlow non installé sur workers

**Solution** : Réinstaller
```python
sc.install_pypi_package("tensorflow==2.16.1", reinstall=True)
```

---

### "Cannot attach cluster"

**Problème** : Cluster pas encore prêt

**Solution** : Attendre l'état WAITING
```bash
./scripts/aws_emr_studio_setup.sh status
```

---

### "OutOfMemoryError"

**Problème** : Pas assez de mémoire

**Solutions** :
1. Réduire le mode (full → apples → mini)
2. Augmenter le type d'instance (m5.2xlarge)
3. Augmenter le nombre de workers dans le script

---

### "Broadcast too large"

**Problème** : Poids du modèle trop gros

**Solution** : Déjà optimisé dans le notebook, mais si problème :
```python
# Utiliser un modèle plus léger
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2
# Remplacer par MobileNetV3-Small si nécessaire
```

---

## 💰 Estimation des Coûts

### Setup Initial (une fois)

| Item | Coût |
|------|------|
| Bucket S3 création | Gratuit |
| Dataset storage (1.5 GB) | ~0.02€/mois |
| EMR Studio | Gratuit |
| Rôles IAM | Gratuit |
| **TOTAL Setup** | **~0.02€/mois** |

---

### Session de Travail (chaque fois)

**Cluster m5.xlarge (1 master + 2 core)** :

| Durée | Test (mini) | Production (full) |
|-------|-------------|-------------------|
| 30 min | 0.75€ | - |
| 1h | 1.50€ | 1.50€ |
| 2h | 3.00€ | 3.00€ |
| 4h | 6.00€ | - |
| 8h (journée) | 12.00€ | - |

**Budget recommandé pour P11** :
- Tests (3-5 sessions) : 5-10€
- Production (2 runs full) : 5-8€
- **Total projet** : **10-20€**

---

## 📚 Commandes Utiles

```bash
# Vérifier les clusters actifs (⚠️ à utiliser souvent !)
aws emr list-clusters --active

# Vérifier le bucket S3
aws s3 ls s3://VOTRE-BUCKET --recursive --human-readable

# Voir les coûts AWS
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics UnblendedCost

# Status complet
./scripts/aws_emr_studio_setup.sh status

# Télécharger résultats
./scripts/aws_emr_studio_setup.sh download-results

# Nettoyage complet (fin de projet)
./scripts/aws_emr_studio_setup.sh cleanup
```

---

## 🎓 Pour la Soutenance OpenClassrooms

### Ce qui compte

✅ **Pipeline PySpark fonctionnel**
- Chargement distribué depuis S3
- Feature extraction avec TensorFlow
- **Broadcast des poids** (point clé !)
- PCA distribuée
- Résultats sur S3

✅ **Architecture cloud documentée**
- Diagramme (dans GUIDE_EMR_STUDIO.md)
- Justification des choix
- RGPD compliance (région EU)

✅ **Scalabilité démontrée**
- Tests sur différentes tailles (mini → full)
- Multi-workers
- Résultats mesurables

### Ce qui ne compte PAS

❌ Complexité du setup (EMR Studio vs JupyterHub)
❌ Collaboration temps réel
❌ Git intégration
❌ Gestion IAM avancée

**💡 Conseil** : Utilisez JupyterHub pour la simplicité, mentionnez EMR Studio comme "évolution production"

---

## 🚀 Prêt à Commencer ?

**Commande pour démarrer** :

```bash
# Setup complet en une ligne (première fois)
./scripts/aws_emr_studio_setup.sh create-bucket && \
./scripts/aws_emr_studio_setup.sh upload-dataset && \
./scripts/aws_emr_studio_setup.sh create-studio && \
./scripts/aws_emr_studio_setup.sh create-cluster

# Puis ouvrir l'URL du studio affichée !
```

**Temps total** : ~45 minutes + votre temps d'exécution

**Bonne chance ! 🎉**