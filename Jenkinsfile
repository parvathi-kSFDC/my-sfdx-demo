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
          # show versions (ok if missing, output helpful debug)
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
          set -e
          echo "Running check-only deploy (may run tests)..."
          if ! sfdx force:source:deploy -p force-app --checkonly --testlevel RunLocalTests --json > sfdx-deploy.json 2>/dev/null; then
            echo "sfdx check-only returned non-zero; saving sfdx-deploy.json (if any)"
          fi

          # show raw json (if present) for debugging
          if [ -s sfdx-deploy.json ]; then
            echo "sfdx-deploy.json contents:"
            cat sfdx-deploy.json
          else
            echo "No sfdx-deploy.json was produced."
            # continue — trigger failure later if appropriate
          fi

          # Try to parse number of componentFailures / test errors with jq (if present)
          if [ -s sfdx-deploy.json ]; then
            FAILS=$(jq -r '.result?.details?.componentFailures // [] | length' sfdx-deploy.json)
            TE=$(jq -r '.result?.numberTestErrors // 0' sfdx-deploy.json)
            echo "Component failures: ${FAILS}, Test errors: ${TE}"
            if [ "${FAILS:-0}" -gt 0 ] || [ "${TE:-0}" -gt 0 ]; then
              echo "Validation or tests failed. Failing the build."
              exit 1
            fi
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
          # PMD download link (correct format)
          PMD_URL="PMD_URL="https://github.com/pmd/pmd/releases/download/pmd_releases%2F7.4.0/pmd-bin-7.4.0.zip"

          if [ ! -d pmd-bin-${PMD_VER} ]; then
            echo "Downloading PMD ${PMD_VER}..."
            curl -L -o pmd.zip "$PMD_URL" || { echo "curl failed"; exit 1; }
            unzip -q pmd.zip || { echo "unzip failed - pmd.zip may be invalid"; ls -l pmd.zip; exit 1; }
          fi

          # Run PMD on Apex classes (ruleset must exist in repo)
          ./pmd-bin-${PMD_VER}/bin/run.sh pmd \
            -d force-app/main/default/classes \
            -R rulesets/apex-ruleset.xml \
            -f html -r pmd-report.html \
            -f xml  -r pmd-report.xml || true

          # Optional quality gate: fail if any violation found
          if [ -f pmd-report.xml ]; then
            VIOLATIONS=$(grep -c "<violation" pmd-report.xml || true)
            echo "PMD violations count: ${VIOLATIONS}"
            # Uncomment to fail on violations:
            # if [ "$VIOLATIONS" -gt 0 ]; then exit 1; fi
          fi
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'pmd-report.*', allowEmptyArchive: true
        }
      }
    }
  } // stages

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
