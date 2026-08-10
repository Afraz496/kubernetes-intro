# k8s-starter

A small, self-contained Kubernetes playground you can run entirely on a Windows PC.

It packages a toy anomaly-detection script into a container, runs a real Kubernetes
cluster on your laptop, and executes the script as a **Job** across three regions in
parallel. Everything runs locally, costs nothing, and is deleted with one command.

The point isn't the model — it's the loop:

```
edit code  ->  build image  ->  load into cluster  ->  apply manifest  ->  read logs
```

Once that loop is muscle memory, a cloud cluster is the same commands with different
credentials.

---

## Prerequisites (Windows)

| Tool | Install | Why |
|---|---|---|
| **Docker Desktop** | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) | Builds and runs containers. Enable the **WSL 2 backend** during setup. |
| **kind** | `winget install Kubernetes.kind` | Runs a real Kubernetes cluster inside Docker. |
| **kubectl** | `winget install Kubernetes.kubectl` | The command-line interface to any cluster. |
| **Git** | `winget install Git.Git` | Version control. |
| **VS Code** | `winget install Microsoft.VisualStudioCode` | Editor. |

Open a **new** PowerShell window after installing (PATH changes need a fresh shell), then verify:

```powershell
docker version
kind version
kubectl version --client
```

If `docker version` errors, Docker Desktop isn't running — start it from the Start menu
and wait for the whale icon to stop animating.

> **WSL 2 note.** Docker Desktop will prompt you to install the WSL 2 kernel if it's
> missing. Accept it. Containers are Linux processes, so Windows needs a Linux kernel
> to run them — WSL 2 provides one.

---

## Quick start

Unzip the folder somewhere sensible (`C:\dev\k8s-starter` is fine — avoid OneDrive-synced
paths, Docker builds get slow there), then:

```powershell
cd C:\dev\k8s-starter
code .
```

The Git history is already initialised with one commit. To put it on GitHub:

```powershell
git remote add origin https://github.com/Afraz496/k8s-starter.git
git push -u origin main
```

Create the empty repo on GitHub first, without a README — this one already has one.

Then, in the VS Code terminal (`` Ctrl+` ``):

```powershell
.\scripts\up.ps1        # create the cluster (~40 seconds, one time)
.\scripts\run-job.ps1   # build the image, run the Job, print the logs
.\scripts\down.ps1      # delete the cluster and everything in it
```

If PowerShell blocks the scripts, allow local ones for this session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## What's in here

```
k8s-starter/
├─ app/
│  ├─ main.py              the "model" — flags anomalous daily counts for one region
│  └─ requirements.txt     Python dependencies
├─ Dockerfile              how the image is built: OS + system libs + Python + code
├─ kind-cluster.yaml       cluster shape: one control plane, two worker nodes
├─ k8s/
│  ├─ namespace.yaml       a namespace to keep this separate from anything else
│  ├─ job.yaml             run three regions in parallel, then stop
│  └─ cronjob.yaml         the same work, every night at 02:00
├─ scripts/
│  ├─ up.ps1               create the kind cluster
│  ├─ run-job.ps1          build → load → apply → logs
│  └─ down.ps1             delete the cluster
├─ .vscode/
│  ├─ extensions.json      extensions VS Code will offer to install
│  ├─ settings.json        YAML schema support, LF line endings
│  └─ tasks.json           the same commands as Ctrl+Shift+B tasks
└─ docs/walkthrough.md     a slower, explained walk through the same steps
```

---

## The five commands that matter

| Command | What it does |
|---|---|
| `docker build -t k8s-starter:dev .` | Turn the Dockerfile into an image. |
| `kind load docker-image k8s-starter:dev --name modelling-lab` | Copy the image into the cluster's nodes. **Easy to forget.** |
| `kubectl apply -f k8s/job.yaml` | Submit the work. |
| `kubectl get pods -n modelling -w` | Watch it run. `Ctrl+C` to stop watching. |
| `kubectl logs -n modelling -l job-name=anomaly-scan --tail=-1` | Read the output of every pod at once. |

Clean up a finished Job so you can re-run it:

```powershell
kubectl delete job anomaly-scan -n modelling
```

---

## Why `kind load` exists

Your cluster's nodes are Docker containers with their own image store. They cannot see
images sitting in your laptop's Docker daemon. `kind load docker-image` copies the image
across.

Forget it and the pod sits in `ErrImagePull` — Kubernetes assumes any image it can't find
locally must live in a registry, so it goes looking for `k8s-starter:dev` on Docker Hub
and fails. In a real cluster you'd push to a registry instead; `kind load` is the local
shortcut.

---

## Troubleshooting

**`ErrImagePull` / `ImagePullBackOff`**
You skipped `kind load docker-image`, or you rebuilt the image and didn't reload it.
Re-run `.\scripts\run-job.ps1`, which always does both.

**`exec /app/entrypoint.sh: no such file or directory`**
Windows line endings. Git is configured by `.gitattributes` to check shell scripts out
with LF, but if you created a new `.sh` file yourself, set the encoding to LF in the
VS Code status bar (bottom right, where it says `CRLF`).

**`kubectl` says the connection was refused**
The cluster is gone or Docker restarted. Run `.\scripts\up.ps1` again — it's idempotent.

**Job says `Completed` but there are no logs**
Pods are garbage-collected after a while. Add `--tail=-1` and run it sooner, or check
`kubectl describe job anomaly-scan -n modelling`.

**Everything is broken and I want to start over**

```powershell
.\scripts\down.ps1
.\scripts\up.ps1
```

---

## Where to go next

- Change `parallelism` in `k8s/job.yaml` from `3` to `1` and watch the regions run in sequence instead.
- Add a `resources.requests` block that asks for more CPU than your machine has, and watch the pod sit in `Pending` — that's the scheduler telling you it can't fit.
- Apply `k8s/cronjob.yaml` and change the schedule to `*/2 * * * *` to see it fire every two minutes.
- Swap `app/main.py` for something of your own. Nothing else has to change.

When you're ready for a real cluster, only the first command differs:

```powershell
gcloud container clusters create-auto modelling-lab --region=northamerica-northeast1
gcloud container clusters get-credentials modelling-lab --region=northamerica-northeast1
kubectl apply -f k8s/job.yaml
```

You'd push the image to a registry rather than `kind load` it. Everything else — the
manifests, the `kubectl` commands, the workflow — is identical.
