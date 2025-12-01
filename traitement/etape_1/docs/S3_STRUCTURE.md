# Structure S3 pour le projet P11 - Étape 1

## 📊 Vue d'ensemble

Tous les éléments du projet seront uploadés dans le dossier racine :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/
```

## 📁 Sous-dossiers requis

Oui, il faut créer **4 sous-dossiers** dans `read_fruits_data/` :

```
s3://oc-p11-fruits-david-scanu/read_fruits_data/
│
├── config/              # ✅ Configuration Python
├── scripts/             # ✅ Scripts PySpark et bootstrap
├── output/              # ✅ Résultats des jobs
└── logs/                # ✅ Logs EMR
```

### Détail de chaque dossier

#### 1. `scripts/` - Scripts d'exécution

**Contenu** :
- `install_dependencies.sh` : Script de bootstrap (installation des packages)
- `read_fruits_data.py` : Script PySpark principal

**Chemins complets** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/scripts/install_dependencies.sh
s3://oc-p11-fruits-david-scanu/read_fruits_data/scripts/read_fruits_data.py
```

**Utilisé par** :
- `create_cluster.sh` : Bootstrap action
- `submit_job.sh` : Exécution du step PySpark

---

#### 2. `output/` - Résultats des jobs

**Contenu** : Résultats générés automatiquement par les jobs PySpark

**Structure** :
```
output/
└── etape_1/
    ├── metadata_20251118_083045/
    │   ├── _SUCCESS
    │   └── part-00000-xxx.csv
    │
    └── stats_20251118_083045/
        ├── _SUCCESS
        └── part-00000-xxx.csv
```

**Chemin complet** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/output/etape_1/
```

**Créé par** : Le script PySpark `read_fruits_data.py`

**Contenu des CSV** :
- `metadata_*.csv` : Liste complète des images avec métadonnées (nom, label, taille, etc.)
- `stats_*.csv` : Statistiques par classe (count Training/Test)

---

#### 3. `logs/` - Logs EMR

**Contenu** : Logs générés automatiquement par EMR

**Structure** :
```
logs/
└── emr/
    └── j-CLUSTERID/           # ID unique du cluster
        ├── node/              # Logs système des nœuds
        │   ├── i-xxx/
        │   └── ...
        ├── containers/        # Logs des conteneurs YARN/Spark
        │   ├── application_xxx/
        │   └── ...
        └── steps/             # Logs des steps (jobs)
            ├── s-STEPID/
            └── ...
```

**Chemin complet** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/
```

**Créé par** : EMR automatiquement (configuré dans `create_cluster.sh` via `--log-uri`)

**Usage** : Debugging en cas d'erreur

---

## 🚀 Création automatique des dossiers

**Bonne nouvelle** : Ces dossiers seront créés automatiquement lors de l'upload des scripts !

Le script `upload_scripts.sh` créera automatiquement :
- ✅ `scripts/` (lors de l'upload des scripts .sh et .py)

Les dossiers `output/` et `logs/` seront créés automatiquement par :
- ✅ `output/` : Créé par le script PySpark lors de l'écriture des résultats
- ✅ `logs/` : Créé par EMR lors du démarrage du cluster

**Aucune action manuelle requise !** 🎉

---

## 📍 Données d'entrée (séparé)

Les données d'entrée restent dans leur emplacement actuel :

```
s3://oc-p11-fruits-david-scanu/data/raw/
├── Training/
│   ├── Apple Braeburn/
│   │   ├── 0_100.jpg
│   │   ├── 1_100.jpg
│   │   └── ...
│   ├── Apple Crimson Snow/
│   └── ... (224 classes)
└── Test/
    └── ... (224 classes)
```

**Chemin complet** :
```
s3://oc-p11-fruits-david-scanu/data/raw/Training/Apple Braeburn/0_100.jpg
```

**Important** : Les noms de dossiers contiennent des espaces (`Apple Braeburn`), mais PySpark gère cela automatiquement.

---

## 🔄 Workflow de création des dossiers

### Étape 1 : Upload des scripts (manuel)

```bash
cd traitement/etape_1
./scripts/upload_scripts.sh
```

**Résultat** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/
└── scripts/
    ├── install_dependencies.sh   ✅ Créé
    └── read_fruits_data.py       ✅ Créé
```

### Étape 2 : Création du cluster (automatique)

```bash
./scripts/create_cluster.sh
```

**Résultat** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/
└── logs/
    └── emr/
        └── j-XXXXXXXXXXXXX/      ✅ Créé par EMR
```

### Étape 3 : Exécution du job (automatique)

```bash
./scripts/submit_job.sh
```

**Résultat** :
```
s3://oc-p11-fruits-david-scanu/read_fruits_data/
└── output/
    └── etape_1/
        ├── metadata_20251118_083045/  ✅ Créé par PySpark
        └── stats_20251118_083045/     ✅ Créé par PySpark
```

---

## ✅ Vérification de la structure

Après l'upload des scripts, vérifier avec :

```bash
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/ --region eu-west-1
```

**Résultat attendu** :
```
                           PRE config/
                           PRE scripts/
```

Après l'exécution du job :
```
                           PRE config/
                           PRE logs/
                           PRE output/
                           PRE scripts/
```

---

## 📋 Résumé

| Dossier | Création | Contenu | Taille estimée |
|---------|----------|---------|----------------|
| `scripts/` | Upload manuel | 2 scripts (.sh + .py) | ~7 KB |
| `output/` | PySpark automatique | CSV résultats | ~10-50 MB |
| `logs/` | EMR automatique | Logs cluster | ~100-500 MB |

**Total estimé** : ~500 MB après exécution complète

---

## 🎯 Commandes de vérification

```bash
# Vérifier la structure complète
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/ --recursive --region eu-west-1

# Vérifier les données d'entrée
aws s3 ls s3://oc-p11-fruits-david-scanu/data/raw/Training/ --region eu-west-1

# Compter les images (exemple)
aws s3 ls s3://oc-p11-fruits-david-scanu/data/raw/ --recursive --region eu-west-1 | grep "\.jpg$" | wc -l

# Taille totale du dossier
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/ --recursive --human-readable --summarize --region eu-west-1
```

---

**Conclusion** : Vous n'avez **rien à créer manuellement** ! Tout sera créé automatiquement lors de l'upload et de l'exécution. 🚀
