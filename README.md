# Copado Source Format Pipeline – Exercises

This repository documents three exercises for implementing DevOps best practices with Salesforce using **Copado Source Format Pipeline (SFP)**:

1. Setting Up a Source Format Pipeline  
2. Committing Changes in Source Format  
3. Deploying Changes with Quality Gates  

---

## 1. Setting Up a Source Format Pipeline

### Description
Create and configure a new **Salesforce Source Format Pipeline** in the Copado Playground. The pipeline uses Salesforce DX (SFDX) source format to manage metadata in a modular, source-driven way.

### Requirements
- Access to **Copado Playground** (via setup wizard or provided org).  
- A connected **Git repository** (e.g., GitHub/Bitbucket) with permissions.  
- Familiarity with Salesforce orgs (scratch orgs or sandboxes).  
- Basic Copado knowledge (Fundamentals certification recommended).  

### Steps
1. Go to **Copado Setup → Pipelines → New Pipeline**.  
2. Select **Source Format Pipeline**.  
3. Add environments (e.g., `Development`, `QA`).  
4. Connect each environment to its Salesforce org credential.  
5. Link the pipeline to your Git branch (SFDX repo).  
6. Validate pipeline → ensure no errors in Copado logs.  

### Expected Outcomes
- A fully functional Source Format Pipeline with Dev → QA flow.  
- Pipeline connected to GitHub with initial metadata in SFDX format.  
- Successful connection validation (no errors/warnings).  

### Assessment
- Show pipeline creation in Copado UI.  
- Submit screenshots of **pipeline overview**, **environments**, and **Git integration**.  
- Demonstrate pipeline ID or logs confirming setup.  
- Answer quiz on pipeline components (environments, credentials, Git repo).  

---

## 2. Committing Changes in Source Format

### Description
Make a metadata change in a Salesforce dev org, convert it into **SFDX source format**, and commit it to Git via Copado. Focus on **atomic commits** (one change per commit) and maintaining clean structure.

### Requirements
- Copado Playground with an existing Source Format Pipeline.  
- Tools like **Salesforce Developer Console** or **VS Code + SFDX CLI**.  
- Git account with push permissions.  
- Basic Git + SFDX knowledge.  

### Steps
1. In **Dev org**, make a change (e.g., add custom field or update layout).  
2. In Copado, go to **User Story → Commit Changes**.  
3. Select the changed components.  
4. Commit to GitHub (stored in `force-app/main/default/...`).  
5. Verify the commit in GitHub history with a clear message.  

### Expected Outcomes
- Metadata changes successfully converted & committed in SFDX format.  
- Commit visible in GitHub history with descriptive commit message.  
- No conflicts or formatting issues (e.g., XML well-formed).  

### Assessment
- Show commit details in GitHub (diff view).  
- Validate folder structure (SFDX format).  
- Ensure commit messages follow best practices (e.g., `US-1234 | Added custom field to Account`).  
- Provide commit hash or repository link for inspection.  

---

## 3. Deploying Changes with Quality Gates

### Description
Promote and deploy the committed changes through the **Source Format Pipeline** (Dev → QA). Use **quality gates** to simulate CI/CD with quality assurance.  

Quality Gates to configure:  
1. **PMD check** for static code analysis.  
2. **85% Apex test coverage**.  
3. **PR approval** (via GitHub or Copado).  

### Requirements
- Completed pipeline setup + committed changes.  
- At least 2 connected Salesforce orgs (Dev + QA).  
- PMD ruleset configured in Copado.  
- Apex tests in the org.  
- GitHub PR approval workflow enabled.  

### Steps
1. In Copado, go to the **User Story** → **Promote to QA**.  
2. Pipeline runs:  
   - Validate deployment with Apex tests.  
   - Run PMD static analysis.  
   - Check for PR approval.  
3. Only after passing all gates does deployment proceed.  

### Expected Outcomes
- Changes promoted successfully from Dev → QA.  
- PMD passes with no critical violations.  
- Apex test coverage ≥ 85%.  
- PR approval completed.  
- Changes visible in QA org (e.g., custom field appears in Setup).  

### Assessment
- Show **Deployment Results** in Copado dashboard (logs + Quality Gate results).  
- Open **PMD scan report** (highlight rule checks).  
- Validate test coverage in Copado report.  
- Show PR approval in GitHub/Copado logs.  
- Demonstrate deployed change in QA org.  
- Submit deployment notes (conflicts, results, quality gates).  
- Explain why quality gates are important in CI/CD.  

---

# ✅ Summary
- **Pipeline Setup** → Provides a structured flow (Dev → QA) with Git integration.  
- **Commit Process** → Ensures clean, traceable changes in SFDX format.  
- **Quality Gates Deployment** → Enforces static analysis (PMD), test coverage, and approvals before deployment.  

Together, these exercises demonstrate a **full Copado SFP workflow** for secure, automated Salesforce DevOps.
