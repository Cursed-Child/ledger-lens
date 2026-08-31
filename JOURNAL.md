# Journal — ledger-lens

## Week 1, Day 1 — 2026-08-30

**What I built:** Project scaffold, repo structure, toolchain verified (Docker, kubectl, minikube, Helm). Set up a `post-commit` git hook to remind me to update this journal on every commit.

**Fork in the road:** Decided to containerize both FastAPI and Postgres from day one, and use Helm
from the start rather than staging plain YAML first — optimizing for portability across two laptops.
Also decided against using the `kvm2` minikube driver in favor of `docker` — kvm2 adds real virtualization
setup complexity (BIOS virtualization flags, libvirt, qemu) for no benefit at the local-dev stage;
moved standalone VM/KVM fundamentals practice to Month 3 instead.

**Next:** Build FastAPI app skeleton, Dockerfile, and initial Helm chart.
