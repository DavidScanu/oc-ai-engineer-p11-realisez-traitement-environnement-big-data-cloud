# Manifeste des fichiers - Étape 1

## 📦 Fichiers créés

### 📂 Configuration (`config/`)

| Fichier | Taille | Description |
|---------|--------|-------------|
| `config.sh` | 3.1 KB | Configuration centralisée (S3, EMR, réseau, IAM) |

### 🔧 Scripts d'exécution (`scripts/`)

| Fichier | Taille | Type | Description |
|---------|--------|------|-------------|
| `verify_setup.sh` | 5.7 KB | Bash | Vérification de la configuration AWS avant création |
| `upload_scripts.sh` | 2.3 KB | Bash | Upload des scripts et config sur S3 |
| `create_cluster.sh` | 3.4 KB | Bash | Création du cluster EMR avec bootstrap |
| `monitor_cluster.sh` | 3.0 KB | Bash | Surveillance de l'état du cluster (polling) |
| `submit_job.sh` | 3.1 KB | Bash | Soumission du step PySpark sur le cluster |
| `terminate_cluster.sh` | 2.3 KB | Bash | Terminaison du cluster EMR |
| `cleanup.sh` | 4.0 KB | Bash | Nettoyage complet des ressources AWS et locales |
| `install_dependencies.sh` | 959 B | Bash | Bootstrap action (installation packages Python) |
| `read_fruits_data.py` | 5.4 KB | Python | Script PySpark principal (lecture images, métadonnées, CSV) |

### 📚 Documentation (`docs/`)

| Fichier | Taille | Description |
|---------|--------|-------------|
| `QUICKSTART.md` | 2.9 KB | Guide de démarrage rapide (5 minutes) |
| `ARCHITECTURE.md` | 14 KB | Architecture technique détaillée |
| `WORKFLOW.md` | 13 KB | Workflow complet et best practices |

### 📄 Documentation racine

| Fichier | Taille | Description |
|---------|--------|-------------|
| `README.md` | 12 KB | Documentation principale complète |
| `.gitignore` | - | Fichiers à exclure du versioning Git |
| `MANIFEST.md` | - | Ce fichier (liste de tous les fichiers) |

### 📁 Fichiers générés automatiquement (non versionés)

| Fichier | Description |
|---------|-------------|
| `cluster_id.txt` | ID du cluster EMR créé |
| `step_id.txt` | ID du step PySpark soumis |
| `master_dns.txt` | DNS du nœud Master |

## 📊 Statistiques

- **Total fichiers** : 19 fichiers
- **Total taille** : ~159 KB
- **Scripts Bash** : 7 fichiers (24.6 KB)
- **Scripts Python** : 1 fichier (5.4 KB)
- **Configuration** : 2 fichiers (3.4 KB)
- **Documentation** : 4 fichiers (42 KB)

## 🎯 Fichiers clés par cas d'usage

### Démarrage rapide
1. `docs/QUICKSTART.md` → Guide de démarrage
2. `config/config.sh` → Configuration à éditer
3. `scripts/verify_setup.sh` → Vérification
4. `scripts/create_cluster.sh` → Création cluster

### Compréhension du projet
1. `README.md` → Documentation principale
2. `docs/ARCHITECTURE.md` → Architecture technique
3. `docs/WORKFLOW.md` → Workflow détaillé

### Exécution
1. `scripts/upload_scripts.sh` → Upload S3
2. `scripts/create_cluster.sh` → Cluster
3. `scripts/monitor_cluster.sh` → Surveillance
4. `scripts/submit_job.sh` → Job PySpark
5. `scripts/terminate_cluster.sh` → Terminaison

### Debugging
1. `scripts/verify_setup.sh` → Vérifier config
2. `logs/` (après exécution) → Logs locaux
3. S3 logs → `s3://bucket/logs/emr/`

## 🔄 Dépendances entre fichiers

```
config.sh
    ├─► create_cluster.sh
    ├─► monitor_cluster.sh
    ├─► submit_job.sh
    ├─► terminate_cluster.sh
    ├─► cleanup.sh
    ├─► verify_setup.sh
    └─► upload_scripts.sh

install_dependencies.sh
    └─► create_cluster.sh (bootstrap action)

read_fruits_data.py
    └─► submit_job.sh (step)

cluster_id.txt (généré par create_cluster.sh)
    ├─► monitor_cluster.sh
    ├─► submit_job.sh
    ├─► terminate_cluster.sh
    └─► cleanup.sh

step_id.txt (généré par submit_job.sh)
    └─► cleanup.sh
```

## 📝 Ordre d'exécution recommandé

1. ✏️ Éditer `config/config.sh`
2. ✅ `./scripts/verify_setup.sh`
3. 📤 `./scripts/upload_scripts.sh`
4. 🚀 `./scripts/create_cluster.sh`
5. 👀 `./scripts/monitor_cluster.sh` (attendre WAITING)
6. 🎯 `./scripts/submit_job.sh`
7. 📥 Télécharger résultats depuis S3
8. 🛑 `./scripts/terminate_cluster.sh`
9. 🧹 `./scripts/cleanup.sh` (optionnel)

## 🔒 Fichiers sensibles (ne pas versionner)

- `cluster_id.txt` → Contient l'ID du cluster
- `step_id.txt` → Contient l'ID du job
- `master_dns.txt` → Contient le DNS du master
- `*.pem` → Clés SSH privées
- `config.sh.local` → Configuration locale personnalisée
- `credentials.csv` → Credentials AWS

**Note** : Ces fichiers sont déjà dans `.gitignore`

## 📦 Fichiers à uploader sur S3

Via `upload_scripts.sh` :
1. `scripts/install_dependencies.sh` → `s3://bucket/scripts/`
2. `scripts/read_fruits_data.py` → `s3://bucket/scripts/`

## 🔧 Maintenance

### Modification de la configuration
1. Éditer `config/config.sh`
2. Re-exécuter `verify_setup.sh`
3. Si cluster actif : le terminer et recréer

### Modification du script PySpark
1. Éditer `scripts/read_fruits_data.py`
2. Exécuter `upload_scripts.sh`
3. Soumettre nouveau step avec `submit_job.sh`

### Modification du bootstrap
1. Éditer `scripts/install_dependencies.sh`
2. Exécuter `upload_scripts.sh`
3. Recréer le cluster (bootstrap s'exécute au démarrage)

## 📚 Documentation à consulter

| Question | Document |
|----------|----------|
| Comment démarrer rapidement ? | `docs/QUICKSTART.md` |
| Comment fonctionne l'architecture ? | `docs/ARCHITECTURE.md` |
| Quel est le workflow complet ? | `docs/WORKFLOW.md` |
| Détails des scripts et configuration ? | `README.md` |

## ✅ Checklist de validation

- [x] Configuration créée et documentée
- [x] Scripts d'automatisation créés
- [x] Script PySpark fonctionnel
- [x] Documentation complète (4 fichiers)
- [x] Fichiers exécutables (chmod +x)
- [x] .gitignore configuré
- [x] Structure de dossiers claire
- [ ] Tests d'exécution sur AWS (à faire par l'utilisateur)

## 🎓 Prochaines étapes (Étape 2-4)

Fichiers à ajouter pour les prochaines étapes :
- `scripts/extract_features.py` : Extraction de features TensorFlow
- `scripts/broadcast_weights.py` : Broadcast des poids du modèle
- `scripts/apply_pca.py` : PCA distribué
- `config/model_config.sh` : Configuration du modèle TensorFlow

---

**Version** : 1.0
**Date** : 2025-11-18
**Auteur** : Projet P11 - OpenClassrooms AI Engineer
