pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Hello World') {
            steps {
                echo 'Jenkins is working with GitHub!'
            }
        }
    }
}
