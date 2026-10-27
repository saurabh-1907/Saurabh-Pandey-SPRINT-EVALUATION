# Enterprise PSA – SAP CAP + SAP HANA Cloud + SAP Fiori (UI5) + XSUAA

Professional Services Automation app built with the SAP Cloud Application Programming Model.
Requirements: [`requiremnets.txt`](requiremnets.txt) and [`docs/requirements`](docs/requirements).

## Problem → Solution

| Problem                                              | How this project solves it |
|------------------------------------------------------|----------------------------|
| **Scope creep** – a task burns hours unseen          | Approved hours update each task's `actual_hours` / `burn_pct`; alerts are raised at **75 %, 90 %, 100 %** of a task estimate or project budget |
| **No real-time tracking** – budget seen at month end | When an admin approves a timesheet, hours roll up instantly: Entry → Task → Milestone → Project → Budget |
| **Disconnected invoicing** – spreadsheets            | `generateInvoice` builds the invoice from approved billable hours (T&M, Fixed, Retainer); billed hours are linked so they are never billed twice |

## Data model (same style as the reference SAP-Repository project)

Hierarchy from requirements.txt:

```
Client ──< Project ──1 Budget
              │
              └──< Milestone ──< Task ──< TimesheetEntry >── Timesheet >── Employee
Project ──< Invoice      Project ──< Alert
```

| File | Content |
|---|---|
| `db/common.cds` | reusable types (`Guid`, `Email`, `String255`, `AmountT` …), status enums, aspects `Amount` and `Address` |
| `db/master.cds` | `context master`: **Clients** (uses `common.Address`), **Employees** (`cuid`, a manager = `isManager = true`) |
| `db/schema.cds` | `context transaction`: **Projects**, **Budgets** (1 per project), **Milestones**, **Tasks**, **Timesheets** (header: one employee, one week), **TimesheetEntries** (items: one day, one task, linked with `PARENT`), **Invoices** (uses `common.Amount`), **Alerts** |

Like the reference project: keys are `key NODE_KEY : common.Guid`, fields are UPPERCASE,
items point to their header with `PARENT`, CSV files are named `psa.db-master.*.csv` / `psa.db-transaction.*.csv`,
and the service exposes projections named `...Srv` (`ProjectSrv`, `TimesheetSrv` …).

Simplified vs. the FRD: Manager merged into Employees, Department left out.

## Technology

Only SAP technology is used:

| Layer | Technology |
|---|---|
| Database | **SAP HANA Cloud** (HDI container, plan `hdi-shared`) |
| Backend | **SAP CAP** (Node.js), OData V4 |
| UI | **SAP Fiori Elements** apps (SAPUI5) in a **SAP Fiori launchpad** (sandbox) |
| Login / roles | **XSUAA** (plan `application`) + **SAP Approuter** |

(SQLite is only a dev-dependency so that `npm test` can run without HANA.)

## Users and roles (XSUAA)

| Role collection | Role | Sees in the launchpad | Can do |
|---|---|---|---|
| **PSA_Admin** | Admin | admin home page + all 6 apps | clients, employees, projects (budget, milestones, tasks), approve / reject timesheets, invoices, alerts |
| **PSA_User**  | User  | only **My Timesheets** | own timesheets only (any open task can be picked) |

- A User gets **no data** of projects, budgets, clients, invoices or other employees – the server does not return it
  (`@restrict` in `srv/psa-service.cds`), and the home page does not show those apps.
- Users log in with their **SAP account** (XSUAA login page); roles are assigned in the BTP cockpit
  (Security → Role Collections). Deployed app: use the collections named **PSA_Admin (org-space)** / **PSA_User (org-space)**.
- The login e-mail links a user to an **Employee** (`Employees.email`) – an admin creates the employee in the
  **Employees** app with the same e-mail. `…/odata/v4/psa/whoAmI()` shows login, roles and linked employee.
- The shell header shows the real user; **Sign Out** (user menu) logs out via the approuter (`/do/logout`).

## Home page and Fiori apps

The launchpad opens on a custom **Home** page instead of the standard square tiles (only SAPUI5
controls: `sap.f.Card` with numeric headers, lists, avatars, progress bars; colours come from the SAP theme).
Object pages show progress bars for budget burn,
hours used, milestone completion and task burn, coloured status icons (green / orange / red) and a
success toast after each action.

| App | Role | What you do there |
|---|---|---|
| **Home** (start page) | User, Admin | Welcome banner with quick actions. **Admin:** KPI cards (FRD §9) *Active Projects, At-Risk Budgets, Pending Approvals, Unbilled Hours, Draft Invoices, Overdue Amount*; timesheets waiting for approval (approve right there); budget burn per project (click → Project page); tasks at risk; scope-creep alerts. **User:** hours this week, *Log time* (opens or creates the current week), recent timesheets with status and rejection reason, how-it-works steps |
| **My Timesheets** | User, Admin | *Create* (week = current week, row defaults: week start, 8 h, billable) → add rows in *Hours* → *Create* (save) → *Submit for Approval* |
| **Approve Timesheets** | Admin | select submitted timesheets → *Approve* or *Reject* (reason) |
| **Projects** | Admin | *Create* / *Edit* project, fill *Budget*, add *Milestones* → open a milestone → add *Tasks*; see budget burn, alerts, invoices |
| **Billing Workbench** (Invoices) | Admin | *Generate Invoice* (project + period) → *Issue* → *Mark as Paid* |
| **Clients**, **Employees** | Admin | maintain master data |

## Flow

1. **User** creates a weekly timesheet and adds hours per task and day
   – any date is moved to the Monday of its week; only the FRD rules are checked on save:
     0.25–24 h, date inside the week, max 24 h/day, no duplicate task+day, task not Done, employee active
2. **Submit** → *Submitted* (locked: Edit / Delete are hidden)
3. **Admin** approves (budget roll-up + alerts happen here) or rejects with a reason (user can correct and submit again)
4. **Admin** generates the invoice → *Issue* → *Mark as Paid*

| Billing type | Invoice amount |
|---|---|
| T&M      | approved billable hours × billing rate |
| Fixed    | same, but never more than the budget (contract) amount |
| Retainer | flat retainer fee per period (each period billed once) |

Tax 18 % is added; due date = invoice date + 30 days.

## Project structure

```
db/                    data model + sample data (db/data/*.csv)
srv/psa-service.cds    OData V4 service PSAService (roles, drafts)
srv/psa-service.js     business logic
app/index.html         SAP Fiori launchpad (sandbox); start page = app/home (rootIntent PSA-home)
app/home/webapp        Home page (SAPUI5 XML view + css/style.css, role-aware)
app/annotations.cds    Fiori Elements UI annotations
app/<name>/webapp      Fiori Elements apps: timesheets, approvals, projects, invoices, clients, employees
.deploy/app-router     SAP Approuter (XSUAA login)
xs-security.json       XSUAA roles + role collections PSA_Admin / PSA_User
mta.yaml               Cloud Foundry deployment
test/psa.test.js       30 automated tests (npm test)
```

## Run in SAP Business Application Studio (hybrid: SAP HANA Cloud + XSUAA)

**One-time prerequisites**
- BTP subaccount (free tier / trial) with Cloud Foundry and a **running SAP HANA Cloud** instance mapped to your space
- BAS Dev Space **Full Stack Cloud Application** (`node -v` must be 22 or higher for the approuter)

**1. Get the code**

```bash
cd ~/projects
git clone https://github.com/saurabh-1907/Saurabh-Pandey-Sprint-Evaluation
cd Saurabh-Pandey-Sprint-Evaluation
npm install
```

Put your BTP login e-mails into `db/data/psa.db-master.Employees.csv` (Meera = admin user, Rahul = normal user).

**2. Log in to Cloud Foundry and create the XSUAA instance (once)**

```bash
cf login
cf create-service xsuaa application psa-hybrid-auth -c xs-security.json
cds bind auth --to psa-hybrid-auth
```

**3. Build, deploy to HANA, start the CAP server**

```bash
cds build --production
cds deploy --to hana
cds watch --profile hybrid
```

**4. Start the approuter (second terminal) – this is where you log in**

Run from the **project root** (the XSUAA binding is stored there in `.cdsrc-private.json`):

```bash
npm install --prefix .deploy/app-router
cds bind --exec --profile hybrid -- npm start --prefix .deploy/app-router
```

Open port **5000** (*Open in a New Tab*) → SAP login page → **Fiori launchpad** with the home page.
Logout: open `/do/logout`.

**5. Give users their roles (once)** – BTP cockpit → *Security* → *Users* → select user → *Assign Role Collection* →
**PSA_Admin** or **PSA_User**. Log out and in again after a change. To test both roles use two BTP users
(an admin cannot approve their own timesheet).

Notes
- Port 4004 alone answers `401` – always go through the approuter (port 5000).
- Data in HANA is persistent. To reset to the sample data run `cds deploy --to hana` again.
- After pulling a new version with model changes, run `cds build --production` and `cds deploy --to hana` again.

## Deploy to Cloud Foundry (public URL, free tier / trial)

**Prerequisites:** CF enabled in the subaccount, HANA Cloud instance **running** and mapped to the CF space,
BAS dev space (has `mbt` and `cf deploy` built in).

```bash
cd ~/projects/Saurabh-Pandey-Sprint-Evaluation
git pull
npm install
cf login                                   # API endpoint of your subaccount, e.g. https://api.cf.us10-001.hana.ondemand.com
mbt build                                  # creates mta_archives/psa-application_1.0.0.mtar
cf deploy mta_archives/psa-application_1.0.0.mtar
```

`cf deploy` creates/updates: the HDI container `psa-application-db` (`hdi-shared`), the XSUAA instance
`psa-application-auth` (plan `application`), the CAP server `psa-application-srv` (512 MB),
the approuter `psa-application` (256 MB) and deploys tables + sample data.

**After the deployment**

1. `cf apps` → copy the URL of **psa-application** (the approuter) – this is the public link of the app.
2. BTP cockpit → Subaccount → Security → **Role Collections**:
   - **PSA_Admin (org-space)** → add admin users
   - **PSA_User (org-space)** → add employees
   (choose identity provider **Default identity provider**; the user needs an SAP account – free at accounts.sap.com)
3. Every user must exist in **Employees** with the same e-mail as the login (Employees app as admin, or the CSV before deploying).
4. Users open the link from anywhere → SAP login → Fiori launchpad. Logout: `<link>/do/logout`.

**Updating** after code changes: `git pull`, `mbt build`, `cf deploy mta_archives/psa-application_1.0.0.mtar` again.

**Trial notes:** HANA Cloud stops every night – start it in HANA Cloud Central; then `cf restart psa-application-srv` if needed.

## Tests

`npm test` – runs the 30 tests on an in-memory database with test logins (no HANA / XSUAA needed).
