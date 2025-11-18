# 📋 Guide d'inspection des logs EMR

Ce guide vous aide à télécharger et analyser les logs de votre job PySpark sur EMR.

## 📁 Fichiers de référence

Le dossier `traitement/etape_1/` contient les identifiants nécessaires :

- `cluster_id.txt` - ID du cluster EMR
- `step_id.txt` - ID du job soumis
- `master_dns.txt` - DNS du nœud master (pour SSH)

## 🔍 Inspection rapide

### 1. Charger les identifiants

```bash
cd traitement/etape_1

CLUSTER_ID=$(cat cluster_id.txt)
STEP_ID=$(cat step_id.txt)
MASTER_DNS=$(cat master_dns.txt)

echo "Cluster: ${CLUSTER_ID}"
echo "Step: ${STEP_ID}"
echo "Master: ${MASTER_DNS}"
```

### 2. Vérifier l'état actuel du job

```bash
aws emr describe-step \
    --cluster-id ${CLUSTER_ID} \
    --step-id ${STEP_ID} \
    --region eu-west-1 \
    --query 'Step.Status'
```

## 📥 Télécharger les logs

### Logs disponibles

```bash
# Lister tous les logs disponibles pour ce step
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/ \
    --region eu-west-1 \
    --human-readable
```

### Télécharger dans le dossier logs/

```bash
# Créer le dossier logs
mkdir -p logs

# Télécharger stderr (logs du driver Spark - le plus important)
aws s3 cp s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/stderr.gz \
    logs/ --region eu-west-1

# Télécharger controller (infos sur l'exécution du job)
aws s3 cp s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/controller.gz \
    logs/ --region eu-west-1

# Télécharger stdout (si disponible)
aws s3 cp s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/stdout.gz \
    logs/ --region eu-west-1 2>/dev/null || echo "Pas de stdout"

# Décompresser tous les fichiers
gunzip logs/*.gz 2>/dev/null || true
```

## 🔎 Analyser les logs

### Stderr (logs principaux du script)

```bash
# Voir tout le fichier
cat logs/stderr

# Voir les 100 dernières lignes
tail -100 logs/stderr

# Voir les 50 premières lignes
head -50 logs/stderr

# Chercher les erreurs
grep -i "error\|exception\|failed\|traceback" logs/stderr

# Chercher les étapes de votre script
grep "🍎\|📂\|✅\|❌\|📊" logs/stderr

# Chercher les infos sur les données
grep -i "fichiers\|images\|count\|training\|test" logs/stderr

# Voir les warnings
grep -i "warning\|warn" logs/stderr
```

### Controller (infos sur le job)

```bash
# Voir le fichier controller
cat logs/controller

# Voir juste le résumé
head -20 logs/controller
```

### Stdout (si disponible)

```bash
cat logs/stdout 2>/dev/null || echo "Pas de stdout disponible"
```

## 🚀 Inspection en temps réel (sans télécharger)

### Voir directement le stderr (50 dernières lignes)

```bash
aws s3 cp s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/stderr.gz - \
    --region eu-west-1 | gunzip | tail -50
```

### Voir tout le stderr

```bash
aws s3 cp s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/stderr.gz - \
    --region eu-west-1 | gunzip | less
```

### Surveiller l'ajout de nouveaux logs

```bash
# Vérifier la taille du fichier stderr (augmente pendant l'exécution)
watch -n 5 "aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/ --region eu-west-1 --human-readable"
```

## 📊 Logs du cluster (niveau supérieur)

### Logs globaux du cluster

```bash
# Lister tous les logs du cluster
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/ \
    --recursive --region eu-west-1 --human-readable

# Logs des nodes (master, core)
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/node/ \
    --recursive --region eu-west-1
```

### Logs de bootstrap

```bash
# Voir si le bootstrap s'est bien exécuté
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/node/*/bootstrap-actions/ \
    --recursive --region eu-west-1
```

## 🐛 Débogage avancé

### Connexion SSH au master node

```bash
# Connexion SSH (nécessite la clé SSH configurée)
ssh -i ~/.ssh/emr-p11-fruits-key-codespace.pem hadoop@${MASTER_DNS}

# Une fois connecté, voir les logs YARN
yarn logs -applicationId <application_id>

# Voir les logs Spark
ls -la /var/log/spark/
```

### Trouver l'Application ID Spark

```bash
# Dans les logs stderr, chercher
grep "application_" logs/stderr | head -1
```

### Logs YARN via S3

```bash
# Les logs YARN sont aussi copiés sur S3 après la fin du job
aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/containers/ \
    --recursive --region eu-west-1
```

## 📈 Métriques et monitoring

### Voir les métriques du step

```bash
aws emr describe-step \
    --cluster-id ${CLUSTER_ID} \
    --step-id ${STEP_ID} \
    --region eu-west-1 \
    --query 'Step.Status.Timeline'
```

### Voir l'historique de tous les steps

```bash
aws emr list-steps \
    --cluster-id ${CLUSTER_ID} \
    --region eu-west-1 \
    --query 'Steps[*].[Id,Name,Status.State,Status.Timeline.StartDateTime,Status.Timeline.EndDateTime]' \
    --output table
```

## ❓ Messages d'erreur courants

### "File does not exist"
- Le script Python n'a pas été trouvé sur S3
- Vérifier : `aws s3 ls s3://oc-p11-fruits-david-scanu/read_fruits_data/scripts/ --region eu-west-1`

### "Permission denied"
- Problème de rôles IAM
- Vérifier les rôles EMR dans la config

### "No space left on device"
- Disque EBS plein
- Augmenter `EBS_VOLUME_SIZE` dans `config/config.sh`

### Job bloqué longtemps
- Regarder la taille du stderr qui augmente
- Vérifier les logs YARN pour voir l'activité des executors

## 🔄 Script automatisé

### Télécharger et afficher en une commande

```bash
# Script all-in-one
./scripts/download_and_inspect_logs.sh
```

### Créer ce script

```bash
cat > scripts/download_and_inspect_logs.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

CLUSTER_ID=$(cat cluster_id.txt)
STEP_ID=$(cat step_id.txt)

echo "=================================================="
echo "📋 Téléchargement des logs"
echo "=================================================="
echo "Cluster: ${CLUSTER_ID}"
echo "Step: ${STEP_ID}"
echo ""

mkdir -p logs
aws s3 sync s3://oc-p11-fruits-david-scanu/read_fruits_data/logs/emr/${CLUSTER_ID}/steps/${STEP_ID}/ \
    logs/ --region eu-west-1

gunzip logs/*.gz 2>/dev/null || true

echo "=================================================="
echo "📊 STDERR (50 dernières lignes)"
echo "=================================================="
tail -50 logs/stderr

echo ""
echo "=================================================="
echo "❌ ERREURS DÉTECTÉES"
echo "=================================================="
grep -i "error\|exception\|failed" logs/stderr || echo "Aucune erreur trouvée"

echo ""
echo "📁 Logs sauvegardés dans: logs/"
EOF

chmod +x scripts/download_and_inspect_logs.sh
```

## 📚 Ressources

- [AWS EMR - Logs de debug](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-manage-debugging.html)
- [Spark - Configuration des logs](https://spark.apache.org/docs/latest/configuration.html#configuring-logging)
- [YARN - Application logs](https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/YarnCommands.html#logs)

## 💡 Conseils

1. **Toujours vérifier stderr en premier** - c'est là que sont les prints de votre script
2. **Chercher les emojis** de votre script pour suivre la progression
3. **Regarder les timestamps** pour identifier les étapes lentes
4. **Sauvegarder les logs** avant de terminer le cluster
5. **Comparer avec les logs locaux** si vous avez testé en local

---

**Dernière mise à jour**: 2025-11-18