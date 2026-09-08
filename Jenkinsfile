pipeline{
    agent any
    environment{ 
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        IMAGE_TAG = "${BUILD_NUMBER}"
        NGINX_IMAGE = "mynginx:${BUILD_NUMBER}"
        ORIGINAL_IMAGE = "flask-app:${BUILD_NUMBER}-original"
        SLIM_IMAGE = "flask-app:${BUILD_NUMBER}-slim"
        DOCKERHUB_REPO = "chrisreeves1/flask-app-1"
        SOANR_HOST_URL = "http://172.31.23.181:9000"
        SONAR_PROJECT_KEY = "flask-app" 
    }
    parameters{
        booleanParam(
            name: 'USE_SLIM_IMAGE',
            defaultValue: false,
            description: "An experimental slim build of the flask-app image - do not trust"
        )
    }
    stages{
        stage("init"){
            steps{
                sh """
                    docker rm -f flask-app mynginx 2>/dev/null || true
                    docker network rm new-network 2>/dev/null || true
                    docker network create new-network
                """
            }
        }
        stage("Parallel pre-build check"){
            parallel{
                stage("trivy fs scan"){
                    steps{
                        sh """
                            trivy fs --cache-dir /tmp/trivycache-fs --format json -o trivy-report.json . 
                        """
                    }
                    post{
                        always{
                            archiveArtifacts artifacts: "trivy-report.json", allowEmptyArchive: true
                        }
                    }
                }
                stage("unit test(s)"){
                    steps{
                        catchError(BuildResult: 'UNSTABLE', stageResult: 'UNSTABLE'){
                           sh """
                                python3 -m venv .venv
                                . .venv/bin/activate
                                pip install -r requirements.txt
                                python3 -m unittest -v test-app.py
                                deactivate
                           """     
                        }
                    }
                }
                stage("sonarqube static analysis"){
                    steps {
                        withCredentials([
                            string(
                                credentialsId: 'sonarqube-token',
                                variable: 'SONAR_TOKEN'
                            )
                ]) {
                    sh '''
                        docker run --rm \
                            -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                            -e SONAR_TOKEN="$SONAR_TOKEN" \
                            -v "$WORKSPACE:/usr/src" \
                            sonarsource/sonar-scanner-cli \
                            -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
                            -Dsonar.sources=. \
                            -Dsonar.exclusions=".venv/**,venv/**,__pycache__/**,**/*.pyc"
                    '''
                            }
                        }
                    }
                }
            }
        }
    }

// stages:
//     - init (rm commands and build networks/volumes if needed)
    
//     - parallel stage:
//                 trivy fs scan
//                 unit test
//                 sonarqube: add gate in sqube to fail otherwise manual aporoval gate needed.

//     - build metadata

//     - parallel stage:
//                 build flask-app
//                 build nginx

//     - conditional param slim image (experimental)
//             if used we need a selector

//     - parallel stage:
//                 image scan
//                 SBOM 

//     - 200 mb size gate

//     - manual approval gate? 

//     - run + smoke test 

//     - Push to dockerhub

//     - post actions 
// }