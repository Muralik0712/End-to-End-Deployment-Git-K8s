// Put this file at the ROOT of your application repo (next to Dockerfile / pom.xml).
pipeline {
  agent any

  environment {
    IMAGE_REPO = "${env.IMAGE_REPO ?: 'muralik007/devops-project'}"
    TAG        = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build WAR') {
      steps { sh 'mvn -B clean package' }
    }

    stage('Docker build & push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                          usernameVariable: 'DU', passwordVariable: 'DP')]) {
          sh '''
            set -e
            echo "$DP" | docker login -u "$DU" --password-stdin
            docker build -t "$IMAGE_REPO:$TAG" -t "$IMAGE_REPO:latest" .
            docker push "$IMAGE_REPO:$TAG"
            docker push "$IMAGE_REPO:latest"
          '''
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh '''
          set -e
          kubectl apply -f k8s/
          # unique tag per build => guaranteed rollout (a fixed :v1 tag would not redeploy)
          kubectl set image deployment/deploy-1 "*=$IMAGE_REPO:$TAG"
          kubectl rollout status deployment/deploy-1 --timeout=180s
        '''
      }
    }
  }
}
