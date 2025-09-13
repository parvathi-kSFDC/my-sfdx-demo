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

    stage('Ensure Salesforce CLI (sf)') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      # Uninstall legacy sfdx-cli if present on PATH to avoid conflicts
      if command -v sfdx >/dev/null 2>&1; then
        echo "Legacy sfdx-cli detected: $(sfdx --version || true)"
        npm uninstall -g sfdx-cli || true
      fi

      # Ensure new Salesforce CLI
      if ! command -v sf >/dev/null 2>&1; then
        echo "Installing @salesforce/cli (sf)..."
        npm install -g @salesforce/cli@latest --no-audit --no-fund
      fi
      sf --version
    '''
  }
}


   stage('Authenticate to Salesforce') {
  steps {
    withCredentials([string(credentialsId: 'SF_AUTH_URL', variable: 'SF_AUTH_URL')]) {
      sh '''
        set -e
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        echo "$SF_AUTH_URL" > sfdx.auth

        # Use sf (new CLI). This sets alias CI and default org.
        sf org login sfdx-url \
          --sfdx-url-file sfdx.auth \
          --alias CI \
          --set-default

        # Quick sanity check
        sf org display --target-org CI --verbose --json > reports/sf-org.json
      '''
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/sf-org.json', allowEmptyArchive: true
    }
  }
}



stage('SFDX Validation (check-only)') {
  steps {
    sh '''
      set -e
      mkdir -p reports
      sf project deploy validate \
        --source-dir force-app \
        --target-org CI \
        --test-level RunLocalTests \
        --ignore-warnings \
        --wait 60 \
        --json > reports/sf-validate.json || true

      [ -s reports/sf-validate.json ] || { echo "No sf-validate.json produced"; exit 1; }

      python3 - <<'PY'
import json, sys
d=json.load(open('reports/sf-validate.json'))
res=d.get('result',{}) or {}
success=bool(res.get('success',False)) or res.get('status') in (0,'0')
det=res.get('details',{}) or {}
cf=det.get('componentFailures',[])
if isinstance(cf,dict): cf=[cf]
rtr=det.get('runTestResult',{}) or {}
nf=int(rtr.get('numFailures',0) or 0)
if (not success) or len(cf)>0 or nf>0:
  print(f"Validation failed: success={success}, compFailures={len(cf)}, testFailures={nf}")
  sys.exit(1)
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

      echo "=== Check/Install JDK 17 ==="
      # Apple's stub 'java' exists even when no JDK is installed. Detect real JDK via java_home
      if ! /usr/libexec/java_home -V >/dev/null 2>&1; then
        echo "No JDK found. Installing Temurin 17..."
        brew install --cask temurin17
      fi

      # Prefer an explicit JAVA_HOME for reliability
      export JAVA_HOME=$(/usr/libexec/java_home -v 17)
      echo "JAVA_HOME=$JAVA_HOME"
      "$JAVA_HOME/bin/java" -version

      echo "=== Ensure PMD locally (zip) ==="
      PMD_VERSION="7.4.0"
      PMD_ZIP="pmd-dist-${PMD_VERSION}-bin.zip"
      PMD_DIR="${WORKSPACE}/pmd-bin-${PMD_VERSION}"

      if [ ! -d "$PMD_DIR" ]; then
        echo "Downloading PMD $PMD_VERSION..."
        curl -L -o "$PMD_ZIP" "https://github.com/pmd/pmd/releases/download/pmd_releases/${PMD_VERSION}/${PMD_ZIP}"
        unzip -q -o "$PMD_ZIP" -d "${WORKSPACE}"
      fi
      "${PMD_DIR}/bin/pmd" --version
    '''
  }
}

stage('Run PMD (Apex)') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
      export JAVA_HOME=$(/usr/libexec/java_home -v 17)
      PMD_DIR=$(echo "${WORKSPACE}/pmd-bin-"7.*)

      mkdir -p pmd-output

      # pick target dir (fallback if classes folder isn’t present)
      TARGET_DIR="force-app/main/default/classes"
      [ -d "$TARGET_DIR" ] || TARGET_DIR="force-app"

      # If there are zero Apex classes, skip gracefully
      APEX_COUNT=$(find "$TARGET_DIR" -type f -name "*.cls" | wc -l | tr -d ' ')
      if [ "$APEX_COUNT" = "0" ]; then
        echo "No Apex classes found under $TARGET_DIR. Skipping PMD."
        echo "<pmd/>" > pmd-output/pmd-report.xml
        exit 0
      fi

      RULESET="rulesets/apex-ruleset.xml"
      [ -f "$RULESET" ] || { echo "Ruleset $RULESET not found"; ls -la rulesets || true; exit 1; }

      echo "Running PMD on $APEX_COUNT Apex files..."
      "${PMD_DIR}/bin/pmd" check \
        -d "$TARGET_DIR" \
        -R "$RULESET" \
        -f xml  -r pmd-output/pmd-report.xml

      "${PMD_DIR}/bin/pmd" check \
        -d "$TARGET_DIR" \
        -R "$RULESET" \
        -f html -r pmd-output/pmd-report.html

      [ -s pmd-output/pmd-report.xml ] || { echo "PMD XML not produced"; exit 1; }

      VIOL=$(grep -c "<violation" pmd-output/pmd-report.xml || echo 0)
      echo "PMD violations: $VIOL"
      # Uncomment to fail build on any violations:
      # [ "$VIOL" -gt 0 ] && { echo "Failing due to PMD violations"; exit 1; }
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'pmd-output/*', allowEmptyArchive: false
      // Remove this unless you’ve installed the "Warnings Next Generation" plugin:
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
