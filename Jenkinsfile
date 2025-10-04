pipeline {
    agent any

    environment {
        GITHUB_CRED = credentials('github-cred')
        DOCKER_CRED = credentials('docker-server-cred')
        DOCKER_HOST = "18.142.185.65"
        DOCKER_USER = "ubuntu"   // replace with your Docker server username
        APP_NAME = "my-app"
        JAR_FILE = "target/my-app-1.0-SNAPSHOT.jar"
        IMAGE_NAME = "my-app-image"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Deena7/demo-proj.git',
                    credentialsId: 'github-cred'
            }
        }

        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Deploy to Docker Server') {
            steps {
                sshagent(['docker-server-cred']) {
                    sh """
                        # Copy jar and Dockerfile to server
                        scp ${JAR_FILE} ${DOCKER_USER}@${DOCKER_HOST}:/home/${DOCKER_USER}/
                        scp Dockerfile ${DOCKER_USER}@${DOCKER_HOST}:/home/${DOCKER_USER}/
                        
                        # Build and run container
                        ssh ${DOCKER_USER}@${DOCKER_HOST} '
                           sudo docker build -t ${IMAGE_NAME} /home/${DOCKER_USER}/
                           sudo docker stop ${APP_NAME} || true
                           sudo docker rm ${APP_NAME} || true
                           sudo docker run -d --name ${APP_NAME} -p 8080:8080 ${IMAGE_NAME}
                        '
                    """
                }
            }
        }
    }
}

