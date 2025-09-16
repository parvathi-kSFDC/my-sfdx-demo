## 🔀 Handling Metadata Conflicts

Salesforce metadata often changes in shared components like Profiles, Layouts, or Flows.  
To minimize and resolve conflicts:

1. Use **SFDX source format** to split large files (reduces overlap).  
2. Always **merge latest develop** before opening PRs.  
3. Resolve conflicts manually using Git’s conflict markers.  
4. Validate merged metadata with `sf project deploy validate`.  
5. Rely on **Jenkins PR builds** to catch issues early.  

➡️ This ensures stable merges and prevents broken deployments to higher environments.


PR Validation with Jenkins (SFDX)

Validate every pull request (PR) with a Jenkins pipeline that runs a check-only deploy to Salesforce and fails fast on test or metadata errors.

🧰 Prerequisites

GitHub repo in SFDX source format (force-app/...)

Branches: main, develop, and feature/*

Jenkins with:

Multibranch Pipeline job using GitHub Branch Source (or Pipeline + GHPRB plugin)

A GitHub Personal Access Token credential for checkout

A secret text credential SF_AUTH_URL (org auth file content)

(Optional) Email Extension Plugin for notifications

GitHub webhook from the repo → your Jenkins URL (fires on PR + push)

🔒 Branch Protection (GitHub)

Protect main and develop:

Require Pull Request before merging

Require status checks to pass: the Jenkins build context (e.g., continuous-integration/jenkins/pr-head)

(Optional) Require code review approvals

🔁 Workflow (What happens on every PR)

Developer creates/updates a PR from feature/* → develop (or main).

GitHub sends a webhook → Jenkins.

Jenkins discovers the PR branch and runs Jenkinsfile:

Checks out code

Ensures Salesforce CLI

Authenticates using SF_AUTH_URL

Runs check-only validation with RunLocalTests

Fails on component/test errors

Jenkins reports status back to GitHub:

✅ Success → PR can be merged

❌ Failed → PR blocked until fixed

(Optional) Jenkins emails failure details to the team.

🧪 What the Pipeline Validates

Deployability of all changed metadata (no missing deps)

Apex tests (RunLocalTests) compile + pass

Basic org checks (e.g., API version) via sf project deploy validate


PMD Static Code Analysis (Apex)

This repository integrates PMD into the Jenkins pipeline to provide instant code quality feedback for Apex classes.

🧰 Prerequisites

Jenkins agent with:

Java 17+

curl + unzip



PMD ruleset file: rulesets/apex-ruleset.xml (in repo)

pmd.yml pipeline definition

⚙️ Workflow

On every PR or commit to the develop branch:

Jenkins checks out the repo

Installs Java + PMD

Runs PMD on all Apex classes under force-app/main/default/classes

Generates reports:

pmd-report.xml (machine-readable, CI tools)

pmd-report.html (human-friendly)

Uploads reports as build artifacts

GitHub PR → Jenkins → status check shows ✅ (clean) or ❌ (violations).

📄 Example pmd.yml
pipeline:
  agent any
  stages:
    - stage: Checkout
      steps:
        - checkout scm

    - stage: Install Java + PMD
      steps:
        - sh: |
            set -e
            PMD_VERSION="7.4.0"
            PMD_DIR="pmd-bin-${PMD_VERSION}"
            if [ ! -d "$PMD_DIR" ]; then
              curl -L -o pmd.zip \
                "https://github.com/pmd/pmd/releases/download/pmd_releases/${PMD_VERSION}/pmd-dist-${PMD_VERSION}-bin.zip"
              unzip -q pmd.zip
            fi
            $PMD_DIR/bin/pmd --version

    - stage: Run PMD
      steps:
        - sh: |
            set -e
            mkdir -p pmd-output
            TARGET="force-app/main/default/classes"
            RULESET="rulesets/apex-ruleset.xml"
            $PMD_DIR/bin/pmd check \
              -d "$TARGET" \
              -R "$RULESET" \
              -f xml -r pmd-output/pmd-report.xml
            $PMD_DIR/bin/pmd check \
              -d "$TARGET" \
              -R "$RULESET" \
              -f html -r pmd-output/pmd-report.html

    - stage: Archive Report
      steps:
        - archiveArtifacts: "pmd-output/*"

✅ Expected Outcomes

Jenkins job automatically runs on pull requests and develop commits.

PMD violations are visible in pmd-output/pmd-report.html.

PRs blocked until Jenkins status check is ✅ (if branch protection is enabled).

📚 Usage Notes

For Developers:

Run PMD locally before pushing:

./pmd-bin-7.4.0/bin/pmd check \
  -d force-app/main/default/classes \
  -R rulesets/apex-ruleset.xml \
  -f text


Fix violations before raising a PR.

For Reviewers:

Check Jenkins artifacts (pmd-report.html) for violations when reviewing PRs.

For Admins:

Customize rules in rulesets/apex-ruleset.xml (e.g., avoid empty catch blocks, enforce naming conventions).
