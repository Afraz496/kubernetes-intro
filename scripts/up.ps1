# Create the local cluster. Safe to run again - it skips if it already exists.
$ErrorActionPreference = "Stop"
$cluster = "modelling-lab"

foreach ($tool in @("docker", "kind", "kubectl")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' is not on your PATH. Install it (winget install Kubernetes.kind / Kubernetes.kubectl, or Docker Desktop) and open a NEW PowerShell window."
    }
}

Write-Host "Checking Docker..." -ForegroundColor Cyan
docker version --format '{{.Server.Version}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker isn't responding. Start Docker Desktop and wait for the whale icon to settle."
}

# 'kind get clusters' prints "No kind clusters found." to stderr when there are none.
# With ErrorActionPreference=Stop that would abort the script, so soften it here.
$existing = @()
try {
    $ErrorActionPreference = "SilentlyContinue"
    $existing = @(kind get clusters 2>&1 | ForEach-Object { "$_".Trim() } |
                  Where-Object { $_ -and $_ -notmatch "No kind clusters found" })
} finally {
    $ErrorActionPreference = "Stop"
}

if ($existing -contains $cluster) {
    Write-Host "Cluster '$cluster' already exists." -ForegroundColor Yellow
} else {
    Write-Host "Creating cluster '$cluster' (this takes about 40 seconds)..." -ForegroundColor Cyan
    kind create cluster --config kind-cluster.yaml
    if ($LASTEXITCODE -ne 0) { throw "kind failed to create the cluster." }
}

kubectl apply -f k8s/namespace.yaml
Write-Host "`nNodes:" -ForegroundColor Green
kubectl get nodes
Write-Host "`nReady. Next: .\scripts\run-job.ps1" -ForegroundColor Green
