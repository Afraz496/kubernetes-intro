# Delete the cluster. Nothing is left behind except the images in Docker.
$ErrorActionPreference = "Stop"
kind delete cluster --name modelling-lab
Write-Host "Cluster deleted. 'docker image prune' if you want the disk space back too." -ForegroundColor Green
