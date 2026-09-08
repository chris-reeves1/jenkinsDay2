pipeline{
    agent any
    environment{ 
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        IMAGE_TAG = "${BUILD_NUMBER}"
        NGINX_IMAGE = "mynginx:${BUILD_NUMBER}"
        ORIGINAL_IMAGE = "flask-app:${BUILD_NUMBER}-original"
        SLIM_IMAGE = "flask-app:${BUILD_NUMBER}-slim"
        DOCKERHUB_REPO = "chrisreeves1/flask-app-1"
        SONAR_HOST_URL = "http://172.31.23.181:9000"
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
                        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE'){
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
            stage("build metadata"){
                steps{
                    sh """
                        COMMIT_HASH="\$(git rev-parse HEAD 2>/dev/null || echo unknown)"
                    COMMIT_SHORT="\$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
                    BRANCH_NAME_VALUE="\$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

                    cat > build-metadata.json <<EOF
                    {
                      "commit_hash": "\${COMMIT_HASH}",
                      "commit_short": "\${COMMIT_SHORT}",
                      "branch_name": "\${BRANCH_NAME_VALUE}",
                      "build_number": "${BUILD_NUMBER}",
                      "jenkins_job": "${JOB_NAME}",
                      "build_url": "${BUILD_URL}",
                      "original_image": "${ORIGINAL_IMAGE}",
                      "slim_image": "${SLIM_IMAGE}",
                      "nginx_image": "${NGINX_IMAGE}",
                      "dockerhub_repo": "${DOCKERHUB_REPO}"
                    }
                    EOF

                    cat build-metadata.json 
                    """
                        // cat > means override stdout
                        // <<EOF send this to cat
                        // cat > file <<EOF == write this to the file

                }
                post{
                    always{
                        archiveArtifacts artifacts: "build-metadata.json", allowEmptyArchive: true
                    }
                }
            }
            stage("Image builds in parallel"){
                parallel{
                    stage("build flask-app"){
                        steps{
                            sh """
                                docker build -t ${ORIGINAL_IMAGE} .
                            """
                        }
                    }
                    stage("build nginx"){
                        steps{
                            sh """
                                docker build -t ${NGINX_IMAGE} -f Dockerfile.nginx . 
                            """
                        }
                    }
                }
            }
            stage("optional slim logic"){
                when{
                    expression { return params.USE_SLIM_IMAGE}
                }
                steps{
                    sh """
                        slim build \
                        --target ${ORIGINAL_IMAGE} \
                        --tag ${SLIM_IMAGE} \
                        --http-probe=false
                    """
                }
            }
            stage("select final image"){
                steps{
                    script{
                        if (params.USE_SLIM_IMAGE) {
                            env.FINAL_IMAGE = env.SLIM_IMAGE
                        } else {
                            env.FINAL_IMAGE = env.ORIGINAL_IMAGE
                        }
                    }

                }
            }
            stage("Parallel post-build actions"){
                parallel{
                    stage("image build metadata"){
                        steps{
                            sh """
                                docker inspect ${FINAL_IMAGE} > docker_inspect.json
                                docker history ${FINAL_IMAGE} > docker_history.txt
                                docker image ${FINAL_IMAGE} > docker_image.txt
                            """
                        }
                        post{
                            always{
                                archiveArtifacts artifacts: "docker_inspect.json,docker_history.txt,docker_image.txt", allowEmptyArchive:true
                            }
                        }
                    }
                    stage("trivy image scan"){
                        steps{
                            sh """
                                trivy image --cache-dir /tmp/trivycache-image --format json -o trivy-image-report.json ${FINAL_IMAGE}
                            """
                        }
                        post{
                            always{
                                archiveArtifacts artifacts: "trivy-image-report.json", allowEmptyArchive:true
                            }
                        }
                    }
                    stage("generate SBOM"){
                        steps{
                            sh """
                                trivy image \
                                --cache-dir /tmp/trivycache-sbom \
                                --format cyclonedx \
                                --output flask-app-sbom.cdx.json \
                            ${FINAL_IMAGE}
                            """
                        }
                        post{
                            always{
                                archiveArtifacts artifacts: "flask-app-sbom.cdx.json", allowEmptyArchive:true
                            }
                        }
                    }
                }
                stage("size gate"){
                    steps{
                        script{
                            def sizeBytes = sh(
                                script: "docker image inspect ${FINAL_IMAGE} --format='{{.Size}}'",
                                returnStdout: true
                            ).trim().toLong()

                            def maxBytes = 200 * 1024 * 1024

                            if (sizeBytes > maxBytes) {
                                unstable("Image size threshold breached 200MB")
                            }
                        }
                    }
                }
                stage("approval (manual - not best practice so remove eventually)"){
                    steps{
                        input message: "quality gate continue?", ok: "proceed"
                    }
                }
            }
        }
    }








//     - manual approval gate? 

//     - run + smoke test 

//     - Push to dockerhub

//     - post actions 
// }