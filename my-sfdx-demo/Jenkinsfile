pipeline {
  agent any
  environment { SFDX_DISABLE_TELEMETRY = '1' }
  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Install SFDX') {
      steps {
        sh '''
        if ! command -v sfdx >/dev/null 2>&1; then
          npm i -g sfdx-cli@latest
        fi
        sfdx --version || true
        '''
      }
    }

    stage('Authenticate') {
      steps {
        withCredentials([string(credentialsId: 'SF_AUTH_URL', variable: 'SF_AUTH_URL')]) {
          sh '''
            echo "$SF_AUTH_URL" > sfdx.auth
            sfdx auth:sfdxurl:store -f sfdx.auth -s -a CI || true
            sfdx force:org:list --verbose || true
          '''
        }
      }
    }

    stage('Validate (check-only)') {
      steps {
        sh '''
          set -e
          sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json || EXIT=$?
          if [ "${EXIT:-0}" -ne 0 ]; then
            cat sfdx-deploy.json || true
            exit 1
          fi
        '''
      }
    }
  }
  post { always { archiveArtifacts artifacts: 'sfdx-deploy.json', allowEmptyArchive: true } }
}
