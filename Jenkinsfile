// CI/CD pipeline for CloudSleuth.
// Runs on the Jenkins server on AWS EC2: pull from GitHub -> build Docker image ->
// run tests inside the image -> deploy the container -> check it is healthy.

pipeline {
    agent any

    environment {
        IMAGE     = 'cloudsleuth'
        TAG       = "${env.BUILD_NUMBER}"
        CONTAINER = 'cloudsleuth'
        APP_PORT  = '80'       // public port on EC2 -> container port 8000
    }

    triggers {
        githubPush()                 // GitHub webhook: build on every push
        pollSCM('H/5 * * * *')       // fallback if the webhook can't reach Jenkins
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty="Commit %h by %an: %s"'
            }
        }

        stage('Build Docker image') {
            steps {
                sh 'docker build -t $IMAGE:$TAG -t $IMAGE:latest .'
            }
        }

        stage('Test') {
            steps {
                // The same image that will be deployed is the one that gets tested.
                sh 'docker run --rm $IMAGE:$TAG python -m pytest -q'
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    docker rm -f $CONTAINER 2>/dev/null || true
                    docker run -d --name $CONTAINER \
                        --restart unless-stopped \
                        --memory 300m \
                        -p $APP_PORT:8000 \
                        -e BUILD_NUMBER=$TAG \
                        -e GIT_COMMIT_SHORT=$(git rev-parse --short HEAD) \
                        -e DEPLOYED_AT="$(date -u '+%Y-%m-%d %H:%M UTC')" \
                        $IMAGE:$TAG
                '''
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    for i in $(seq 1 30); do
                        if curl -fs http://localhost:$APP_PORT/health; then
                            echo
                            echo "Deployed build $TAG and it is healthy."
                            exit 0
                        fi
                        sleep 2
                    done
                    echo "App did not become healthy"; docker logs --tail 50 $CONTAINER
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            // Free disk space on the small EC2 instance: keep only the latest images.
            sh 'docker image prune -f >/dev/null || true'
            sh '''
                docker images $IMAGE --format "{{.Tag}}" | grep -E "^[0-9]+$" | sort -rn | tail -n +4 \
                    | xargs -r -I{} docker rmi $IMAGE:{} >/dev/null 2>&1 || true
            '''
        }
        success { echo 'Pipeline succeeded: CloudSleuth is live on port 80.' }
        failure { echo 'Pipeline failed: the previous container (if any) was replaced; check the logs above.' }
    }
}
