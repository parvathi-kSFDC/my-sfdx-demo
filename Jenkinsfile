pipeline {
  agent any

  // ONE environment block only (global)
  environment {
    // ensure homebrew/npm and system bin locations are visible to every sh step
    PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${env.PATH}"
    SF_DISABLE_TELEMETRY = '1'
    PMD_VER = '7.4.0'
    RULESET = 'rulesets/apex-ruleset.xml'
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
      echo "Running check-only deploy (RunLocalTests)..."
      mkdir -p reports

      sfdx force:source:deploy \
        -p force-app \
        --checkonly \
        --testlevel RunLocalTests \
        --json > reports/sfdx-deploy.json || true

      # Parse result robustly (componentFailures can be object or array)
      python3 - <<'PY'
import json, sys
with open("reports/sfdx-deploy.json") as f:
  data=json.load(f)
res=data.get("result", {})
status_ok = (res.get("status")==0) or res.get("success", False)

det = res.get("details", {}) or {}
cf = det.get("componentFailures", [])
if isinstance(cf, dict): cf=[cf]
has_cf = len(cf)>0

rtr = det.get("runTestResult", {}) or {}
num_fail = int(rtr.get("numFailures", 0) or 0)

if (not status_ok) or has_cf or num_fail>0:
  print(f"Validation failed: status_ok={status_ok}, compFailures={len(cf)}, testFailures={num_fail}")
  sys.exit(1)
else:
  print("Validation OK.")
PY
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/sfdx-deploy.json', allowEmptyArchive: true
    }
  }
}


stage('Run PMD (Apex)') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      # Ensure Java 17+ for PMD
      if ! command -v java >/dev/null 2>&1; then
        echo "Installing Java 17..."
        brew install --cask temurin17 || brew install --cask zulu17 || true
      fi
      java -version || { echo "Java not available; PMD needs Java 17+"; exit 1; }

      # Ensure PMD (Homebrew provides PMD 7.x on mac)
      if ! command -v pmd >/dev/null 2>&1; then
        echo "Installing PMD..."
        brew install pmd
      fi
      pmd --version || true

      mkdir -p pmd-output

      # pick target dir (fallback if classes folder isn’t present)
      TARGET_DIR="force-app/main/default/classes"
      [ -d "$TARGET_DIR" ] || TARGET_DIR="force-app"

      # ruleset path from env (you added RULESET above)
      [ -f "$RULESET" ] || { echo "Ruleset $RULESET not found"; ls -la rulesets || true; exit 1; }

      # PMD **7** syntax uses the 'check' subcommand
      pmd check -d "$TARGET_DIR" -R "$RULESET" -f xml  -r pmd-output/pmd-report.xml  || true
      pmd check -d "$TARGET_DIR" -R "$RULESET" -f html -r pmd-output/pmd-report.html || true

      # must exist to avoid empty archives
      [ -s pmd-output/pmd-report.xml ] || { echo "PMD XML not produced"; exit 1; }

      echo "Violations: $(grep -c "<violation" pmd-output/pmd-report.xml || echo 0)"
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'pmd-output/*', allowEmptyArchive: false
      recordIssues enabledForFailure: true, tools: [pmdParser(pattern: 'pmd-output/pmd-report.xml')]
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
