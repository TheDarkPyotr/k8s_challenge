provider "kubernetes" {
  config_context_cluster = "kubernetes"
  config_path = "./playbooks/output/admin.conf"
}

provider "helm" {
  kubernetes {
  config_path = "./playbooks/output/admin.conf"
  }
}


resource "kubernetes_namespace" "kiratech-test" {
  metadata {
    name      = "kiratech-test"
  }
}
