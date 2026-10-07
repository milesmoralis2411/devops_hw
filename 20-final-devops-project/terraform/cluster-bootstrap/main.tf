# Cluster bootstrap: everything a fresh cluster needs before GitOps takes over.
#   1. namespaces with Pod Security Standards
#   2. guardrails for the app namespace (ResourceQuota + LimitRange)
#   3. Secrets (app API key, Grafana admin) - generated here, never written to Git
#   4. Argo CD, which then deploys everything else from Git

# ------------------------------------------------------------- namespaces
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/part-of"          = "yatri"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = "monitoring"
    labels = { "app.kubernetes.io/part-of" = "yatri" }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name   = "argocd"
    labels = { "app.kubernetes.io/part-of" = "yatri" }
  }
}

# ------------------------------------------------------------- guardrails
resource "kubernetes_resource_quota" "app" {
  metadata {
    name      = "yatri-quota"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"           = "4"
      "requests.memory"        = "4Gi"
      "limits.cpu"             = "8"
      "limits.memory"          = "8Gi"
      "persistentvolumeclaims" = "5"
      "pods"                   = "30"
    }
  }
}

# Containers that forget requests/limits get these defaults instead of none.
resource "kubernetes_limit_range" "app" {
  metadata {
    name      = "yatri-defaults"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
      default = {
        cpu    = "300m"
        memory = "256Mi"
      }
    }
  }
}

# ------------------------------------------------------------- app secret
resource "random_password" "api_key" {
  length  = 40
  special = false
}

resource "kubernetes_secret" "api_key" {
  metadata {
    name      = "yatri-trips-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = { "app.kubernetes.io/part-of" = "yatri" }
  }
  data = {
    API_KEY = random_password.api_key.result
  }
  type = "Opaque"
}

resource "random_password" "grafana" {
  length  = 24
  special = false
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    password = random_password.grafana.result
  }
  type = "Opaque"
}

# ---------------------------------------------------------------- Argo CD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 900
  wait       = true

  values = [yamlencode({
    configs = {
      cm = {
        # Poll Git every 30s instead of 3m so the demo converges quickly.
        "timeout.reconciliation" = "30s"
      }
      params = {
        "server.insecure" = true # TLS terminates at the ingress / port-forward in the lab
      }
    }
    dex = { enabled = false } # no SSO in the lab
  })]
}
