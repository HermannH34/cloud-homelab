# k3s Cluster sur AWS avec Terraform

Ce projet déploie automatiquement un cluster k3s sur AWS en utilisant Terraform. Le cluster est configuré avec une instance t3.micro dans la région Europe (eu-west-1).

## 🏗️ Architecture

- **Région AWS** : Europe (eu-west-1 - Irlande)
- **Instance** : t3.micro (éligible au free tier)
- **OS** : Ubuntu 22.04 LTS
- **Réseau** : VPC dédié avec sous-réseau public
- **k3s** : Version v1.28.5+k3s1

## 📋 Prérequis

1. **AWS CLI** configuré avec vos credentials
2. **Terraform** >= 1.0 installé
3. **Compte AWS** avec les permissions nécessaires

### Configuration AWS CLI

```bash
aws configure
# Entrez vos AWS Access Key ID, Secret Access Key, et région (eu-west-1)
```

## 🚀 Déploiement

### 1. Cloner et naviguer vers le dossier terraform

```bash
cd terraform
```

### 2. Initialiser Terraform

```bash
terraform init
```

### 3. Planifier le déploiement

```bash
terraform plan
```

### 4. Appliquer la configuration

```bash
terraform apply
```

Tapez `yes` pour confirmer le déploiement.

## 📊 Informations post-déploiement

Après le déploiement, Terraform affichera les informations importantes :

- **IP publique** du master node
- **Commande SSH** pour se connecter
- **URL de l'API Kubernetes**
- **URL de test** de l'application nginx

### Exemple de sortie :

```
cluster_endpoint = "https://54.123.45.67:6443"
master_public_ip = "54.123.45.67"
ssh_connection_command = "ssh -i k3s-keypair.pem ubuntu@54.123.45.67"
test_application_url = "http://54.123.45.67:30080"
```

## 🔧 Utilisation

### Se connecter au cluster

```bash
# SSH vers le master node
ssh -i k3s-keypair.pem ubuntu@<IP_PUBLIQUE>

# Vérifier le statut du cluster
./cluster-info.sh
```

### Télécharger le kubeconfig

```bash
# Depuis votre machine locale
scp -i k3s-keypair.pem ubuntu@<IP_PUBLIQUE>:/home/ubuntu/.kube/config ./kubeconfig

# Utiliser le kubeconfig
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

### Tester l'application

Ouvrez votre navigateur et allez à : `http://<IP_PUBLIQUE>:30080`

## 🛠️ Gestion du cluster

### Déployer une application

```bash
# Exemple : déployer une application simple
kubectl create deployment hello-world --image=nginx
kubectl expose deployment hello-world --port=80 --type=NodePort
```

### Installer Helm charts

```bash
# Helm est déjà installé sur le cluster
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

## 🔒 Sécurité

### Recommandations pour la production :

1. **Restreindre l'accès SSH** : Modifier `allowed_cidr_blocks` dans `terraform.tfvars`
2. **Utiliser un Load Balancer** : Pour la haute disponibilité
3. **Chiffrement** : Les volumes EBS sont déjà chiffrés
4. **Monitoring** : Ajouter CloudWatch ou Prometheus

### Exemple de restriction d'accès :

```hcl
# Dans terraform.tfvars
allowed_cidr_blocks = ["VOTRE_IP/32"]  # Remplacer par votre IP
```

## 📁 Structure des fichiers

```
terraform/
├── main.tf              # Configuration principale
├── versions.tf          # Versions des providers
├── variables.tf         # Variables d'entrée
├── terraform.tfvars     # Valeurs des variables
├── vpc.tf              # Configuration réseau
├── security-groups.tf  # Groupes de sécurité
├── instances.tf        # Instances EC2
├── outputs.tf          # Sorties du déploiement
├── user-data.sh       # Script d'initialisation k3s
└── k3s-keypair.pem    # Clé SSH privée (générée)
```

## 🧹 Nettoyage

Pour supprimer toutes les ressources créées :

```bash
terraform destroy
```

Tapez `yes` pour confirmer la suppression.

## 🐛 Dépannage

### Problèmes courants :

1. **Erreur de credentials AWS** :
   ```bash
   aws configure list
   ```

2. **Instance non accessible** :
   - Vérifier les Security Groups
   - Vérifier que l'IP publique est assignée

3. **k3s non démarré** :
   ```bash
   # Se connecter en SSH et vérifier
   sudo systemctl status k3s
   sudo journalctl -u k3s
   ```

4. **Logs d'installation** :
   ```bash
   # Vérifier les logs d'installation
   cat /var/log/k3s-install.log
   cat /var/log/cloud-init-output.log
   ```

## 💰 Coûts

Avec une instance t3.micro dans le free tier AWS :
- **Instance** : Gratuite (750h/mois pendant 12 mois)
- **Stockage EBS** : ~2€/mois pour 20GB
- **Transfert de données** : Gratuit (1GB/mois sortant)

## 📚 Ressources utiles

- [Documentation k3s](https://docs.k3s.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Contribution

N'hésitez pas à ouvrir des issues ou proposer des améliorations !

## 📄 Licence

Ce projet est sous licence MIT. 