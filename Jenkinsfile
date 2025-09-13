pipeline {
  agent any

  environment {
    PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${env.PATH}"
    SF_DISABLE_TELEMETRY = '1'    // newer env var to avoid telemetry warnings
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
          # show both CLIs if present
          sfdx --version 2>/dev/null || true
          sf --version 2>/dev/null || true
          java -version || echo "java missing (PMD may fail)"
          jq --version || echo "jq missing"
        '''
      }
    }

    stage('Ensure SFDX CLI (if needed)') {
      steps {
        sh '''
          # prefer preinstalled CLI; install only if absolutely missing
          if ! command -v sfdx >/dev/null 2>&1 && ! command -v sf >/dev/null 2>&1; then
            echo "No Salesforce CLI found, installing sfdx-cli via npm..."
            npm install -g sfdx-cli@latest --no-audit --no-fund || { echo "npm install failed"; exit 1; }
          else
            echo "Salesforce CLI present."
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
            if ! sfdx auth:sfdxurl:store -f sfdx.auth -s -a CI 2>/dev/null; then
              # try 'sf' equivalent (if installed)
              if command -v sf >/dev/null 2>&1; then
                echo "sfdx auth failed; attempting sf auth:sfdxurl:store..."
                sf auth:sfdxurl:store -f sfdx.auth -s -a CI || { echo "Auth store failed (sf)"; exit 1; }
              else
                echo "Auth store failed and 'sf' not found"; exit 1
              fi
            fi
            echo "Authenticated. Listing orgs..."
            sfdx force:org:list --verbose 2>/dev/null || sf org list --verbose 2>/dev/null || true
          '''
        }
      }
    }

    stage('SFDX Validation (check-only)') {
      steps {
        sh '''
          set +e
          echo "Running check-only deploy (may run tests)..."

          # remove previous files
          rm -f sfdx-deploy.json sfdx-deploy.stderr

          # Try legacy sfdx command first (most scripts expect this)
          if command -v sfdx >/dev/null 2>&1; then
            echo "Using sfdx CLI..."
            sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json 2> sfdx-deploy.stderr
            SFDX_EXIT=$?
          else
            # Fallback to 'sf' modern CLI (command names differ)
            if command -v sf >/dev/null 2>&1; then
              echo "Using sf CLI fallback..."
              # Use source-dir or project deploy start depending on installed version
              # Try sf project deploy start (newer)
              sf project deploy start --source-dir force-app --check-only --test-level RunLocalTests --json > sfdx-deploy.json 2> sfdx-deploy.stderr
              SFDX_EXIT=$?
            else
              echo "No Salesforce CLI found!" > sfdx-deploy.stderr
              SFDX_EXIT=127
            fi
          fi

          echo "sfdx exit code: ${SFDX_EXIT:-unknown}"
          echo "----- sfdx stderr (if any) -----"
          sed -n '1,200p' sfdx-deploy.stderr || true
          echo "--------------------------------"

          # If CLI didn't produce JSON, show failure and exit
          if [ ! -s sfdx-deploy.json ]; then
            echo "ERROR: sfdx did NOT produce sfdx-deploy.json. See stderr above."
            echo "Check authentication, CLI version, or whether sfdx crashed."
            exit 1
          fi

          # Parse results with jq
          FAILS=$(jq -r '.result?.details?.componentFailures // [] | length' sfdx-deploy.json)
          TE=$(jq -r '.result?.numberTestErrors // 0' sfdx-deploy.json)
          echo "Component failures: ${FAILS}, Test errors: ${TE}"

          if [ "${FAILS:-0}" -gt 0 ] || [ "${TE:-0}" -gt 0 ]; then
            echo "Validation or tests failed. Failing the build."
            jq '.' sfdx-deploy.json || true
            exit 1
          fi

          echo "SFDX validation passed (or no failures reported)."
          set -e
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'sfdx-deploy.json, sfdx-deploy.stderr', allowEmptyArchive: true
        }
      }
    }

    stage('Run PMD (Apex)') {
      steps {
        sh '''
          export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
          if ! command -v pmd >/dev/null 2>&1; then
            echo "Installing pmd via brew..."
            brew update || true
            brew install pmd || { echo "brew install pmd failed"; exit 1; }
          else
            echo "pmd available: $(pmd --version 2>/dev/null || true)"
          fi
          mkdir -p pmd-output
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
  }

  post {
    always {
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
    failure {
      echo "Build failed. Check console output and archived artifacts."
    }
  }
}
