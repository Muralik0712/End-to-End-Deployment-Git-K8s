# 🚀 CI/CD Pipeline Automation with Jenkins + Docker + Kubernetes (AWS EKS)

## 📌 Project Overview
This project demonstrates a **complete CI/CD pipeline** using:

- Jenkins (on Amazon Linux 2023 EC2)
- Docker
- Kubernetes (Amazon EKS)
- GitHub Webhooks

The pipeline automatically:

1. Pulls the latest code from GitHub
2. Builds the project using Maven
3. Packages the WAR file
4. Builds a Docker image containing the WAR
5. Pushes the Docker image to Docker Hub
6. Deploys the application to an EKS cluster

This enables **fully automated deployment** whenever code is pushed to GitHub.

---

## 🧱 Architecture

```
Developer → GitHub → Jenkins (EC2) → Docker Hub → Amazon EKS → LoadBalancer
              (Webhook Trigger)
```

- GitHub triggers Jenkins via webhook
- Jenkins builds the WAR with Maven
- Docker image is built and pushed to Docker Hub
- Jenkins applies Kubernetes manifests to EKS
- EKS exposes the app via a `LoadBalancer` service (AWS ELB)

---

## 🚀 Technologies Used
- Jenkins
- Docker
- Amazon EKS (Kubernetes)
- eksctl / kubectl / AWS CLI
- Apache Maven
- GitHub
- Java 17 (Amazon Corretto) / Spring Boot / WAR-based web application
- Amazon Linux 2023 (EC2)

---

## 🔐 Key Features
- Automatic build trigger using GitHub Webhook
- Continuous Integration using Jenkins
- Automated Docker image creation and push
- Automated deployment to Amazon EKS
- IAM role–based authentication (no static AWS keys on the instance)
- End-to-end CI/CD pipeline for WAR-based applications

---

## 📂 Project Structure

```
devops-project/
│── Dockerfile
│── pom.xml
│── server/
│── taxi-booking/
│   └── target/
│       └── taxi-booking-1.0.1.war
│── k8s/
│   ├── deployment.yaml
│   └── service.yaml
│── README.md
```

---

## ⚙️ Setup Steps

### 1. Launch the EC2 instance

- AMI: **Amazon Linux 2023**
- Instance type: `m7i-flex.large` or similar (2 vCPU / 8 GB RAM minimum recommended — Jenkins + Docker + Maven builds need real memory)
- Security group: open ports **22** (SSH) and **8080** (Jenkins UI)

```bash
sudo dnf update -y
sudo dnf install -y java-17-amazon-corretto maven docker unzip git
sudo systemctl enable --now docker
```

> ⚠️ **Java version matters.** Jenkins requires Java 17 or 21. If Jenkins fails to start with a control-process error, run `java -version` and `rpm -qa | grep java` — an old/missing JDK is the most common cause. See Troubleshooting below.

---

### 2. Create an IAM role for the EC2 instance

Jenkins and the CLI tools need AWS credentials to create/manage the EKS cluster. The clean way to do this is an **IAM role attached to the EC2 instance** — no access keys stored anywhere.

1. AWS Console → IAM → Roles → **Create role**
2. Trusted entity type: **AWS service** → Use case: **EC2**
3. Attach policy: `AdministratorAccess` (fine for learning/testing; scope down for production)
4. Name it e.g. `jenkins-eks-role` → Create role
5. EC2 Console → select your instance → **Actions → Security → Modify IAM role** → attach `jenkins-eks-role`

Verify it's attached:

```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
aws sts get-caller-identity
```

> The **use case** field during role creation (EC2, Lambda, etc.) is different from the **permissions policy** (AdministratorAccess). Don't type the policy name into the use-case search box — that's a common mix-up.

---

### 3. Install eksctl and kubectl

```bash
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

---

### 4. Create the EKS cluster

```bash
eksctl create cluster \
  --name devops-pipeline \
  --region eu-north-1 \
  --nodegroup-name workers \
  --node-type t3.micro \
  --nodes 2 \
  --managed
```

Takes ~15–20 minutes. Verify:

```bash
kubectl get nodes
```

> ⚠️ **Free Tier accounts:** if your account is Free Tier–restricted, `t3.medium` and larger will fail with `InvalidParameterCombination — not eligible for Free Tier`. Use `t3.micro` instead (see Troubleshooting for recovering from a failed nodegroup stack).

---

### 5. Install Jenkins

```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

sudo dnf install -y jenkins
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins
```

Open `http://<ec2-public-ip>:8080`, unlock with:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Install the suggested plugins and create your admin user.

---

### 6. Give Jenkins Docker and Kubernetes access

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins docker
```

> ⚠️ **Jenkins runs as its own OS user.** Root having a working kubeconfig does *not* mean Jenkins can talk to the cluster — the `jenkins` user needs its own copy:

```bash
sudo -u jenkins aws eks update-kubeconfig --name devops-pipeline --region eu-north-1
sudo -u jenkins kubectl get nodes
```

If this returns your cluster's nodes, Jenkins is correctly wired up.

---

### 7. Install required Jenkins plugins

Manage Jenkins → Plugins → Available:
- Git Plugin
- Maven Integration Plugin
- Docker Plugin
- Kubernetes CLI Plugin

---

### 8. Add Docker Hub credentials

Manage Jenkins → Credentials → System → Global credentials → **Add Credentials** (twice):

| Kind | ID | Secret |
|---|---|---|
| Secret text | `DOCKER_USERNAME` | your Docker Hub username |
| Secret text | `DOCKER_PASSWORD` | your Docker Hub password or access token |

---

### 9. Configure the Jenkins job

- New Item → Freestyle Project
- **Source Code Management** → Git → repo URL:
  `https://github.com/<your-username>/End-to-End-Deployment-Git-K8s.git`
- **Build Triggers** → check **GitHub hook trigger for GITScm polling**
- **Build Environment** → check **Use secret text(s) or file(s)** → add both bindings:
  - Variable `DOCKER_USERNAME` → credential `DOCKER_USERNAME`
  - Variable `DOCKER_PASSWORD` → credential `DOCKER_PASSWORD`
- **Build Steps**:
  1. Invoke top-level Maven targets → Goals: `clean package`
  2. Execute shell:

```bash
#!/bin/bash
set -e

echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
docker build -t muralik007/devops-project:v1 .
docker push muralik007/devops-project:v1
kubectl apply -f k8s/
kubectl rollout status deployment/deploy-1 --timeout=120s
```

---

### 10. Configure the GitHub webhook

Repo → Settings → Webhooks → Add webhook:
- Payload URL: `http://<jenkins-ip>:8080/github-webhook/`
- Content type: `application/json`
- Event: **Push events only**

---

### 11. Deploy

```bash
git commit --allow-empty -m "trigger pipeline"
git push
```

Jenkins triggers automatically → Maven builds → Docker image built and pushed → EKS deployment updated.

Verify:

```bash
kubectl get pods
kubectl get svc
```

Grab the `EXTERNAL-IP` (a LoadBalancer DNS name) and open it in your browser.

---

## ⚠️ Problems Faced & How We Solved Them

| Problem | Cause | Solution |
|---|---|---|
| Jenkins service failed to start | No compatible JDK, or wrong Java version active | `sudo dnf install -y java-17-amazon-corretto`, then `sudo alternatives --config java` to select it |
| `eksctl` fails: "no EC2 IMDS role found" | No IAM role attached to the EC2 instance | Create an IAM role (trusted entity: EC2, policy: AdministratorAccess) and attach it via EC2 → Actions → Security → Modify IAM role |
| Nodegroup CloudFormation stack fails: `InvalidParameterCombination - not eligible for Free Tier` | Free Tier account rejected `t3.medium` | Use `t3.micro` (or check Billing → Free Tier for what your account allows) |
| Can't delete failed nodegroup stack: `TerminationProtection is enabled` | eksctl enables termination protection by default | `aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name <stack>` before deleting |
| `kubectl get nodes` returns Jenkins' login HTML | No kubeconfig exists, so kubectl defaults to `localhost:8080` (Jenkins' port) | `aws eks update-kubeconfig --name <cluster> --region <region>` — and run it separately for the `jenkins` user with `sudo -u jenkins` |
| `kubectl get nodes` under Jenkins fails, but works for root | Jenkins runs as its own OS user with its own home directory and kubeconfig | `sudo -u jenkins aws eks update-kubeconfig --name devops-pipeline --region eu-north-1` |
| Maven WAR build fails: `Cannot access defaults field of Properties` | Default/unpinned `maven-war-plugin` resolves to an ancient version (2.2) incompatible with Java 17 | Explicitly pin `maven-war-plugin` to `3.4.0` (or newer) in the module's `pom.xml`; also update `maven-compiler-plugin` to `3.13.0` with `source`/`target` set to `17` |
| Docker build permission denied | Jenkins user not in the `docker` group | `sudo usermod -aG docker jenkins` then restart Jenkins |
| Docker COPY fails (no such file or directory) | WAR file didn't exist before the Docker build ran | Run the Maven build step *before* the Docker build step |
| Docker login fails (non-TTY error) | Credentials not injected as environment variables | Use Jenkins **Secret text** credentials + "Use secret text(s) or file(s)" binding |

✅ Each fix was verified by re-running the pipeline until the build reached `BUILD SUCCESS` and the pods showed `Running`.

---

## 🔍 Testing

| Test Case | Expected Result |
|---|---|
| GitHub Push | ✅ Jenkins triggered automatically |
| Jenkins Build | ✅ WAR built successfully (`mvn clean package`) |
| Docker Push | ✅ Image pushed to Docker Hub (`muralik007/devops-project:v1`) |
| Kubernetes Deploy | ✅ `kubectl get pods` shows pods `Running` |
| Application | ✅ Reachable via the LoadBalancer's external DNS name |

---

## 💰 Cost Note

An EKS control plane costs ~$0.10/hour even when idle, plus the EC2 instance and LoadBalancer. If this cluster is for learning/portfolio purposes, tear it down when you're done:

```bash
eksctl delete cluster --name devops-pipeline --region eu-north-1
```

---

## 🎯 Learning Outcomes
- Implemented an end-to-end CI/CD pipeline from GitHub to a live Kubernetes deployment
- Provisioned an EKS cluster with `eksctl` and connected Jenkins to it via IAM role–based auth
- Automated Jenkins builds for Maven, Docker, and `kubectl`
- Diagnosed and fixed a legacy Maven plugin incompatibility with Java 17
- Solved real-world AWS issues: missing IAM roles, Free Tier instance restrictions, CloudFormation termination protection
- Secured credential injection in Jenkins using Secret text bindings
- Integrated GitHub Webhooks for automated build triggers

---

## 👨‍💻 Author

Murali Prasad K

GitHub: https://github.com/Muralik0712/End-to-End-Deployment-Git-K8s
