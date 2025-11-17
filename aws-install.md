# Installation et configuration de l'AWS CLI (v2)

Ce document décrit la procédure d'installation, de configuration et de vérification de l'AWS CLI (version 2) sur une machine Ubuntu (ex. Ubuntu 24.04). Il inclut les commandes que nous avons exécutées et des bonnes pratiques de sécurité.

## 1. Vérifier l'environnement

Vérifie l'OS et l'architecture :

```bash
lsb_release -a
uname -m
```

Si `uname -m` renvoie `x86_64` prends l'archive `x86_64`. Si `aarch64`, prends l'archive `aarch64`.

## 2. Installer les prérequis

```bash
sudo apt update
sudo apt install -y curl unzip
```

## 3. Télécharger et installer AWS CLI v2

Choisis la bonne archive selon ton architecture.

- Pour x86_64 :

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

- Pour aarch64 (ARM) :

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Alternative (snap) :

```bash
sudo snap install aws-cli --classic
```

## 4. Vérifier l'installation

```bash
aws --version
which aws
```

Si `aws --version` renvoie une erreur, vérifie que `/usr/local/bin` est dans ton `PATH` et relance un nouveau shell.

## 5. Configuration initiale (`aws configure`)

Tu peux configurer tes identifiants et la région globale avec :

```bash
aws configure
```

Il te sera demandé : `AWS Access Key ID`, `AWS Secret Access Key`, `Default region name` (ex. `eu-west-1`) et `Default output format` (ex. `json`).

Si tu as déjà renseigné ces valeurs (comme indiqué), elles sont stockées dans `~/.aws/credentials` et `~/.aws/config`.

### Créer ou utiliser un profil nommé

Pour ne pas écraser le profil `default`, crée un profil nommé :

```bash
aws configure --profile p11-fruits
```

Ensuite, pour utiliser ce profil :

```bash
AWS_PROFILE=p11-fruits aws sts get-caller-identity
# ou
aws sts get-caller-identity --profile p11-fruits
```

## 6. Vérifications post-configuration

- Vérifier quelle source fournit les credentials :

```bash
aws configure list
```

- Lister les profils disponibles :

```bash
aws configure list-profiles
```

- Vérifier l'identité AWS (doit retourner ARN/Account) :

```bash
aws sts get-caller-identity
```

Interprétation : si `Arn` contient `root`, tu utilises des credentials root (non recommandé).

- Tester l'accès S3 :

```bash
aws s3api list-buckets --query "Buckets[].Name" --output text
aws s3 ls s3://oc-p11-fruits-david-scanu || true
```

- Tester EMR (ex.) :

```bash
aws emr list-clusters --region eu-west-1
```

## 7. Dépannage et debug

- Relancer une commande avec `--debug` pour obtenir les détails bas niveau :

```bash
aws sts get-caller-identity --debug
```

- Vérifier l'heure système (les signatures AWS sont sensibles à la dérive d'horloge) :

```bash
date -u
```

- Vérifier les variables d'environnement qui pourraient surcharger la config :

```bash
echo "AWS_PROFILE=$AWS_PROFILE"
echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-<vide>}"
echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-<vide>}"
echo "AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-<vide>}"
```

## 8. Bonne pratique de sécurité

- N'utilise pas les credentials root pour des opérations régulières. Crée un utilisateur IAM avec les permissions minimales nécessaires.
- Active MFA sur le compte root et sur les utilisateurs à privilèges.
- Ne partage jamais le contenu de `~/.aws/credentials` ou des clés privées.
- Utilise des rôles IAM et des sessions temporaires (STS) quand c'est possible.

## 9. Désinstallation (si besoin)

```bash
# uninstall script fourni par aws cli v2
sudo /usr/local/aws-cli/v2/current/uninstall || true

# ou suppression manuelle (si nécessaire)
sudo rm -rf /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/aws_completer
```

## 10. Autocomplétion bash (optionnel)

Active l'autocomplétion pour `aws` :

```bash
command -v aws_completer || which aws_completer
echo "complete -C '/usr/local/bin/aws_completer' aws" >> ~/.bashrc
source ~/.bashrc
```

## 11. Note sur les identifiants déjà renseignés

Tu as indiqué dans la session que tu as renseigné `Access key ID` et `Secret access key`. Vérifie qu'elles sont bien présentes dans `~/.aws/credentials` et qu'elles appartiennent à un utilisateur IAM (et non au root). Pour vérifier rapidement :

```bash
aws sts get-caller-identity
aws iam get-user || true
```

Si `aws iam get-user` renvoie un `User` ou si `sts get-caller-identity` retourne un `Arn` contenant `user/`, alors tu utilises un utilisateur IAM. Si l'`Arn` contient `root`, reconsidère l'usage de ces clés et crée un utilisateur IAM.

---

Fichier créé : `aws-install.md` (racine du dépôt). Si tu veux, j'ajoute un petit script `scripts/aws-verify.sh` qui exécute automatiquement ces vérifications et imprime un rapport.
