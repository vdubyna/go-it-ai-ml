resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  atomic          = true
  cleanup_on_fail = true
  recreate_pods   = true
  timeout         = 600
  wait            = true

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]
}

resource "helm_release" "argocd_bootstrap" {
  name       = "argocd-bootstrap"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  atomic          = true
  cleanup_on_fail = true
  timeout         = 300
  wait            = true

  values = [
    yamlencode({
      applications = {
        goit-argo-root = {
          namespace = var.argocd_namespace
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
          project = "default"
          source = {
            repoURL        = var.app_repo_url
            targetRevision = var.app_repo_branch
            path           = var.app_repo_path
            directory = {
              recurse = true
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.argocd_namespace
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
          }
          revisionHistoryLimit = 2
        }
      }
    })
  ]

  depends_on = [
    helm_release.argocd
  ]
}
