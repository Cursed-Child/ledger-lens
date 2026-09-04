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



## Week 1, Day 4 - 2026-09-03

**What I built:** Resumed from the Day 3 stopping point. Pointed the shell at minikube's internal Docker daemon (`eval $(minikube docker-env)`) and rebuilt the FastAPI image there, since minikube runs its own Docker daemon separate from the host, an image built normally on the host isn't visible to the cluster. Added `imagePullPolicy: Never` to the Deployment so Kubernetes doesn't attempt to pull the image from an external registry it was never pushed to.

**Fork in the road, minikube vs kind:** Someone asked "why minikube was chosen over kind, given kind's `kind load docker-image` workflow is more Docker-native (build normally on host, load directly into the cluster, no daemon-switching required)". Good question and my reason was that the minikube choice earlier was mostly convention and momentum, not a deliberate tradeoff analysis. I had thought about switching but being mid-Week-1 with a working chart and toolchain already in existence around minikube, thought otherwise. That being said, I have flagged kind as worth trying deliberately later (maybe later as I work with Gateway API testing) specifically to compare the image-loading ergonomics and multi-node testing capability firsthand - something I believe will be a good conversation.

**Next:** Next I have to verify both the FastAPI and Postgres pods come up healthy via `helm install` and `kubectl get pods`, then test connectivity between them.


**What I built:** Verified full stack is running end to end. `helm install` deployed both FastAPI and Postgres. I confirmed via `kubectl port-forward` that `/health` responds correctly through the Kubernetes Service, not just a direct container port, proving the Deployment to Service to probe chain works.

**Debugging story:** I hit `ImagePullBackOff` first (since image was built on host, and not visible to minikube's internal Docker daemon). I fixed by rebuilding inside `eval $(minikube docker-env)` and setting `imagePullPolicy: Never`. Then hit a second, less obvious issue: `kubectl port-forward` failed with service not found, even though `helm lint` had passed cleanly earlier. Ran root-cause with `helm get manifest ledger-lens`, comparing the actual rendered output against what was expected, which revealed the FastAPI Service was missing entirely from the manifest. I traced it to `templates/service.yaml` and realized I never created it in the first place. Was not sure if its a file-creation step that silently failed earlier without an error, and since `helm lint` doesn't catch a missing file (only syntax errors in files that exist), I obviously missed it. I recreated the file, ran `helm upgrade` (not `install`, since the release already existed), confirmed the Service appeared and connectivity worked.

**Lesson:** `helm lint` validates syntax of what's there, it does not confirm all expected resources actually exist. When a resource seems to be missing at runtime, `helm get manifest <release>` is the fastest way to see exactly what Kubernetes actually received, rather than assuming the source templates are correct.

**Next:** Wire FastAPI to Postgres (actual DB connection, not just co-located pods), then build the first real CRUD endpoint.


**What I built:** I wired FastAPI to Postgres via SQLAlchemy, using the headless service DNS name
(`ledger-lens-postgres`) as the connection host. I then added a `/db-check` endpoint that runs a real query
through the connection to prove it works end to end, not just that both pods exist side by side.

**Debugging story:** My first deploy attempt hit `CrashLoopBackOff`. Root cause was the Dockerfile only
had `COPY main.py .`, so the new `database.py` module never made it into the image, the import failed
at container startup. Of course, I forgot to add the file and fixed by switching to `COPY . .` so the whole app directory copies in automatically as the app grows, paired with a new `.dockerignore` (same syntax as `.gitignore`) to
keep `venv/` and `__pycache__/` out of the build context. This is a pattern I have always followed but not sure why it was missed this time .. maybe I am very tired ? 

**Fork in the road:** I just want to make the database connection work and for a quick fix used `os.getenv` with a hardcoded fallback for the database connection string rather than hardcoding it directly, so the same code works across local dev and different cluster environments without a code change, just a config change. The fallback is obviously HORRIFIC for security because currently still contains the Postgres password in plaintext, which is a known gap. I am going to move it to a proper Kubernetes Secret rather than leaving it in `values.yaml` and the code's default string.

**Next:** Move the Postgres password out of `values.yaml` into a Kubernetes Secret, wire it into both
the Postgres StatefulSet and the FastAPI Deployment via environment variables so neither has the
credential hardcoded in source.

**What I built:** I moved the Postgres password out of `values.yaml`/inline env values into a proper
Kubernetes Secret. Both the Postgres StatefulSet and the FastAPI Deployment now source credentials via
`secretKeyRef` rather than plaintext. The `DATABASE_URL` is being assembled inside the Deployment spec using
Kubernetes' `$(VAR)` interpolation between env vars sourced from the same Secret, so the full connection
string is never written as a literal string anywhere in the manifests.

**Fork in the road:** Switched `database.py` from `os.getenv("DATABASE_URL", <hardcoded fallback>)` to
`os.environ["DATABASE_URL"]`. Though a small change, the difference matters more than it looks: `getenv` with a default fails silently, if the env var were ever missing due to a misconfigured Secret or a YAML typo, the app would
keep running normally, using the wrong hardcoded credential, `/health` would still report ok, and
nothing would visibly signal the misconfiguration. However `os.environ[...]` raises immediately if the variable
is missing, converting a silent wrong-config failure into something that cannot be ignored.

**Verification:** Then I confirmed the Secret actually landed in the container via `kubectl exec ... -- printenv DATABASE_URL` before trusting `/db-check`, rather than only inferring success from the endpoint working, since a masked failure (wrong DB, silently connected somewhere unintended) wouldn't necessarily be obvious from the app behaving normally.

**Known remaining gap:** I know the password still lies in plaintext in `values.yaml`, which is committed to git. In a real production secret handling would pull this from a cloud secrets manager (AWS Secrets Manager, Vault) or use a tool like Sealed Secrets/External Secrets Operator so nothing sensitive is ever committed at all, not even inside a Secret manifest's source values. I will get to this later when I focus on cloud security as a topic. 

**Next:** I want to continue hardening infrastructure further and then step up on an actual app.
