#!/bin/bash
sudo sed -i "/^c.Spawner.environment/d" /etc/jupyter/conf/jupyterhub_config.py
echo "c.Spawner.environment = {
    'SPARKMAGIC_CONF_DIR': '/etc/jupyter/conf',
    'JUPYTER_ENABLE_LAB': 'yes',
    'S3_ENDPOINT_URL': 'https://s3.eu-west-1.amazonaws.com',
    'AWS_REGION': 'eu-west-1',
    'AWS_DEFAULT_REGION': 'eu-west-1'
}" | sudo tee -a /etc/jupyter/conf/jupyterhub_config.py