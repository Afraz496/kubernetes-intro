# Walkthrough

The README gets you running in three commands. This walks the same ground slowly,
explaining what each piece is for. Roughly 30 minutes if you type it out yourself.

---

## 0. Set up VS Code

Open the folder with `code .`. VS Code will notice `.vscode/extensions.json` and offer
to install the recommended extensions — accept.

What each one buys you:

- **Docker** — right-click a `Dockerfile` to build it; a panel listing your images and containers.
- **Kubernetes** — a tree view of the cluster. Click a pod, get its logs. Genuinely the fastest way to see what's happening.
- **YAML** — schema validation for the manifests. Misspell `parallelism` and it underlines it before you apply it, which is worth the install on its own.
- **Python** — linting and the debugger for `app/main.py`.
- **WSL** — lets you open a terminal inside the Linux environment Docker uses.
- **PowerShell** — proper highlighting for the scripts in `scripts/`.

Open the terminal with `` Ctrl+` ``. On Windows it defaults to PowerShell, which is what
the scripts expect.

---

## 1. Run the code without any of this

Before containers, confirm the script itself works:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r app/requirements.txt
python app/main.py --region fraser
```

You should see a threshold and a count of flagged days. This is the baseline — everything
that follows produces the same output, just from somewhere else.

Deactivate with `deactivate`.

---

## 2. Build the image

```powershell
docker build -t k8s-starter:dev .
```

Watch the output. Each `RUN`, `COPY` and `FROM` in the `Dockerfile` becomes a **layer**,
and Docker caches each one. Edit `app/main.py` and rebuild — only the last two layers
rerun, because the dependency layers above them didn't change. That ordering is
deliberate and it's the single most useful Dockerfile habit.

Run it:

```powershell
docker run --rm k8s-starter:dev --region island
```

Same output as step 1, but the OS, the Python version, the compiler and the packages all
came from the image. Nothing on your machine was used except the kernel.

Prove the isolation:

```powershell
docker run --rm -it --entrypoint bash k8s-starter:dev
cat /etc/os-release   # Debian, on your Windows PC
whoami                # runner, not root
exit
```

---

## 3. Create the cluster

```powershell
kind create cluster --config kind-cluster.yaml
kubectl get nodes
```

Three nodes appear: one control plane and two workers. They are Docker containers —
`docker ps` will show them. That's the trick kind plays: a real Kubernetes cluster whose
"machines" are containers on your laptop.

`kubectl` found the cluster because kind wrote credentials into `%USERPROFILE%\.kube\config`.
That file is the only difference between talking to this cluster and talking to one in
Google Cloud.

Create the namespace:

```powershell
kubectl apply -f k8s/namespace.yaml
```

---

## 4. Get the image into the cluster

```powershell
kind load docker-image k8s-starter:dev --name modelling-lab
```

The nodes have their own image store and cannot reach your laptop's Docker daemon. Skip
this and the pods fail with `ErrImagePull`, because Kubernetes assumes an image it can't
find locally lives in a registry and goes looking for it on Docker Hub.

In a real cluster you'd `docker push` to a registry instead. `kind load` is the local
shortcut.

---

## 5. Run the Job

```powershell
kubectl apply -f k8s/job.yaml
kubectl get pods -n modelling -w
```

Three pods start at once — `parallelism: 3`. Each gets a different
`JOB_COMPLETION_INDEX`, which `main.py` maps to a region. That's `completionMode: Indexed`
doing the work: one manifest, three regions, no loop.

`Ctrl+C` stops watching. Then read everything:

```powershell
kubectl logs -n modelling -l job-name=anomaly-scan --tail=-1 --prefix
```

`--prefix` labels each line with its pod, which matters when three of them interleave.

---

## 6. Look at what the scheduler did

```powershell
kubectl get pods -n modelling -o wide
```

The `NODE` column shows which worker each pod landed on. Nothing told Kubernetes where to
put them — it read `resources.requests` (250m CPU, 256Mi memory) and found room. That is
the entire value proposition in one column of output.

To see the other side of it, edit `k8s/job.yaml` and ask for more than your machine has:

```yaml
requests:
  cpu: "16"
```

Re-apply and the pods sit in `Pending`. `kubectl describe pod <name> -n modelling` will
tell you why, at the bottom under Events. Put it back to `250m` afterwards.

---

## 7. Schedule it

```powershell
kubectl apply -f k8s/cronjob.yaml
kubectl get cronjobs -n modelling
```

Change the schedule to `*/2 * * * *` and re-apply if you want to see it fire without
waiting until 02:00. Each run creates a new Job, and `successfulJobsHistoryLimit: 3` keeps
the last three around so you can read their logs.

---

## 8. Clean up

```powershell
kubectl delete namespace modelling   # everything this repo created
kind delete cluster --name modelling-lab
```

---

## The commands worth memorising

```powershell
kubectl get pods -n modelling              # what is running
kubectl describe pod <name> -n modelling   # why it isn't running
kubectl logs <name> -n modelling           # what it said
kubectl apply -f <file>                    # make it so
kubectl delete -f <file>                   # undo
```

`describe` is the one people forget. Almost every "why is this stuck" question is answered
in its Events section at the bottom.
