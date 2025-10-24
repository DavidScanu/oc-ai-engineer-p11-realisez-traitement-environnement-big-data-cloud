# Projet Big Data & Cloud Computing - Fruits!

## 📋 Contexte du Projet

### Présentation de l'entreprise
Vous êtes Data Scientist dans **"Fruits!"**, une jeune start-up de l'AgriTech qui cherche à proposer des solutions innovantes pour la récolte des fruits.

### Objectif de l'entreprise
- **Mission principale** : Préserver la biodiversité des fruits en permettant des traitements spécifiques pour chaque espèce
- **Solution** : Développer des robots cueilleurs intelligents

### Application mobile
La start-up souhaite se faire connaître en mettant à disposition du grand public une application mobile permettant :
- De prendre en photo un fruit
- D'obtenir des informations sur ce fruit
- De sensibiliser le grand public à la biodiversité des fruits
- De mettre en place une première version du moteur de classification des images de fruits

---

## 🎯 Votre Mission

### Point de départ
Votre collègue **Paul** vous indique l'existence d'un document formalisé par un alternant qui vient de quitter l'entreprise. Il a testé une première approche dans un environnement Big Data AWS EMR.

**Votre rôle** : Vous approprier les travaux réalisés par l'alternant et compléter la chaîne de traitement.

> ⚠️ **Important** : Il n'est pas nécessaire d'entraîner un modèle pour le moment. L'important est de mettre en place les premières briques de traitement qui serviront lorsqu'il faudra passer à l'échelle en termes de volume de données !

### Contraintes et points d'attention

#### 1. **Scalabilité**
- Le volume de données va augmenter très rapidement après la livraison du projet
- Développer des scripts en **PySpark**
- Utiliser le cloud **AWS** pour profiter d'une architecture Big Data (EMR, S3, IAM)
- Alternative possible : **Databricks**

#### 2. **Démonstration requise**
Vous devez faire une démonstration de :
- La mise en place d'une instance EMR opérationnelle
- L'explication pas à pas du script PySpark complété avec :
  - **Traitement de diffusion des poids** du modèle Tensorflow sur les clusters (broadcast des "weights" du modèle) - oublié par l'alternant
  - **Étape de réduction de dimension** de type PCA en PySpark

#### 3. **RGPD**
⚡ **Contrainte importante** : Paramétrer votre installation afin d'utiliser des serveurs situés sur le **territoire européen**

#### 4. **Retour critique**
Votre retour critique de cette solution sera précieux avant de décider de la généraliser

#### 5. **Gestion des coûts**
- La mise en œuvre d'une architecture Big Data de type EMR engendrera des coûts
- **Coût estimé** : < 10 euros pour une utilisation raisonnée (à votre charge)
- ⚠️ **Attention** : Ne pas laisser le cluster EMR ouvert lorsque vous ne l'utilisez pas
- **Recommandation** : Utiliser un serveur local pour la mise à jour du Script PySpark, en limitant l'utilisation du serveur EMR à l'implémentation et aux tests

---

## 📚 Ressources

### Jeu de données
- **Kaggle** : https://www.kaggle.com/datasets/moltean/fruits
- **Téléchargement direct** : https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip

### Notebook de l'alternant
- **Mode opératoire** : https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/P8_Mode_ope%CC%81ratoire.zip

### Article de référence
- **Model inference using TensorFlow Keras API** (en anglais) - disponible dans les ressources

---

## 🛠️ Étapes de Réalisation

### Étape 1 : Préparer la chaîne de traitement PySpark en local
- Reprendre le notebook de l'alternant
- Compléter la démarche, notamment avec une étape de réduction de dimension en PySpark

### Étape 2 : Migrer votre chaîne de traitement dans le Cloud (AWS)
- Prendre connaissance des services AWS
- Identifier les services pertinents pour migrer chaque étape de votre chaîne de traitement
- Mettre en place le cluster EMR pour distribuer les calculs dans le cloud
- Connecter votre notebook Cloud pour réaliser la chaîne de traitement jusqu'à la réduction de dimensions

### Étape 3 : Vérifier votre travail et préparer la soutenance
- Vérifier que votre notebook PySpark est clair et les scripts bien commentés
- S'assurer que les données et résultats sont organisés et accessibles dans le Cloud
- Préparer une présentation concise expliquant votre architecture cloud et le processus de traitement PySpark
- Pratiquer la présentation pour garantir une explication fluide et une démonstration technique sans accroc

---

## 📦 Livrables

1. **Un notebook sur le cloud (Colab)** contenant :
   - Les scripts en PySpark exécutables
   - Le preprocessing
   - Une étape de réduction de dimension de type PCA

2. **Les données stockées dans le cloud** :
   - Les images du jeu de données initial
   - La sortie de la réduction de dimension (matrice CSV ou autre)
   - Disponibles dans un espace de stockage sur le cloud

3. **Un support de présentation** présentant :
   - Les différentes briques d'architecture choisies sur le cloud
   - Leur rôle dans l'architecture Big Data
   - La démarche de mise en œuvre de l'environnement Big Data (EMR ou Databricks)
   - Les étapes de la chaîne de traitement PySpark

### Convention de nommage
Déposez dans un dossier zip nommé `Titre_du_projet_nom_prénom` :

- `Nom_Prénom_1_notebook_mmaaaa`
- `Nom_Prénom_2_images_mmaaaa`
- `Nom_Prénom_3_presentation_mmaaaa`

**Exemple** : `Dupont_Jean_1_notebook_012024`

---

## 🎤 Soutenance (30 minutes)

### Présentation (20 minutes)
1. **Rappel de la problématique et présentation du jeu de données** (3 min)
2. **Présentation du processus de création de l'environnement Big Data, S3 et EMR ou Databricks** (6 min)
3. **Présentation de la réalisation de la chaîne de traitement des images dans un environnement Big Data dans le cloud** (6 min)
4. **Démonstration d'exécution du script PySpark sur le Cloud** (2 min)
5. **Synthèse et conclusion** (3 min)

### Discussion (5 minutes)
L'évaluateur (Paul) vous challengera sur votre compréhension des concepts et techniques mis en œuvre

### Débriefing (5 minutes)
Débriefing ensemble à la fin de la soutenance

> ⚠️ **Important** : La présentation doit durer 20 minutes (+/- 5 minutes). Les présentations en dessous de 15 minutes ou au-dessus de 25 minutes peuvent être refusées.

---

## 🎓 Compétences Évaluées

### Compétence 1 : Sélectionner les outils du Cloud
**Objectif** : Traiter et stocker les données d'un projet Big Data conforme aux normes RGPD

**Critères d'évaluation** :
- CE1 : Identifier les différentes briques d'architecture nécessaires pour la mise en place d'un environnement Big Data
- CE2 : Identifier les outils du cloud permettant de mettre en place l'environnement Big Data conforme aux normes RGPD

### Compétence 2 : Prétraiter, analyser et modéliser
**Objectif** : Traiter des données dans un environnement Big Data en utilisant les outils du Cloud

**Critères d'évaluation** :
- CE1 : Charger les fichiers de départ et ceux après transformation dans un espace de stockage cloud conforme à la réglementation RGPD
- CE2 : Exécuter les scripts en utilisant des machines dans le cloud
- CE3 : Réaliser un script qui permet d'écrire les sorties du programme directement dans l'espace de stockage cloud

### Compétence 3 : Réaliser des calculs distribués
**Objectif** : Traiter des données massives en utilisant les outils adaptés et en prenant en compte le RGPD

**Critères d'évaluation** :
- CE1 : Identifier les traitements critiques lors d'un passage à l'échelle en termes de volume de données
- CE2 : Veiller à ce que l'exploitation des données soit conforme au RGPD (serveurs européens)
- CE3 : Développer les scripts s'appuyant sur Spark
- CE4 : S'assurer que toute la chaîne de traitement est exécutée dans le cloud

---

## 🎯 Ce que vous allez apprendre

### Big Data et Cloud Computing
- Traitement de données massives
- Migration d'un projet Data de l'environnement local vers un environnement Big Data
- Utilisation de **PySpark**
- Travail dans des environnements Cloud distribués avec services prêt-à-l'emploi
- Gestion de grands volumes de données
- Conception d'une architecture Big Data garantissant l'efficacité et la scalabilité

### Pourquoi ces compétences sont importantes ?
Dans un monde où le volume de données ne cesse de croître, la capacité à travailler avec le Big Data est essentielle. Ces compétences :
- Ouvrent des portes dans de nombreux secteurs (finance, santé, marketing, etc.)
- Permettent de développer des solutions innovantes
- Vous positionnent comme un acteur clé capable de relever des défis modernes en data
- Permettent d'apporter des insights précieux à partir de grandes quantités de données

---

## ✅ Checklist du Projet

- [ ] Télécharger et explorer le jeu de données Fruits
- [ ] Télécharger et analyser le notebook de l'alternant
- [ ] Compléter le notebook avec la réduction de dimension PCA en PySpark
- [ ] Ajouter le broadcast des weights du modèle TensorFlow
- [ ] Créer un compte AWS (région européenne)
- [ ] Configurer S3 pour le stockage des données
- [ ] Mettre en place un cluster EMR
- [ ] Tester la chaîne de traitement sur le cloud
- [ ] Préparer le support de présentation
- [ ] Vérifier la conformité RGPD (serveurs européens)
- [ ] Préparer la démonstration
- [ ] ⚠️ Arrêter le cluster EMR après utilisation

---

**Bonne chance ! 🚀**