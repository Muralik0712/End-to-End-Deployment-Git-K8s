# 🚀 CI/CD Pipeline Automation with Jenkins + Docker + Kubernetes

## 📌 Project Overview
This project demonstrates a **complete CI/CD pipeline** using:  

- Jenkins  
- Docker  
- Kubernetes  
- GitHub Webhooks  

The pipeline automatically:  

1. Pulls the latest code from GitHub  
2. Builds the project using Maven  
3. Packages the WAR file  
4. Builds a Docker image containing the WAR  
5. Pushes the Docker image to Docker Hub  
6. Deploys the application to Kubernetes  

This enables **fully automated deployment** whenever code is pushed to GitHub.  

---

## 🧱 Architecture
The workflow is as follows:


Developer → GitHub → Jenkins → Docker Hub → Kubernetes Cluster
(Webhook Trigger)
GitHub triggers Jenkins via webhook
Jenkins builds the WAR
Docker image is built and pushed
Kubernetes deployment updates automatically


> This shows the end-to-end pipeline from code push to automated deployment.

---

## 🚀 Technologies Used
- Jenkins  
- Docker  
- Kubernetes  
- Apache Maven  
- GitHub  
- Java / Spring Boot / WAR-based web application  

---

## 🔐 Key Features
- Automatic build trigger using GitHub Webhook  
- Continuous Integration using Jenkins  
- Automated Docker image creation and push  
- Automated deployment to Kubernetes  
- End-to-end CI/CD pipeline for WAR-based applications  

---

## 📂 Project Structure


devops-project/
│── Dockerfile
│── pom.xml
│── taxi-booking/
│ └── target/
│ └── taxi-booking-1.0.1.war
│── k8s/
│ ├── deployment.yaml
│ └── service.yaml
│── README.md


---

## ⚙️ Setup Steps

### 1. Install Jenkins
- Open Jenkins in your browser:  

http://<jenkins-ip>:8080

- Unlock Jenkins and install suggested plugins.

---

### 2. Install Required Plugins
- Git Plugin  
- Maven Integration Plugin  
- Maven Invoker  
- Docker Plugin  
- Kubernetes CLI Plugin  
- Pipeline Plugin  

> These plugins enable Git integration, Maven build, Docker builds, and Kubernetes deployments.

---

### 3. Configure Jenkins Job
- Create a **Freestyle Project**  
- Add GitHub repository:  

https://github.com/
<your-username>/devops-project.git

- Enable: **GitHub hook trigger for GITScm polling**  

> This ensures that every push to GitHub automatically triggers a build.

---

### 4. Configure Maven Build Step
- Invoke top-level Maven targets  
- Goals:  

clean package


> This step ensures the WAR file (`taxi-booking/target/taxi-booking-1.0.1.war`) is generated **before Docker tries to copy it**, avoiding missing file errors.

---

### 5. Configure Docker Build & Push
- Add an **Execute Shell** build step:

```bash
#!/bin/bash
set -e

# Login to Docker Hub (credentials injected via Jenkins)
echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin

# Build Docker image
docker build -t murali007/devops-project:v1 .

# Push Docker image
docker push murali007/devops-project:v1
Dockerfile content (in project root):
FROM tomcat:9-jdk17
COPY taxi-booking/target/taxi-booking-1.0.1.war /usr/local/tomcat/webapps/
EXPOSE 8080

Using relative paths ensures Docker can find the WAR file inside the build context.

6. Configure Kubernetes Deployment
Apply manifests from k8s/ folder:
kubectl apply -f k8s/

Ensure the Jenkins user has a valid kubeconfig with access to your Kubernetes cluster.

7. Configure GitHub Webhook
Payload URL:
http://<jenkins-ip>:8080/github-webhook/
Content type: application/json
Event: Push events only

This ensures Jenkins is automatically triggered whenever new code is pushed.

8. Deploy
Push code to GitHub → Jenkins triggers → Docker image built and pushed → Kubernetes updated

Fully automated deployment from GitHub to Kubernetes.

⚠️ Docker Problems Faced & How We Solved Them
Docker build permission denied
Cause: Jenkins user not in docker group
Solution: sudo usermod -aG docker jenkins
Docker COPY fails (no such file or directory)
Cause: WAR file does not exist before Docker build
Solution: Added Maven build step before Docker build
Docker login fails (Cannot perform an interactive login from a non TTY)
Cause: Credentials not injected or environment filtered
Solution: Used Jenkins Secret Text binding for DOCKER_USERNAME and DOCKER_PASSWORD
Docker push denied
Cause: Wrong repository name or credentials
Solution: Corrected Docker repository name and used injected credentials
Absolute path in Dockerfile
Cause: Docker build context cannot access full filesystem
Solution: Used relative paths like COPY taxi-booking/target/taxi-booking-1.0.1.war /usr/local/tomcat/webapps/

✅ Step-by-step fixes ensured Docker builds, pushes, and deployment worked without errors.

🔍 Testing
Test Case	Expected Result
GitHub Push	✅ Jenkins triggered
Jenkins Build	✅ WAR built successfully
Docker Push	✅ Image pushed to Docker Hub
Kubernetes Deploy	✅ Application updated in cluster
Application	✅ Loads successfully in browser
🎯 Learning Outcomes
Implemented end-to-end CI/CD pipeline
Automated Jenkins builds for Maven, Docker, and Kubernetes
Secure credential injection in Jenkins
Solved real-world Docker issues (permissions, login, file paths)
Integrated GitHub Webhooks for automated triggers

👨‍💻 Author

Murali Prasad K

GitHub: https://github.com/Muralik0712/End-to-End-Deployment-Git-K8s