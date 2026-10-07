output "namespaces" {
  value = [
    kubernetes_namespace.app.metadata[0].name,
    kubernetes_namespace.monitoring.metadata[0].name,
    kubernetes_namespace.argocd.metadata[0].name,
  ]
}

output "api_key_secret" {
  value = "${kubernetes_secret.api_key.metadata[0].namespace}/${kubernetes_secret.api_key.metadata[0].name}"
}

output "api_key" {
  description = "Read with: terraform output -raw api_key"
  value       = random_password.api_key.result
  sensitive   = true
}

output "argocd_version" {
  value = "${helm_release.argocd.chart} ${helm_release.argocd.version} (app ${helm_release.argocd.metadata[0].app_version})"
}

output "argocd_admin_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "grafana_admin_password" {
  description = "Read with: terraform output -raw grafana_admin_password"
  value       = random_password.grafana.result
  sensitive   = true
}
