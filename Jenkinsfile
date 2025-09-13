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
        sfdx auth:sfdxurl:store -f sfdx.auth -s -a CI

        echo "Authenticated. Listing orgs..."
        sfdx force:org:list --verbose

        # NEW: confirm sf can see the alias too
        sf org display --target-org CI || { echo "sf cannot see alias CI"; exit 1; }
      '''
    }
  }
}


stage('SFDX Validation (check-only)') {
  steps {
    sh '''
      set -e
      echo "Running check-only validate (RunLocalTests) with sf CLI..."
      mkdir -p reports

      # Use source dir; if you prefer package.xml, swap to --manifest manifest/package.xml
      sf project deploy validate \
        --source-dir force-app \
        --target-org CI \
        --test-level RunLocalTests \
        --ignore-warnings \
        --wait 60 \
        --json > reports/sf-validate.json || true

      # Robust parse & fail on errors
      python3 - <<'PY'
import json, sys
p='reports/sf-validate.json'
try:
  data=json.load(open(p))
except Exception as e:
  print("No or invalid JSON:", e); sys.exit(1)

res=data.get('result', {}) or {}
# sf returns "success" boolean; also keep an eye on status
success = bool(res.get('success', False)) or res.get('status') in (0, '0')

det = res.get('details', {}) or {}
# component failures may be object or list
cf = det.get('componentFailures', [])
if isinstance(cf, dict): cf=[cf]
has_cf = len(cf) > 0

rtr = det.get('runTestResult', {}) or {}
num_fail = int(rtr.get('numFailures', 0) or 0)

if (not success) or has_cf or num_fail > 0:
  print(f"Validation failed: success={success}, compFailures={len(cf)}, testFailures={num_fail}")
  sys.exit(1)
else:
  print("Validation OK.")
PY
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/sf-validate.json', allowEmptyArchive: true
    }
  }
}

stage('Install Java + PMD') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      # --- Ensure Java 17+ ---
      if ! command -v java >/dev/null 2>&1; then
        echo "Installing Java 17..."
        brew install --cask temurin17 || brew install --cask zulu17
      fi
      java -version

      # --- Ensure PMD 7.x ---
      if ! command -v pmd >/dev/null 2>&1; then
        echo "Installing PMD..."
        brew install pmd
      fi
      pmd --version || true
    '''
  }
}


stage('Run PMD (Apex)') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      mkdir -p pmd-output

      # pick target dir (fallback if classes folder isn’t present)
      TARGET_DIR="force-app/main/default/classes"
      [ -d "$TARGET_DIR" ] || TARGET_DIR="force-app"

      RULESET="rulesets/apex-ruleset.xml"
      [ -f "$RULESET" ] || { echo "Ruleset $RULESET not found"; ls -la rulesets || true; exit 1; }

      # PMD 7 uses the 'check' subcommand
      pmd check -d "$TARGET_DIR" -R "$RULESET" -f xml  -r pmd-output/pmd-report.xml  || true
      pmd check -d "$TARGET_DIR" -R "$RULESET" -f html -r pmd-output/pmd-report.html || true

      [ -s pmd-output/pmd-report.xml ] || { echo "PMD XML not produced"; exit 1; }

      # OPTIONAL: fail build on any violations
      VIOL=$(grep -c "<violation" pmd-output/pmd-report.xml || echo 0)
      echo "PMD violations: $VIOL"
      # uncomment next line if you want failures to break the build
      # [ "$VIOL" -gt 0 ] && { echo "Failing due to PMD violations"; exit 1; }
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'pmd-output/*', allowEmptyArchive: false
      // comment this out unless you install the Warnings NG plugin
      // recordIssues enabledForFailure: true, tools: [pmdParser(pattern: 'pmd-output/pmd-report.xml')]
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
