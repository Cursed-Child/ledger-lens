# Journal - ledger-lens

## Week 1, Day 1 - 2026-08-30

**What I built:** Project scaffold, repo structure, toolchain verified (Docker, kubectl, minikube, Helm). Set up a `post-commit` git hook to remind me to update this journal on every commit. Initialized the GitHub repo via `gh` CLI rather than the web UI, resolving a PAT scope gap (`repo`, `workflow`, `read:org`) required for CLI-driven repo creation and future Actions workflows.

**Fork in the road:** Decided to containerize both FastAPI and Postgres from day one, and use Helm from the start rather than staging plain YAML first - optimizing for portability across two laptops. Also decided against the `kvm2` minikube driver in favor of `docker` - kvm2 adds real virtualization setup complexity (BIOS virtualization flags, libvirt, qemu) for no benefit at the local-dev stage; moved standalone VM/KVM fundamentals practice to Month 3 instead.

**Next:** Build FastAPI app skeleton, Dockerfile, and initial Helm chart.

## Week 1, Day 2 - 2026-08-30

**What I built:** Minimal FastAPI skeleton (`app/main.py`, `app/requirements.txt`) - single `/health` endpoint. Validated it boots and serves correctly via `uvicorn` standalone before introducing any containerization, to isolate the debugging surface (app-level vs container-level) for the next step.

**Fork in the road:** None significant this session - straightforward build.

**Next:** Write the Dockerfile, build the image, run it standalone before wiring into the Helm chart.

## Week 1, Day 3 - 2026-09-01

**What I built:** Dockerized the FastAPI skeleton. Built and ran the image, confirmed `/health` responds identically inside a container as it did running locally via uvicorn - isolating containerization as a separate, now-validated layer.

Built the full Helm chart for ledger-lens - FastAPI Deployment + ClusterIP Service, Postgres StatefulSet + headless Service + PVC for persistence. `helm lint` passes clean. Also added `scripts/setup-toolchain.sh`, an idempotent script that installs/verifies Docker, kubectl, minikube, Helm, and gh CLI - meant to be updated as new tools enter the project, so either laptop can be brought to a working state with one command instead of manually retyping install steps from memory.

**Fork in the road - network binding:** Bound uvicorn to `0.0.0.0` instead of the default `127.0.0.1`. Inside a container, `127.0.0.1` only accepts traffic originating from within that same network namespace - a request from the host machine, or later from a Kubernetes probe/Service, is treated as external and refused. `0.0.0.0` binds to all interfaces so the container is reachable from outside. Noted this isn't just a connectivity fix - it has production implications: it widens the network surface, so real access control in a client environment comes from layering K8s NetworkPolicies, correct Service type (ClusterIP vs LoadBalancer), and Ingress-level auth on top, not from the bind address alone. Also relevant to K8s liveness/readiness probes, which hit the pod from outside the container and would silently fail (causing restart loops) against a `127.0.0.1`-bound app.

Used exec-form `CMD` (`["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]`) rather than shell-form. Exec form runs the process as PID 1 directly, so it receives signals (e.g. SIGTERM on a `kubectl rollout` or scale-down) correctly for graceful shutdown - shell form wraps it in `/bin/sh -c`, which can swallow or delay signal forwarding to the app.

**Fork in the road - Gateway API vs plain Service:** The default `helm create` scaffold included an `httproute.yaml` (Gateway API) alongside `ingress.yaml`. Removed both. Gateway API is the modern, more expressive successor to Ingress (supports header-based routing, weighted traffic splitting, cross-namespace routing) - but it requires a Gateway controller (e.g. Envoy Gateway, Istio) installed in the cluster, which minikube doesn't have by default. Nothing in this project currently needs external/internet-facing routing - FastAPI is internal-only (ClusterIP), reached via port-forward or from inside the cluster. Keeping unused Gateway API config in the chart would be dead configuration. Deliberately deferred to Month 3 (cloud/networking week), where I'll install a real Gateway controller in a cloud or kind cluster and expose a service through an actual HTTPRoute rule - done properly, with a real external-exposure need, rather than as leftover scaffold boilerplate.

**Other decisions:** Postgres Service is headless (`clusterIP: None`) rather than a normal ClusterIP - standard practice for StatefulSets, since each Postgres pod needs a stable, individually-addressable DNS name rather than round-robin load balancing across replicas (which would be wrong for a database you're connecting to directly). FastAPI Service stays a normal ClusterIP since it's stateless and fine to load-balance across replicas.

**Tip for reruns:** if `docker run -p 8000:8000` fails with "port is already allocated," it's usually a leftover container or local process still bound to that host port - check `docker ps` and stop the stale container, or run on an alternate host port (`-p 8001:8000`) to sidestep it without touching the Dockerfile.

**Diagram:** Generated a context diagram showing how `values.yaml` feeds all four templates (fastapi-deployment, fastapi-service, postgres-statefulset, postgres-service), and how the two Services route to their respective pods. Useful reference for anyone (including future me) trying to understand the chart's structure at a glance.

**Next:** Build the FastAPI image inside minikube's Docker daemon (or push to a registry), then `helm install` the chart and verify both the API and Postgres come up healthy.
