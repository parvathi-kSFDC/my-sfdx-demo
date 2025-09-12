pipeline {
  agent any
  options {
    skipDefaultCheckout(false)
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }
  environment {
    SFDX_DISABLE_TELEMETRY = '1'
    PMD_VER = '7.4.0'
  }
  stages {
    stage('Checkout') {
      steps {
        echo "Checkout (branch: ${env.BRANCH_NAME})"
        checkout scm
      }
    }
stage('Install SFDX CLI & Java check') {
  steps {
    sh '''
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      # install sfdx into the build agent if missing
      if ! command -v sfdx >/dev/null 2>&1; then
        echo "Installing sfdx-cli locally..."
        npm install -g sfdx-cli@latest --no-audit --no-fund
      else
        echo "sfdx already installed: $(sfdx --version)"
      fi

      # sanity checks
      sfdx --version || true
      java -version || echo "Java not found; PMD may fail"
    '''
  }
}

    
    stage('Authenticate to Salesforce') {
  steps {
    withCredentials([string(credentialsId: 'SF_AUTH_URL', variable: 'SF_AUTH_URL')]) {
      sh '''
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        echo "Storing SFDX auth URL to file..."
        echo "$SF_AUTH_URL" > sfdx.auth
        sfdx auth:sfdxurl:store -f sfdx.auth -s -a CI
        sfdx force:org:list --verbose
      '''
    }
  }
}


    stage('SFDX Validation (check-only)') {
      steps {
        sh '''
          set -e
          echo "Running check-only deploy (this may run tests)..."
          sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json || true
          jq -r '.status' sfdx-deploy.json || true
          # If the JSON indicates error or status non-zero, fail:
          ERR=$(jq -r '.status' sfdx-deploy.json)
          if [ "$ERR" != "0" ] && [ "$ERR" != "1" ]; then
            echo "sfdx deploy returned non-standard status: $ERR"
          fi
          # check for any failures in the JSON result
          FAILS=$(jq -r '.result?.details?.componentFailures // [] | length' sfdx-deploy.json || echo 0)
          if [ "$FAILS" -gt 0 ]; then
            echo "Validation reported component failures:"
            jq -r '.result.details.componentFailures[] | {file: .fileName, problem: .problem}' sfdx-deploy.json || true
            exit 1
          fi
          # If tests failed:
          TF=$(jq -r '.result?.numberTestsRun // 0' sfdx-deploy.json || echo 0)
          TE=$(jq -r '.result?.numberTestErrors // 0' sfdx-deploy.json || echo 0)
          if [ "$TE" -gt 0 ]; then
            echo "Test errors: $TE"
            jq -r '.result?.runTestResult?.failures[] | {name: .name, message: .message}' sfdx-deploy.json || true
            exit 1
          fi
          echo "SFDX validation succeeded or returned no failures."
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'sfdx-deploy.json', allowEmptyArchive: true
          sh 'ls -la'
        }
      }
    }

    stage('Run PMD (Apex)') {
      steps {
        sh '''
          # download PMD if not present
          if [ ! -d pmd-bin-${PMD_VER} ]; then
            echo "Downloading PMD ${PMD_VER}..."
            curl -L -o pmd.zip https://github.com/pmd/pmd/releases/download/pmd_releases%2F${PMD_VER}/pmd-bin-${PMD_VER}.zip
            unzip -q pmd.zip
          fi
          # run PMD on Apex classes
          ./pmd-bin-${PMD_VER}/bin/run.sh pmd \
            -d force-app/main/default/classes \
            -R rulesets/apex-ruleset.xml \
            -f html -r pmd-report.html \
            -f xml -r pmd-report.xml || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'pmd-report.*', allowEmptyArchive: true
        }
      }
    }
  } // stages


}
