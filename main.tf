terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 5.9.1"
    }
  }
}

provider "github" {
  token = var.GITHUB_TOKEN
}

module "github_repository" {
  source                   = "github.com/den-vasyliev/tf-github-repository"
  github_owner             = var.GITHUB_OWNER
  github_token             = var.GITHUB_TOKEN
  repository_name          = var.FLUX_GITHUB_REPO
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux"
}

module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
}

module "gke_cluster" {
  source         = "github.com/den-vasyliev/tf-google-gke-cluster?ref=gke_auth"
  GOOGLE_REGION  = var.GOOGLE_REGION
  GOOGLE_PROJECT = var.GOOGLE_PROJECT
  GKE_NUM_NODES  = var.GKE_NUM_NODES
}

module "flux_bootstrap" {
  source            = "github.com/den-vasyliev/tf-fluxcd-flux-bootstrap?ref=gke_auth"
  github_repository = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  private_key       = module.tls_private_key.private_key_pem
  config_host       = module.gke_cluster.config_host
  config_token      = module.gke_cluster.config_token
  config_ca         = module.gke_cluster.config_ca
  github_token      = var.GITHUB_TOKEN
}

############################## Encrypter #####################################

module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  name                = "kustomize-controller"
  namespace           = var.FLUX_GITHUB_REPO
  project_id          = var.GOOGLE_PROJECT
  cluster_name        = "main"
  location            = var.GOOGLE_REGION
  annotate_k8s_sa     = true
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
}

module "kms" {
  source          = "github.com/den-vasyliev/terraform-google-kms"
  project_id      = var.GOOGLE_PROJECT
  keyring         = "sops-flux"
  location        = "global"
  keys            = ["sops-key-flux"]
  prevent_destroy = false
}

########################### add yaml Encrypter ###############################

resource "github_repository_file" "sops-patch" {
  # depends_on          = [module.flux_bootstrap]
  repository          = var.FLUX_GITHUB_REPO
  branch              = "main"
  file                = "${var.FLUX_GITHUB_TARGET_PATH}/${var.FLUX_GITHUB_REPO}/sops-patch.yaml"
  content             = <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${var.FLUX_GITHUB_REPO}
  namespace: ${var.FLUX_GITHUB_REPO}
spec:
  interval: 10m0s
  path: ./clusters
  prune: true
  sourceRef:
    kind: GitRepository
    name: ${var.FLUX_GITHUB_REPO}
  decryption:
    provider: sops
EOF
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "sa-patch" {
  # depends_on          = [module.flux_bootstrap]
  repository          = var.FLUX_GITHUB_REPO
  branch              = "main"
  file                = "${var.FLUX_GITHUB_TARGET_PATH}/${var.FLUX_GITHUB_REPO}/sa-patch.yaml"
  content             = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kustomize-controller
  namespace: ${var.FLUX_GITHUB_REPO}
  annotations:
    iam.gke.io/gcp-service-account: kustomize-controller@${var.GOOGLE_PROJECT}.iam.gserviceaccount.com
EOF
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "kustomization" {
  # depends_on          = [module.flux_bootstrap]
  repository          = var.FLUX_GITHUB_REPO
  branch              = "main"
  file                = "${var.FLUX_GITHUB_TARGET_PATH}/${var.FLUX_GITHUB_REPO}/kustomization.yaml"
  content             = <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
patches:
- path: sops-patch.yaml
  target:
    kind: Kustomization
- path: sa-patch.yaml
  target:
    kind: ServiceAccount
    name: kustomize-controller
EOF
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

############################## add yaml app ##################################

resource "github_repository_file" "ns" {
  # depends_on          = [module.flux_bootstrap]
  repository          = var.FLUX_GITHUB_REPO
  branch              = "main"
  file                = "${var.FLUX_GITHUB_TARGET_PATH}/${var.APP_GITHUB_FOLDER}/ns.yaml"
  content             = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.APP_GITHUB_FOLDER}
EOF
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "tbot-gr" {
  # depends_on          = [module.flux_bootstrap]
  repository          = var.FLUX_GITHUB_REPO
  branch              = "main"
  file                = "${var.FLUX_GITHUB_TARGET_PATH}/${var.APP_GITHUB_FOLDER}/tbot-gr.yaml"
  content             = <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: tbot
  namespace: ${var.APP_GITHUB_FOLDER}
spec:
  interval: 1m0s
  ref:
    # branch: main
    branch: develop
  url: https://github.com/EvgenPavlyuchek/tbot
EOF
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "tbot-hr" {
  # depends_on = [module.flux_bootstrap]
  repository = var.FLUX_GITHUB_REPO
  branch     = "main"
  file       = "${var.FLUX_GITHUB_TARGET_PATH}/${var.APP_GITHUB_FOLDER}/tbot-hr.yaml"
  content    = <<EOF
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: tbot
  namespace: ${var.APP_GITHUB_FOLDER}
spec:
  chart:
    spec:
      chart: ./helm
      reconcileStrategy: Revision
      # reconcileStrategy: ChartVersion
      sourceRef:
        kind: GitRepository
        name: tbot
  interval: 1m0s
EOF
  # values:
  #   secret:
  #     secretValue: ${var.TELE_TOKEN}
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}