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
  wait_for_completion = true
  timeouts {
    create = "2m"
    update = "2m"
  }
}

data "kubernetes_pod" "kubescape_job_pod" {
  metadata {
    name      = kubernetes_job.kubescape_security_benchmark.metadata[0].name
    namespace = kubernetes_job.kubescape_security_benchmark.metadata[0].namespace
  }
}

output "kubescape_job_pod" {
  value = data.kubernetes_pod.kubescape_job_pod.metadata[0].name
}

resource "helm_release" "microservices-chart" {

  name  = "example-app-${terraform.workspace}"
  namespace  = kubernetes_namespace.kiratech-test.metadata[0].name

  # Path to the local Helm chart
  chart = "./helm-chart-microservices"
  force_update = true  
  recreate_pods = true

  # Maximum timeout for the deployment
  timeout = "600"

  # Wait for the previous job to complete before deploying the Helm chart
  depends_on = [kubernetes_job.kubescape_security_benchmark]

}

output "microservices-chart" {
  value = helm_release.microservices-chart.metadata[0].name
}
