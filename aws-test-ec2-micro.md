# Test EC2 t3.micro — création, test SSH, terminaison

Ce document décrit une procédure pas-à-pas pour :
- créer une instance EC2 `t3.micro` (test),
- vérifier la connexion SSH depuis un Codespace/local,
- terminer l'instance et nettoyer les règles temporaires,
- lister toutes les instances et ressources restantes pour éviter des frais.

Toutes les commandes sont données pour la région `eu-west-1`. Adapte `--region` si besoin.

## 1) Pré-requis
- AWS CLI configurée (`aws configure`) avec des identifiants disposant des droits EC2/IAM/SSM.
- `ssh` et `ssh-keygen` disponibles localement.
- (Optionnel) `jq` si tu veux parser JSON facilement.

## 2) Génération / import d'une paire SSH (si tu n'en as pas)
```bash
mkdir -p ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/emr-p11-fruits-key-codespace -C "emr-p11-fruits-key-codespace" -N ""
chmod 600 ~/.ssh/emr-p11-fruits-key-codespace
chmod 644 ~/.ssh/emr-p11-fruits-key-codespace.pub

# Importer la clé publique dans EC2 (région eu-west-1)
aws ec2 import-key-pair \
  --key-name emr-p11-fruits-key-codespace \
  --public-key-material fileb://~/.ssh/emr-p11-fruits-key-codespace.pub \
  --region eu-west-1
```

Si tu préfères, tu peux créer la key-pair depuis la console AWS et télécharger le `.pem`.

## 3) Choisir un AMI rapide (Amazon Linux 2 recommandé)
```bash
ami=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
  --region eu-west-1 --query 'Parameters[0].Value' --output text)
echo "AMI choisi: $ami"
```

## 4) Lancer une instance `t3.micro` (test)
- Exemple : lance une instance dans `subnet-037413c77aa8d5ebb` (adapte si nécessaire).
```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$ami" \
  --count 1 \
  --instance-type t3.micro \
  --key-name emr-p11-fruits-key-codespace \
  --subnet-id subnet-037413c77aa8d5ebb \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ssh-test}]' \
  --region eu-west-1 \
  --query 'Instances[0].InstanceId' --output text)

echo "Instance lancée: $INSTANCE_ID"

# Attendre que l'instance soit en 'running'
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region eu-west-1

# Récupérer IP / DNS
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region eu-west-1 \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PublicDnsName,State.Name]' --output text
```

## 5) Autoriser SSH depuis ton IP (temporaire)
- Récupère ton IP publique :
```bash
MYIP=$(curl -s https://checkip.amazonaws.com)
echo "Mon IP: $MYIP"
```
- Récupère le ou les groupes de sécurité attachés à l'instance :
```bash
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region eu-west-1 \
  --query 'Reservations[0].Instances[0].SecurityGroups' --output json
```
- Pour autoriser l'accès SSH sur le SG ciblé (remplace `sg-xxxx` par l'ID réel) :
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-XXXXXXX \
  --protocol tcp --port 22 --cidr ${MYIP}/32 \
  --region eu-west-1
```
- Après usage, révoque la règle :
```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-XXXXXXX \
  --protocol tcp --port 22 --cidr ${MYIP}/32 \
  --region eu-west-1
```

> Remarque : si l'instance utilise le `default` SG, tu peux préférer modifier ce SG ou attacher un SG dédié.

## 6) Se connecter en SSH (test)
- Préparer la clé localement :
```bash
chmod 600 ~/.ssh/emr-p11-fruits-key-codespace
eval "$(ssh-agent -s)" || true
ssh-add ~/.ssh/emr-p11-fruits-key-codespace || true
```
- Utiliser l'utilisateur adapté selon l'AMI :
  - Amazon Linux 2 → `ec2-user`
  - Ubuntu → `ubuntu`
  - EMR master → `hadoop`

Exemples :
```bash
ssh -i ~/.ssh/emr-p11-fruits-key-codespace ec2-user@<PUBLIC_DNS_OR_IP>
# ou
ssh -i ~/.ssh/emr-p11-fruits-key-codespace hadoop@<MASTER_PUBLIC_DNS>
```
- Pour debug SSH :
```bash
ssh -vvv -i ~/.ssh/emr-p11-fruits-key-codespace ec2-user@<HOST>
```

## 7) Ouvrir un tunnel pour accéder à JupyterHub (si nécessaire)
```bash
ssh -i ~/.ssh/emr-p11-fruits-key-codespace -L 9443:localhost:9443 hadoop@<MASTER_PUBLIC_DNS>
# puis ouvre https://localhost:9443 dans ton navigateur
```

## 8) Inspecter / réparer l'authentification sans SSH (SSM)
- Attacher la policy SSM au rôle EC2 (si nécessaire) :
```bash
aws iam attach-role-policy \
  --role-name EMR_EC2_DefaultRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
  --region eu-west-1
```
- Démarrer une session SSM sur l'instance :
```bash
aws ssm start-session --target $INSTANCE_ID --region eu-west-1
```
- Dans la session SSM, vérifier les fichiers `authorized_keys` et `cloud-init` :
```bash
sudo cat /home/ec2-user/.ssh/authorized_keys || true
sudo tail -n 200 /var/log/cloud-init-output.log
```

## Exemple concret (valeurs trouvées dans cette session)

Pendant la session nous avons utilisé et vérifié les valeurs suivantes (région `eu-west-1`) :

- **AMI** : `ami-056546f8452ba93b4`
- **Subnet** : `subnet-037413c77aa8d5ebb`
- **KeyName** : `emr-p11-fruits-key-codespace`
- **Security Group (attaché à l'instance)** : `sg-092506f11dd68e61f` (groupe `default`)
- **Security Group (autre SG du projet)** : `sg-0ee431c02c5bc7fc4` (utilisé pour les masters EMR)
- **Règle SSH ajoutée (temporaire)** : `CidrIpv4 = 172.166.156.99/32` (SecurityGroupRuleId = `sgr-079c20575ab481523`)
- **Instance test lancée** : `i-0169304e14ac5000b` (tag `Name=ssh-test`)
- **IP publique (instance test)** : `52.213.177.228`

Exemples de commandes prêtes à l'emploi avec ces valeurs :

```bash
# Lancer (exemple réutilisant l'AMI et le subnet trouvés)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-056546f8452ba93b4 \
  --count 1 --instance-type t3.micro \
  --key-name emr-p11-fruits-key-codespace \
  --subnet-id subnet-037413c77aa8d5ebb \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ssh-test}]' \
  --region eu-west-1 --query 'Instances[0].InstanceId' --output text)

# Autoriser SSH temporaire sur le SG attaché à l'instance (si nécessaire)
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id sg-092506f11dd68e61f --protocol tcp --port 22 --cidr ${MYIP}/32 --region eu-west-1

# Vérifier IP / DNS
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region eu-west-1 \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PublicDnsName,State.Name]' --output text

# SSH (Amazon Linux 2)
ssh -i ~/.ssh/emr-p11-fruits-key-codespace ec2-user@52.213.177.228

# Une fois le test fini : terminer l'instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region eu-west-1
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region eu-west-1

# Révoquer la règle SSH temporaire si elle est encore présente
aws ec2 revoke-security-group-ingress \
  --group-id sg-092506f11dd68e61f --protocol tcp --port 22 --cidr ${MYIP}/32 --region eu-west-1
```

> Remarque : la commande `revoke-security-group-ingress` ci‑dessus révoque la règle par CIDR. Si vous préférez révoquer par `SecurityGroupRuleId` il faut utiliser des API plus avancées ou la console ; revocation par CIDR est simple et reproductible.


## 9) Terminer l'instance et nettoyer
- Terminer l'instance :
```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region eu-west-1
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region eu-west-1
```
- Révoquer la règle SSH ajoutée (si pas déjà fait) :
```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-XXXXXXX \
  --protocol tcp --port 22 --cidr ${MYIP}/32 \
  --region eu-west-1
```

## 10) Lister toutes les instances (vérifier qu'il ne reste rien en `running`)
- Lister toutes les instances `running` :
```bash
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]' --output table
```
- Lister toutes les instances (tous états) :
```bash
aws ec2 describe-instances --region eu-west-1 \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime,Tags[?Key==`Name`]|[0].Value]' --output table
```

## 11) Autres ressources à vérifier pour éviter les frais
- Elastic IPs :
```bash
aws ec2 describe-addresses --region eu-west-1 --query 'Addresses[].[PublicIp,AllocationId,InstanceId]' --output table
```
- Volumes EBS non attachés (peuvent coûter) :
```bash
aws ec2 describe-volumes --region eu-west-1 --filters Name=status,Values=available --query 'Volumes[].[VolumeId,Size,AvailabilityZone,State]' --output table
```
- Snapshots volumineux :
```bash
aws ec2 describe-snapshots --owner-ids self --region eu-west-1 --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]' --output table
```
- AMIs privées :
```bash
aws ec2 describe-images --owners self --region eu-west-1 --query 'Images[].[ImageId,Name,State,CreationDate]' --output table
```

## 12) Astuces & bonnes pratiques
- Toujours terminer (ou arrêter) les instances test immédiatement après usage.
- Révoquer les règles Security Group temporaires.
- Supprimer les Elastic IPs non utilisées.
- Nettoyer les volumes EBS non attachés et snapshots inutiles.
- Pour tester régulièrement, créer une AMI préconfigurée pour éviter des installations lors du `user-data`.

---

Fichier créé par l'assistant pour documenter une procédure de test EC2 t3.micro.
