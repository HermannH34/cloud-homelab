# K3s Cluster on AWS

Ce projet Terraform déploie un cluster K3s complet sur AWS EC2 avec tous les security groups nécessaires.

## Ports configurés

### Accès externe (depuis votre IP)
- **22** : SSH
- **6443** : Kubernetes API Server
- **80** : HTTP (Ingress)
- **443** : HTTPS (Ingress)
- **30000-32767** : NodePort services

### Communication interne (self)
- **6444** : K3s server (pour les agents)
- **8472** : Flannel VXLAN (UDP)
- **10248** : Kubelet health
- **10250** : Kubelet API
- **10251-10252** : Metrics server
- **10256** : Kube-proxy health
- **2379-2380** : etcd client (si etcd externe)

## Outils pré-installés

- **K3s** : Kubernetes léger
- **kubectl** : Client Kubernetes
- **Helm** : Gestionnaire de packages
- **Flux CLI** : GitOps toolkit

## Déploiement

1. **Configurer les variables** :
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Éditer terraform.tfvars avec votre IP publique
   ```

2. **Déployer l'infrastructure** :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Récupérer la kubeconfig** :
   ```bash
   # Utiliser la commande affichée dans les outputs
   scp -i k3s-homelab-key.pem ubuntu@<IP>:/home/ubuntu/kubeconfig ./k3s-homelab-kubeconfig.yaml
   ```

4. **Configurer kubectl local** :
   ```bash
   # Modifier l'IP dans le fichier kubeconfig
   sed -i 's/127.0.0.1/<IP_PUBLIQUE>/g' k3s-homelab-kubeconfig.yaml
   
   # Utiliser la kubeconfig
   export KUBECONFIG=$PWD/k3s-homelab-kubeconfig.yaml
   kubectl get nodes
   ```

## Sécurité

### Recommandations
- Changez `allowed_cidr` pour votre IP publique : `"203.0.113.1/32"`
- Utilisez des clés SSH robustes (4096 bits RSA)
- Surveillez les logs d'accès

### Obtenir votre IP publique
```bash
curl ifconfig.me
```

## FluxCD

Si vous avez déjà une configuration FluxCD dans Git :

```bash
# Appliquer votre config FluxCD existante
kubectl apply -f votre-repo/clusters/flux-system/

# Ou bootstrap FluxCD
flux bootstrap github \
  --owner=votre-username \
  --repository=votre-repo \
  --branch=main \
  --path=./clusters/aws
```

## Monitoring

```bash
# Vérifier l'état du cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Logs K3s
ssh -i k3s-homelab-key.pem ubuntu@<IP>
sudo journalctl -u k3s -f
```

## Nettoyage

```bash
terraform destroy
``` 