SFDX + Jenkins + PMD Integration

This project demonstrates Salesforce DX (SFDX) development with Jenkins CI/CD and PMD code quality checks.

🔹 Branch Strategy

main → Production-ready code.

develop → Active development branch.

feature/* → Short-lived branches for new features or bug fixes.

🔹 Branch Protection Rules

Configured in GitHub under Settings → Branches:

main and develop are protected.

Direct pushes are blocked.

Pull Requests are required.

At least 1 reviewer approval is mandatory.

Jenkins status checks must pass before merging.

🔹 Jenkins CI/CD Setup

Pipeline type: Multibranch Pipeline (auto-discovers branches + PRs).

Jenkins authenticates with GitHub using a Personal Access Token (PAT).

Jenkinsfile defines the pipeline stages:

Checkout repository

Install/verify tools (Node, NPM, SFDX, Java, jq)

Ensure SFDX CLI is available

Authenticate with Salesforce (via stored SFDX Auth URL)

SFDX Validation Deploy (--checkonly) with test execution

Run PMD Apex static analysis

Archive reports as build artifacts

🔹 PMD Integration

PMD installed via Homebrew on Jenkins agent.

Custom ruleset file: apex-ruleset.xml in repo.

Reports generated:

pmd-output/pmd-report.xml

pmd-output/pmd-report.html

Artifacts archived for review in Jenkins.

Violations highlighted during PR checks.

🔹 Pull Request Workflow

Developer raises PR → feature/* → develop.

Jenkins runs automatically on PR:

SFDX validation deploy

RunLocalTests

PMD static analysis

Jenkins posts PR status back to GitHub.

PR merge is blocked until:

Jenkins checks pass ✅

Reviewer approval is given ✅

✅ Benefits

Enforces clean deployments (validation-only).

Ensures code quality with PMD.

Prevents direct pushes to protected branches.

Provides instant feedback on PRs via Jenkins → GitHub integration.
