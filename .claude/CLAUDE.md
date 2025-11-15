# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OpenClassrooms AI Engineer project (P11) focused on implementing big data processing in a cloud environment for fruit image classification. The project involves migrating local data processing to a cloud-based PySpark pipeline with PCA dimensionality reduction.

**Key objectives:**
- Migrate data processing from local environment to cloud (AWS)
- Implement distributed processing with PySpark on AWS EMR
- Setup GDPR-compliant Big Data architecture
- Perform PCA dimensionality reduction on fruit images
- Extract features using TensorFlow and process them at scale

## Technology Stack

- **Language**: Python
- **Big Data**: PySpark for distributed processing
- **Cloud Platform**: AWS (EMR for compute clusters, S3 for storage)
- **Deep Learning**: TensorFlow for feature extraction
- **Focus**: Big data processing and cloud infrastructure

## Dataset

**Fruits-360 Dataset** (Kaggle: moltean/fruits)
- **Size**: 155,491 images across 224 classes (100x100 version)
- **Format**: JPG images, 100x100 pixels (standardized)
- **Content**: Various fruits, vegetables, nuts, and seeds with multiple varieties (29 apple types, 12 cherry varieties, 19 tomato types, etc.)
- **License**: CC BY-SA 4.0
- **Structure**: Images captured via rotation (20s at 3 rpm) against white background
- **Naming**: `image_index_100.jpg` or `r_image_index_100.jpg` (r = rotated)

## Project Context

**Company**: "Fruits!" - AgriTech startup developing intelligent fruit-picking robots to preserve biodiversity.

## Technical Requirements

### Critical Constraints
1. **GDPR Compliance**: Must use AWS servers in European regions only
2. **Scalability**: System must handle rapidly increasing data volumes
3. **Cost Management**: Keep AWS EMR costs under €10 by stopping clusters when not in use
4. **No Model Training**: Focus is on data processing pipeline, not ML model training

### Missing Components (to implement)
- **TensorFlow weights broadcast**: Distribute model weights across Spark clusters
- **PCA dimensionality reduction**: Implement in PySpark

## Development Workflow

### Local Development
1. Test and develop PySpark scripts locally first
2. Use AWS EMR only for implementation and final testing
3. Keep EMR cluster stopped when not actively using it

### Cloud Architecture (AWS)
- **Storage**: S3 (European region) for images and results
- **Compute**: EMR cluster for distributed PySpark processing
- **Notebook Environment**: EMR Notebook or Databricks Notebook (both provide native PySpark execution on cloud clusters)
- **Alternative**: Databricks can be used instead of AWS EMR (includes managed notebooks)

## Processing Pipeline

1. Load fruit images from S3
2. Preprocess images
3. Extract features using TensorFlow model (with broadcasted weights)
4. Apply PCA dimensionality reduction in PySpark
5. Store results back to S3 as CSV

## Deliverables

1. **Cloud Notebook**: PySpark scripts with preprocessing and PCA (executable on cloud)
   - **Recommended**: AWS EMR Notebook (native integration with EMR clusters and S3)
   - **Alternative**: Databricks Notebook (managed Spark environment)
   - **Not recommended**: Google Colab (requires manual PySpark setup, no native EMR integration)
2. **Data in S3**: Initial images + PCA output (CSV matrix)
3. **Presentation**: Architecture diagram, cloud setup process, PySpark pipeline explanation

## Intern's Work Analysis

The intern created a comprehensive notebook (`P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb`) with:

**Completed work:**
- Local Spark deployment and testing
- AWS EMR cluster setup documentation (detailed step-by-step)
- S3 storage configuration
- Image loading from S3 using PySpark
- Feature extraction using TensorFlow MobileNetV2 (Transfer Learning)
- Pandas UDF implementation for distributed image processing
- SSH tunneling and JupyterHub connection setup
- EMR cluster management (start/stop/clone)

**Technology stack used:**
- PySpark 3.x with pandas UDF
- TensorFlow 2.x (MobileNetV2 for feature extraction)
- PIL for image processing
- AWS EMR + S3 (JupyterHub notebooks)
- Apache Arrow for efficient data serialization

**Missing components (to implement):**
1. **Model weights broadcast**: The intern did NOT implement `sc.broadcast()` for TensorFlow weights distribution
2. **PCA dimensionality reduction**: No PCA implementation in PySpark (only feature extraction)

**Key code patterns to reuse:**
- Pandas UDF for image processing: `@pandas_udf(return_schema, PandasUDFType.SCALAR)`
- MobileNetV2 without top layer for feature extraction
- Image preprocessing pipeline (PIL → array → preprocess)

## Key Resources

- Dataset: https://www.kaggle.com/datasets/moltean/fruits or https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip
- Intern's notebook: https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/P8_Mode_ope%CC%81ratoire.zip
- Intern's notebook location: `notebooks/alternant/P8_Notebook_Linux_EMR_PySpark_V1.0.ipynb`