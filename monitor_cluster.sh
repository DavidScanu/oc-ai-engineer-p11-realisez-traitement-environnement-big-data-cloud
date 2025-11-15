#!/bin/bash

if [ ! -f cluster_id.txt ]; then
    echo "❌ Fichier cluster_id.txt introuvable"
    echo "Veuillez d'abord créer le cluster avec ./create_cluster.sh"
    exit 1
fi

CLUSTER_ID=$(cat cluster_id.txt)

echo "🔍 Surveillance du cluster: $CLUSTER_ID"
echo "Appuyez sur Ctrl+C pour arrêter"
echo ""

while true; do
    STATE=$(aws emr describe-cluster \
        --cluster-id "$CLUSTER_ID" \
        --region eu-west-1 \
        --query 'Cluster.Status.State' \
        --output text)
    
    TIMESTAMP=$(date '+%H:%M:%S')
    
    case $STATE in
        "STARTING")
            echo "[$TIMESTAMP] 🟡 État: STARTING - Démarrage des instances EC2..."
            ;;
        "BOOTSTRAPPING")
            echo "[$TIMESTAMP] 🟡 État: BOOTSTRAPPING - Installation des dépendances Python..."
            ;;
        "RUNNING")
            echo "[$TIMESTAMP] 🟢 État: RUNNING - Configuration en cours..."
            ;;
        "WAITING")
            echo "[$TIMESTAMP] ✅ État: WAITING - Cluster prêt à l'emploi !"
            echo ""
            
            # Récupérer le DNS du Master
            MASTER_DNS=$(aws emr describe-cluster \
                --cluster-id "$CLUSTER_ID" \
                --region eu-west-1 \
                --query 'Cluster.MasterPublicDnsName' \
                --output text)
            
            echo "🎉 Cluster opérationnel !"
            echo ""
            echo "📡 Master DNS: $MASTER_DNS"
            echo ""
            echo "🔗 Accès JupyterHub (via tunnel SSH):"
            echo "   ssh -i ~/.ssh/emr-p11-fruits-key.pem -L 9443:localhost:9443 hadoop@$MASTER_DNS"
            echo "   Puis ouvrir: https://localhost:9443"
            echo ""
            echo "💾 Master DNS sauvegardé dans: master_dns.txt"
            echo "$MASTER_DNS" > master_dns.txt
            exit 0
            ;;
        "TERMINATING"|"TERMINATED")
            echo "[$TIMESTAMP] 🔴 État: $STATE - Cluster arrêté"
            exit 1
            ;;
        "TERMINATED_WITH_ERRORS")
            echo "[$TIMESTAMP] ❌ État: TERMINATED_WITH_ERRORS"
            echo ""
            echo "Vérifier les logs:"
            echo "  aws emr describe-cluster --cluster-id $CLUSTER_ID --region eu-west-1"
            exit 1
            ;;
        *)
            echo "[$TIMESTAMP] ⚪ État: $STATE"
            ;;
    esac
    
    sleep 30
done