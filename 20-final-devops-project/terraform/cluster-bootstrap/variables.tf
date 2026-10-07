variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type    = string
  default = "minikube"
}

variable "argocd_chart_version" {
  description = "argo/argo-cd chart version (10.10.0 = Argo CD v3.5.4)"
  type        = string
  default     = "10.10.0"
}

variable "app_namespace" {
  type    = string
  default = "yatri"
}
