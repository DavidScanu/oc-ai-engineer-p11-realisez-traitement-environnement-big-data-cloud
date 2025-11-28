# 📦 Livrables Projet P11 - URLs d'accès

**Projet** : Réalisez un traitement dans un environnement Big Data sur le Cloud  
**Étudiant** : David Scanu

> **Dépôt GitHub** : https://github.com/DavidScanu/oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud

---

## 🐍 Livrable 1 : Script PySpark exécutable sur le cloud (preprocessing + PCA)

- **Chemin S3** : `s3://oc-p11-fruits-david-scanu/process_fruits_data/scripts/process_fruits_data.py`
- **Lien GitHub** : [process_fruits_data.py](https://github.com/DavidScanu/oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/blob/main/traitement/etape_2/scripts/process_fruits_data.py)

---

## 📦 Livrable 2 : Images du jeu de données initial sur S3

- **Chemin S3 (répertoire complet)** : `s3://oc-p11-fruits-david-scanu/data/raw/Training/`
- **Exemple d'image** (Apple Braeburn) : [0_100.jpg](https://oc-p11-fruits-david-scanu.s3.eu-west-1.amazonaws.com/data/raw/Training/Apple%20Braeburn/0_100.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAWW47UUWGWU2R3FVC%2F20251128%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20251128T171554Z&X-Amz-Expires=259200&X-Amz-SignedHeaders=host&X-Amz-Signature=022e3670a8194098f5f2561febe6af2cceb98d20adb8b718917ef020f1bd7b69)

---

## 📊 Livrable 3 : Sortie de la réduction de dimension (PCA)

- **Chemin S3 (répertoire)** : `s3://oc-p11-fruits-david-scanu/process_fruits_data/outputs/output-full/pca/csv/pca_20251125_092304/`
- [Échantillon des résultats de réduction de dimension PCA](https://github.com/DavidScanu/oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/blob/d6ab1143d43547e5bbb7371fec99a5003dde2c23/traitement/etape_2/outputs/output-full/pca_sample_results.csv)
  - Chemins S3 des images 
  - Labels
  - Arrays de résultat de PCA (50 dimensions)

---

## 🎤 Livrable 4 : Support de présentation

- **Présentation Google Slides** : [Présentation P11 - David Scanu](https://docs.google.com/presentation/d/1YH2OK8qeV0dBRjcsCU09T9dZZ977ExN2fQvkeF7-Iv0/edit?usp=sharing)

---

## 📌 Notes importantes

- **Validité des URLs pré-signées** : Valides 3 jours (jusqu'au **lundi 01/12/2025 à 17h**)
- **Bucket S3** : `oc-p11-fruits-david-scanu` (région `eu-west-1`, conforme GDPR)
- **Dataset source** : Fruits-360 (67 000+ images, 131 classes)
- **Technologies** : PySpark, AWS EMR, TensorFlow MobileNetV2, PCA (50 composantes)
- **Traitement réalisé le** : 25/11/2025 09:23 UTC (mode FULL)

---

## 🏗️ Architecture Big Data

**Infrastructure Cloud (AWS)** :
- **Stockage** : S3 (eu-west-1)
- **Compute** : EMR 7.11.0 (Spark 3.5.3)
- **Instances** : 1 master m5.2xlarge + 2 core m5.2xlarge
- **Configuration** :
  - Spark Driver Memory : 8g
  - Spark Executor Memory : 8g
  - EBS Volume : 32 GB par instance

**Pipeline de traitement** :
1. Chargement images depuis S3
2. Extraction features (MobileNetV2 via TensorFlow - 1280 features)
3. Broadcast des poids TensorFlow pour optimisation distribuée
4. Réduction dimensionnelle (PCA 50 composantes en PySpark)
5. Sauvegarde résultats sur S3 (format CSV partitionné)

**Chemins S3** :
- Input : `s3://oc-p11-fruits-david-scanu/data/raw/Training/`
- Output : `s3://oc-p11-fruits-david-scanu/process_fruits_data/outputs/output-full/`
- Scripts : `s3://oc-p11-fruits-david-scanu/process_fruits_data/scripts/`
- Logs : `s3://oc-p11-fruits-david-scanu/process_fruits_data/logs/emr/`