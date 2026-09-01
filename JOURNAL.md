# Journal — ledger-lens

## Week 1, Day 1 — 2026-08-30

**What I built:** Project scaffold, repo structure, toolchain verified (Docker, kubectl, minikube, Helm). Set up a `post-commit` git hook to remind me to update this journal on every commit.

**Fork in the road:** Decided to containerize both FastAPI and Postgres from day one, and use Helm
from the start rather than staging plain YAML first — optimizing for portability across two laptops.
Also decided against using the `kvm2` minikube driver in favor of `docker` — kvm2 adds real virtualization
setup complexity (BIOS virtualization flags, libvirt, qemu) for no benefit at the local-dev stage;
moved standalone VM/KVM fundamentals practice to Month 3 instead.

**Next:** Build FastAPI app skeleton, Dockerfile, and initial Helm chart.

## Week 1, Day 3 — 2026-09-01

**What I built:** Dockerized the FastAPI skeleton. Built and ran the image, confirmed `/health` responds
identically inside a container as it did running locally via uvicorn — isolating containerization as a
separate, now-validated layer.

**Fork in the road:** Bound uvicorn to `0.0.0.0` instead of the default `127.0.0.1`. Inside a container,
`127.0.0.1` only accepts traffic originating from within that same network namespace — a request from
the host machine, or later from a Kubernetes probe/Service, is treated as external and refused.
`0.0.0.0` binds to all interfaces so the container is reachable from outside. Noted this isn't just a
connectivity fix — it has production implications: it widens the network surface, so real access
control in a client environment comes from layering K8s NetworkPolicies, correct Service type
(ClusterIP vs LoadBalancer), and Ingress-level auth on top, not from the bind address alone. Also
relevant to K8s liveness/readiness probes, which hit the pod from outside the container and would
silently fail (causing restart loops) against a `127.0.0.1`-bound app.

Used exec-form `CMD` (`["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]`) rather than
shell-form. Exec form runs the process as PID 1 directly, so it receives signals (e.g. SIGTERM on a
`kubectl rollout` or scale-down) correctly for graceful shutdown — shell form wraps it in `/bin/sh -c`,
which can swallow or delay signal forwarding to the app.

**Tip for reruns:** if `docker run -p 8000:8000` fails with "port is already allocated," it's usually a
leftover container or local process still bound to that host port — check `docker ps` and stop the
stale container, or run on an alternate host port (`-p 8001:8000`) to sidestep it without touching the
Dockerfile.

**Next:** Write the Helm chart (FastAPI Deployment/Service, Postgres StatefulSet + PVC).
