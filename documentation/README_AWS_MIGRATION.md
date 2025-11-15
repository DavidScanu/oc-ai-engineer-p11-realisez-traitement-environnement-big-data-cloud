# Migration AWS - Projet P11 Big Data Fruits

**Statut** : ✅ Pipeline local validé - Prêt pour migration AWS
**Date** : 7 Novembre 2025

---

## 📋 Résumé du Projet

Ce projet implémente un pipeline de traitement Big Data pour la classification d'images de fruits en utilisant :
- **PySpark** pour le traitement distribué
- **TensorFlow MobileNetV2** pour l'extraction de features
- **PCA** pour la réduction de dimensionnalité
- **AWS EMR + S3** pour l'infrastructure cloud

### Ce qui a été réalisé (Phase 2 - Local)

✅ **Pipeline PySpark complet** :
- Chargement et traitement de 100 images validé
- Broadcast des poids TensorFlow fonctionnel (260 tenseurs, 8.61 MB)
- Extraction de features : 1280 dimensions par image
- PCA : réduction 1280 → 200 dimensions
- Sauvegarde multi-format (Parquet + CSV)

✅ **Documentation complète** :
- Notebook bien structuré avec 8 sections
- 4 modes de test (MINI, SINGLE_CLASS, APPLES, FULL)
- Code commenté et optimisé

### Prochaine étape : Migration AWS (Phase 3)

🎯 **Objectif** : Déployer le pipeline sur AWS EMR pour traiter les 67,692 images du dataset complet

---

## 🚀 Démarrage Rapide

### Option 1 : Guide Rapide (5 étapes - 30 min)

Suivez le guide de démarrage rapide :

```bash
cat documentation/QUICKSTART_AWS.md
```

**Les 5 étapes** :
1. Installer AWS CLI (5 min)
2. Configurer AWS CLI (5 min)
3. Créer bucket S3 + uploader dataset (30 min)
4. Créer cluster EMR (15 min)
5. Exécuter le pipeline (3-4h)

### Option 2 : Script Automatique (recommandé)

Utilisez le script helper pour automatiser les commandes :

```bash
# Afficher l'aide
./scripts/aws_setup.sh help

# Étapes principales
./scripts/aws_setup.sh create-bucket        # Créer le bucket S3
./scripts/aws_setup.sh upload-dataset       # Upload dataset
./scripts/aws_setup.sh create-cluster       # Créer le cluster EMR
./scripts/aws_setup.sh status               # Vérifier le statut
./scripts/aws_setup.sh connect              # Se connecter (tunnel SSH)
./scripts/aws_setup.sh download-results     # Télécharger les résultats
./scripts/aws_setup.sh terminate            # Arrêter le cluster
```

### Option 3 : Guide Complet (détaillé)

Pour des instructions détaillées avec toutes les explications :

```bash
cat documentation/GUIDE_MIGRATION_AWS.md
```

---

## 📁 Structure du Projet

```
.
├── data/
│   ├── raw/
│   │   └── fruits-360_dataset/        # Dataset local (67,692 images)
│   ├── features/                      # Features extraites (local)
│   ├── pca/                           # Résultats PCA (local)
│   └── emr_output/                    # Résultats téléchargés depuis AWS
│
├── notebooks/
│   ├── p11-david-scanu-local-development.ipynb    # ✅ Pipeline validé
│   └── alternant/
│       └── P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb
│
├── scripts/
│   └── aws_setup.sh                   # 🛠️ Script helper AWS
│
└── documentation/
    ├── PLAN_ACTION.md                 # Plan détaillé du projet
    ├── GUIDE_MIGRATION_AWS.md         # 📘 Guide complet AWS
    ├── QUICKSTART_AWS.md              # ⚡ Démarrage rapide
    ├── DATASET_INFO.md                # Infos sur le dataset
    └── MISSION.md                     # Contexte du projet
```

---

## 🎯 Pipeline PySpark

### Architecture

```
┌─────────────────┐
│  Images S3      │ ─┐
│  67,692 images  │  │
└─────────────────┘  │
                     ▼
              ┌─────────────┐
              │   PySpark   │
              │   Cluster   │
              └─────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   ┌────────┐  ┌────────┐  ┌────────┐
   │Worker 1│  │Worker 2│  │Worker 3│
   └────────┘  └────────┘  └────────┘
        │            │            │
        └────────────┴────────────┘
                     │
              ┌──────▼──────┐
              │  Broadcast  │
              │  Weights    │
              │  (8.61 MB)  │
              └──────┬──────┘
                     │
              ┌──────▼──────────┐
              │  MobileNetV2    │
              │  Feature Extract│
              │  (1280 dims)    │
              └──────┬──────────┘
                     │
              ┌──────▼──────┐
              │     PCA     │
              │  (200 dims) │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │ Results S3  │
              │ Parquet+CSV │
              └─────────────┘
```

### Composants Clés

1. **Broadcast TensorFlow** :
   - Optimisation cruciale pour éviter de recharger le modèle sur chaque worker
   - 260 tenseurs (~8.61 MB) distribués une seule fois
   - Gain de performance significatif

2. **Pandas UDF** :
   - Traitement par batch d'images
   - Utilisation d'Apache Arrow pour la sérialisation
   - Parallélisation automatique par Spark

3. **PCA distribué** :
   - `pyspark.ml.feature.PCA`
   - Réduction 1280 → 200 dimensions
   - Conservation excellente de la variance

---

## 💰 Estimation des Coûts AWS

| Composant | Configuration | Durée | Coût |
|-----------|---------------|-------|------|
| EMR Master | m5.xlarge | 3h | ~0.70€ |
| EMR Core (x2) | m5.xlarge | 3h | ~1.40€ |
| EMR Surcharge | - | 3h | ~0.20€ |
| S3 Stockage | 2 GB | 1 mois | ~0.05€ |
| **TOTAL** | | | **~2.35€** |

**⚠️ Note** : Si le traitement du dataset complet prend 4h, prévoir ~3-4€

---

## 📊 Performances Attendues

### Tests Locaux (référence)

| Mode | Images | Temps Features | Temps PCA | Total |
|------|--------|----------------|-----------|-------|
| MINI | 100 | ~2 min | ~4 sec | ~2-3 min |
| MINI | 500 | ~8 min | ~30 sec | ~8-10 min |

### Projections AWS EMR (3 workers m5.xlarge)

| Dataset | Images | Temps Estimé | Coût Estimé |
|---------|--------|--------------|-------------|
| Apples | 6,404 | ~1h | ~1€ |
| Full | 67,692 | ~3-4h | ~2.35-3€ |

**Facteurs d'accélération** :
- Parallélisation sur 3 workers
- Broadcast évite les rechargements réseau
- S3A filesystem optimisé pour EMR 7.x

---

## ✅ Checklist Migration

### Prérequis
- [ ] Compte AWS actif avec carte de crédit
- [ ] Dataset local téléchargé et extrait
- [ ] Pipeline local testé et validé

### Configuration AWS (30 min)
- [ ] AWS CLI installé
- [ ] Clés IAM créées et configurées
- [ ] Région EU configurée (eu-west-1 ou eu-central-1)

### Bucket S3 (30 min)
- [ ] Bucket créé en région européenne
- [ ] Accès public bloqué
- [ ] Dataset uploadé (67,692 images)
- [ ] Structure de dossiers créée

### Cluster EMR (15 min + 3-4h exécution)
- [ ] Paire de clés SSH créée
- [ ] Cluster EMR lancé (EMR 7.5.0, Spark 3.5.x)
- [ ] Cluster en état WAITING
- [ ] Tunnel SSH créé vers JupyterHub

### Exécution (3-4h)
- [ ] JupyterHub accessible (https://localhost:9443)
- [ ] Notebook créé avec code adapté
- [ ] Test rapide 100 images réussi
- [ ] Dataset complet traité
- [ ] Résultats vérifiés sur S3

### Finalisation (30 min)
- [ ] Résultats téléchargés localement
- [ ] Cluster EMR arrêté (état TERMINATED)
- [ ] Coûts vérifiés dans AWS Billing

---

## 🆘 Support et Documentation

### Guides disponibles

1. **[QUICKSTART_AWS.md](documentation/QUICKSTART_AWS.md)** - Démarrage rapide en 5 étapes
2. **[GUIDE_MIGRATION_AWS.md](documentation/GUIDE_MIGRATION_AWS.md)** - Guide complet détaillé
3. **[PLAN_ACTION.md](documentation/PLAN_ACTION.md)** - Plan global du projet
4. **[aws_setup.sh](scripts/aws_setup.sh)** - Script d'automatisation

### Notebook de référence

- **[p11-david-scanu-local-development.ipynb](notebooks/p11-david-scanu-local-development.ipynb)** - Pipeline validé localement

### Ressources AWS

- [AWS EMR Documentation](https://docs.aws.amazon.com/emr/)
- [PySpark on EMR](https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-spark.html)
- [EMR Pricing Calculator](https://aws.amazon.com/emr/pricing/)

---

## 🔒 Sécurité et Conformité

### RGPD

✅ **Région européenne** : Toutes les ressources sont créées en `eu-west-1` (Irlande) ou `eu-central-1` (Francfort)

✅ **Accès S3** : Bucket configuré pour bloquer l'accès public

✅ **Chiffrement** : Données en transit chiffrées (HTTPS, SSH)

### Bonnes Pratiques

- Clés SSH avec permissions 400
- Clés IAM avec permissions minimales requises
- Security groups restrictifs (seulement votre IP)
- Arrêt systématique du cluster après utilisation

---

## 🎓 Livrables du Projet

Après la migration AWS, les livrables finaux seront :

1. **Notebook production** : `David_Scanu_1_notebook_112025.ipynb`
   - Pipeline complet exécuté sur AWS EMR
   - Commentaires détaillés
   - Résultats validés

2. **Documentation des images** : `David_Scanu_2_images_112025.pdf`
   - Lien vers le bucket S3
   - Screenshots de l'exécution sur EMR
   - Métriques Spark UI

3. **Présentation** : `David_Scanu_3_presentation_112025.pdf`
   - Architecture Big Data
   - Pipeline PySpark expliqué
   - Résultats et performances

---

## 📞 Contact

**Projet** : OpenClassrooms - Parcours AI Engineer - Projet 11
**Étudiant** : David Scanu
**Date** : Novembre 2025

---

**Dernière mise à jour** : 7 Novembre 2025