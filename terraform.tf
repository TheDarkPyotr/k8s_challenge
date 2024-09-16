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


# Apply the ClusterRole resource
resource "kubernetes_cluster_role" "kubescape_cluster_role" {
  metadata {
    name = "kubescape-cluster-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "services", "pods", "namespaces", "configmaps", "serviceaccounts"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
    verbs      = ["list", "get"]
  }
   
}

# Apply the ClusterRoleBinding resource
resource "kubernetes_cluster_role_binding" "kubescape_cluster_role_binding" {
  metadata {
    name = "kubescape-cluster-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.kiratech-test.metadata[0].name
  }

  role_ref {
    kind     = "ClusterRole"
    name     = kubernetes_cluster_role.kubescape_cluster_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

# Apply the Kubernetes Job resource (Kubescape security benchmark)
resource "kubernetes_job" "kubescape_security_benchmark" {
  metadata {
    name      = "kubescape-security-benchmark"
    namespace = kubernetes_namespace.kiratech-test.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "kubescape"
        }
      }

      spec {
        container {
          name  = "kubescape"
          image = "bitnami/kubescape:latest"

          command = ["kubescape", "scan"]
        
        }
        restart_policy = "Never"
       
      }
    }
  }

}
