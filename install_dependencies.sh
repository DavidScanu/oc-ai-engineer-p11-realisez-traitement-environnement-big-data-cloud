#!/bin/bash
# Script d'installation des dépendances Python pour EMR
# À placer sur S3

# Installer les packages critiques
sudo python3 -m pip install \
  pillow==10.4.0 \
  ipython \
  ipykernel \
  notebook \
  jupyterlab \
  pandas==2.2.0 \
  numpy==1.26.4 \
  pyarrow==15.0.0 \
  matplotlib==3.8.2 \
  seaborn==0.13.1 \
  boto3==1.34.34 \
  tqdm==4.66.1 \
  optree \
  tensorflow \
  "python-dateutil<=2.9.0"

echo "✅ Dépendances Python installées avec succès"