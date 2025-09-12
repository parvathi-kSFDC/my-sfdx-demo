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
          # If sfdx missing, try install via npm (requires npm present)
          if ! command -v sfdx >/dev/null 2>&1; then
            echo "Installing sfdx-cli..."
            npm install -g sfdx-cli@latest --no-audit --no-fund || { echo "npm install sfdx-cli failed"; exit 1; }
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
            # ensure PATH again (safe)
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

            echo "Storing SFDX auth URL to file..."
            echo "$SF_AUTH_URL" > sfdx.auth
            # attempt to store auth; fail if it errors
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
          #!/bin/bash
          # Ensure npm global bin in PATH (so npm-installed sfdx is found)
          export PATH="$(npm bin -g 2>/dev/null):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

          echo "Running check-only deploy (may run tests)..."
          # allow non-zero so we can inspect json output even when deploy fails
          set +e

          # Remove any old outputs
          rm -f sfdx-deploy.json sfdx-deploy.stderr

          # Run sfdx and capture JSON stdout + stderr separately
          sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json 2> sfdx-deploy.stderr
          SFDX_EXIT=$?

          echo "sfdx exit code: ${SFDX_EXIT}"
          echo "----- sfdx stderr (if any) -----"
          if [ -s sfdx-deploy.stderr ]; then
            cat sfdx-deploy.stderr
          else
            echo "(no stderr)"
          fi
          echo "--------------------------------"

          # If we have JSON output, parse it
          if [ -s sfdx-deploy.json ]; then
            echo "sfdx-deploy.json contents:"
            jq . sfdx-deploy.json || cat sfdx-deploy.json

            # Extract component failure count and number test errors
            FAILS=$(jq -r '.result?.details?.componentFailures // [] | length' sfdx-deploy.json 2>/dev/null || echo 0)
            TE=$(jq -r '.result?.numberTestErrors // 0' sfdx-deploy.json 2>/dev/null || echo 0)

            echo "Component failures: ${FAILS}, Test errors: ${TE}"

            if [ "${FAILS:-0}" -gt 0 ] || [ "${TE:-0}" -gt 0 ]; then
              echo "Validation or tests failed. Failing the build."
              exit 1
            fi

            # If sfdx exited non-zero but JSON shows no failures, treat as success for now.
            # If you prefer to fail whenever sfdx exit != 0, uncomment the following line:
            # exit ${SFDX_EXIT}

          else
            # No JSON produced — fatal (likely CLI crash, auth fail, or unexpected error)
            echo "ERROR: sfdx did NOT produce sfdx-deploy.json. See stderr above."
            echo "Check authentication, CLI version, or whether sfdx crashed."
            exit 1
          fi

          echo "SFDX validation passed (no component failures or test errors)."
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
          # adjust ruleset path if needed (rulesets/apex-ruleset.xml in repo)
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
    }
  }
}
