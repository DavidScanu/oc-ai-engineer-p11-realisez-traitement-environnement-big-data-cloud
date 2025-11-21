#!/usr/bin/env python3
"""
P11 - Étape 2: Feature Extraction + PCA
=========================================

Pipeline PySpark pour l'extraction de features avec MobileNetV2 et PCA.

Architecture:
1. Chargement des images depuis S3
2. Extraction de features avec TensorFlow MobileNetV2 (broadcast des poids)
3. Réduction de dimension avec PCA (PySpark MLlib)
4. Sauvegarde des résultats sur S3 (Parquet + CSV)

Usage:
    spark-submit process_fruits_data.py <input_path> <output_path> <mode> <pca_components>

Arguments:
    input_path      : Chemin S3 des images (ex: s3://bucket/data/raw/)
    output_path     : Chemin S3 de sortie (ex: s3://bucket/process_fruits_data/output/)
    mode            : Mode de traitement (mini/apples/full)
    pca_components  : Nombre de composantes PCA (ex: 50)

Exemple:
    spark-submit process_fruits_data.py \
        s3://bucket/data/raw/ \
        s3://bucket/process_fruits_data/output/ \
        mini \
        50
"""

import sys
import os
import time
from datetime import datetime
import json

# Désactiver les warnings TensorFlow
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import warnings
warnings.filterwarnings('ignore')

# PySpark imports
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, pandas_udf, element_at, split, udf, lit, when
from pyspark.sql.types import ArrayType, FloatType, StringType, StructType, StructField, IntegerType
from pyspark.ml.feature import PCA
from pyspark.ml.linalg import Vectors, VectorUDT

# TensorFlow imports
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input
from tensorflow.keras.preprocessing.image import img_to_array

# Autres imports
from PIL import Image
import pandas as pd
import numpy as np
import io


def parse_arguments():
    """Parse les arguments de ligne de commande."""
    if len(sys.argv) != 5:
        print("❌ Erreur: Nombre d'arguments incorrect")
        print(f"Usage: {sys.argv[0]} <input_path> <output_path> <mode> <pca_components>")
        print("Modes disponibles: mini (300 images), apples (~6400), full (~67000)")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    mode = sys.argv[3].lower()

    try:
        pca_components = int(sys.argv[4])
    except ValueError:
        print(f"❌ Erreur: pca_components doit être un entier, reçu: {sys.argv[4]}")
        sys.exit(1)

    if mode not in ['mini', 'apples', 'full']:
        print(f"❌ Erreur: Mode invalide '{mode}'. Choisir: mini, apples, full")
        sys.exit(1)

    return input_path, output_path, mode, pca_components


def create_spark_session():
    """Crée et configure la SparkSession."""
    spark = SparkSession.builder \
        .appName("P11-Etape2-ProcessFruitsData") \
        .config("spark.executor.memory", "8g") \
        .config("spark.driver.memory", "8g") \
        .config("spark.executor.memoryOverhead", "2g") \
        .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
        .config("spark.sql.execution.arrow.pyspark.fallback.enabled", "true") \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")

    return spark


def load_images(spark, input_path, mode):
    """
    Charge les images depuis S3 selon le mode spécifié.

    Returns:
        DataFrame avec colonnes: path, content
    """
    print(f"\n{'='*60}")
    print(f"📂 CHARGEMENT DES IMAGES - Mode: {mode.upper()}")
    print(f"{'='*60}")

    if mode == "mini":
        print(f"🔍 Mode MINI: 300 images de pommes")
        image_path = f"{input_path}Training/Apple*/*.jpg"
        df_images = spark.read.format("binaryFile").load(image_path).limit(300)

    elif mode == "apples":
        print(f"🔍 Mode APPLES: ~6,400 images de pommes")
        image_path = f"{input_path}Training/Apple*/*.jpg"
        df_images = spark.read.format("binaryFile").load(image_path)

    elif mode == "full":
        print(f"🔍 Mode FULL: ~67,000 images (tous les fruits)")
        image_path = f"{input_path}Training/*/*.jpg"
        df_images = spark.read.format("binaryFile").load(image_path)

    num_images = df_images.count()
    print(f"✅ {num_images:,} images chargées depuis S3")

    return df_images


def extract_labels(df_images):
    """Extrait les labels depuis les chemins S3."""
    print(f"\n📋 Extraction des labels...")

    # Extraire le label depuis le chemin
    # s3://bucket/data/raw/Training/Apple Braeburn/0_100.jpg -> Apple Braeburn
    df_with_labels = df_images.withColumn(
        "label",
        element_at(split(col("path"), "/"), -2)
    )

    num_classes = df_with_labels.select("label").distinct().count()
    print(f"✅ Labels extraits: {num_classes} classes trouvées")

    return df_with_labels


def broadcast_model_weights(spark):
    """
    Charge MobileNetV2 et broadcast les poids à tous les workers.

    Returns:
        broadcast_weights: Poids du modèle broadcastés
        output_dim: Dimension de sortie (1280 pour MobileNetV2)
    """
    print(f"\n{'='*60}")
    print(f"🤖 CHARGEMENT DU MODÈLE MOBILENETV2")
    print(f"{'='*60}")

    # Charger MobileNetV2 sans la couche de classification
    model = MobileNetV2(
        weights='imagenet',
        include_top=False,
        pooling='avg'
    )

    output_dim = model.output_shape[1]

    print(f"✅ Modèle MobileNetV2 chargé")
    print(f"   Input shape: {model.input_shape}")
    print(f"   Output shape: {model.output_shape}")
    print(f"   Dimension des features: {output_dim}")

    # Extraire les poids
    model_weights = model.get_weights()

    weights_size_mb = sum([w.nbytes for w in model_weights]) / 1024 / 1024
    print(f"\n📦 Broadcast des poids du modèle...")
    print(f"   Nombre de tenseurs: {len(model_weights)}")
    print(f"   Taille en mémoire: {weights_size_mb:.2f} MB")

    # Broadcaster les poids
    sc = spark.sparkContext
    broadcast_weights = sc.broadcast(model_weights)

    print(f"✅ Poids broadcastés à tous les workers")

    return broadcast_weights, output_dim


def create_feature_extraction_udf(broadcast_weights, output_dim):
    """
    Crée la Pandas UDF pour l'extraction de features.

    Returns:
        extract_features_udf: UDF pour extraction de features
    """
    features_schema = ArrayType(FloatType())

    @pandas_udf(features_schema)
    def extract_features_udf(content_series: pd.Series) -> pd.Series:
        """
        Extrait les features avec MobileNetV2.
        Exécuté sur chaque worker Spark.
        """
        # Reconstruire le modèle dans le worker
        local_model = MobileNetV2(
            weights=None,
            include_top=False,
            pooling='avg'
        )

        # Charger les poids broadcastés
        local_model.set_weights(broadcast_weights.value)

        def process_image(content):
            try:
                # Charger l'image
                img = Image.open(io.BytesIO(content))

                # Convertir en RGB
                if img.mode != 'RGB':
                    img = img.convert('RGB')

                # Redimensionner (224x224)
                img = img.resize((224, 224))

                # Convertir en array
                img_array = img_to_array(img)
                img_array = np.expand_dims(img_array, axis=0)
                img_array = preprocess_input(img_array)

                # Extraire les features
                features = local_model.predict(img_array, verbose=0)

                return features[0].tolist()

            except Exception as e:
                # Retourner None en cas d'erreur
                return None

        return content_series.apply(process_image)

    return extract_features_udf


def extract_features(df_with_labels, extract_features_udf):
    """
    Applique l'extraction de features sur toutes les images.

    Returns:
        df_features: DataFrame avec colonnes path, label, features
        df_errors: DataFrame avec les images en erreur
    """
    print(f"\n{'='*60}")
    print(f"🎨 EXTRACTION DES FEATURES")
    print(f"{'='*60}")

    start_time = time.time()

    # Appliquer l'extraction
    df_with_features = df_with_labels.withColumn(
        "features",
        extract_features_udf(col("content"))
    )

    # Séparer les succès et les erreurs
    df_features = df_with_features.filter(col("features").isNotNull())
    df_errors = df_with_features.filter(col("features").isNull())

    # Cache pour réutilisation
    df_features.cache()
    df_errors.cache()

    count_success = df_features.count()
    count_errors = df_errors.count()

    elapsed_time = time.time() - start_time

    print(f"✅ Extraction terminée")
    print(f"   Images traitées: {count_success:,}")
    print(f"   Images en erreur: {count_errors:,}")
    print(f"   Temps d'exécution: {elapsed_time:.2f}s")
    print(f"   Vitesse: {count_success / elapsed_time:.2f} images/seconde")

    if count_errors > 0:
        error_rate = (count_errors / (count_success + count_errors)) * 100
        print(f"   ⚠️  Taux d'erreur: {error_rate:.2f}%")

    return df_features, df_errors


def apply_pca(df_features, pca_components):
    """
    Applique la PCA pour réduire les dimensions.

    Returns:
        df_pca: DataFrame avec colonnes path, label, features, pca_features
        pca_model: Modèle PCA entraîné
    """
    print(f"\n{'='*60}")
    print(f"📊 RÉDUCTION DE DIMENSION AVEC PCA")
    print(f"{'='*60}")

    # Convertir array → vecteur dense pour PCA
    array_to_vector = udf(lambda a: Vectors.dense(a), VectorUDT())

    df_for_pca = df_features.withColumn(
        "features_vector",
        array_to_vector(col("features"))
    )

    df_for_pca.cache()
    count = df_for_pca.count()

    print(f"📦 {count:,} vecteurs préparés pour PCA")

    # Créer et entraîner le modèle PCA
    print(f"⏳ Application de PCA (1280 → {pca_components} dimensions)...")
    start_time = time.time()

    pca = PCA(
        k=pca_components,
        inputCol="features_vector",
        outputCol="pca_features"
    )

    pca_model = pca.fit(df_for_pca)

    # Appliquer la transformation
    df_pca = pca_model.transform(df_for_pca)

    df_pca.cache()
    count = df_pca.count()

    elapsed_time = time.time() - start_time

    print(f"✅ PCA appliquée avec succès!")
    print(f"   Dimensions: 1280 → {pca_components}")
    print(f"   Images: {count:,}")
    print(f"   Temps: {elapsed_time:.2f}s")

    # Analyser la variance expliquée
    explained_variance = pca_model.explainedVariance
    total_variance = sum(explained_variance)

    print(f"\n📈 Variance expliquée:")
    print(f"   Total: {total_variance:.4f}")
    print(f"   Top 10 composantes:")
    for i in range(min(10, len(explained_variance))):
        print(f"      PC{i+1}: {explained_variance[i]:.6f}")

    return df_pca, pca_model


def save_results(df_pca, df_errors, pca_model, output_path, pca_components):
    """
    Sauvegarde tous les résultats sur S3.
    """
    print(f"\n{'='*60}")
    print(f"💾 SAUVEGARDE DES RÉSULTATS SUR S3")
    print(f"{'='*60}")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 1. Features brutes (1280D) - Parquet
    print(f"\n📤 Sauvegarde des features brutes (Parquet)...")
    features_parquet_path = f"{output_path}features/parquet/features_{timestamp}"
    df_pca.select("path", "label", "features").write.mode("overwrite").parquet(features_parquet_path)
    print(f"   ✅ {features_parquet_path}")

    # 2. Features brutes (1280D) - CSV
    print(f"\n📤 Sauvegarde des features brutes (CSV)...")

    # Convertir array → string pour CSV
    def array_to_string(arr):
        if arr is None:
            return None
        return ",".join([str(float(x)) for x in arr])

    array_to_string_udf = udf(array_to_string, StringType())

    df_features_csv = df_pca.withColumn(
        "features_string",
        array_to_string_udf(col("features"))
    ).select("path", "label", "features_string")

    features_csv_path = f"{output_path}features/csv/features_{timestamp}"
    df_features_csv.write.mode("overwrite").option("header", "true").csv(features_csv_path)
    print(f"   ✅ {features_csv_path}")

    # 3. Features PCA (50D) - Parquet
    print(f"\n📤 Sauvegarde des features PCA (Parquet)...")
    pca_parquet_path = f"{output_path}pca/parquet/pca_{timestamp}"
    df_pca.select("path", "label", "pca_features").write.mode("overwrite").parquet(pca_parquet_path)
    print(f"   ✅ {pca_parquet_path}")

    # 4. Features PCA (50D) - CSV
    print(f"\n📤 Sauvegarde des features PCA (CSV)...")

    def vector_to_string(v):
        if v is None:
            return None
        return ",".join([str(float(x)) for x in v.toArray()])

    vector_to_string_udf = udf(vector_to_string, StringType())

    df_pca_csv = df_pca.withColumn(
        "pca_features_string",
        vector_to_string_udf(col("pca_features"))
    ).select("path", "label", "pca_features_string")

    pca_csv_path = f"{output_path}pca/csv/pca_{timestamp}"
    df_pca_csv.write.mode("overwrite").option("header", "true").csv(pca_csv_path)
    print(f"   ✅ {pca_csv_path}")

    # 5. Métadonnées - CSV
    print(f"\n📤 Sauvegarde des métadonnées (CSV)...")
    metadata_path = f"{output_path}metadata/metadata_{timestamp}"
    df_pca.select("path", "label").write.mode("overwrite").option("header", "true").csv(metadata_path)
    print(f"   ✅ {metadata_path}")

    # 6. Informations du modèle PCA - JSON
    print(f"\n📤 Sauvegarde des informations PCA (JSON)...")

    explained_variance = pca_model.explainedVariance
    cumsum_variance = np.cumsum(explained_variance)

    model_info = {
        "timestamp": timestamp,
        "pca_components": pca_components,
        "original_dimensions": 1280,
        "reduced_dimensions": pca_components,
        "total_variance_explained": float(sum(explained_variance)),
        "variance_by_component": [float(v) for v in explained_variance],
        "cumulative_variance": [float(v) for v in cumsum_variance],
        "num_images_processed": df_pca.count()
    }

    # Sauvegarder localement puis uploader (PySpark ne peut pas écrire JSON directement)
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(model_info, f, indent=2)
        temp_path = f.name

    # Créer un DataFrame à partir du JSON et sauvegarder
    from pyspark.sql import Row
    spark = df_pca.sql_ctx.sparkSession
    json_string = json.dumps(model_info, indent=2)
    df_json = spark.createDataFrame([Row(json_content=json_string)])

    model_info_path = f"{output_path}model_info/model_info_{timestamp}"
    df_json.write.mode("overwrite").text(model_info_path)
    print(f"   ✅ {model_info_path}")

    # 7. Informations PCA - CSV (pour analyse facile)
    print(f"\n📤 Sauvegarde de la variance PCA (CSV)...")

    variance_data = [
        (i+1, float(explained_variance[i]), float(cumsum_variance[i]))
        for i in range(len(explained_variance))
    ]

    variance_schema = StructType([
        StructField("component", IntegerType(), False),
        StructField("variance_explained", FloatType(), False),
        StructField("cumulative_variance", FloatType(), False)
    ])

    df_variance = spark.createDataFrame(variance_data, variance_schema)
    variance_csv_path = f"{output_path}model_info/variance_{timestamp}"
    df_variance.write.mode("overwrite").option("header", "true").csv(variance_csv_path)
    print(f"   ✅ {variance_csv_path}")

    # 8. Rapport d'erreurs - CSV
    if df_errors.count() > 0:
        print(f"\n📤 Sauvegarde du rapport d'erreurs (CSV)...")
        errors_path = f"{output_path}errors/errors_{timestamp}"
        df_errors.select("path", "label").write.mode("overwrite").option("header", "true").csv(errors_path)
        print(f"   ✅ {errors_path}")
        print(f"   ⚠️  {df_errors.count()} images en erreur sauvegardées")

    print(f"\n✅ Tous les résultats ont été sauvegardés sur S3!")


def main():
    """Point d'entrée principal du script."""
    print(f"\n{'='*60}")
    print(f"🍎 P11 - ÉTAPE 2: FEATURE EXTRACTION + PCA")
    print(f"{'='*60}")
    print(f"⏰ Démarrage: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Parse arguments
    input_path, output_path, mode, pca_components = parse_arguments()

    print(f"\n📋 Configuration:")
    print(f"   Input: {input_path}")
    print(f"   Output: {output_path}")
    print(f"   Mode: {mode}")
    print(f"   PCA components: {pca_components}")

    # Créer SparkSession
    spark = create_spark_session()

    print(f"\n✅ SparkSession créée")
    print(f"   Version Spark: {spark.version}")
    print(f"   Master: {spark.sparkContext.master}")
    print(f"   App Name: {spark.sparkContext.appName}")

    try:
        # 1. Charger les images
        df_images = load_images(spark, input_path, mode)

        # 2. Extraire les labels
        df_with_labels = extract_labels(df_images)

        # 3. Broadcast du modèle
        broadcast_weights, output_dim = broadcast_model_weights(spark)

        # 4. Créer l'UDF d'extraction
        extract_features_udf = create_feature_extraction_udf(broadcast_weights, output_dim)

        # 5. Extraire les features
        df_features, df_errors = extract_features(df_with_labels, extract_features_udf)

        # 6. Appliquer la PCA
        df_pca, pca_model = apply_pca(df_features, pca_components)

        # 7. Sauvegarder les résultats
        save_results(df_pca, df_errors, pca_model, output_path, pca_components)

        # Nettoyage
        broadcast_weights.unpersist()
        df_features.unpersist()
        df_errors.unpersist()
        df_pca.unpersist()

        print(f"\n{'='*60}")
        print(f"✅ TRAITEMENT TERMINÉ AVEC SUCCÈS!")
        print(f"{'='*60}")
        print(f"⏰ Fin: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    except Exception as e:
        print(f"\n{'='*60}")
        print(f"❌ ERREUR LORS DU TRAITEMENT")
        print(f"{'='*60}")
        print(f"Erreur: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    finally:
        spark.stop()


if __name__ == "__main__":
    main()
