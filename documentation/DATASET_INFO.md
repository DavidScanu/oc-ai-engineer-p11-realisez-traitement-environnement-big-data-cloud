# Dataset Fruits-360 - Informations

## 📊 Structure du dataset

```
data/raw/
├── fruits-360_dataset/
│   └── fruits-360/
│       ├── Training/          # 67,692 images (131 classes)
│       ├── Test/               # 22,688 images
│       ├── test-multiple_fruits/
│       └── papers/
└── fruits-360-original-size/
    └── fruits-360-original-size/
        ├── Training/
        ├── Test/
        ├── Validation/
        ├── Meta/
        └── Papers/
```

## 📈 Statistiques

**Version 100x100 (fruits-360_dataset)** - Utilisée pour le projet
- **Training**: 67,692 images
- **Test**: 22,688 images
- **Classes**: 131 classes de fruits/légumes
- **Format**: JPG, 100x100 pixels
- **Taille**: ~985 MB

**Version original-size (fruits-360-original-size)**
- Images en tailles originales (dimensions variables)
- **Taille**: ~583 MB

## 🍎 Exemples de classes

Le dataset contient de nombreuses variétés, notamment:
- **Pommes** (Apple): Braeburn, Crimson Snow, Golden 1-3, Granny Smith, Pink Lady, Red 1-3
- **Cerises** (Cherry): Différentes variétés
- **Tomates** (Tomato): Différentes variétés
- Et bien d'autres fruits, légumes, noix...

## 🎯 Utilisation pour le projet

**Pour le développement local**:
- Commencer avec un **subset** (ex: Apple* classes) pour tester rapidement
- Une fois le code validé, traiter le **dataset complet**

**Chemins dans le code PySpark**:
```python
# Training (100x100)
IMAGES_PATH = "data/raw/fruits-360_dataset/fruits-360/Training"

# Test (100x100)
TEST_PATH = "data/raw/fruits-360_dataset/fruits-360/Test"

# Subset pour tests
image_path = f"file://{IMAGES_PATH}/Apple*/*.jpg"  # ~10 classes

# Dataset complet
image_path = f"file://{IMAGES_PATH}/*/*.jpg"       # 131 classes
```

## ⚠️ Important

- Le dossier `data/` est exclu du git (.gitignore) car trop volumineux
- Taille totale extraite: ~1.5 GB
- Le fichier ZIP original a été supprimé après extraction

## 📚 Source

- **Kaggle**: https://www.kaggle.com/datasets/moltean/fruits
- **S3 Direct**: https://s3.eu-west-1.amazonaws.com/course.oc-static.com/projects/Data_Scientist_P8/fruits.zip
- **Créateur**: Mihai Oltean (2017-)
- **Licence**: CC BY-SA 4.0
