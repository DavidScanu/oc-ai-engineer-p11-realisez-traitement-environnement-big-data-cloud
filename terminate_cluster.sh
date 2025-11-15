#!/bin/bash

if [ ! -f cluster_id.txt ]; then
    echo "❌ Fichier cluster_id.txt introuvable"
    exit 1
fi

CLUSTER_ID=$(cat cluster_id.txt)

echo "⚠️  Vous allez terminer le cluster: $CLUSTER_ID"
read -p "Êtes-vous sûr ? (oui/non): " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "❌ Annulé"
    exit 0
fi

echo "🛑 Arrêt du cluster..."

aws emr terminate-clusters \
    --cluster-ids "$CLUSTER_ID" \
    --region eu-west-1

echo "✅ Commande d'arrêt envoyée"
echo ""
echo "🔍 Surveiller la terminaison:"
echo "   watch -n 10 'aws emr describe-cluster --cluster-id $CLUSTER_ID --region eu-west-1 --query \"Cluster.Status.State\"'"
echo ""
echo "⚠️  Vérifier les instances EC2 après 5 minutes:"
echo "   aws ec2 describe-instances --region eu-west-1 --filters \"Name=instance-state-name,Values=running,pending\" --output table"