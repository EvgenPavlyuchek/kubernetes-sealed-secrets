## Kubernetes Cluster Deployment with Sealed Secrets, SOPS-KMS-FLUX, and GitHub Actions

This repository showcases a deployment workflow a Kubernetes cluster using the Sealed Secrets with SOPS-KMS-FLUX. The deployment process leverages Terraform to provision the infrastructure and Flux to manage the synchronization of changes in the Git repository to the production environment.

### Features:

    Sealed Secrets: The Sealed Secrets method is employed to encrypt sensitive data, ensuring secure storage and transmission of secrets within the Git repository.
    SOPS-KMS-FLUX Integration: SOPS (Secrets OPerationS) is integrated with KMS (Key Management Service) and Flux to handle encryption, key management, and secret synchronization.
    Terraform Deployment: The cluster infrastructure is deployed using Terraform, enabling consistent and reproducible deployments.
    GitHub Actions: The repository leverages GitHub Actions to automate the deployment process and manage secrets securely.
    Secret Management Options: The workflow provides two options for storing the application token secret: GitHub Secrets or GCP Secret Manager.
    Secure Encryption with SOPS: SOPS is utilized to encrypt the YAML file containing the application token secret, ensuring that it remains confidential and protected.

### Workflow Overview:

    Infrastructure Deployment: Terraform provisions the necessary resources to create the Kubernetes cluster in the desired cloud environment (GCP).
    SOPS-KMS-FLUX Integration: SOPS, KMS, and Flux are integrated to handle secret encryption, key management, and secret synchronization within the cluster.
    GitHub Actions Automation: GitHub Actions automates the deployment workflow, including the creation of the application token secret YAML file.
    Secret Encryption with SOPS: The application secret YAML file is encrypted using SOPS to protect its confidentiality.
    Git Repository Update: The encrypted secret YAML file is added to the Git repository, ensuring secure storage of sensitive information.
    Flux Deployment Sync: Flux continuously monitors the Git repository for changes and implements them in the production environment, ensuring consistent and secure deployments.
    Protected Repository: The repository maintains the security of sensitive data, as all secrets are encrypted and protected within the repository.

By utilizing Sealed Secrets, SOPS-KMS-FLUX, Terraform, and GitHub Actions, this repository provides a secure and automated approach to deploying Kubernetes clusters, managing secrets, and ensuring the confidentiality of sensitive data within a Git repository.

## Using
Run the following command to deploy the infrastructure:
```bash
terraform apply
```

Manually create the following secrets in the automatically created GitHub repository:
```bash
GOOGLE_PROJECT - GCP project name
GCP_SA_KEY     - GCP service account json key
TOKEN_SECRET   - if you want to use github secret for tocken
```

Manually create a GCP service account with the roles "Cloud KMS CryptoKey Encrypter/Decrypter" and "Secret Manager Secret Accessor".
Create a JSON key for the service account and add it to the GCP_SA_KEY secret.

In GitHub Actions, push: run the workflow.

```bash
gcloud container clusters get-credentials main --zone us-central1-c --project <GOOGLE_PROJECT>
kubectl get pod -n flux-system
kubectl -n demo get po,secrets -o wide
```

## Inputs

|       Name       |            Description           | Required |
|:----------------:|:--------------------------------:|:--------:|
| GOOGLE_PROJECT   | GCP project name                 |    yes   |
| GITHUB_OWNER     | GITHUB    OWNER                  |    yes   |
| GITHUB_TOKEN     | GITHUB TOKEN                     |    yes   |
