# Build the image, load it into the cluster, run the Job, print the logs.
$ErrorActionPreference = "Stop"
$cluster = "modelling-lab"
$image   = "k8s-starter:dev"

Write-Host "[1/4] Building $image..." -ForegroundColor Cyan
# --provenance=false keeps Docker Desktop's containerd store from adding attestation
# manifests, which 'kind load docker-image' sometimes refuses to read.
docker build --provenance=false -t $image .
if ($LASTEXITCODE -ne 0) { throw "docker build failed." }

Write-Host "[2/4] Loading the image into the cluster..." -ForegroundColor Cyan
# Cluster nodes have their own image store and cannot see your local Docker daemon.
kind load docker-image $image --name $cluster
if ($LASTEXITCODE -ne 0) {
    Write-Host "Direct load failed - falling back to a tar archive..." -ForegroundColor Yellow
    docker save $image -o k8s-starter.tar
    kind load image-archive k8s-starter.tar --name $cluster
    Remove-Item k8s-starter.tar -ErrorAction SilentlyContinue
}

Write-Host "[3/4] Submitting the Job..." -ForegroundColor Cyan
kubectl delete job anomaly-scan -n modelling --ignore-not-found
kubectl apply -f k8s/job.yaml
kubectl wait --for=condition=complete job/anomaly-scan -n modelling --timeout=180s

Write-Host "[4/4] Logs from all three pods:" -ForegroundColor Green
kubectl logs -n modelling -l job-name=anomaly-scan --tail=-1 --prefix
