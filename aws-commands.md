
# Commandes AWS utiles pour EMR et IAM

Toutes les commandes AWS CLI documentées ici sont à exécuter dans un terminal où l’AWS CLI est installée et configurée avec des identifiants ayant les droits nécessaires (IAM user avec permissions EMR, S3, IAM selon les besoins).

---

## Upload du dataset vers S3

Pour transférer ton dataset local vers le bucket S3 (exemple : `oc-p11-fruits-david-scanu`), tu peux utiliser la commande suivante :

```bash
aws s3 cp --recursive ./data/raw/fruits-360_dataset/fruits-360/Training/ \
	s3://oc-p11-fruits-david-scanu/data/raw/Training/
```

Cette commande copie tout le dossier `Training` (et son contenu) dans le bucket S3, en conservant l’arborescence.

Pour vérifier l’upload :

```bash
aws s3 ls s3://oc-p11-fruits-david-scanu/data/raw/Training/Apple\ Braeburn/
```

**Remarque** : Les espaces dans les noms de dossiers/fichiers doivent être échappés avec un antislash (`\`) ou entourés de guillemets.

---

## Autorisations nécessaires pour EMR_EC2_DefaultRole (Résumé)

Le rôle `EMR_EC2_DefaultRole` doit avoir les autorisations suivantes pour un fonctionnement optimal du cluster EMR :

- **Accès S3** : lecture/écriture sur les buckets utilisés (logs, scripts, données, persistance Jupyter).
- **Policy gérée AmazonElasticMapReduceforEC2Role** : donne accès à EC2, CloudWatch, S3 (certains usages), DynamoDB, KMS, etc. (déjà attachée par défaut).
- **CloudWatch Logs** : pour écrire les logs Spark/Hadoop/Jupyter (inclus dans la policy gérée).
- **KMS** : si tu utilises des buckets S3 chiffrés avec KMS.
- **DynamoDB** : si tu utilises EMRFS consistent view.
- **Glue** : si tu utilises le Data Catalog Glue comme metastore Hive/Spark.
- **Autres (optionnel)** : `CloudWatchAgentServerPolicy` (monitoring avancé), `AmazonSSMManagedInstanceCore` (accès SSM/Session Manager).

Pour la majorité des cas EMR Spark/Hadoop/Jupyter, la policy gérée + accès S3 spécifique suffisent.


### Donner l'accès S3 à EMR_EC2_DefaultRole pour Jupyter sur EMR

Pour permettre à EMR de sauvegarder les notebooks Jupyter sur votre bucket S3 (ex : `oc-p11-fruits-david-scanu`), il faut accorder les droits nécessaires au rôle IAM `EMR_EC2_DefaultRole`.

#### 1. Vérifier les policies du rôle

```bash
aws iam list-attached-role-policies --role-name EMR_EC2_DefaultRole
aws iam list-role-policies --role-name EMR_EC2_DefaultRole
```

#### 2. Ajouter ou mettre à jour la policy d'accès S3

```bash
aws iam put-role-policy \
	--role-name EMR_EC2_DefaultRole \
	--policy-name EMR-S3-Access \
	--policy-document '{
		"Version": "2012-10-17",
		"Statement": [
			{
				"Effect": "Allow",
				"Action": [
					"s3:GetObject",
					"s3:PutObject",
					"s3:ListBucket"
				],
				"Resource": [
					"arn:aws:s3:::oc-p11-fruits-david-scanu",
					"arn:aws:s3:::oc-p11-fruits-david-scanu/*"
				]
			}
		]
	}'
```

#### 3. Vérifier la policy ajoutée

```bash
aws iam get-role-policy --role-name EMR_EC2_DefaultRole --policy-name EMR-S3-Access
```

Après cette étape, le cluster EMR pourra lire et écrire dans le bucket S3 pour la persistance des notebooks Jupyter.

---

## Script de création de cluster EMR avec AWS CLI

Ce fichier documente les commandes pour exécuter `create_cluster.sh`, capturer le ClusterId EMR, et les vérifications recommandées avant l'exécution.   


### Avant de lancer / vérifications (recommandé)

- Vérifie ta configuration AWS CLI et tes identifiants :

```bash
aws sts get-caller-identity
```

Vérifie qu'aucun cluster n'est encore actif :

```bash
aws emr list-clusters --active --region eu-west-1
```

Si un cluster tourne encore, termine-le immédiatement :

```bash
aws emr terminate-clusters --cluster-ids j-XXXXXXXXXXXXX --region eu-west-1
```

- Vérifie la syntaxe du script sans l'exécuter :

```bash
bash -n create_cluster.sh
```

- Confirme que les ARNs, groupes de sécurité, paire de clés et sous-réseau utilisés dans le script appartiennent à ton compte/région. Le script fait référence à des ARNs IAM, des IDs de groupes de sécurité, une paire de clés et un sous-réseau — si l'un d'eux est incorrect, la création du cluster échouera ou créera des ressources dans un autre compte.

```bash
aws iam get-role --role-name EMR_DefaultRole
aws iam get-role --role-name EMR_EC2_DefaultRole
aws ec2 describe-key-pairs --key-names emr-p11-fruits-key
```

#### Vérifier les groupes de sécurité et sous-réseaux utilisés dans le script de création de cluster

Avant de lancer `create_cluster.sh`, assure-toi que les IDs référencés existent bien dans ton compte et ta région AWS, et qu'ils appartiennent au bon VPC.

**1. Vérifier les groupes de sécurité (Security Groups)**

Dans le script, les groupes utilisés sont par exemple :
	- `EmrManagedMasterSecurityGroup` : `sg-0ee431c02c5bc7fc4`
	- `EmrManagedSlaveSecurityGroup` : `sg-03b5c1607e57d5935`

Pour vérifier leur existence et leur VPC :

```bash
aws ec2 describe-security-groups --group-ids sg-0ee431c02c5bc7fc4 sg-03b5c1607e57d5935 --region eu-west-1 --query 'SecurityGroups[*].[GroupId,GroupName,Description,VpcId]' --output table
```

Vérifie que le VpcId correspond à celui de ton sous-réseau et que la région est correcte.

**2. Vérifier le sous-réseau (Subnet)**

Dans le script, le sous-réseau utilisé est par exemple :
	- `SubnetIds` : `subnet-037413c77aa8d5ebb`

Pour vérifier son existence, sa zone de disponibilité et son VPC :

```bash
aws ec2 describe-subnets --subnet-ids subnet-037413c77aa8d5ebb --region eu-west-1 --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`]|[0].Value,VpcId]' --output table
```

Vérifie que le VpcId est le même que celui des groupes de sécurité, et que la zone de disponibilité te convient.

**3. Lister tous les groupes de sécurité ou sous-réseaux disponibles (pour choisir)**

```bash
# Groupes de sécurité
aws ec2 describe-security-groups --region eu-west-1 --query 'SecurityGroups[*].[GroupId,GroupName,Description,VpcId]' --output table

# Sous-réseaux
aws ec2 describe-subnets --region eu-west-1 --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`]|[0].Value,VpcId]' --output table
```

**Astuce** : Si tu as un doute sur le VPC utilisé, tu peux aussi lister les VPCs :

```bash
aws ec2 describe-vpcs --region eu-west-1 --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`]|[0].Value,CidrBlock]' --output table
```

Cela t'assure que tous les IDs utilisés dans `create_cluster.sh` sont valides et cohérents.

- Sois conscient que cela va créer des instances EC2 et peut engendrer des coûts. Vérifie les types d'instances, tailles EBS et paramètres d'Auto-termination/IdleTimeout dans le script.

- Si tu souhaites une invite de confirmation avant de créer des ressources, enveloppe la commande dans une petite invite `read` ou ajoute un wrapper dry-run.

### Upload des scripts de bootstrap (si besoin)

Avant de lancer le script de création du cluster, assure-toi que les scripts de bootstrap (ex : `install_dependencies.sh`, `set_jupyter_env.sh`) sont uploadés dans le bucket S3 référencé dans le script.

Rendre les scripts exécutables (si ce n'est pas déjà fait) :

```bash
chmod +x install_dependencies.sh
chmod +x set_jupyter_env.sh
```

Upload les scripts dans le bucket S3 :

```bash
aws s3 cp install_dependencies.sh s3://oc-p11-fruits-david-scanu/scripts/install_dependencies.sh
aws s3 cp set_jupyter_env.sh s3://oc-p11-fruits-david-scanu/scripts/set_jupyter_env.sh
``` 

Vérifie qu'ils sont bien présents :

```bash
aws s3 ls s3://oc-p11-fruits-david-scanu/scripts/
```

### Procédure pour configurer une clé SSH

Générer la paire SSH locale (Linux / Codespace) :

```bash
mkdir -p ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/emr-p11-fruits-key-codespace -C "emr-p11-fruits-key-codespace" -N ""
```

Résultat :
-- clé privée : `~/.ssh/emr-p11-fruits-key-codespace` (garde-la secrète)
-- clé publique : `~/.ssh/emr-p11-fruits-key-codespace.pub`

```bash
# 
chmod 600 ~/.ssh/emr-p11-fruits-key-codespace
chmod 644 ~/.ssh/emr-p11-fruits-key-codespace.pub

# 
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/emr-p11-fruits-key-codespace
```

Importer la clé publique en tant que key-pair nommée `emr-p11-fruits-key-codespace` (région `eu-west-1` dans ton dépôt) :

```bash
aws ec2 import-key-pair \
  --key-name emr-p11-fruits-key-codespace \
  --public-key-material fileb://~/.ssh/emr-p11-fruits-key-codespace.pub \
  --region eu-west-1
```

Vérifier que la key-pair existe dans la région :

```bash
aws ec2 describe-key-pairs --region eu-west-1
aws ec2 describe-key-pairs --key-names emr-p11-fruits-key --region eu-west-1
aws ec2 describe-key-pairs --key-names emr-p11-fruits-key-codespace --region eu-west-1
```

Comparer l'empreinte AWS (base64 SHA256) avec ta clé publique locale :

```bash
# Empreinte AWS (copie la valeur KeyFingerprint depuis describe-key-pairs)
aws ec2 describe-key-pairs --key-names emr-p11-fruits-key-codespace --region eu-west-1 --query 'KeyPairs[0].KeyFingerprint' --output text

# Empreinte locale (format compatible) :
ssh-keygen -lf ~/.ssh/emr-p11-fruits-key-codespace.pub | awk '{print $2}' | sed 's/^SHA256://'
```

#### Mettre à jour `create_cluster.sh` pour utiliser cette clé

Après avoir importé la clé publique avec le nom `emr-p11-fruits-key-codespace`, il faut s'assurer que le script de création de cluster (`create_cluster.sh`) utilise ce même `KeyName`. Dans `create_cluster.sh` tu trouveras la section `--ec2-attributes` contenant la paire :

	```bash
	"KeyName":"emr-p11-fruits-key",
	```

Vérifier la valeur actuelle de KeyName dans `create_cluster.sh` :

```bash
grep -n '"KeyName"' create_cluster.sh || sed -n '1,200p' create_cluster.sh
```

Pour remplacer automatiquement le nom dans le script, exécute (depuis la racine du dépôt) :

```bash
sed -i 's/"KeyName":"emr-p11-fruits-key"/"KeyName":"emr-p11-fruits-key-codespace"/' create_cluster.sh
```

Vérifie ensuite que la modification est bien appliquée :

```bash
grep -n "KeyName" create_cluster.sh || sed -n '1,200p' create_cluster.sh
```
```

### Exécution rapide

Rendre le script exécutable (si ce n'est pas déjà fait) :

```bash
chmod +x create_cluster.sh
``` 

Exécute depuis la racine du dépôt (où se trouve `create_cluster.sh`) :

```bash
./create_cluster.sh
```
Ou explicitement avec bash :

```bash
bash create_cluster.sh
```

La commande `aws emr create-cluster` affiche du JSON avec le nouvel id de cluster (par exemple : `{"ClusterId":"j-XXXXXXXXXXXXX"}`).

### Capturer le ClusterId (optionnel)

Si tu souhaites capturer le ClusterId dans une variable shell pour une utilisation ultérieure, tu peux utiliser l'une des méthodes suivantes.

- Utilisation de `jq` (recommandé) :

```bash
CLUSTER_ID=$(./create_cluster.sh | jq -r '.ClusterId')
echo "Cluster créé : $CLUSTER_ID"
```

### Comment vérifier le statut du cluster après la création

- Liste les clusters récents :

```bash
aws emr list-clusters --cluster-states STARTING RUNNING WAITING BOOTSTRAPPING --region eu-west-1
``` 

- Exporte le ClusterId dans une variable d'environnement : 

```bash
export CLUSTER_ID=$(cat cluster_id.txt)
```

- Décris le cluster (remplace par l'id réel) :

```bash
aws emr describe-cluster --cluster-id $CLUSTER_ID --region eu-west-1
```

- Pour vérifier les applications installées sur le cluster EMR :

```bash
aws emr describe-cluster --cluster-id $(cat cluster_id.txt) --region eu-west-1 --query 'Cluster.Applications'
```

### Aides optionnelles

- Exécute le script et capture la sortie de création dans un fichier pour inspection :

```bash
./create_cluster.sh > create_cluster_output.txt
``` 

### Exemple de sortie

```txt
🚀 Création du cluster EMR p11-fruits-cluster...
📍 Région: eu-west-1
💰 Configuration: 1 Master + 2 Core (m5.xlarge)


✅ Cluster créé avec succès !
📋 Cluster ID: j-2VLI6NTZXUAY2

🔍 Pour surveiller l'état:
   aws emr describe-cluster --cluster-id j-2VLI6NTZXUAY2 --region eu-west-1 --query 'Cluster.Status.State'

🌐 Console AWS:
   https://eu-west-1.console.aws.amazon.com/emr/home?region=eu-west-1#/clusters/j-2VLI6NTZXUAY2

⏰ Attendre ~15 minutes que l'état passe à 'WAITING'

💾 Cluster ID sauvegardé dans: cluster_id.txt
```

### Surveiller l'état du cluster EMR (`monitor_cluster.sh`)

Ce script permet de suivre en temps réel l'évolution de l'état du cluster EMR.

**Utilisation :**

```bash
./monitor_cluster.sh
```

- Il lit l'ID du cluster dans `cluster_id.txt` (généré par `create_cluster.sh`).
- Il affiche l'état du cluster (STARTING, BOOTSTRAPPING, RUNNING, WAITING, etc.) toutes les 30 secondes.
- Quand le cluster est prêt (`WAITING`), il affiche le DNS du master, propose la commande SSH pour accéder à JupyterHub, et sauvegarde le DNS dans `master_dns.txt`.
- En cas d'arrêt ou d'erreur, il affiche un message explicite.

### Terminer le cluster EMR (`terminate_cluster.sh`)

Ce script permet d'arrêter proprement le cluster EMR pour éviter des coûts inutiles.

**Utilisation :**

```bash
./terminate_cluster.sh
```

- Il lit l'ID du cluster dans `cluster_id.txt`.
- Il demande une confirmation avant d'envoyer la commande d'arrêt.
- Il affiche la commande pour surveiller la terminaison du cluster et pour vérifier les instances EC2 restantes.

**Bonnes pratiques :** Toujours terminer le cluster quand il n'est plus utilisé pour éviter des frais AWS.

---

## Étapes suivantes après la création du cluster EMR

Après la création du cluster EMR et une fois qu'il est en état `WAITING`, voici les étapes pour accéder à JupyterHub, configurer la persistance S3, et commencer à travailler avec Spark.

### Optionnel : Ajouter l’étape (step) pour configurer JupyterHub (si pas fait en bootstrap)

Dans `create_cluster.sh`, nous ajoutons l’étape pour exécuter le script `set_jupyter_env.sh` depuis S3, qui configure les variables d’environnement nécessaires dans JupyterHub.

Ce script corrigé (qui supprime proprement l’ancien bloc, réécrit la config, et relance le conteneur Docker JupyterHub), tu es conforme aux bonnes pratiques pour EMR + JupyterHub + S3.

Si nous uploadons ce script sur S3 et l’utilisons dans ton step EMR, la configuration sera proprement appliquée à chaque création de cluster. Nous ne devrions plus rencontrer de problème de lancement de serveur JupyterHub lié à la persistance S3 ou à la variable S3_ENDPOINT_URL.

```bash
aws emr add-steps \
  --cluster-id $(cat cluster_id.txt) \
  --steps Type=CUSTOM_JAR,Name="SetJupyterEnv",ActionOnFailure=CONTINUE,Jar=command-runner.jar,Args=["bash","s3://oc-p11-fruits-david-scanu/scripts/set_jupyter_env.sh"] \
  --region eu-west-1
```

### Accéder à JupyterHub

- Récupérer ton IP publique et ajouter la règle (exécuter après la création du cluster) : 

```bash
# Ajouter la règle
MYIP=$(curl -s https://checkip.amazonaws.com)
echo "Ton IP publique: $MYIP"
aws ec2 authorize-security-group-ingress \
  --group-id sg-0ee431c02c5bc7fc4 \
  --protocol tcp --port 22 --cidr ${MYIP}/32 \
  --region eu-west-1

# Vérifier la règle ajoutée (liste des règles ingress) : 
aws ec2 describe-security-groups --group-ids sg-0ee431c02c5bc7fc4 --region eu-west-1 --query 'SecurityGroups[0].IpPermissions' --output json

aws ec2 describe-security-groups \
  --group-ids sg-0ee431c02c5bc7fc4 \
  --region eu-west-1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22` && ToPort==`22`]' \
  --output json

# Après usage, révoquer la règle (supprimer l’entrée spécifique) :
aws ec2 revoke-security-group-ingress \
  --group-id sg-0ee431c02c5bc7fc4 \
  --protocol tcp --port 22 --cidr ${MYIP}/32 \
  --region eu-west-1
```

- Récupérer le DNS du master EMR :

```bash
# Récupérer le DNS master (si cluster créé)
aws emr describe-cluster \
  --cluster-id $(cat cluster_id.txt) \
  --region eu-west-1 \
  --query 'Cluster.MasterPublicDnsName' \
  --output text > master_dns.txt
```

- Ouvre un tunnel SSH vers le master :

Se connecter depuis le codespace : 

```bash
# Pour ouvrir le tunnel JupyterHub :
ssh -i ~/.ssh/emr-p11-fruits-key-codespace -L 9443:localhost:9443 hadoop@$(cat master_dns.txt)

# Se connecter (depuis ce Codespace si la clé privée y est) :
ssh -i ~/.ssh/emr-p11-fruits-key-codespace hadoop@$(cat master_dns.txt)
```

Se connecter depuis mon environnement local :

```bash
ssh -i ~/.ssh/emr-p11-fruits-key.pem -L 9443:localhost:9443 hadoop@$(cat master_dns.txt)
```

### Modifier la configuration de JupyterHub pour S3 et Spark (si besoin)

Vérifier que la variable d’environnement est bien prise en compte dans le conteneur JupyterHub :

```bash
sudo cat /etc/jupyter/conf/jupyterhub_config.py
```

Voici la commande unique, propre et corrigée à utiliser juste après ta connexion SSH pour écraser proprement la configuration d’environnement JupyterHub :

```bash
sudo cp /etc/jupyter/conf/jupyterhub_config.py /etc/jupyter/conf/jupyterhub_config.py.bak.$(date -u +"%Y%m%dT%H%M%SZ")
ls -l /etc/jupyter/conf/jupyterhub_config.py*
```

```bash
# Upload du fichier dans la machine EMR (depuis votre machine locale / Codespace)
scp -i ~/.ssh/emr-p11-fruits-key-codespace /workspaces/oc-ai-engineer-p11-realisez-traitement-environnement-big-data-cloud/jupyterhub_config_working.py hadoop@$(cat master_dns.txt):/tmp/

# ensuite, sur l'EMR (ou via ssh -i ... hadoop@$(cat master_dns.txt) '...'):
sudo mv /tmp/jupyterhub_config_working.py /etc/jupyter/conf/jupyterhub_config.py
sudo chown root:root /etc/jupyter/conf/jupyterhub_config.py
sudo chmod 644 /etc/jupyter/conf/jupyterhub_config.py

# Vérifier que le fichier de configuration a bien été uploadé
sudo cat /etc/jupyter/conf/jupyterhub_config.py
```

Redémarrer le conteneur Docker : 

```bash
# Redémarrage du conteneur
sudo docker restart jupyterhub
# Vérification de l'état du conteneur
sudo docker ps --filter "name=jupyterhub" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
# Vérifier que le port 9443 est bien écouté :
sudo ss -ltnp | grep 9443 || sudo netstat -ltnp | grep 9443
# Vérifier les logs en cas de problème de spawn
sudo docker logs jupyterhub
# ou 
sudo docker logs -f jupyterhub
```

### Uploader le notebook de travail dans S3 pour la persistance 

- Avant de commencer à travailler, upload le notebook `notebooks/p11-david-scanu-EMR-production.ipynb` dans ton bucket S3 pour t'assurer que la persistance fonctionne correctement :

```bash
aws s3 cp notebooks/p11-david-scanu-EMR-production.ipynb s3://oc-p11-fruits-david-scanu/jupyter/jovyan/p11-david-scanu-EMR-production.ipynb --acl bucket-owner-full-control
```
- Puis vérifie qu’il apparaît dans le bucket S3 :

```bash
aws s3 ls s3://oc-p11-fruits-david-scanu/jupyter/jovyan/
``` 

En alternative, crée un notebook directement depuis JupyterHub et vérifie qu’il est bien sauvegardé dans S3.

- Si besoin, importe `notebooks/p11-david-scanu-EMR-production.ipynb` via le bouton "Upload" de JupyterHub (https://localhost:9443).
- Sinon, crée un nouveau notebook en choisissant le kernel PySpark et travaille directement dedans ; vérifie ensuite que le fichier apparaît dans ton bucket S3.

### Connexion à JupyterHub

- Dans ton navigateur, ouvre : https://localhost:9443
- **Identifiants JupyterHub par défaut** :
	- Username : `jovyan`
	- Password : `jupyter`
- Ces identifiants sont ceux utilisés par défaut dans de nombreux déploiements JupyterHub Docker (notamment sur EMR), pour simplifier l'accès initial. Pour un usage sécurisé, il est recommandé de les modifier ou de configurer une authentification plus robuste.

### 4. Charger et explorer les données

- Sélectionner le kernel **PySpark** fourni par EMR (et non un kernel Python classique).
- Ouvre ce notebook pour exécuter le pipeline et lire les données depuis S3.

#### **Ajustements et vérifications pratiques**

- Crée toujours un notebook avec le kernel **PySpark** EMR pour bénéficier de Spark et Java préconfigurés.
- Utilise le préfixe `s3a://` pour tous les accès S3 avec Spark.
- Vérifie la disponibilité de la SparkSession et la version de Spark :
  ```python
  print("SparkSession disponible :", 'spark' in globals())
  print("Version Spark :", spark.version)
  ```

#### Pour lire les données depuis S3 :

##### Avec pandas (pour des petits fichiers CSV ou images) :

```python
import pandas as pd
df = pd.read_csv('s3://oc-p11-fruits-david-scanu/data/raw/Training/Apple Braeburn/0_100.jpg')
```

##### Avec PySpark :

- Pour tester la lecture d'une image en binaire avec Spark :
```python
# Pour tester la lecture d'une image en binaire avec Spark
df = spark.read.format("binaryFile").load("s3a://oc-p11-fruits-david-scanu/data/raw/Training/Apple Braeburn/0_100.jpg")
df.show()
```
- Pour charger un grand nombre de fichiers ou traiter en distribué, ou lire des images :
```python
# Utilise bien le préfixe s3a://
df = spark.read.format('csv').load('s3a://oc-p11-fruits-david-scanu/data/raw/Training/*')
# Pour lire des images ou lister les fichiers :
s3_path = "s3a://oc-p11-fruits-david-scanu/data/raw/Training/*/*"
df = spark.read.format("binaryFile").load(s3_path)
df.select("path").show(5, truncate=False)
```
- Pour lister des fichiers sur S3 (et vérifier l'accès S3 via Spark), utilise :
```python
s3_path = "s3a://oc-p11-fruits-david-scanu/data/raw/Training/*/*"
df = spark.read.format("binaryFile").load(s3_path)
df.select("path").show(5, truncate=False)
```

Si tu vois des chemins S3 s'afficher, l'accès S3 via Spark est validé. Les notebooks et résultats sauvegardés seront automatiquement stockés dans S3 sous `s3://oc-p11-fruits-david-scanu/jupyter/jovyan/`.

### 5. **Lancer tes traitements Spark ou analyses**
	- Exécute tes scripts ou notebooks de traitement, d’analyse ou de machine learning.

### 6. **Sauvegarder les résultats**
	- Écris les résultats (CSV, modèles, etc.) dans un dossier dédié sur S3.

### 7. **Arrêter le cluster quand tu as terminé**
	- Pour éviter des coûts inutiles :
	  ```bash
	  ./terminate_cluster.sh
	  ```

**Bonnes pratiques** : Sauvegarde régulièrement tes notebooks, surveille l’utilisation des ressources, et arrête toujours le cluster après usage.

---

## Débogage de la persistance S3 et de JupyterHub sur EMR

Si le serveur JupyterHub démarre mais que la création d'un notebook échoue (erreur lors du spawn du serveur utilisateur), il s'agit souvent d'un problème de configuration de l'accès S3 ou du point d'accès (endpoint) S3.

### Symptômes typiques
- Impossible de créer ou sauvegarder un notebook (erreur 500 ou message d'échec dans JupyterHub)
- Logs JupyterHub/Docker mentionnant des erreurs d'accès S3 ou d'endpoint

### Étapes de diagnostic et de résolution

1. **Vérifier les logs JupyterHub**

  - Se connecter en SSH sur le master du cluster EMR (environnement local):
    ```bash
    ssh -i ~/.ssh/emr-p11-fruits-key.pem hadoop@$(cat master_dns.txt)
    ```
  - Se connecter en SSH sur le master du cluster EMR (environnement codespace):
    ```bash
    ssh -i ~/.ssh/emr-p11-fruits-key-codespace hadoop@$(cat master_dns.txt)
    ```
  - Consulter les logs :
    ```bash
    sudo cat /var/log/jupyter/jupyter.log | tail -n 100
    ```

2. **Vérifier la configuration du point d'accès S3**

	 - Le fichier de configuration se trouve généralement ici :
    ```bash
    sudo cat /etc/jupyter/conf/jupyterhub_config.py
    ```
	 - Vérifier la ligne suivante :
    ```python
    c.Spawner.environment['S3_ENDPOINT_URL'] = 'https://s3.eu-west-1.amazonaws.com'
    ```
	 - L'endpoint doit correspondre à la région de votre bucket S3 (ex : `eu-west-1`).

3. **Modifier la configuration si besoin**
	 - Pour corriger l'endpoint, utiliser la commande suivante :
    ```bash
    sudo sed -i "s|s3_endpoint_url = os.environ.get('S3_ENDPOINT_URL', .*|s3_endpoint_url = os.environ.get('S3_ENDPOINT_URL', 's3.eu-west-1.amazonaws.com')|" /etc/jupyter/conf/jupyterhub_config.py
    ```

4. **Activer le mode debug pour JupyterHub**
	 - Ajouter ou modifier la ligne suivante dans le même fichier :
		 ```python
		 sudo sed -i "s|^c.JupyterHub.log_level *=.*|c.JupyterHub.log_level = 'DEBUG'|" /etc/jupyter/conf/jupyterhub_config.py
		 ```

5. **Redémarrer le conteneur JupyterHub**
	 - Trouver le nom du conteneur (ex : `jupyterhub` ou similaire) :
		 ```bash
		 sudo docker ps
		 ```
	 - Redémarrer le conteneur :
		 ```bash
		 sudo docker restart jupyterhub
		 ```
	 - Vérifier qu'il est bien relancé :
		 ```bash
		 sudo docker ps
		 ```

6. **Réessayer la connexion à JupyterHub**
	 - Ouvre à nouveau le tunnel SSH et connecte-toi à https://localhost:9443
	 - Tente de créer un notebook et vérifie la persistance S3

### Bonnes pratiques
- Toujours vérifier que l'endpoint S3 correspond à la région du bucket
- Activer le mode debug pour obtenir plus d'informations dans les logs
- Après modification de la configuration, toujours redémarrer le conteneur JupyterHub