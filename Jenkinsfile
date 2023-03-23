//SCRIPTED

//DECLARATIVE
pipeline {
    agent {
        docker {
            image 'node:19-alpine3.16'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn --version'
            }
        }
        stage('Test') {
            steps {
                echo "Test"
            }
        }
        stage('Integration Test') {
            steps {
                echo "Integration Test"
            }
        }
    }
}
