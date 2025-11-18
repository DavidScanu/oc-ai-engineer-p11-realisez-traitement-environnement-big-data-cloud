# Guide de démarrage rapide - Étape 1

## 🚀 Démarrage en 5 minutes

### Prérequis

- AWS CLI configuré (`aws configure`)
- Credentials AWS avec permissions EMR, S3, EC2, IAM
- Dataset Fruits-360 uploadé sur S3

### Étapes

#### 1. Configuration (une seule fois)

```bash
cd traitement/etape_1

# Éditer la configuration
nano config/config.sh
# Modifier: S3_BUCKET, EC2_KEY_NAME, Security Groups, Subnet, ARNs IAM
```

#### 2. Vérification

```bash
./scripts/verify_setup.sh
```

**Résultat attendu** : ✅ VÉRIFICATION RÉUSSIE

#### 3. Upload des scripts

```bash
./scripts/upload_scripts.sh
```

#### 4. Créer le cluster

```bash
./scripts/create_cluster.sh
# Confirmer avec: oui
```

#### 5. Attendre que le cluster soit prêt

```bash
./scripts/monitor_cluster.sh
# Attendre: ✅ WAITING - Cluster prêt à l'emploi !
```

**Durée** : 10-15 minutes

#### 6. Soumettre le job PySpark

```bash
./scripts/submit_job.sh
```

**Durée** : 25 minutes

#### Optionnel : Inspecter les logs (si besoin)

```bash
# Rendre le script exécutable
chmod +x ./scripts/download_and_inspect_logs.sh
# Lancer le script automatisé
./scripts/download_and_inspect_logs.sh
```

###### 📄 Voir les logs YARN (où sont vos prints Python)

Les prints de notre script sont dans les logs des executors YARN :

```bash 
# Lister les logs YARN
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/j-2Z5SWHT00E1LR/containers/ --recursive --region eu-west-1 | grep application_1763458321894_0001

# Télécharger les logs YARN
mkdir -p logs/yarn
aws s3 sync s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/j-2Z5SWHT00E1LR/containers/ logs/yarn/ --region eu-west-1

# Chercher vos prints avec emojis
find logs/yarn -name "*.gz" -exec zcat {} \; | grep "🍎\|📂\|✅\|📊"
```

**Sortie attendue** : 

```bash
🍎 P11 - ÉTAPE 1: Lecture et indexation du dataset Fruits-360
✅ Spark version: 3.5.6-amzn-0
✅ Spark Master: yarn
✅ Executor Memory: 4g
✅ Driver Memory: 4g
📂 Étape 1: Lecture des fichiers images depuis S3...
✅ Fichiers lus: 67692 images trouvées
✅ Métadonnées extraites: 67692 images valides
📊 Étape 3: Calcul des statistiques...
✅ Training images: 67692
✅ Test images: 0
✅ Nombre de classes: 131
✅ Résultats sauvegardés avec succès
✅ TRAITEMENT TERMINÉ AVEC SUCCÈS
📊 Total images: 67692
📊 Training: 67692
📊 Test: 0
📊 Classes: 131
```

#### 7. Récupérer les résultats

Une fois le job terminé (état `COMPLETED`), téléchargez les résultats vers le dossier local `output/` :

```bash
./scripts/download_results.sh
```

Le script télécharge automatiquement :
- Les métadonnées de toutes les images indexées
- Les statistiques par classe (Training/Test)

**Commandes manuelles alternatives :**
```bash
# Lister les résultats disponibles sur S3
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/output/etape_1/ --recursive --region eu-west-1

# Télécharger manuellement dans le dossier output/
aws s3 sync s3://oc-p11-fruits-david-scanu/read_fruits_data/output/etape_1/ ./output/ \
    --region eu-west-1 \
    --exclude "*.crc" \
    --exclude "_SUCCESS"
```

**Résultats attendus :**
```
output/
├── metadata_YYYYMMDD_HHMMSS/
│   └── part-00000-*.csv          # ~67K lignes (1 par image)
└── stats_YYYYMMDD_HHMMSS/
    └── part-00000-*.csv          # Nombre d'images par classe
```

#### 8. Terminer le cluster

```bash
./scripts/terminate_cluster.sh
# Confirmer avec: oui
```

## 📋 Checklist

- [x] AWS CLI configuré et testé
- [x] Configuration éditée dans `config/config.sh`
- [x] Dataset uploadé sur S3
- [x] Scripts vérifiés avec `verify_setup.sh`
- [x] Scripts uploadés avec `upload_scripts.sh`
- [x] Cluster créé avec `create_cluster.sh`
- [x] Cluster prêt (état: WAITING)
- [x] Job soumis avec `submit_job.sh`
- [x] Résultats téléchargés
- [x] Cluster terminé avec `terminate_cluster.sh`

## ⚡ Commandes utiles

```bash
# Surveiller l'état du cluster
./scripts/monitor_cluster.sh

# Surveiller l'état du job
aws emr describe-step --cluster-id $(cat cluster_id.txt) --step-id $(cat step_id.txt) --region eu-west-1 --query "Step.Status"

# Terminer le cluster
./scripts/terminate_cluster.sh

# Nettoyer toutes les ressources
./scripts/cleanup.sh

# Console AWS EMR
echo "https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/$(cat cluster_id.txt)"
```

## ❗ Points d'attention

1. **Coûts** : Le cluster coûte ~0.50€/heure → Toujours terminer après usage !
2. **Auto-terminaison** : Activée après 4h d'inactivité (configurable)
3. **Région** : Toujours utiliser `eu-west-1` (ou autre région EU) pour GDPR
4. **Logs** : Vérifier `s3://bucket/logs/emr/` en cas d'erreur

## 🆘 Dépannage rapide

| Problème | Solution |
|----------|----------|
| `verify_setup.sh` échoue | Vérifier la configuration dans `config/config.sh` |
| Cluster ne démarre pas | Vérifier les logs EMR dans S3 |
| Job échoue | Vérifier les logs du step dans S3 |
| Coûts élevés | Vérifier les instances EC2 en cours avec `aws ec2 describe-instances` |

## 📚 Documentation complète

Voir [README.md](../README.md) pour la documentation détaillée.
