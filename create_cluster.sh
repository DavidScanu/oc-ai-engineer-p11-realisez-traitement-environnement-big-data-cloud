#!/bin/bash
set -e  # Arrêter en cas d'erreur

echo "🚀 Création du cluster EMR p11-fruits-cluster..."
echo "📍 Région: eu-west-1"
echo "💰 Configuration: 1 Master + 2 Core (m5.xlarge)"
echo ""

CLUSTER_ID=$(aws emr create-cluster \
 --name "p11-fruits-cluster" \
 --log-uri "s3://oc-p11-fruits-david-scanu/logs/emr/" \
 --release-label "emr-7.11.0" \
 --service-role "arn:aws:iam::461506913677:role/EMR_DefaultRole" \
 --unhealthy-node-replacement \
 --ec2-attributes '{
   "InstanceProfile":"EMR_EC2_DefaultRole",
   "EmrManagedMasterSecurityGroup":"sg-0ee431c02c5bc7fc4",
   "EmrManagedSlaveSecurityGroup":"sg-03b5c1607e57d5935",
   "KeyName":"emr-p11-fruits-key-codespace",
   "SubnetIds":["subnet-037413c77aa8d5ebb"]
 }' \
 --applications Name=JupyterHub Name=Hadoop Name=Hive Name=JupyterEnterpriseGateway Name=Livy Name=Spark Name=TensorFlow \
 --configurations '[
   {
     "Classification":"jupyter-s3-conf",
     "Properties":{
       "s3.persistence.bucket":"oc-p11-fruits-david-scanu",
       "s3.persistence.enabled":"true"
     }
   },
   {
     "Classification":"spark-defaults",
     "Properties":{
       "spark.executor.memory":"4g",
       "spark.driver.memory":"4g",
       "spark.sql.execution.arrow.pyspark.enabled":"true",
       "spark.executor.memoryOverhead":"1g"
     }
   }
 ]' \
 --instance-groups '[
   {
     "InstanceCount":2,
     "InstanceGroupType":"CORE",
     "Name":"Core",
     "InstanceType":"m5.xlarge",
     "EbsConfiguration":{
       "EbsBlockDeviceConfigs":[{
         "VolumeSpecification":{
           "VolumeType":"gp3",
           "SizeInGB":32
         },
         "VolumesPerInstance":1
       }]
     }
   },
   {
     "InstanceCount":1,
     "InstanceGroupType":"MASTER",
     "Name":"Primary",
     "InstanceType":"m5.xlarge",
     "EbsConfiguration":{
       "EbsBlockDeviceConfigs":[{
         "VolumeSpecification":{
           "VolumeType":"gp3",
           "SizeInGB":32
         },
         "VolumesPerInstance":1
       }]
     }
   }
 ]' \
 --bootstrap-actions '[{
   "Name":"InstallPythonDeps",
   "Path":"s3://oc-p11-fruits-david-scanu/scripts/install_dependencies.sh"
 }]' \
 --auto-scaling-role "arn:aws:iam::461506913677:role/EMR_AutoScaling_DefaultRole" \
 --scale-down-behavior "TERMINATE_AT_TASK_COMPLETION" \
 --auto-termination-policy '{"IdleTimeout":14400}' \
 --region "eu-west-1" \
 --output text \
 --query 'ClusterId')

echo ""
echo "✅ Cluster créé avec succès !"
echo "📋 Cluster ID: $CLUSTER_ID"
echo ""
echo "🔍 Pour surveiller l'état:"
echo "   aws emr describe-cluster --cluster-id $CLUSTER_ID --region eu-west-1 --query 'Cluster.Status.State'"
echo ""
echo "🌐 Console AWS:"
echo "   https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/$CLUSTER_ID"
echo ""
echo "⏰ Attendre ~15 minutes que l'état passe à 'WAITING'"
echo ""

# Sauvegarder le Cluster ID dans un fichier
echo "$CLUSTER_ID" > cluster_id.txt
echo "💾 Cluster ID sauvegardé dans: cluster_id.txt"


# Attendre que le cluster soit en état WAITING
while true; do
  STATE=$(aws emr describe-cluster --cluster-id "$CLUSTER_ID" --region eu-west-1 --query 'Cluster.Status.State' --output text)
  echo "État actuel du cluster: $STATE"
  if [ "$STATE" = "WAITING" ]; then
    break
  elif [[ "$STATE" = "TERMINATING" || "$STATE" = "TERMINATED" || "$STATE" = "TERMINATED_WITH_ERRORS" ]]; then
    echo "Le cluster s'est arrêté prématurément."
    exit 1
  fi
  sleep 30
done

# Ajouter le step EMR pour appliquer la config JupyterHub
aws emr add-steps \
  --cluster-id "$CLUSTER_ID" \
  --steps Type=CUSTOM_JAR,Name="SetJupyterEnv",ActionOnFailure=CONTINUE,Jar=command-runner.jar,Args=["bash","-c","aws s3 cp s3://oc-p11-fruits-david-scanu/scripts/set_jupyter_env.sh . && chmod +x set_jupyter_env.sh && sudo ./set_jupyter_env.sh"] \
  --region eu-west-1