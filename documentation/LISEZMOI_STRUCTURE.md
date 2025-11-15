# 📂 Structure du Projet P11 - Big Data Fruits

**Mise à jour** : 2025-11-14
**Statut** : Deux approches disponibles (JupyterHub + EMR Studio)

---

## 🗂️ Organisation des Fichiers

```
oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/
│
├── 📄 Guides de Démarrage Rapide
│   ├── COMMENCER_ICI.md                          # 👈 Point d'entrée principal
│   ├── COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md   # Quelle approche choisir ?
│   ├── GUIDE_RAPIDE_EMR_STUDIO.md                # Guide rapide EMR Studio
│   └── README_AWS_MIGRATION.md                   # Migration JupyterHub (existant)
│
├── 📜 Scripts d'Automatisation
│   ├── scripts/
│   │   ├── aws_setup.sh                          # JupyterHub (approche simple)
│   │   └── aws_emr_studio_setup.sh               # EMR Studio (approche pro)
│
├── 📓 Notebooks PySpark
│   ├── notebooks/
│   │   ├── p11-emr-fruits-pca.ipynb              # Pour JupyterHub
│   │   ├── p11-emr-studio-fruits-pca.ipynb       # Pour EMR Studio ⭐ NOUVEAU
│   │   └── p11-david-scanu-EMR-production.ipynb  # Ancien (référence)
│
├── 📚 Documentation Complète
│   ├── documentation/
│   │   ├── GUIDE_MIGRATION_AWS.md                # Migration vers AWS
│   │   ├── GUIDE_EMR_STUDIO.md                   # Guide complet EMR Studio ⭐ NOUVEAU
│   │   ├── QUICKSTART_AWS.md                     # Démarrage rapide AWS
│   │   ├── PLAN_ACTION.md                        # Plan d'action projet
│   │   └── DATASET_INFO.md                       # Info dataset Fruits-360
│
├── 💾 Données (non versionné)
│   └── data/
│       ├── raw/                                  # Dataset Fruits-360 (local)
│       └── emr_output/                           # Résultats téléchargés d'EMR
│
├── ⚙️ Configuration (non versionné)
│   └── .aws/
│       ├── config.env                            # Config JupyterHub
│       └── emr_studio_config.env                 # Config EMR Studio
│
└── 📋 Fichiers de Configuration
    ├── .gitignore                                # Ignorer data/ et .aws/
    ├── requirements.txt                          # Dépendances Python
    └── CLAUDE.md                                 # Instructions pour Claude Code
```

---

## 🎯 Quelle Approche Utiliser ?

### 🔵 Approche JupyterHub (Simple)

**Pour qui ?**
- Soutenance OpenClassrooms P11
- Tests et prototypes rapides
- Apprentissage de PySpark
- Environnement pédagogique

**Fichiers à utiliser** :
```bash
scripts/aws_setup.sh                    # Script setup
notebooks/p11-emr-fruits-pca.ipynb      # Notebook
README_AWS_MIGRATION.md                 # Guide
```

**Démarrage rapide** :
```bash
./scripts/aws_setup.sh create-bucket
./scripts/aws_setup.sh upload-dataset
./scripts/aws_setup.sh create-cluster
./scripts/aws_setup.sh connect
# Naviguer vers https://localhost:9443
```

**Documentation** : [README_AWS_MIGRATION.md](README_AWS_MIGRATION.md)

---

### 🟢 Approche EMR Studio (Professionnelle)

**Pour qui ?**
- Portfolio professionnel
- Projets en équipe
- Environnement de production
- Intégration Git/CI-CD

**Fichiers à utiliser** :
```bash
scripts/aws_emr_studio_setup.sh               # Script setup
notebooks/p11-emr-studio-fruits-pca.ipynb     # Notebook
documentation/GUIDE_EMR_STUDIO.md             # Guide complet
GUIDE_RAPIDE_EMR_STUDIO.md                    # Guide rapide
```

**Démarrage rapide** :
```bash
./scripts/aws_emr_studio_setup.sh create-bucket
./scripts/aws_emr_studio_setup.sh upload-dataset
./scripts/aws_emr_studio_setup.sh create-studio
./scripts/aws_emr_studio_setup.sh create-cluster
# Ouvrir l'URL EMR Studio affichée
```

**Documentation** : [GUIDE_EMR_STUDIO.md](documentation/GUIDE_EMR_STUDIO.md)

---

## 📖 Guides par Cas d'Usage

### 🎓 Je prépare la soutenance OpenClassrooms

1. **Lire** : [COMMENCER_ICI.md](COMMENCER_ICI.md)
2. **Choisir** : Approche JupyterHub (simplicité)
3. **Suivre** : [README_AWS_MIGRATION.md](README_AWS_MIGRATION.md)
4. **Exécuter** : `scripts/aws_setup.sh`
5. **Notebook** : `notebooks/p11-emr-fruits-pca.ipynb`

**Temps total** : 2-3 heures
**Coût estimé** : 5-10€

---

### 💼 Je veux un projet portfolio pro

1. **Lire** : [COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md](COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md)
2. **Choisir** : Approche EMR Studio
3. **Suivre** : [GUIDE_RAPIDE_EMR_STUDIO.md](GUIDE_RAPIDE_EMR_STUDIO.md)
4. **Exécuter** : `scripts/aws_emr_studio_setup.sh`
5. **Notebook** : `notebooks/p11-emr-studio-fruits-pca.ipynb`

**Temps total** : 3-4 heures (setup plus complexe)
**Coût estimé** : 10-20€

---

### 🔬 Je veux tester rapidement (local)

1. **Installer** : PySpark en local
2. **Télécharger** : Dataset Fruits-360 (subset)
3. **Utiliser** : Mode `mini` dans le notebook
4. **Pas de cloud** : Développement 100% local

**Temps total** : 1 heure
**Coût** : 0€

---

### 🏢 Je veux déployer en production entreprise

1. **Lire** : [GUIDE_EMR_STUDIO.md](documentation/GUIDE_EMR_STUDIO.md)
2. **Setup** : EMR Studio + IAM roles avancés
3. **Configurer** : VPC privé, security groups personnalisés
4. **Intégrer** : Git, CI/CD, monitoring CloudWatch
5. **Sécuriser** : Encryption at rest/in transit

**Temps total** : 1-2 jours (infrastructure complète)
**Coût** : Variable selon usage

---

## 🔑 Fichiers Clés par Rôle

### Pour l'Étudiant OpenClassrooms

| Fichier | Description | Priorité |
|---------|-------------|----------|
| [COMMENCER_ICI.md](COMMENCER_ICI.md) | Point d'entrée | ⭐⭐⭐ |
| [README_AWS_MIGRATION.md](README_AWS_MIGRATION.md) | Guide JupyterHub | ⭐⭐⭐ |
| `scripts/aws_setup.sh` | Automation | ⭐⭐⭐ |
| `notebooks/p11-emr-fruits-pca.ipynb` | Notebook principal | ⭐⭐⭐ |
| [COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md](COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md) | Comparaison approches | ⭐⭐ |

---

### Pour le Développeur Pro

| Fichier | Description | Priorité |
|---------|-------------|----------|
| [GUIDE_EMR_STUDIO.md](documentation/GUIDE_EMR_STUDIO.md) | Guide complet EMR Studio | ⭐⭐⭐ |
| [GUIDE_RAPIDE_EMR_STUDIO.md](GUIDE_RAPIDE_EMR_STUDIO.md) | Quick start | ⭐⭐⭐ |
| `scripts/aws_emr_studio_setup.sh` | Automation avancée | ⭐⭐⭐ |
| `notebooks/p11-emr-studio-fruits-pca.ipynb` | Notebook EMR Studio | ⭐⭐⭐ |
| [COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md](COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md) | Décision architecture | ⭐⭐ |

---

### Pour le Jury de Soutenance

| Fichier | Description |
|---------|-------------|
| [COMMENCER_ICI.md](COMMENCER_ICI.md) | Vue d'ensemble projet |
| [documentation/PLAN_ACTION.md](documentation/PLAN_ACTION.md) | Plan et progression |
| `notebooks/p11-emr-fruits-pca.ipynb` | Pipeline PySpark |
| [COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md](COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md) | Justification choix techniques |
| [documentation/GUIDE_MIGRATION_AWS.md](documentation/GUIDE_MIGRATION_AWS.md) | Architecture cloud |

---

## 📊 Comparaison des Scripts

| Critère | `aws_setup.sh` | `aws_emr_studio_setup.sh` |
|---------|----------------|---------------------------|
| **Complexité** | ⭐⭐ Simple | ⭐⭐⭐⭐ Avancé |
| **Applications EMR** | JupyterHub + Spark | Livy + Spark |
| **Connexion** | Tunnel SSH | Web direct |
| **IAM Roles** | Par défaut | Personnalisés |
| **Persistance** | Cluster | S3 |
| **Collaboration** | Non | Oui |
| **Setup time** | 5 min | 30 min |
| **Recommandé pour** | Soutenance | Production |

---

## 🎯 Workflow Recommandé

### Phase 1 : Développement Local (optionnel)

```bash
# Installer dépendances
pip install -r requirements.txt

# Tester le code localement (sans cloud)
jupyter notebook notebooks/p11-emr-fruits-pca.ipynb

# Mode mini (100 images) pour valider la logique
```

---

### Phase 2 : Tests Cloud (JupyterHub)

```bash
# Setup rapide
./scripts/aws_setup.sh create-bucket
./scripts/aws_setup.sh upload-dataset
./scripts/aws_setup.sh create-cluster

# Connexion et tests
./scripts/aws_setup.sh connect
# Uploader notebook, exécuter en mode mini

# Arrêter
./scripts/aws_setup.sh terminate
```

---

### Phase 3 : Production (EMR Studio) - optionnel

```bash
# Setup complet (une fois)
./scripts/aws_emr_studio_setup.sh create-bucket
./scripts/aws_emr_studio_setup.sh upload-dataset
./scripts/aws_emr_studio_setup.sh create-studio

# Chaque session
./scripts/aws_emr_studio_setup.sh create-cluster
# Ouvrir workspace, exécuter notebook
./scripts/aws_emr_studio_setup.sh terminate
```

---

## ⚠️ Fichiers à NE PAS Committer

Ces fichiers sont automatiquement ignorés par `.gitignore` :

```
.aws/                    # Configuration AWS (contient cluster IDs, bucket names)
.aws/config.env          # Config JupyterHub
.aws/emr_studio_config.env   # Config EMR Studio
data/                    # Dataset (1.5 GB)
rootkey.csv              # Credentials AWS (si créées)
.bucket_name             # Anciens fichiers de config (legacy)
.cluster_id
.key_name
.master_dns
```

**🚨 IMPORTANT** : Ne jamais committer de credentials AWS !

---

## 💡 Astuces

### Vérifier les Coûts

```bash
# Clusters actifs (⚠️ coûtent de l'argent !)
aws emr list-clusters --active

# Coûts du mois
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics UnblendedCost
```

---

### Télécharger les Résultats

```bash
# JupyterHub
./scripts/aws_setup.sh download-results

# EMR Studio
./scripts/aws_emr_studio_setup.sh download-results

# Résultats dans : data/emr_output/
```

---

### Nettoyage Complet

```bash
# JupyterHub
./scripts/aws_setup.sh cleanup

# EMR Studio
./scripts/aws_emr_studio_setup.sh cleanup

# ⚠️ Supprime TOUT (cluster + S3 + IAM roles)
```

---

## 📞 Support

### Documentation

- **Quick start** : [COMMENCER_ICI.md](COMMENCER_ICI.md)
- **JupyterHub** : [README_AWS_MIGRATION.md](README_AWS_MIGRATION.md)
- **EMR Studio** : [GUIDE_EMR_STUDIO.md](documentation/GUIDE_EMR_STUDIO.md)
- **Comparaison** : [COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md](COMPARAISON_JUPYTERHUB_VS_EMR_STUDIO.md)

### Ressources AWS

- [EMR Documentation](https://docs.aws.amazon.com/emr/)
- [EMR Studio Guide](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-studio.html)
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)

### Communauté

- [Stack Overflow - PySpark](https://stackoverflow.com/questions/tagged/pyspark)
- [AWS Forums - EMR](https://repost.aws/tags/TAiHN8YCfRQ36ixMIJTtgZhg/amazon-emr)

---

## ✅ Checklist Projet Complet

### Avant de Commencer

- [ ] AWS CLI v2 installé
- [ ] Credentials AWS configurés
- [ ] Région EU sélectionnée (RGPD)
- [ ] Budget AWS confirmé (~10-20€)
- [ ] Documentation lue

### Développement

- [ ] Approche choisie (JupyterHub ou EMR Studio)
- [ ] Bucket S3 créé
- [ ] Dataset uploadé
- [ ] Cluster EMR créé
- [ ] Pipeline testé en mode mini
- [ ] Pipeline exécuté en mode full
- [ ] Résultats vérifiés

### Finalisation

- [ ] Résultats téléchargés localement
- [ ] Cluster arrêté
- [ ] Documentation mise à jour
- [ ] Présentation préparée (si soutenance)
- [ ] Nettoyage AWS effectué

---

## 🎉 Conclusion

Ce projet propose **deux chemins** vers le même objectif :

1. **JupyterHub** : Simple, rapide, parfait pour apprendre et soutenir
2. **EMR Studio** : Professionnel, scalable, idéal pour portfolio et production

**Les deux fonctionnent parfaitement !** Choisissez selon votre contexte.

**Bonne chance ! 🚀**