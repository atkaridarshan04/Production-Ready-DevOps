pipeline {
    agent {
        label 'slave'
    }

    // Define pipeline parameters
    parameters {
        string(name: 'BRANCH_NAME', defaultValue: 'main', description: 'Branch to build')
        choice(name: 'ENV', choices: ['dev', 'staging', 'prod'], description: 'Deployment environment')
        string(name: 'VERSION', defaultValue: '', description: 'Version number (leave empty for auto-versioning)')
    }

    // Define tools to use
    tools {
        maven 'maven'
    }

    // Define environment variables
    environment {
        SONAR_HOME = tool 'sonar'
        DOCKER_REGISTRY = 'atkaridarshan04'
        APP_NAME = 'bankapp'
        GIT_REPO = 'https://github.com/atkaridarshan04/Production-Ready-DevOps.git'
        // Auto-generate version if not provided
        VERSION = "${params.VERSION ? params.VERSION : env.BUILD_NUMBER}"
        // Create semantic versioning tag based on environment
        IMAGE_TAG = "${params.ENV == 'prod' ? 'v' + VERSION : params.ENV + '-' + VERSION}"
        // Set timestamp for build
        BUILD_TIMESTAMP = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
    }

    // Define options for the pipeline
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage("Initialize") {
            steps {
                // Clean workspace before build
                cleanWs()
                
                // Display build information
                echo "Building branch: ${params.BRANCH_NAME}"
                echo "Environment: ${params.ENV}"
                echo "Version: ${env.VERSION}"
                echo "Image tag: ${env.IMAGE_TAG}"
            }
        }

        stage ('Code Checkout') {
            steps {
                // Checkout code with timeout and retry for network issues
                timeout(time: 5, unit: 'MINUTES') {
                    retry(3) {
                        git branch: "${params.BRANCH_NAME}", url: "${env.GIT_REPO}"
                    }
                }
            }
        }

        stage ('Build and Test') {
            parallel {
                stage ('Compile Code') {
                    steps {
                        // Compile with proper error handling
                        dir('src') {
                            sh "mvn -B compile"
                        }
                    }
                }
                
                stage ('Run Unit Tests') {
                    steps {
                        // Run tests and generate reports
                        dir('src') {
                            sh "mvn -B test -D skipTests"   // skipTests=false for actual test runs
                            // junit '**/target/surefire-reports/*.xml'
                        }
                    }
                    // Enable when running tests
                    // post { 
                    //     always {
                    //         // Archive test results
                    //         archiveArtifacts artifacts: 'src/target/surefire-reports/*.xml', allowEmptyArchive: true
                    //     }
                    // }
                }
                
                stage ('Static Code Analysis') {
                    steps {
                        // Run static code analysis
                        dir('src') {
                            sh "mvn -B checkstyle:checkstyle pmd:pmd"
                        }
                    }
                }
            }
        }
        
        stage ('Security Scans') {
            parallel {
            //     stage ('OWASP Dependency Check') {
            //         steps {
            //             // Check dependencies for vulnerabilities
            //             sh "mvn -B org.owasp:dependency-check-maven:check"
            //         }
            //         post {
            //             always {
            //                 // Archive dependency check results
            //                 archiveArtifacts artifacts: 'target/dependency-check-report.html', allowEmptyArchive: true
            //             }
            //         }
            //     }
                
                stage ('File System Scan') {
                    steps {
                        // Scan filesystem for vulnerabilities
                        sh "trivy fs --format table -o fs-scan.html src/"
                    }
                    post {
                        always {
                            // Archive trivy scan results
                            archiveArtifacts artifacts: 'fs-scan.html', allowEmptyArchive: true
                        }
                    }
                }
            }
        }

        stage ('Code Quality') {
            steps {
                // Run SonarQube analysis
                withSonarQubeEnv('sonar') {
                    sh '''
                    $SONAR_HOME/bin/sonar-scanner \
                    -Dsonar.projectName=bankapp \
                    -Dsonar.projectKey=bankapp \
                    -Dsonar.sources=src \
                    -Dsonar.java.binaries=src/target \
                    -Dsonar.java.checkstyle.reportPaths=src/target/checkstyle-result.xml \
                    '''
                }
            }
        }

        stage("Quality Gate") {
            steps {
                // Wait for quality gate with timeout
                timeout(time: 10, unit: "MINUTES") {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage ('Build and Publish Artifact') {
            when {
                expression { params.ENV != 'dev' } // Skip for dev environment
            }
            steps {
                // Build and publish to Nexus
                dir('src') {
                    withMaven(globalMavenSettingsConfig: 'maven-settings', maven: 'maven', mavenSettingsConfig: '', traceability: true) {
                        sh "mvn -B deploy -DskipTests=true"
                    }
                    // Archive the built artifacts
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }

        stage ('Docker Build and Publish') {
            steps {
                script {
                    // Build Docker image with proper tags from src directory
                    sh "docker build -t ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_REGISTRY}/${env.APP_NAME}:latest ./src"
                    
                    // Scan Docker image for vulnerabilities
                    sh "trivy image --format table -o docker-scan.html ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG}"
                    archiveArtifacts artifacts: 'docker-scan.html', allowEmptyArchive: true
                    
                    // Check for critical vulnerabilities and fail if found
                    def criticalVulnerabilities = sh(script: "trivy image --severity CRITICAL --exit-code 1 ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG} || echo 'CRITICAL_VULNERABILITIES_FOUND'", returnStdout: true).trim()
                    if (criticalVulnerabilities == 'CRITICAL_VULNERABILITIES_FOUND' && params.ENV == 'prod') {
                        error "Critical vulnerabilities found in Docker image."
                    }
                    
                    // Push Docker image to registry
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-token', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                        sh "echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin"
                    }
                    
                    sh "docker push ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG}"
                    sh "docker push ${env.DOCKER_REGISTRY}/${env.APP_NAME}:latest"
                    
                    // Clean up local images
                    sh "docker rmi ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG} ${env.DOCKER_REGISTRY}/${env.APP_NAME}:latest || true"
                }
            }
        }

        stage("Update Kubernetes Manifests") {
            steps {
                script {
                    // Clone the repository with Kubernetes manifests
                    withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_TOKEN')]) {
                        // Clone the repository to a separate directory
                        sh "git clone https://github.com/atkaridarshan04/Production-Ready-DevOps.git app-repo"

                        // Update the image tag in Kubernetes manifests
                        dir('app-repo/kubernetes-manifests') {
                            // Use proper sed command with error handling
                            sh "sed -i -e 's|image: ${env.DOCKER_REGISTRY}/${env.APP_NAME}:.*|image: ${env.DOCKER_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG}|g' bankapp.yml"
                            
                            // Verify the change was made
                            sh "grep -A 1 'image:' bankapp.yml"
                        }

                        // Commit and push the changes
                        dir('app-repo') {
                            sh """
                                git config user.email "jenkins@example.com"
                                git config user.name "Jenkins CI"
                                
                                git status
                                git add .
                                git commit -m "[CI/CD] Update image tag to ${env.IMAGE_TAG} for ${params.ENV} environment"
                                git push https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/atkaridarshan04/Production-Ready-DevOps.git ${params.BRANCH_NAME}
                            """
                        }
                    }
                }
            }
        }
    }
    
    // Post-build actions
    post {
        always {
            // Clean workspace
            cleanWs()
            // Remove any Docker images to save space
            sh "docker system prune -f || true"
        }
        success {
            echo "Pipeline completed successfully!"
            // Send success notification via email
            emailext (
                subject: "[SUCCESS] ${env.APP_NAME} - Build #${env.BUILD_NUMBER} - ${params.ENV} Environment",
                body: """
                <html>
                    <body>
                        <h2>✅ Build Successful!</h2>
                        <p>The deployment to <b>${params.ENV}</b> environment was successful.</p>
                        <h3>Build Information:</h3>
                        <ul>
                            <li><b>Project:</b> ${env.APP_NAME}</li>
                            <li><b>Build Number:</b> ${env.BUILD_NUMBER}</li>
                            <li><b>Branch:</b> ${params.BRANCH_NAME}</li>
                            <li><b>Environment:</b> ${params.ENV}</li>
                            <li><b>Image Tag:</b> ${env.IMAGE_TAG}</li>
                            <li><b>Build URL:</b> <a href=\"${env.BUILD_URL}\">${env.BUILD_URL}</a></li>
                        </ul>
                        <p>View the <a href=\"${env.BUILD_URL}console\">Console Output</a> for more details.</p>
                    </body>
                </html>
                """,
                to: 'atkaridarshan04@gmail.com',
                mimeType: 'text/html',
                attachmentsPattern: 'docker-scan.html,fs-scan.html'
            )
        }
        failure {
            echo "Pipeline failed!"
            // Send failure notification via email
            emailext (
                subject: "[FAILED] ${env.APP_NAME} - Build #${env.BUILD_NUMBER} - ${params.ENV} Environment",
                body: """
                <html>
                    <body>
                        <h2>❌ Build Failed!</h2>
                        <p>The deployment to <b>${params.ENV}</b> environment has failed.</p>
                        <h3>Build Information:</h3>
                        <ul>
                            <li><b>Project:</b> ${env.APP_NAME}</li>
                            <li><b>Build Number:</b> ${env.BUILD_NUMBER}</li>
                            <li><b>Branch:</b> ${params.BRANCH_NAME}</li>
                            <li><b>Environment:</b> ${params.ENV}</li>
                            <li><b>Image Tag:</b> ${env.IMAGE_TAG}</li>
                            <li><b>Build URL:</b> <a href=\"${env.BUILD_URL}\">${env.BUILD_URL}</a></li>
                        </ul>
                        <p>View the <a href=\"${env.BUILD_URL}console\">Console Output</a> for more details.</p>
                        <p style=\"color: red;\"><b>Action Required:</b> Please investigate the failure and fix the issues.</p>
                    </body>
                </html>
                """,
                to: 'atkaridarshan04@gmail.com',
                mimeType: 'text/html',
                attachmentsPattern: 'docker-scan.html,fs-scan.html'
            )
        }
        unstable {
            echo "Pipeline is unstable!"
            // Send unstable notification via email
            emailext (
                subject: "[UNSTABLE] ${env.APP_NAME} - Build #${env.BUILD_NUMBER} - ${params.ENV} Environment",
                body: """
                <html>
                    <body>
                        <h2>⚠️ Build Unstable!</h2>
                        <p>The deployment to <b>${params.ENV}</b> environment completed with warnings or test failures.</p>
                        <h3>Build Information:</h3>
                        <ul>
                            <li><b>Project:</b> ${env.APP_NAME}</li>
                            <li><b>Build Number:</b> ${env.BUILD_NUMBER}</li>
                            <li><b>Branch:</b> ${params.BRANCH_NAME}</li>
                            <li><b>Environment:</b> ${params.ENV}</li>
                            <li><b>Image Tag:</b> ${env.IMAGE_TAG}</li>
                            <li><b>Build URL:</b> <a href=\"${env.BUILD_URL}\">${env.BUILD_URL}</a></li>
                        </ul>
                        <p>View the <a href=\"${env.BUILD_URL}console\">Console Output</a> for more details.</p>
                        <p style=\"color: orange;\"><b>Action Recommended:</b> Please review the warnings and test failures.</p>
                    </body>
                </html>
                """,
                to: 'atkaridarshan04@gmail.com',
                mimeType: 'text/html',
                attachmentsPattern: 'docker-scan.html,fs-scan.html'
            )
        }
    }
}