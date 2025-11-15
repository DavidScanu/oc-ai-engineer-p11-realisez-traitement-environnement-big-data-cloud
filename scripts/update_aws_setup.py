#!/usr/bin/env python3
"""
Script pour mettre à jour aws_setup.sh afin d'utiliser le fichier de configuration centralisé.
Remplace toutes les références aux anciens fichiers cachés par des appels à load_config/save_config.
"""

import re

# Lire le script actuel
with open("scripts/aws_setup.sh", "r") as f:
    content = f.read()

# Définir les remplacements
replacements = [
    # Remplacer les vérifications de fichiers
    (r'if \[ ! -f \.bucket_name \]; then',
     r'migrate_old_config\n    BUCKET_NAME=$(load_config "BUCKET_NAME")\n    if [ -z "$BUCKET_NAME" ]; then'),

    (r'if \[ ! -f \.cluster_id \]; then',
     r'migrate_old_config\n    CLUSTER_ID=$(load_config "CLUSTER_ID")\n    if [ -z "$CLUSTER_ID" ]; then'),

    (r'if \[ ! -f \.key_name \]; then',
     r'migrate_old_config\n    KEY_NAME=$(load_config "KEY_NAME")\n    if [ -z "$KEY_NAME" ]; then'),

    # Remplacer les lectures de fichiers
    (r'BUCKET_NAME=\$\(cat \.bucket_name\)',
     r'BUCKET_NAME=$(load_config "BUCKET_NAME")'),

    (r'CLUSTER_ID=\$\(cat \.cluster_id\)',
     r'CLUSTER_ID=$(load_config "CLUSTER_ID")'),

    (r'KEY_NAME=\$\(cat \.key_name\)',
     r'KEY_NAME=$(load_config "KEY_NAME")'),

    (r'MASTER_DNS=\$\(cat \.master_dns\)',
     r'MASTER_DNS=$(load_config "MASTER_DNS")'),

    # Remplacer les écritures de fichiers
    (r'echo \$\{CLUSTER_ID\} > \.cluster_id',
     r'save_config "CLUSTER_ID" "${CLUSTER_ID}"'),

    (r'echo \$\{KEY_NAME\} > \.key_name',
     r'save_config "KEY_NAME" "${KEY_NAME}"'),

    (r'echo \$\{MASTER_DNS\} > \.master_dns',
     r'save_config "MASTER_DNS" "${MASTER_DNS}"'),
]

# Appliquer les remplacements
for pattern, replacement in replacements:
    content = re.sub(pattern, replacement, content)

# Écrire le résultat
with open("scripts/aws_setup.sh", "w") as f:
    f.write(content)

print("✅ Script mis à jour avec succès!")
print("   Toutes les références aux anciens fichiers ont été remplacées.")