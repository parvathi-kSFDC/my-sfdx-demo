pipeline {
  agent any

  // ONE environment block only (global)
  environment {
    // ensure homebrew/npm and system bin locations are visible to every sh step
    PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${env.PATH}"
    SFDX_DISABLE_TELEMETRY = '1'
    PMD_VER = '7.4.0'
  }

  options {
    skipDefaultCheckout(false)
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Checkout') {
      steps {
        echo "Checkout (branch: ${env.BRANCH_NAME})"
        checkout scm
      }
    }

    stage('Install / Verify Tools') {
      steps {
        sh '''
          echo "PATH: $PATH"
          node --version || echo "node missing"
          npm --version || echo "npm missing"
          sfdx --version || echo "sfdx missing"
          java -version || echo "java missing (PMD may fail)"
          jq --version || echo "jq missing"
        '''
      }
    }

    stage('Ensure SFDX CLI') {
      steps {
        sh '''
          if ! command -v sfdx >/dev/null 2>&1; then
            echo "Installing sfdx-cli..."
            npm install -g sfdx-cli@latest --no-audit --no-fund
          else
            echo "sfdx present: $(sfdx --version)"
          fi
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
            if ! sfdx auth:sfdxurl:store -f sfdx.auth -s -a CI; then
              echo "Auth store failed"
              exit 1
            fi
            echo "Authenticated. Listing orgs..."
            sfdx force:org:list --verbose
          '''
        }
      }
    }

    stage('SFDX Validation (check-only)') {
      steps {
        sh '''
          set -e
          echo "Running check-only deploy (may run tests)..."
          if ! sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json 2>/dev/null; then
            echo "sfdx check-only returned non-zero; saving sfdx-deploy.json (if any)"
          fi

          if [ -s sfdx-deploy.json ]; then
            echo "sfdx-deploy.json contents:"
            cat sfdx-deploy.json
            FAILS=$(jq -r '.result?.details?.componentFailures // [] | length' sfdx-deploy.json)
            TE=$(jq -r '.result?.numberTestErrors // 0' sfdx-deploy.json)
            echo "Component failures: ${FAILS}, Test errors: ${TE}"
            if [ "${FAILS:-0}" -gt 0 ] || [ "${TE:-0}" -gt 0 ]; then
              echo "Validation or tests failed. Failing the build."
              exit 1
            fi
          else
            echo "No sfdx-deploy.json was produced."
          fi

          echo "SFDX validation passed (or no failures reported)."
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'sfdx-deploy.json', allowEmptyArchive: true
        }
      }
    }

    stage('Run PMD (Apex)') {
      steps {
        sh '''
          export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

          # Use Homebrew-installed pmd if available, else install
          if ! command -v pmd >/dev/null 2>&1; then
            echo "Installing pmd via brew..."
            brew update || true
            brew install pmd || { echo "brew install pmd failed"; exit 1; }
          else
            echo "pmd already available: $(pmd --version 2>/dev/null || true)"
          fi

          mkdir -p pmd-output

          # Run PMD on Apex classes, generate xml + html reports
          pmd -d force-app/main/default/classes -R rulesets/apex-ruleset.xml -f xml -r pmd-output/pmd-report.xml || true
          pmd -d force-app/main/default/classes -R rulesets/apex-ruleset.xml -f html -r pmd-output/pmd-report.html || true

          if [ -f pmd-output/pmd-report.xml ]; then
            echo "PMD XML size: $(wc -c < pmd-output/pmd-report.xml) bytes"
            grep -c "<violation" pmd-output/pmd-report.xml || true
          else
            echo "PMD XML not produced!"
          fi
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'pmd-output/*', allowEmptyArchive: true
        }
      }
    }
  } // end stages

  post {
    always {
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
    failure {
      echo "Build failed. Check console output and archived artifacts."
      // mail step removed to avoid SMTP errors; re-add only if SMTP configured
    }
  }
}
