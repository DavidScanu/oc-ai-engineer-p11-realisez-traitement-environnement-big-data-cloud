#!/usr/bin/env python3
"""
Script pour convertir le notebook local en version EMR avec chemins S3.

Usage:
    python scripts/convert_notebook_to_emr.py

Le script modifie automatiquement:
- Les chemins file:// vers s3://
- La configuration Spark (retire .master("local[*]"))
- Les paths de sauvegarde vers S3
- Le titre et les instructions
"""

import json
import sys
from pathlib import Path

# Lire le nom du bucket depuis .bucket_name
bucket_name_file = Path(".bucket_name")
if bucket_name_file.exists():
    BUCKET_NAME = bucket_name_file.read_text().strip()
else:
    BUCKET_NAME = "oc-p11-fruits-david-scanu"  # Valeur par défaut
    print(f"⚠️  Fichier .bucket_name non trouvé. Utilisation du bucket par défaut: {BUCKET_NAME}")

# Chemins
NOTEBOOK_LOCAL = Path("notebooks/p11-david-scanu-local-development.ipynb")
NOTEBOOK_EMR = Path("notebooks/p11-david-scanu-EMR-production.ipynb")

def convert_notebook():
    """Convertit le notebook local en version EMR."""

    print(f"📖 Lecture du notebook local: {NOTEBOOK_LOCAL}")
    with open(NOTEBOOK_LOCAL, 'r', encoding='utf-8') as f:
        nb = json.load(f)

    # Modifications à apporter
    modifications = 0

    for cell in nb['cells']:
        if cell['cell_type'] == 'markdown':
            # Modifier le titre et les instructions
            if 'source' in cell:
                source = ''.join(cell['source'])

                # Changement 1: Titre principal
                if "Développement local" in source and "Projet 11" in source:
                    cell['source'] = [
                        "# Projet 11 - Big Data Cloud : Classification de Fruits\n",
                        "\n",
                        "**Auteur** : David Scanu  \n",
                        "**Date** : Novembre 2025  \n",
                        "**Environnement** : AWS EMR (Production)  \n",
                        "**Objectif** : Pipeline PySpark distribué avec broadcast TensorFlow et PCA sur S3\n",
                        "\n",
                        "---\n",
                        "\n",
                        "## 📋 Sommaire\n",
                        "\n",
                        "1. [Setup et Configuration](#1-setup-et-configuration)\n",
                        "2. [Configuration S3 et Spark](#2-configuration-s3-et-spark)\n",
                        "3. [Chargement des Données depuis S3](#3-chargement-des-donnees-depuis-s3)\n",
                        "4. [Extraction de Features avec TensorFlow](#4-extraction-de-features-avec-tensorflow)\n",
                        "5. [Broadcast des Poids du Modèle](#5-broadcast-des-poids-du-modele)\n",
                        "6. [Réduction de Dimension avec PCA](#6-reduction-de-dimension-avec-pca)\n",
                        "7. [Sauvegarde des Résultats sur S3](#7-sauvegarde-des-resultats-sur-s3)\n",
                        "\n",
                        "---\n",
                        "\n",
                        "## ⚠️ Important\n",
                        "\n",
                        "Ce notebook est conçu pour **AWS EMR en production**.\n",
                        "\n",
                        "- ✅ Lit les données depuis S3\n",
                        "- ✅ Utilise le cluster Spark EMR\n",
                        "- ✅ Sauvegarde les résultats sur S3\n",
                        "- ⚠️  **ATTENTION AUX COÛTS** : ~2-3€/heure de cluster\n",
                        "\n",
                        "**N'oubliez pas d'arrêter le cluster après usage !**\n"
                    ]
                    modifications += 1

                # Changement 2: Instructions configuration
                if "développement et test en local" in source.lower():
                    cell['source'] = [
                        "## ⚠️ Configuration AWS EMR\n",
                        "\n",
                        "Ce notebook s'exécute sur AWS EMR JupyterHub.\n",
                        "\n",
                        "- ✅ SparkSession déjà créée (pas besoin de `.master(\"local[*]\"`)\n",
                        "- ✅ Accès S3 configuré automatiquement\n",
                        "- ✅ Cluster avec plusieurs workers pour traitement distribué\n",
                        "\n",
                        "**Bucket S3** : `", BUCKET_NAME, "`\n"
                    ]
                    modifications += 1

        elif cell['cell_type'] == 'code':
            if 'source' in cell:
                source_lines = cell['source']
                new_source = []
                modified = False

                for line in source_lines:
                    original_line = line

                    # Changement 3: Configuration des chemins - REMPLACER TOUTE LA SECTION
                    if "# Chemins du projet" in line or "PROJECT_ROOT = find_project_root()" in line:
                        new_source = [
                            f"# ============================================================\n",
                            f"# CONFIGURATION S3 POUR AWS EMR\n",
                            f"# ============================================================\n",
                            f"\n",
                            f"# Bucket S3 (adapter si nécessaire)\n",
                            f'BUCKET_NAME = "{BUCKET_NAME}"\n',
                            f"\n",
                            f"# Chemins S3\n",
                            f'S3_INPUT_PATH = f"s3://{{BUCKET_NAME}}/data/raw/Training/"\n',
                            f'S3_FEATURES_OUTPUT = f"s3://{{BUCKET_NAME}}/data/features/"\n',
                            f'S3_PCA_OUTPUT = f"s3://{{BUCKET_NAME}}/data/pca/"\n',
                            f"\n",
                            f'print(f"📦 Bucket S3: {{BUCKET_NAME}}")\n',
                            f'print(f"📥 Input: {{S3_INPUT_PATH}}")\n',
                            f'print(f"📤 Features output: {{S3_FEATURES_OUTPUT}}")\n',
                            f'print(f"📤 PCA output: {{S3_PCA_OUTPUT}}")\n'
                        ]
                        modified = True
                        # Skip jusqu'à la fin de la section (après les prints)
                        continue

                    # Changement 4: Configuration Spark - COMMENTER la création
                    if "spark = SparkSession.builder" in line:
                        new_source.extend([
                            "# ============================================================\n",
                            "# CONFIGURATION SPARK POUR EMR\n",
                            "# ============================================================\n",
                            "# Sur EMR, la SparkSession est déjà créée et configurée\n",
                            "# Pas besoin de créer une nouvelle session\n",
                            "\n",
                            "# Récupérer la session Spark existante (fournie par EMR)\n",
                            "# La variable 'spark' existe déjà dans l'environnement JupyterHub EMR\n",
                            "\n",
                            "# Configuration du niveau de log\n",
                            "spark.sparkContext.setLogLevel(\"WARN\")\n",
                            "\n",
                            "# Récupérer le SparkContext pour le broadcast\n",
                            "sc = spark.sparkContext\n",
                            "\n",
                            'print(f"✅ SparkSession EMR utilisée")\n',
                            'print(f"   Version Spark: {spark.version}")\n',
                            'print(f"   Master: {spark.sparkContext.master}")\n',
                            'print(f"   App Name: {spark.sparkContext.appName}")\n',
                        ])
                        modified = True
                        # Skip toutes les lignes de configuration Spark
                        continue

                    # Skip les lignes de configuration Spark si on est dans ce bloc
                    if modified and (".appName(" in line or ".master(" in line or ".config(" in line or ".getOrCreate()" in line):
                        continue

                    # Changement 5: Chemins de chargement - file:// vers S3
                    if "file://" in line and "IMAGES_PATH" in line:
                        line = line.replace(f'file://{"{IMAGES_PATH}"}/Apple*/*.jpg', f'{"{S3_INPUT_PATH}"}Apple*/*.jpg')
                        line = line.replace(f'file://{"{IMAGES_PATH}"}/*/*.jpg', f'{"{S3_INPUT_PATH}"}*/*.jpg')
                        line = line.replace(f'file://{"{IMAGES_PATH}"}/{"{SINGLE_CLASS}"}/*.jpg', f'{"{S3_INPUT_PATH}"}{"{SINGLE_CLASS}"}/*.jpg')
                        modified = True

                    # Changement 6: Chemins de sauvegarde vers S3
                    if "features_output_path = str(FEATURES_DIR" in line:
                        line = 'features_output_path = S3_FEATURES_OUTPUT + "mobilenetv2_features"\n'
                        modified = True
                    if "pca_output_path = str(PCA_DIR" in line:
                        line = 'pca_output_path = S3_PCA_OUTPUT + "pca_results"\n'
                        modified = True
                    if "csv_output_path = str(PCA_DIR" in line:
                        line = 'csv_output_path = S3_PCA_OUTPUT + "pca_results_csv"\n'
                        modified = True

                    # Changement 7: Supprimer les références aux chemins locaux inutilisés
                    if "IMAGES_PATH = str(RAW_DATA_DIR" in line or "TEST_IMAGES_PATH = str(RAW_DATA_DIR" in line:
                        continue  # Skip cette ligne

                    new_source.append(line)

                if modified:
                    cell['source'] = new_source
                    modifications += 1

    # Sauvegarder le notebook modifié
    print(f"\n✅ {modifications} sections modifiées")
    print(f"💾 Sauvegarde du notebook EMR: {NOTEBOOK_EMR}")

    with open(NOTEBOOK_EMR, 'w', encoding='utf-8') as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)

    print(f"\n✅ Notebook EMR créé avec succès !")
    print(f"   Bucket S3: {BUCKET_NAME}")
    print(f"   Fichier: {NOTEBOOK_EMR}")
    print(f"\n📤 Prochaine étape:")
    print(f"   1. Créer le cluster EMR: ./scripts/aws_setup.sh create-cluster")
    print(f"   2. Se connecter: ./scripts/aws_setup.sh connect")
    print(f"   3. Uploader ce notebook via JupyterHub")

if __name__ == "__main__":
    try:
        convert_notebook()
    except Exception as e:
        print(f"❌ Erreur: {e}")
        sys.exit(1)