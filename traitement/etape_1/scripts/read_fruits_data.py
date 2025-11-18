#!/usr/bin/env python3
"""
Script PySpark - Étape 1: Lecture et indexation du dataset Fruits-360

Objectifs:
1. Lire les images depuis S3
2. Créer un DataFrame avec métadonnées (nom fichier, chemin S3, label)
3. Sauvegarder le résultat en CSV sur S3

Ce script valide:
- La lecture de données depuis S3
- L'installation des packages Python (boto3, etc.)
- L'écriture de résultats vers S3
"""

import sys
import os
from datetime import datetime
from pyspark.sql import SparkSession
from pyspark.sql.functions import input_file_name, regexp_extract, col, lit
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

def main():
    """Fonction principale du script PySpark"""

    # Récupérer les arguments
    if len(sys.argv) != 3:
        print("Usage: read_fruits_data.py <s3_input_path> <s3_output_path>")
        print("Example: read_fruits_data.py s3://bucket/data/fruits-360/ s3://bucket/output/etape_1/")
        sys.exit(1)

    s3_input_path = sys.argv[1]
    s3_output_path = sys.argv[2]

    print("=" * 80)
    print("🍎 P11 - ÉTAPE 1: Lecture et indexation du dataset Fruits-360")
    print("=" * 80)
    print(f"📥 Input:  {s3_input_path}")
    print(f"📤 Output: {s3_output_path}")
    print(f"⏰ Début:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

    # Initialiser Spark Session
    print("\n🔧 Initialisation de Spark...")
    spark = SparkSession.builder \
        .appName("P11-Etape1-ReadFruitsData") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()

    # Afficher la configuration Spark
    print(f"✅ Spark version: {spark.version}")
    print(f"✅ Spark Master: {spark.sparkContext.master}")
    print(f"✅ Executor Memory: {spark.sparkContext.getConf().get('spark.executor.memory', 'default')}")
    print(f"✅ Driver Memory: {spark.sparkContext.getConf().get('spark.driver.memory', 'default')}")

    # Étape 1: Lire les fichiers images depuis S3
    print("\n📂 Étape 1: Lecture des fichiers images depuis S3...")
    print(f"   Chemin: {s3_input_path}")

    # Lire tous les fichiers JPG (pattern récursif)
    # binaryFiles() retourne: (path, content, modification_time)
    df_files = spark.read.format("binaryFile") \
        .option("pathGlobFilter", "*.jpg") \
        .option("recursiveFileLookup", "true") \
        .load(s3_input_path)

    print(f"✅ Fichiers lus: {df_files.count()} images trouvées")

    # Étape 2: Extraire les métadonnées
    print("\n🔍 Étape 2: Extraction des métadonnées...")

    # Extraire le nom du fichier et le label depuis le chemin
    # Format: s3://bucket/data/fruits-360/Training/Apple_Braeburn/image_001_100.jpg
    # Label: Apple_Braeburn
    df_metadata = df_files.select(
        col("path").alias("s3_path"),
        regexp_extract(col("path"), r"/([^/]+)/[^/]+\.jpg$", 1).alias("label"),
        regexp_extract(col("path"), r"/([^/]+\.jpg)$", 1).alias("filename"),
        regexp_extract(col("path"), r"/(Training|Test)/", 1).alias("split"),
        col("modificationTime").alias("modification_time"),
        col("length").alias("file_size_bytes")
    )

    # Filtrer les lignes où le label est vide (fichiers mal placés)
    df_clean = df_metadata.filter(col("label") != "")

    print(f"✅ Métadonnées extraites: {df_clean.count()} images valides")

    # Étape 3: Statistiques de base
    print("\n📊 Étape 3: Calcul des statistiques...")

    # Compter par label et par split
    df_stats = df_clean.groupBy("split", "label").count() \
        .orderBy("split", "label")

    total_training = df_clean.filter(col("split") == "Training").count()
    total_test = df_clean.filter(col("split") == "Test").count()
    total_labels = df_clean.select("label").distinct().count()

    print(f"✅ Training images: {total_training}")
    print(f"✅ Test images: {total_test}")
    print(f"✅ Nombre de classes: {total_labels}")

    # Afficher un échantillon
    print("\n📋 Échantillon des données:")
    df_clean.select("filename", "label", "split", "file_size_bytes").show(10, truncate=False)

    # Étape 4: Sauvegarder les résultats en CSV
    print("\n💾 Étape 4: Sauvegarde des résultats sur S3...")

    # Créer le timestamp pour le nom du fichier
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_metadata = f"{s3_output_path}/metadata_{timestamp}"
    output_stats = f"{s3_output_path}/stats_{timestamp}"

    print(f"   Metadata: {output_metadata}")
    print(f"   Stats: {output_stats}")

    # Sauvegarder le DataFrame principal (métadonnées)
    df_clean.coalesce(1) \
        .write \
        .mode("overwrite") \
        .option("header", "true") \
        .csv(output_metadata)

    # Sauvegarder les statistiques
    df_stats.coalesce(1) \
        .write \
        .mode("overwrite") \
        .option("header", "true") \
        .csv(output_stats)

    print("✅ Résultats sauvegardés avec succès")

    # Résumé final
    print("\n" + "=" * 80)
    print("✅ TRAITEMENT TERMINÉ AVEC SUCCÈS")
    print("=" * 80)
    print(f"📊 Total images: {df_clean.count()}")
    print(f"📊 Training: {total_training}")
    print(f"📊 Test: {total_test}")
    print(f"📊 Classes: {total_labels}")
    print(f"📤 Output: {s3_output_path}")
    print(f"⏰ Fin: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

    # Arrêter Spark
    spark.stop()

if __name__ == "__main__":
    main()
