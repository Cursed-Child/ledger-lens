#!/bin/bash
# setup-toolchain.sh
# Installs the local dev toolchain for ledger-lens.
# Keep this updated as new tools are added to the project.
# Usage: bash scripts/setup-toolchain.sh

set -e

echo "== Docker =="
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker "$USER"
  echo "Docker installed. Run 'newgrp docker' or restart your shell to use it without sudo."
else
  echo "Docker already installed: $(docker --version)"
fi

echo "== kubectl =="
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
else
  echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

echo "== minikube =="
if ! command -v minikube &> /dev/null; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f minikube-linux-amd64
else
  echo "minikube already installed: $(minikube version --short 2>/dev/null || minikube version)"
fi

echo "== Helm =="
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Helm already installed: $(helm version --short 2>/dev/null || helm version)"
fi

echo "== GitHub CLI (gh) =="
if ! command -v gh &> /dev/null; then
  sudo apt update && sudo apt install -y gh
else
  echo "gh already installed: $(gh --version | head -n1)"
fi

echo ""
echo "Toolchain check complete. Versions installed:"
docker --version
kubectl version --client
minikube version
helm version
gh --version | head -n1

echo ""
echo "Next: run 'minikube start --driver=docker' to bring up the local cluster."