# 🗑️ Guide de Nettoyage du Projet

Ce document liste les fichiers obsolètes qui peuvent être supprimés en toute sécurité.

---

## ⚠️ Important : Sauvegarder avant de nettoyer

```bash
# Créer un commit avant le nettoyage
git add -A
git commit -m "save: Avant nettoyage des fichiers obsolètes"
git push
```

---

## 📂 Fichiers obsolètes à supprimer

### 1. Dossier `documentation/` (approche JupyterHub abandonnée)

**Raison** : Tentatives d'utilisation de JupyterHub/EMR Studio qui n'ont pas fonctionné. L'approche finale utilise des scripts bash + EMR steps (dans `traitement/`).

```bash
rm -rf documentation/
```

**Fichiers supprimés** :
- `COMMANDES_AWS.txt`
- `COMMENCER_ICI.md`
- `COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md`
- `DATASET_INFO.md`
- `FICHIERS_PYSPARK.md`
- `GUIDE_EMR_STUDIO.md`
- `GUIDE_MIGRATION_AWS.md`
- `GUIDE_RAPIDE_EMR_STUDIO.md`
- `LISEZMOI_STRUCTURE.md`
- `MISSION.md`
- `PLAN_ACTION.md`
- `QUICKSTART_AWS.md`
- `README_AWS_MIGRATION.md`
- `aws-commands.md`
- `aws-install.md`
- `aws-test-ec2-micro.md`

---

### 2. Fichiers de configuration JupyterHub (racine)

**Raison** : Configurations pour JupyterHub (non utilisé).

```bash
rm -f jupyterhub_config_not_working.py
rm -f jupyterhub_config_working.py
rm -f set_jupyter_env.sh
rm -f config.json
```

---

### 3. Scripts EMR Studio non utilisés

**Raison** : Scripts de setup EMR Studio (approche abandonnée).

```bash
rm -f scripts/aws_emr_studio_setup.sh
```

---

## ✅ Fichiers à CONSERVER

### Structure finale recommandée

```
oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/
│
├── traitement/              ✅ PIPELINE PRINCIPAL
│   ├── etape_1/
│   └── etape_2/             ⭐ PIPELINE COMPLET (MobileNetV2 + PCA)
│
├── notebooks/               ✅ Notebooks de développement
│   ├── p11-emr-fruits-pca.ipynb
│   └── alternant/
│
├── scripts/                 ✅ Utilitaires
│   └── aws_audit.sh
│
├── .claude/                 ✅ Instructions Claude
│   └── CLAUDE.md
│
├── README.md                ✅ Documentation principale
├── NETTOYAGE.md             ✅ Ce fichier
└── .gitignore               ✅ Git config
```

---

## 🚀 Commandes de nettoyage complètes

### Option 1 : Nettoyage total (recommandé)

```bash
# 1. Commit de sauvegarde
git add -A
git commit -m "save: Avant nettoyage des fichiers obsolètes"
git push

# 2. Supprimer les fichiers obsolètes
rm -rf documentation/
rm -f jupyterhub_config_not_working.py
rm -f jupyterhub_config_working.py
rm -f set_jupyter_env.sh
rm -f config.json
rm -f scripts/aws_emr_studio_setup.sh

# 3. Vérifier ce qui reste
tree -L 2 -I 'node_modules|.git|__pycache__|output|logs'

# 4. Commit du nettoyage
git add -A
git commit -m "chore: Nettoyage fichiers obsolètes (JupyterHub, EMR Studio)"
git push
```

---

### Option 2 : Nettoyage progressif

Si vous préférez vérifier avant chaque suppression :

```bash
# 1. Examiner le dossier documentation
ls -la documentation/

# 2. Supprimer documentation/
rm -rf documentation/
git status

# 3. Examiner les fichiers JupyterHub
ls -la jupyterhub_config_*.py set_jupyter_env.sh config.json

# 4. Supprimer les configs JupyterHub
rm -f jupyterhub_config_*.py set_jupyter_env.sh config.json
git status

# 5. Supprimer script EMR Studio
rm -f scripts/aws_emr_studio_setup.sh
git status

# 6. Commit final
git add -A
git commit -m "chore: Nettoyage fichiers obsolètes"
git push
```

---

## 📊 Espace libéré

Estimation de l'espace libéré :

```bash
# Avant nettoyage
du -sh documentation/ jupyterhub_config_*.py set_jupyter_env.sh config.json scripts/aws_emr_studio_setup.sh 2>/dev/null | awk '{sum+=$1} END {print sum " KB libérés"}'
```

**Estimation** : ~200-300 KB (fichiers markdown et configs)

---

## ✅ Vérification post-nettoyage

```bash
# Vérifier la structure finale
tree -L 2 -I 'node_modules|.git|__pycache__|output|logs'

# Vérifier que traitement/ est intact
ls -la traitement/etape_2/scripts/

# Vérifier git status
git status
```

**Attendu** :
- ✅ `traitement/etape_1/` et `traitement/etape_2/` intacts
- ✅ `notebooks/` intact
- ✅ `scripts/aws_audit.sh` présent
- ✅ Pas de fichiers JupyterHub ou EMR Studio

---

## 📝 Message de commit recommandé

```bash
git commit -m "chore: 🗑️ Nettoyage fichiers obsolètes

Suppression des fichiers liés aux approches abandonnées :
- documentation/ (guides JupyterHub/EMR Studio non fonctionnels)
- jupyterhub_config_*.py (configs JupyterHub inutilisées)
- set_jupyter_env.sh (script JupyterHub)
- config.json (config générique)
- scripts/aws_emr_studio_setup.sh (EMR Studio non utilisé)

Approche finale retenue : EMR Steps + scripts bash (traitement/)

Conservation :
- traitement/etape_1/ et etape_2/ (pipeline principal)
- notebooks/ (développement local)
- scripts/aws_audit.sh (utilitaire)
"
```

---

## 🔍 Diagnostic des fichiers restants

Si vous avez un doute sur d'autres fichiers, utilisez :

```bash
# Trouver les gros fichiers
find . -type f -size +1M ! -path "./.git/*" ! -path "./node_modules/*" -exec ls -lh {} \; | sort -k5 -hr | head -20

# Trouver les fichiers modifiés récemment
find . -type f -mtime -7 ! -path "./.git/*" ! -path "./node_modules/*" -ls | sort -k10,11

# Trouver les doublons potentiels
find . -type f -name "*.md" ! -path "./.git/*" | sort
```

---

## 💡 Après le nettoyage

1. **Tester** : Vérifier que `traitement/etape_2/` fonctionne toujours
2. **Documenter** : Le README.md est déjà à jour
3. **Archiver** : Si besoin, créer une branche `archive/old-jupyterhub-approach`

```bash
# Optionnel : Archiver l'ancienne approche dans une branche
git checkout -b archive/old-jupyterhub-approach HEAD~1
git push origin archive/old-jupyterhub-approach
git checkout main
```

---

**✅ Nettoyage terminé ! Votre projet est maintenant plus clair et focalisé sur l'approche fonctionnelle.**
