#!/bin/bash

set -e

echo "🚀 K3s Homelab avec Flux - Script de déploiement automatisé"
echo "============================================================"
echo ""

# Vérifications préalables
echo "🔍 Vérification des prérequis..."

# Vérifier Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform n'est pas installé. Installez-le depuis https://terraform.io"
    exit 1
fi

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI n'est pas installé. Installez-le depuis https://aws.amazon.com/cli/"
    exit 1
fi

# Vérifier la configuration AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI n'est pas configuré. Exécutez 'aws configure'"
    exit 1
fi

echo "✅ Prérequis validés"
echo ""

# GitHub token check
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  GITHUB_TOKEN n'est pas défini."
    echo "   Pour le bootstrap Flux automatique, définissez votre token :"
    echo "   export GITHUB_TOKEN=your_github_token_here"
    echo ""
    read -p "Continuer sans token GitHub ? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Déploiement annulé. Définissez GITHUB_TOKEN et relancez."
        exit 1
    fi
    BOOTSTRAP_FLUX=false
else
    echo "✅ GITHUB_TOKEN détecté"
    BOOTSTRAP_FLUX=true
fi

echo ""
echo "📋 Configuration du déploiement :"
echo "   - Région AWS: eu-west-3"
echo "   - Instance: t3.small"
echo "   - K3s avec Flux"
echo "   - Bootstrap Flux: $BOOTSTRAP_FLUX"
echo ""

read -p "Démarrer le déploiement ? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Déploiement annulé."
    exit 0
fi

echo ""
echo "🔧 Initialisation de Terraform..."
terraform init

echo ""
echo "📋 Planification du déploiement..."
terraform plan

echo ""
echo "🚀 Déploiement en cours..."
terraform apply -auto-approve

echo ""
echo "📊 Récupération des informations du cluster..."
INSTANCE_IP=$(terraform output -raw instance_ip)
SSH_COMMAND=$(terraform output -raw ssh_command)

echo ""
echo "✅ Déploiement terminé !"
echo ""
echo "📋 Informations du cluster :"
echo "   IP publique: $INSTANCE_IP"
echo "   Commande SSH: $SSH_COMMAND"
echo ""

echo "⏳ Attente que le cluster soit prêt (peut prendre 2-3 minutes)..."
sleep 120

echo ""
echo "🔍 Vérification du statut du cluster..."
terraform output cluster_info_command
eval $(terraform output -raw cluster_info_command)

echo ""
if [ "$BOOTSTRAP_FLUX" = true ]; then
    echo "🔄 Bootstrap de Flux en cours..."
    ssh -o StrictHostKeyChecking=no -i k3s-key.pem ubuntu@$INSTANCE_IP "
        export GITHUB_TOKEN=$GITHUB_TOKEN
        ./bootstrap-flux.sh
    "
    
    echo ""
    echo "⏳ Surveillance du déploiement Flux (60 secondes)..."
    ssh -o StrictHostKeyChecking=no -i k3s-key.pem ubuntu@$INSTANCE_IP "
        timeout 60 watch -n 5 kubectl get pods -A
    " || true
else
    echo "⚠️  Bootstrap Flux manuel requis :"
    echo "   1. SSH: $SSH_COMMAND"
    echo "   2. Définir le token: export GITHUB_TOKEN=your_token"
    echo "   3. Exécuter: ./bootstrap-flux.sh"
fi

echo ""
echo "🎉 Homelab K3s avec Flux déployé avec succès !"
echo ""
echo "🔗 Commandes utiles :"
echo "   - SSH vers le cluster: $SSH_COMMAND"
echo "   - Infos cluster: $(terraform output -raw cluster_info_command)"
echo "   - Bootstrap Flux: $(terraform output -raw flux_bootstrap_command)"
echo "   - Surveillance pods: $SSH_COMMAND './watch-pods.sh'"
echo ""
echo "🔑 Clé Age publique pour SOPS:"
terraform output age_public_key_command
eval $(terraform output -raw age_public_key_command)
echo ""
echo "💡 Prochaines étapes :"
echo "   1. Créer le repository GitHub 'kubernetes-homelab'"
echo "   2. Ajouter la clé Age publique à votre configuration SOPS"
echo "   3. Committer vos manifests Kubernetes dans le repo"
echo "   4. Flux va automatiquement déployer vos applications"
echo ""
echo "🧹 Pour supprimer l'infrastructure: terraform destroy" 