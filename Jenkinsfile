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

        # Login (sets alias CI + default org)
        sf org login sfdx-url \
          --sfdx-url-file sfdx.auth \
          --alias CI \
          --set-default

        # Ensure reports dir exists before writing
        mkdir -p reports

        # Save org details
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

      # Skip if there’s nothing to deploy
      MD_COUNT=$(find force-app -type f \\( -name "*.cls" -o -name "*.trigger" -o -name "*.xml" -o -name "*.js" -o -name "*.page" -o -name "*.cmp" \\) | wc -l | tr -d ' ')
      if [ "$MD_COUNT" = "0" ]; then
        echo "No deployable metadata found in force-app. Skipping validation."
        echo '{"skipped":true,"reason":"no_metadata"}' > reports/sf-validate.json
        exit 0
      fi

      echo "Running check-only validate (RunLocalTests) with sf CLI..."
      # IMPORTANT: capture BOTH stdout (JSON) and stderr (diagnostics)
      # Increase wait so the job can finish even on a cold org.
      set +e
      sf project deploy validate \
        --source-dir force-app \
        --target-org CI \
        --test-level RunLocalTests \
        --ignore-warnings \
        --api-version 64.0 \
        --wait 300 \
        --json > reports/sf-validate.json 2> reports/sf-validate.stderr
      SF_EXIT=$?
      set -e

      # Show quick summary for debugging
      if command -v jq >/dev/null 2>&1 && [ -s reports/sf-validate.json ]; then
        echo "sf validate summary:"
        jq '{status:.status, message:.message, warnings:.warnings, name:.name, result_success:.result?.success, details_present: (.result?.details!=null)}' reports/sf-validate.json || true
      fi

      # If JSON missing, print stderr and fail
      if [ ! -s reports/sf-validate.json ]; then
        echo "No sf-validate.json produced (sf exit=$SF_EXIT). Stderr follows:"
        echo "---- reports/sf-validate.stderr ----"
        tail -n +1 reports/sf-validate.stderr || true
        exit 1
      fi

      # Robust parse & fail on real failures, but surface CLI errors too
      python3 - <<'PY'
import json, sys, pathlib
p = pathlib.Path('reports/sf-validate.json')
d = json.load(p.open())

# If we explicitly skipped
if d.get('skipped'):
  print("Validation skipped: no metadata.")
  sys.exit(0)

status = d.get('status')  # 0 ok, 1 error (CLI-level)
msg = d.get('message')

res = d.get('result') or {}
success = bool(res.get('success', False)) or res.get('status') in (0, '0')
det = (res.get('details') or {})

# componentFailures may be dict or list
cf = det.get('componentFailures', [])
if isinstance(cf, dict): cf = [cf]

rtr = det.get('runTestResult') or {}
num_fail = int(rtr.get('numFailures', 0) or 0)

# If CLI errored (status==1) and no details, print top-level message
if status == 1 and not det:
  print(f"CLI error (status=1): {msg or 'No message provided'}")
  sys.exit(1)

# Otherwise, this is a normal validation result — gate on failures
if (not success) or len(cf) > 0 or num_fail > 0:
  print(f"Validation failed: success={success}, compFailures={len(cf)}, testFailures={num_fail}")
  sys.exit(1)

print("Validation OK.")
PY
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/sf-validate.*', allowEmptyArchive: true
    }
  }
}


stage('Install Java + PMD') {
  steps {
    sh '''
      set -e
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      PMD_VERSION="7.4.0"
      PMD_DIR="${WORKSPACE}/pmd-bin-${PMD_VERSION}"

      echo "=== Ensure JDK 17 ==="
      # Try to locate JDK 17; install if missing (try multiple cask names)
      if ! /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
        echo "JDK 17 not found. Attempting install..."
        brew update || true
        brew install --cask temurin17 || brew install --cask temurin@17 || brew install --cask temurin
      fi

      if ! /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
        echo "ERROR: JDK 17 still not available after install." >&2
        exit 1
      fi

      export JAVA_HOME="$(
        /usr/libexec/java_home -v 17
      )"
      echo "JAVA_HOME=$JAVA_HOME"
      "$JAVA_HOME/bin/java" -version

      echo "=== Ensure PMD ${PMD_VERSION} locally ==="
      PMD_ZIP="pmd-dist-${PMD_VERSION}-bin.zip"
      if [ ! -d "$PMD_DIR" ]; then
        echo "Downloading PMD ${PMD_VERSION}..."
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

      PMD_VERSION="7.4.0"
      PMD_DIR="${WORKSPACE}/pmd-bin-${PMD_VERSION}"
      export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
      export PATH="$JAVA_HOME/bin:$PATH"

      mkdir -p pmd-output

      TARGET_DIR="force-app/main/default/classes"
      [ -d "$TARGET_DIR" ] || TARGET_DIR="force-app"

      APEX_COUNT=$(find "$TARGET_DIR" -type f -name "*.cls" | wc -l | tr -d ' ')
      if [ "$APEX_COUNT" = "0" ]; then
        echo "No Apex classes found under $TARGET_DIR. Skipping PMD."
        echo "<pmd/>" > pmd-output/pmd-report.xml
        exit 0
      fi

      RULESET="rulesets/apex-ruleset.xml"
      [ -f "$RULESET" ] || { echo "Ruleset $RULESET not found"; ls -la rulesets || true; exit 1; }

      echo "Running PMD ${PMD_VERSION} on $APEX_COUNT Apex files..."
      "${PMD_DIR}/bin/pmd" check \
        -d "$TARGET_DIR" \
        -R "$RULESET" \
        -f xml  -r pmd-output/pmd-report.xml \
        --no-fail-on-violation

      "${PMD_DIR}/bin/pmd" check \
        -d "$TARGET_DIR" \
        -R "$RULESET" \
        -f html -r pmd-output/pmd-report.html \
        --no-fail-on-violation
    '''
  }
 post {
  always {
    archiveArtifacts artifacts: 'pmd-output/*', allowEmptyArchive: true
    script {
      // Produce ONE clean number for the count
      def violStr = sh(
        returnStdout: true,
        script: '''
          if [ -s pmd-output/pmd-report.xml ]; then
            # Count <violation occurrences; wc -l always exits 0 and prints a single number
            grep -o "<violation" pmd-output/pmd-report.xml | wc -l | tr -d " "
          else
            echo 0
          fi
        '''
      ).trim()

      echo "PMD violations: ${violStr}"

      // If you want to BLOCK the build on violations:
      // if (violStr.isInteger() && violStr.toInteger() > 0) {
      //   error("Failing due to ${violStr} PMD violation(s)")
      // }

      // If you prefer to pass the build but mark it UNSTABLE instead:
      // if (violStr.isInteger() && violStr.toInteger() > 0) {
      //   currentBuild.result = 'UNSTABLE'
      //   echo "Marking build UNSTABLE due to ${violStr} PMD violation(s)"
      // }
    }
  }
}
}



  } // end stages

 post {
  always {
    echo "Pipeline finished: ${currentBuild.currentResult}"
  }
  failure {
    echo "Build failed. Sending email..."
    emailext(
      subject: "Jenkins Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      body: """<p>Build <b>${env.JOB_NAME} #${env.BUILD_NUMBER}</b> has failed.</p>
               <p><b>Branch:</b> ${env.BRANCH_NAME}</p>
               <p><b>Commit:</b> ${env.GIT_COMMIT}</p>
               <p><a href="${env.BUILD_URL}">Click here to view the build logs</a></p>""",
      to: "parvathi@example.com"
    )
  }
}

}
