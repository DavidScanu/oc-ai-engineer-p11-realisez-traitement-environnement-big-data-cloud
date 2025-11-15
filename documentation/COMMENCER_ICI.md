# 🚀 COMMENCER ICI - Migration AWS

**Vous êtes prêt à migrer votre pipeline PySpark vers AWS EMR !**

---

## ✅ Ce qui est déjà fait

- Pipeline PySpark complet validé localement
- Broadcast TensorFlow fonctionnel
- PCA implémentée et testée
- 100 images traitées avec succès
- Code documenté et optimisé

---

## 📚 Documentation Disponible

| Fichier | Description | Quand l'utiliser |
|---------|-------------|------------------|
| **[QUICKSTART_AWS.md](documentation/QUICKSTART_AWS.md)** | Démarrage rapide en 5 étapes | ⭐ **Commencez ici** |
| **[GUIDE_MIGRATION_AWS.md](documentation/GUIDE_MIGRATION_AWS.md)** | Guide complet détaillé | Pour les détails techniques |
| **[README_AWS_MIGRATION.md](README_AWS_MIGRATION.md)** | Vue d'ensemble du projet | Pour comprendre le contexte |
| **[COMMANDES_AWS.txt](COMMANDES_AWS.txt)** | Liste de toutes les commandes | Aide-mémoire rapide |
| **[scripts/aws_setup.sh](scripts/aws_setup.sh)** | Script d'automatisation | Pour automatiser les tâches |

---

## ⚡ Démarrage Ultra-Rapide

### 1️⃣ Voir le Quick Start (5 min)

```bash
cat documentation/QUICKSTART_AWS.md
```

### 2️⃣ Utiliser le script automatique (recommandé)

```bash
# Voir l'aide
./scripts/aws_setup.sh help

# Étapes principales
./scripts/aws_setup.sh create-bucket        # 1. Créer bucket S3
./scripts/aws_setup.sh upload-dataset       # 2. Upload dataset (~30 min)
./scripts/aws_setup.sh create-cluster       # 3. Créer cluster EMR (~15 min)
./scripts/aws_setup.sh status               # 4. Vérifier le statut
./scripts/aws_setup.sh connect              # 5. Se connecter (tunnel SSH)
```

### 3️⃣ Ou suivre le guide détaillé

```bash
# Pour des explications complètes
less documentation/GUIDE_MIGRATION_AWS.md
```

---

## 📋 Checklist Rapide

### Avant de commencer (vérifiez que vous avez) :
- [ ] Compte AWS actif
- [ ] Carte de crédit configurée sur AWS
- [ ] ~10€ de budget disponible
- [ ] 3-4 heures de temps disponible

### Étapes principales :
1. [ ] Installer AWS CLI (~5 min)
2. [ ] Configurer AWS CLI avec vos identifiants (~5 min)
3. [ ] Créer le bucket S3 en région EU (~2 min)
4. [ ] Uploader le dataset sur S3 (~30 min)
5. [ ] Créer le cluster EMR (~15 min de setup)
6. [ ] Exécuter le pipeline (~3-4h de traitement)
7. [ ] Télécharger les résultats (~10 min)
8. [ ] **ARRÊTER LE CLUSTER** ⚠️ (~1 min)

---

## 💰 Budget

| Ressource | Coût estimé |
|-----------|-------------|
| Cluster EMR (3h) | ~2.30€ |
| Stockage S3 | ~0.05€ |
| **TOTAL** | **~2.35€** |

⚠️ **Important** : Arrêter le cluster après utilisation pour éviter les coûts inutiles

---

## 🆘 Besoin d'Aide ?

### Problèmes courants

**AWS CLI non installé** :
```bash
# Installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Clés IAM manquantes** :
- Console AWS → IAM → Utilisateurs → Créer une clé d'accès
- Permissions requises : S3FullAccess, EMRFullAccess, EC2FullAccess

**Cluster bloqué** :
```bash
# Vérifier le statut
./scripts/aws_setup.sh status

# Si bloqué > 20 min, arrêter et recréer
./scripts/aws_setup.sh terminate
```

### Documentation

- **Guide rapide** : [QUICKSTART_AWS.md](documentation/QUICKSTART_AWS.md)
- **Guide complet** : [GUIDE_MIGRATION_AWS.md](documentation/GUIDE_MIGRATION_AWS.md)
- **Dépannage** : Section "Dépannage" dans le guide complet

---

## 🎯 Prochaine Action

**Pour commencer maintenant** :

```bash
# Option 1 : Script automatique (recommandé)
./scripts/aws_setup.sh create-bucket

# Option 2 : Guide rapide
cat documentation/QUICKSTART_AWS.md

# Option 3 : Guide complet
less documentation/GUIDE_MIGRATION_AWS.md
```

---

**Bonne migration ! 🚀**
