//SCRIPTED

//DECLARATIVE
pipeline {
    agent {
        docker {
            image 'maven:3.9'
            label 'my-defined-label'
            args '-v $HOME/.m2:/root/.m2'
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
