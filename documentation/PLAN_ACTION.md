# Plan d'Action - Projet Big Data Fruits

## Vue d'ensemble

Ce document décrit le plan d'action détaillé pour compléter le projet de traitement Big Data sur le cloud pour la classification de fruits.

## État des lieux

### Travail de l'alternant (Complété)

L'alternant a produit un notebook complet (`P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb`) qui contient :

✅ **Infrastructure Cloud AWS**
- Configuration détaillée d'AWS EMR (instances, sécurité, bootstrap)
- Configuration S3 pour le stockage des données
- Mise en place du tunnel SSH et accès JupyterHub
- Documentation step-by-step pour instancier/arrêter/cloner le cluster

✅ **Traitement PySpark fonctionnel**
- Chargement d'images depuis S3 avec PySpark
- Extraction de features avec TensorFlow MobileNetV2 (Transfer Learning)
- Utilisation de Pandas UDF pour le traitement distribué
- Sauvegarde des résultats sur S3

✅ **Technologies maîtrisées**
- PySpark 3.1.1 avec Apache Arrow
- TensorFlow 2.4.1 (MobileNetV2)
- PIL pour le preprocessing d'images
- AWS EMR 6.3.0 + S3

**📌 Note** : L'infrastructure a évolué depuis le travail de l'alternant
- EMR actuel : 7.10.0 (vs 6.3.0)
- Spark actuel : 3.5.5 (vs 3.1.1)
- TensorFlow actuel : 2.16.1 (vs 2.4.1)
- Nouveau connecteur S3A par défaut (vs EMRFS)

### Composants manquants (À implémenter)

❌ **1. Broadcast des poids du modèle TensorFlow**
- Le modèle MobileNetV2 est actuellement rechargé sur chaque worker
- Nécessite l'implémentation de `sc.broadcast()` pour distribuer les weights une seule fois
- Améliore considérablement les performances et réduit la consommation mémoire

❌ **2. Réduction de dimension PCA en PySpark**
- Actuellement, seule l'extraction de features est réalisée
- Nécessite l'ajout d'une étape PCA avec `pyspark.ml.feature.PCA`
- Output attendu : matrice CSV avec dimensions réduites

---

## Phase 1 : Analyse et Préparation (Local)

### 1.1 Étude du notebook de l'alternant ✅ TERMINÉ

**Objectif** : Comprendre l'architecture et le code existant

**Actions** :
- [x] Lire et analyser le notebook complet
- [x] Identifier les points d'insertion pour les nouveaux composants
- [x] Comprendre la structure des données (schema PySpark)
- [x] Analyser l'utilisation de Pandas UDF

**Livrables** ✅ :
- ✅ Notes dans CLAUDE.md (section "Intern's Work Analysis")
- ✅ Notebook alternant importé dans `notebooks/alternant/`
- ✅ 47 images de documentation EMR importées

**Date de complétion** : 24 octobre 2025

### 1.2 Téléchargement et exploration du dataset ✅ TERMINÉ

**Objectif** : Obtenir et analyser le jeu de données Fruits-360

**Actions** :
- [x] Télécharger le dataset (lien direct S3)
- [x] Extraire et explorer la structure des dossiers
- [x] Vérifier la qualité des images (format, dimensions)
- [x] Analyser la distribution des classes

**Livrables** ✅ :
- ✅ Dataset local dans `data/raw/fruits-360_dataset/` (67,692 images Training, 131 classes)
- ✅ Dataset original-size dans `data/raw/fruits-360-original-size/`
- ✅ Documentation complète dans `documentation/DATASET_INFO.md`
- ✅ ZIP supprimé pour économiser l'espace (1.3GB)
- ✅ Configuration .gitignore pour exclure les données volumineuses

**Statistiques** :
- Training: 67,692 images, 131 classes
- Test: 22,688 images
- Format: JPG 100x100 pixels
- Taille totale: ~1.5 GB

**Date de complétion** : 24 octobre 2025

### 1.3 Setup environnement local PySpark ✅ TERMINÉ

**Objectif** : Reproduire l'environnement local pour tester le code

**Actions** :
- [x] Vérifier Java JDK (Java 11 ✅ compatible)
- [x] Créer requirements.txt avec PySpark 3.5.0
- [x] Définir TensorFlow 2.16.1
- [x] Lister toutes les dépendances (PIL, pandas, numpy, pyarrow)
- [x] Configurer VSCode pour le projet

**Livrables** ✅ :
- ✅ `requirements.txt` créé avec toutes les dépendances
- ✅ `.vscode/settings.json` configuré (exclusion data/, config Python/Jupyter)
- ✅ Java 11.0.27 vérifié et compatible
- ✅ Structure de projet complète

**Date de complétion** : 24 octobre 2025

---

## Phase 2 : Développement Local

### 2.1 Implémenter le broadcast des poids TensorFlow ✅ IMPLÉMENTÉ (À TESTER)

**Objectif** : Optimiser la distribution du modèle sur les workers

**Statut** : ✅ Code implémenté dans le notebook, prêt pour tests locaux

**Contexte technique** :
Sans broadcast, chaque worker recharge le modèle MobileNetV2 (plusieurs MB), ce qui :
- Augmente la consommation mémoire
- Ralentit les traitements
- Génère du trafic réseau inutile

**Actions** :
- [ ] Extraire les weights du modèle MobileNetV2
- [ ] Implémenter `broadcast_weights = sc.broadcast(model.get_weights())`
- [ ] Modifier la Pandas UDF pour utiliser les weights broadcastés
- [ ] Reconstruire le modèle dans chaque worker avec les weights
- [ ] Tester en local avec un subset du dataset

**Code pattern attendu** :
```python
# Dans la cellule de préparation du modèle
model = MobileNetV2(weights='imagenet', include_top=False, pooling='avg')
broadcast_weights = sc.broadcast(model.get_weights())

# Dans la Pandas UDF
def extract_features(content_series):
    model = MobileNetV2(weights=None, include_top=False, pooling='avg')
    model.set_weights(broadcast_weights.value)
    # ... reste du code
```

**Livrables** ✅ :
- ✅ Code implémenté dans `notebooks/p11-david-scanu-local-development.ipynb`
- ✅ Extraction des poids: `model_weights = model.get_weights()`
- ✅ Broadcast: `broadcast_weights = sc.broadcast(model_weights)`
- ✅ Reconstruction dans workers: `local_model.set_weights(broadcast_weights.value)`
- ⏳ Tests de performance à réaliser

**Date d'implémentation** : 24 octobre 2025

### 2.2 Implémenter la réduction PCA en PySpark ✅ IMPLÉMENTÉ (À TESTER)

**Objectif** : Ajouter une étape de dimensionnalité reduction après l'extraction de features

**Statut** : ✅ Code implémenté dans le notebook, prêt pour tests locaux

**Contexte technique** :
MobileNetV2 (sans top, avec pooling='avg') produit des features de dimension 1280.
La PCA permettra de réduire cette dimension tout en conservant la variance significative.

**Actions** :
- [ ] Charger les features extraites (output de l'étape précédente)
- [ ] Assembler les features en un vecteur avec `VectorAssembler`
- [ ] Appliquer `pyspark.ml.feature.PCA` sur les features
- [ ] Configurer le nombre de composantes (ex: 100, 200, ou variance expliquée)
- [ ] Sauvegarder le résultat en CSV sur S3
- [ ] Tester en local avec un subset du dataset

**Code pattern attendu** :
```python
from pyspark.ml.feature import PCA, VectorAssembler

# Assembler les colonnes de features en un vecteur
assembler = VectorAssembler(inputCols=feature_cols, outputCol="features")
df_features = assembler.transform(df_extracted)

# Appliquer PCA
pca = PCA(k=100, inputCol="features", outputCol="pca_features")
model_pca = pca.fit(df_features)
df_pca = model_pca.transform(df_features)

# Sauvegarder
df_pca.select("image_path", "label", "pca_features").write.csv("s3://bucket/pca_output/")
```

**Livrables** ✅ :
- ✅ Code PCA implémenté avec `pyspark.ml.feature.PCA`
- ✅ Configuration k=200 composantes (paramétrable)
- ✅ Conversion array → vecteur dense avec UDF
- ✅ Analyse de variance expliquée préparée
- ✅ Sauvegarde en Parquet et CSV
- ⏳ Tests et validation à réaliser

**Date d'implémentation** : 24 octobre 2025

### 2.3 Intégration et tests locaux ⏳ EN ATTENTE

**Objectif** : Valider le pipeline complet en local

**Statut** : ⏳ Prêt pour tests - nécessite installation dépendances et exécution notebook

**Actions** :
- [ ] Créer un notebook consolidé avec toutes les modifications
- [ ] Tester sur un subset du dataset (ex: 1000 images)
- [ ] Vérifier les outputs à chaque étape
- [ ] Mesurer les temps d'exécution
- [ ] Documenter le code avec des commentaires clairs

**Livrables** :
- Notebook PySpark fonctionnel en local
- Documentation des résultats de tests

---

## Phase 3 : Migration Cloud (AWS)

### 3.1 Configuration AWS

**Objectif** : Préparer l'environnement cloud conforme RGPD

**Actions** :
- [ ] Créer un compte AWS (si nécessaire)
- [ ] Configurer IAM (utilisateur, rôles, policies)
- [ ] Créer un bucket S3 dans une région européenne (eu-west-1, eu-central-1)
- [ ] Configurer les permissions S3
- [ ] Uploader le dataset sur S3

**Livrables** :
- Bucket S3 configuré et accessible
- Dataset uploadé sur S3
- Documentation des configurations

### 3.2 Configuration EMR

**Objectif** : Créer et configurer le cluster EMR

**Actions** :
- [ ] Suivre la documentation de l'alternant pour créer le cluster
- [ ] Sélectionner la région européenne
- [ ] Configurer les instances (type, nombre de nodes)
- [ ] Ajouter les bootstrap actions pour installer les dépendances
- [ ] Configurer les security groups
- [ ] Créer la paire de clés SSH

**Configuration recommandée** :
- **Région** : eu-west-1 (Irlande) ou eu-central-1 (Francfort)
- **Release** : EMR 7.10.0 (ou 7.x latest)
  - Spark 3.5.5
  - TensorFlow 2.16.1
  - JupyterHub (latest)
  - Hadoop 3.4.1
- **Instances** : 1 master m5.xlarge + 2 core m5.xlarge (ajustable selon budget)
- **Applications** : Spark, JupyterHub, Hadoop, TensorFlow

**⚠️ Changement important (EMR 7.10+)** :
- S3A filesystem remplace EMRFS comme connecteur S3 par défaut
- Adapter les chemins S3 si nécessaire (généralement transparent)

**Livrables** :
- Cluster EMR opérationnel
- Documentation de la configuration

### 3.3 Connexion et setup du notebook

**Objectif** : Accéder au notebook cloud et préparer l'environnement

**Actions** :
- [ ] Créer le tunnel SSH vers le master node
- [ ] Configurer FoxyProxy pour accéder aux interfaces web
- [ ] Se connecter à JupyterHub
- [ ] Créer un nouveau notebook PySpark
- [ ] Installer les packages nécessaires (TensorFlow, PIL)

**Livrables** :
- Accès JupyterHub fonctionnel
- Notebook PySpark prêt

### 3.4 Exécution du pipeline sur EMR

**Objectif** : Exécuter la chaîne complète sur le cloud

**Actions** :
- [ ] Copier le code du notebook local vers EMR
- [ ] Adapter les chemins S3 (input/output)
- [ ] Exécuter le pipeline par étapes
- [ ] Monitorer l'exécution via Spark UI
- [ ] Vérifier les outputs sur S3
- [ ] Télécharger et valider les résultats

**Livrables** :
- Pipeline exécuté avec succès sur EMR
- Données de sortie (features + PCA) sur S3
- Logs d'exécution et métriques

### 3.5 Optimisation et validation

**Objectif** : Optimiser les performances et valider les résultats

**Actions** :
- [ ] Analyser les métriques Spark (temps, shuffle, etc.)
- [ ] Ajuster les paramètres si nécessaire
- [ ] Vérifier la conformité RGPD (région EU)
- [ ] Tester avec le dataset complet
- [ ] Valider la qualité des résultats PCA

**Livrables** :
- Rapport de performance
- Résultats validés

### 3.6 Arrêt et nettoyage

**Objectif** : Gérer les coûts et nettoyer les ressources

**Actions** :
- [ ] ⚠️ **IMPORTANT** : Arrêter le cluster EMR après utilisation
- [ ] Vérifier que toutes les données sont bien sur S3
- [ ] Optionnel : Cloner la configuration du cluster pour réutilisation
- [ ] Documenter les coûts réels

**Livrables** :
- Cluster arrêté
- Configuration sauvegardée pour réutilisation

---

## Phase 4 : Documentation et Présentation

### 4.1 Finalisation du notebook

**Objectif** : Produire un notebook propre et documenté

**Actions** :
- [ ] Nettoyer le code (supprimer les tests, commentaires inutiles)
- [ ] Ajouter des commentaires explicatifs
- [ ] Structurer avec des sections markdown claires
- [ ] Ajouter des visualisations (si pertinent)
- [ ] Exporter en .ipynb et .html

**Livrables** :
- Notebook final propre et documenté
- Export HTML pour visualisation

### 4.2 Organisation des données S3

**Objectif** : Structurer les données sur S3 de manière claire

**Structure S3 recommandée** :
```
s3://mon-bucket-fruits/
├── data/
│   ├── raw/                  # Images originales
│   │   ├── Training/
│   │   └── Test/
│   ├── features/             # Features extraites (MobileNetV2)
│   └── pca/                  # Résultats PCA
├── models/                   # Weights du modèle (optionnel)
└── logs/                     # Logs d'exécution (optionnel)
```

**Actions** :
- [ ] Organiser les fichiers sur S3
- [ ] Documenter l'arborescence
- [ ] Vérifier les permissions d'accès

**Livrables** :
- Arborescence S3 claire et documentée

### 4.3 Préparation de la présentation

**Objectif** : Créer le support de présentation pour la soutenance

**Contenu attendu** (20 minutes) :
1. **Problématique et dataset** (3 min)
   - Contexte "Fruits!"
   - Dataset Fruits-360
   - Objectifs du projet

2. **Architecture Big Data** (6 min)
   - Schéma de l'architecture AWS (EMR + S3)
   - Justification des choix techniques
   - Conformité RGPD
   - Gestion des coûts

3. **Pipeline PySpark** (6 min)
   - Vue d'ensemble du pipeline
   - Broadcast des weights TensorFlow (explication + code)
   - PCA en PySpark (explication + code)
   - Optimisations réalisées

4. **Démonstration** (2 min)
   - Exécution du notebook sur EMR
   - Visualisation des résultats

5. **Conclusion** (3 min)
   - Résultats obtenus
   - Retour critique sur la solution
   - Scalabilité et perspectives

**Actions** :
- [ ] Créer le support (PowerPoint, Google Slides, etc.)
- [ ] Créer les schémas d'architecture
- [ ] Préparer des screenshots du code clé
- [ ] Préparer la démonstration live
- [ ] Répéter la présentation (timing)

**Livrables** :
- Support de présentation finalisé
- Script de démonstration

---

## Checklist Finale

### Avant la soutenance

- [ ] Notebook PySpark complet et testé sur EMR
- [ ] Broadcast TensorFlow implémenté et fonctionnel
- [ ] PCA en PySpark implémentée et validée
- [ ] Données sur S3 (images + features + PCA)
- [ ] Cluster EMR arrêté (coûts maîtrisés)
- [ ] Présentation finalisée et répétée
- [ ] Démonstration testée
- [ ] Tous les livrables prêts :
  - `Nom_Prénom_1_notebook_mmaaaa.ipynb`
  - `Nom_Prénom_2_images_mmaaaa` (lien S3 ou export)
  - `Nom_Prénom_3_presentation_mmaaaa.pdf`

### Vérifications techniques

- [ ] Conformité RGPD : serveurs en région européenne ✓
- [ ] Scalabilité : code PySpark distribué ✓
- [ ] Performance : broadcast + optimisations ✓
- [ ] Documentation : code commenté et clair ✓
- [ ] Résultats : PCA output validé ✓

---

## Estimation des coûts AWS

**EMR Cluster** (configuration recommandée) :
- 1 master m5.xlarge + 2 core m5.xlarge
- Région eu-west-1
- Coût estimé : ~2-3€/heure

**Stratégie de gestion des coûts** :
1. Développer et tester en local au maximum
2. Utiliser EMR uniquement pour les tests finaux et la démo
3. Arrêter le cluster immédiatement après utilisation
4. Prévoir 3-4 heures max de cluster actif
5. **Budget total estimé : 6-10€**

**S3 Storage** :
- Dataset : ~1GB
- Features + PCA : ~500MB
- Coût stockage : < 0.50€/mois (négligeable)

---

## Points d'attention critiques

⚠️ **Gestion des coûts EMR**
- Ne JAMAIS laisser le cluster actif inutilement
- Vérifier que le cluster est bien arrêté après chaque session

⚠️ **RGPD**
- Toujours utiliser des régions européennes (eu-west-1, eu-central-1)
- Vérifier la région lors de la création du bucket S3 et du cluster EMR

⚠️ **Performance**
- Le broadcast des weights est CRITIQUE pour la performance
- Tester avec un subset avant de lancer sur le dataset complet

⚠️ **Soutenance**
- La démonstration doit être fluide et rapide (2 min)
- Avoir un plan B si problème de connexion (screenshots/vidéo)

---

## Ressources et Documentation

**Documentation officielle** :
- [PySpark ML - PCA](https://spark.apache.org/docs/latest/ml-features.html#pca)
- [PySpark - Broadcast Variables](https://spark.apache.org/docs/latest/rdd-programming-guide.html#broadcast-variables)
- [AWS EMR - Getting Started](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-what-is-emr.html)
- [TensorFlow + Spark](https://www.tensorflow.org/guide/distributed_training)

**Notebooks et exemples** :
- Notebook de l'alternant : `notebooks/alternant/P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb`
- Mode opératoire : https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/P8_Mode_ope%CC%81ratoire.zip

---

**Dernière mise à jour** : 24 Octobre 2025
