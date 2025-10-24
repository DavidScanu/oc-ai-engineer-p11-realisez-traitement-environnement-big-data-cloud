# Projet 11 : Réalisez un traitement dans un environnement Big Data sur le Cloud


# Projet Big Data - Classification de Fruits

[![Python](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python&logoColor=white)](https://www.python.org/)
[![PySpark](https://img.shields.io/badge/PySpark-3.x-E25A1C?logo=apachespark&logoColor=white)](https://spark.apache.org/)
[![AWS](https://img.shields.io/badge/AWS-EMR%20%7C%20S3-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.x-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/)
[![Dataset](https://img.shields.io/badge/Dataset-Fruits--360-green?logo=kaggle&logoColor=white)](https://www.kaggle.com/datasets/moltean/fruits)

> 🎓 OpenClassrooms • Parcours [AI Engineer](https://openclassrooms.com/fr/paths/795-ai-engineer) | 👋 *Étudiant* : [David Scanu](https://www.linkedin.com/in/davidscanu14/)

## 📋 Description

Projet de mise en place d'une architecture Big Data dans le cloud pour le traitement d'images de fruits. Développé pour "Fruits!", une start-up AgriTech qui développe des robots cueilleurs intelligents pour préserver la biodiversité des fruits. Ce projet constitue la première étape : une application mobile de classification de fruits pour sensibiliser le grand public.

## 🎯 Objectifs

- Compléter la chaîne de traitement PySpark initiée par un alternant
- Ajouter le broadcast des poids du modèle TensorFlow sur les clusters
- Implémenter la réduction de dimension PCA en PySpark
- Migrer la chaîne de traitement vers le cloud AWS (EMR + S3)
- Garantir la conformité RGPD (serveurs européens uniquement)

> ⚠️ **Important** : Pas d'entraînement de modèle nécessaire. L'objectif est de mettre en place les briques de traitement scalables.

## 🛠️ Technologies utilisées

- **PySpark** - Traitement distribué des données
- **AWS EMR** - Cluster de calcul distribué
- **AWS S3** - Stockage cloud
- **Python** - Langage de programmation
- **TensorFlow** - Extraction de features

## 📁 Structure du projet

```
├── notebook/           # Notebook PySpark exécutable sur le cloud
├── data/              # Images et résultats (stockés sur S3)
├── presentation/      # Support de présentation
├── documentation/     # Documentation du projet
└── README.md
```

## 🚀 Étapes de réalisation

### 1. Développement local
- Reprendre le notebook de l'alternant
- Compléter avec la réduction de dimension PCA en PySpark
- Ajouter le broadcast des weights du modèle TensorFlow

### 2. Migration cloud (AWS)
- Configurer S3 dans une région européenne (RGPD)
- Mettre en place un cluster EMR
- Exécuter la chaîne de traitement complète sur le cloud

### 3. Livrables
- **Notebook cloud PySpark** exécutable (preprocessing + PCA)
  - EMR Notebook (recommandé avec AWS EMR) ou Databricks Notebook
  - ⚠️ Pas Google Colab (incompatible avec l'architecture EMR native)
- **Données sur S3** (images + matrice CSV de sortie PCA)
- **Support de présentation** (architecture + démarche)

> ⚠️ **Gestion des coûts** : Arrêter le cluster EMR lorsqu'il n'est pas utilisé (coût estimé < 10€)

## 📊 Jeu de données

**Fruits-360 Dataset**

- **Créateur** : Mihai Oltean (2017-)
- **Taille** : 155,491 images réparties en 224 classes (version 100x100)
- **Format** : JPG, 100x100 pixels (standardisé)
- **Contenu** : Fruits, légumes, noix et graines avec de multiples variétés
  - 29 types de pommes
  - 12 variétés de cerises
  - 19 types de tomates
  - Et bien d'autres...
- **Méthode de capture** : Images capturées par rotation (20s à 3 rpm) sur fond blanc
- **Licence** : CC BY-SA 4.0

**Sources** :
- [Kaggle](https://www.kaggle.com/datasets/moltean/fruits)
- [Téléchargement direct](https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip)

## 📚 Ressources

- [Notebook de l'alternant](https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/P8_Mode_ope%CC%81ratoire.zip)

## 👤 Auteur

> 🎓 OpenClassrooms • Parcours [AI Engineer](https://openclassrooms.com/fr/paths/795-ai-engineer) | 👋 *Étudiant* : [David Scanu](https://www.linkedin.com/in/davidscanu14/)

## 📅 Date

Début : 24 Octobre 2025