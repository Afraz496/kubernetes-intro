# Create the local cluster. Safe to run again - it skips if it already exists.
$ErrorActionPreference = "Stop"
$cluster = "modelling-lab"

Write-Host "Checking Docker..." -ForegroundColor Cyan
docker version --format '{{.Server.Version}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker isn't responding. Start Docker Desktop and wait for the whale icon to settle."
}

$existing = kind get clusters 2>$null
if ($existing -contains $cluster) {
    Write-Host "Cluster '$cluster' already exists." -ForegroundColor Yellow
} else {
    Write-Host "Creating cluster '$cluster' (this takes about 40 seconds)..." -ForegroundColor Cyan
    kind create cluster --config kind-cluster.yaml
}

kubectl apply -f k8s/namespace.yaml
Write-Host "`nNodes:" -ForegroundColor Green
kubectl get nodes
Write-Host "`nReady. Next: .\scripts\run-job.ps1" -ForegroundColor Green
