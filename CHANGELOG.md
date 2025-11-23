# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

---

## [2025-11-23] - Support Multi-Mode et Optimisations

### ✨ Ajouts

#### Infrastructure Multi-Mode
- **Support de 3 modes de traitement** :
  - `mini` : 300 images (test rapide, ~2-5 min)
  - `apples` : ~6,400 images de pommes (~15-30 min)
  - `full` : ~67,000 images complètes (~2-3h estimé)

- **Organisation structurée des outputs** :
  - `traitement/etape_2/outputs/output-mini/` : Résultats mode MINI
  - `traitement/etape_2/outputs/output-apples/` : Résultats mode APPLES
  - `traitement/etape_2/outputs/output-full/` : Résultats mode FULL (à venir)

- **Fichiers de métadonnées par mode** :
  - `cluster_id.txt` : ID du cluster EMR utilisé
  - `step_id.txt` : ID du step PySpark exécuté
  - `master_dns.txt` : DNS du nœud master
  - `mode.txt` : Mode de traitement utilisé

#### Nouveaux Scripts
- **`scripts/monitor_job.sh`** : Surveillance en temps réel de l'exécution PySpark
  - Affichage de l'état (PENDING → RUNNING → COMPLETED)
  - Temps écoulé et durée estimée selon le mode
  - Instructions post-traitement automatiques
  - Support multi-mode pour les métadonnées

#### Documentation et Analyse
- **Notebooks Jupyter interactifs** :
  - `outputs/output-mini/resultats-mini.ipynb` : Analyse mode MINI
  - `outputs/output-apples/resultats-apples.ipynb` : Analyse mode APPLES
  - Visualisations : métadonnées, features, PCA, projections 2D/3D
  - Comparaisons inter-modes

- **Documentation détaillée des résultats** :
  - `outputs/output-mini/RESULTATS-MINI.md` : Résultats MINI (300 images, 92.93% variance)
  - `outputs/output-apples/RESULTATS-APPLES.md` : Résultats APPLES (6,404 images, 83.40% variance)
  - Métriques de performance, coûts AWS, tableaux comparatifs

### 🔧 Modifications

#### Scripts de Configuration
- **`config/config.sh`** :
  - Ajout de `S3_DATA_OUTPUT_BASE` pour chemins dynamiques
  - Nouvelle fonction `set_output_path(mode)` : Définit le chemin S3 selon le mode
  - Nouvelle fonction `get_metadata_dir(mode, script_dir)` : Obtient le répertoire de métadonnées
  - Support du mode par défaut via `DEFAULT_MODE`

#### Scripts de Traitement
- **`scripts/submit_job.sh`** :
  - Menu interactif pour sélection du mode (1=mini, 2=apples, 3=full)
  - Création automatique du dossier de métadonnées par mode
  - Sauvegarde de `mode.txt` pour référence future
  - Métadonnées sauvegardées dans `outputs/output-{mode}/`
  - Compatibilité avec ancienne structure (sauvegarde aussi à la racine)
  - Affichage de la durée estimée selon le mode

- **`scripts/download_results.sh`** :
  - Support du paramètre `mode` (ex: `./download_results.sh apples`)
  - Lecture automatique depuis `mode.txt` si pas d'argument
  - Téléchargement vers `outputs/output-{mode}/`
  - Détection automatique du mode utilisé

- **`scripts/download_and_inspect_logs.sh`** :
  - Organisation des logs par mode dans `logs/{mode}/`
  - Support multi-mode pour la recherche de métadonnées
  - Téléchargement ciblé selon le mode de traitement

- **`scripts/monitor_cluster.sh`** :
  - Sauvegarde du `master_dns.txt` dans le dossier de métadonnées du mode
  - Compatibilité avec structure multi-mode

#### Documentation Principale
- **`README.md`** :
  - Section "Modes de traitement validés" avec métriques de chaque mode
  - Liens directs vers les résultats et notebooks (MINI et APPLES)
  - Indication de la variance selon le mode (83-93%)
  - Mention du support multi-mode dans les accomplissements

### 🗂️ Réorganisation

#### Structure Locale
```
traitement/etape_2/
├── outputs/
│   ├── output-mini/          # Résultats mode MINI
│   │   ├── cluster_id.txt
│   │   ├── step_id.txt
│   │   ├── mode.txt
│   │   ├── RESULTATS-MINI.md
│   │   ├── resultats-mini.ipynb
│   │   ├── metadata.csv
│   │   ├── features.csv
│   │   └── pca_output.csv
│   │
│   └── output-apples/        # Résultats mode APPLES
│       ├── cluster_id.txt
│       ├── step_id.txt
│       ├── mode.txt
│       ├── RESULTATS-APPLES.md
│       ├── resultats-apples.ipynb
│       ├── metadata.csv
│       ├── features.csv
│       └── pca_output.csv
│
└── logs/
    ├── mini/                 # Logs mode MINI
    └── apples/               # Logs mode APPLES
```

#### Structure S3
```
s3://oc-p11-fruits-david-scanu/
└── process_fruits_data/
    └── outputs/
        ├── output-mini/      # Résultats mode MINI
        └── output-apples/    # Résultats mode APPLES
```

### 📊 Résultats Validés

#### Mode MINI
- **Images** : 300 (100% succès)
- **Durée** : 3min 34s
- **Débit** : ~84 img/min
- **Variance PCA** : 92.93%
- **Coût AWS** : ~0.50€

#### Mode APPLES
- **Images** : 6,404 (100% succès)
- **Durée** : ~20-25 min
- **Débit** : ~260-320 img/min (3-4× plus rapide que MINI)
- **Variance PCA** : 83.40% (normal avec plus de variabilité)
- **Coût AWS** : ~0.40€

### 🔄 Compatibilité

- **Rétrocompatibilité** : Les scripts cherchent d'abord les métadonnées à la racine, puis dans `outputs/output-{mode}/`
- **Migration automatique** : Anciens résultats déplacés vers `outputs/output-mini/`
- **S3** : Ancienne structure `output/` migrée vers `outputs/output-mini/`

### 🎯 Prochaines Étapes

- [ ] Mode FULL : Traitement de ~67,000 images (optionnel, ~2-3h, ~1.60€)
- [ ] Optimisations supplémentaires selon les besoins
- [ ] Documentation additionnelle si requise

---

## [Historique Antérieur]

### Développement Initial
- Configuration AWS EMR et S3 (région EU pour GDPR)
- Script PySpark `process_fruits_data.py` avec TensorFlow et PCA
- Pipeline de traitement : extraction features (MobileNetV2) + PCA (1280D → 50D)
- Scripts de gestion : création cluster, soumission job, téléchargement résultats
- Mode MINI validé (300 images)
