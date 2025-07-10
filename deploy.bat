@echo off
setlocal enabledelayedexpansion

echo [1/8] Removing existing Helm releases and resources
helm uninstall argocd -n argocd >nul 2>&1
kubectl delete applications --all -n argocd >nul 2>&1
kubectl delete deploy -n default -l arch=outer >nul 2>&1
kubectl delete deploy -n default -l arch=inner >nul 2>&1
kubectl delete svc -n default -l arch=outer >nul 2>&1
kubectl delete svc -n default -l arch=inner >nul 2>&1

echo [2/8] Adding and updating Helm repositories
helm repo add argo https://argoproj.github.io/argo-helm >nul 2>&1
helm repo update

echo [3/8] Installing Argo CD
helm upgrade --install argocd argo/argo-cd ^
  --namespace argocd ^
  --create-namespace ^
  --version 5.51.6 ^
  --set crds.install=true ^
  -f argocd/values.yaml

echo [WAIT] Waiting for Argo CD installation to stabilize (3 minutes)

echo [4/8] Installing Argo CD Image Updater
helm upgrade --install argocd-image-updater argo/argocd-image-updater ^
  --namespace argocd ^
  --create-namespace ^
  -f image-updater/values.yaml

echo [WAIT] Waiting for Image Updater installation to stabilize (2 minutes)
timeout /t 120 >nul

echo [5/8] Deploying kube-prometheus-stack (prometheus, grafana)
kubectl apply -f istio/kube-prometheus-stack.yaml -n argocd

echo [6/8] Deploying 00-core (RabbitMQ/Redis)
kubectl apply -f apps/00-core/application.yaml -n argocd

echo [WAIT] Waiting for 00-core deployment to stabilize (2 minutes)
timeout /t 120 >nul

echo [7/8] Deploying 01-config (Config Server)
kubectl apply -f apps/01-config/application.yaml -n argocd

echo [WAIT] Waiting for 01-config deployment to stabilize (2 minutes)
timeout /t 120 >nul

echo [8/8] Deploying 03-services (App of Apps)
kubectl apply -f apps/03-services/application.yaml -n argocd

echo [WAIT] Waiting for 03-services deployment to stabilize (2 minutes)

echo.
echo [🎉] Deployment complete! Check the status below.
kubectl get applications -n argocd
kubectl get pods -n default

pause
endlocal
