#!/bin/bash
# Script d'installation des dépendances Python pour EMR - Étape 2
# Feature Extraction (TensorFlow) + PCA
# À placer sur S3 et utilisé comme bootstrap action

# Note: Pas de "set -e" pour éviter les échecs sur warnings pip

echo "🔧 Installation des dépendances Python pour l'étape 2..."

# Installer les packages critiques (sans échec sur warnings)
sudo python3 -m pip install --no-cache-dir \
  pillow==10.4.0 \
  pandas==2.2.0 \
  numpy==1.26.4 \
  pyarrow==15.0.0 \
  boto3==1.34.34 \
  tqdm==4.66.1 \
  tensorflow==2.16.1 \
  scikit-learn==1.4.0 \
  "python-dateutil<=2.9.0" || {
    echo "⚠️  Certains packages ont généré des warnings, mais l'installation continue..."
}

echo "✅ Dépendances Python installées"
echo "📦 Packages critiques:"
echo "   - Pillow 10.4.0 (traitement d'images)"
echo "   - TensorFlow 2.16.1 (MobileNetV2)"
echo "   - scikit-learn 1.4.0 (comparaison PCA)"
echo "   - pandas 2.2.0 (Pandas UDF)"
echo "   - numpy 1.26.4 (calculs numériques)"
echo "   - pyarrow 15.0.0 (sérialisation Arrow)"
echo "   - boto3 (AWS SDK)"

# Vérifier que TensorFlow est bien installé
python3 -c "import tensorflow; print(f'✅ TensorFlow version: {tensorflow.__version__}')" || {
    echo "❌ ERREUR: TensorFlow non installé correctement"
    exit 1
}

echo "✅ Bootstrap terminé avec succès"
