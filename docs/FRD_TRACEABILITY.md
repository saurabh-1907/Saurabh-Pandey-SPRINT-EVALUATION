# FRD / PPT traceability – Enterprise PSA

How each requirement of the *Functional Requirement Document* (FRD v1, 08-Oct-26) and the
*Functional Requirements Deck* (TEAM_1 – PSA_FINAL) is covered by this project.

Legend: ✅ implemented · 🟡 implemented in a simplified way · ⬜ out of scope (needs paid BTP services or external systems)

## 1. Business problems (FRD §2.1, PPT slide 2)

| Problem | Addressed by | Status | Where |
|---|---|---|---|
| Scope creep – a task burns hours unseen | FR-003, FR-008, FR-009 | ✅ | task burn % + colours, alerts at 75/90/100 %, Manager Home KPI *At-Risk Budgets* |
| Disconnected systems – spreadsheets for invoicing | FR-005, FR-010, FR-011 | ✅ | `importHours`, `generateInvoice`, invoice lifecycle |
| No real-time tracking – month-end visibility | FR-004, FR-007 | ✅ | roll-up runs immediately on approval (< 1 s) |

## 2. Functional requirements (FRD §8, PPT slide 9)

| ID | Requirement | Status | Implementation |
|---|---|---|---|
| FR-001 | Admin maintains Clients, Departments, Employees, Managers | 🟡 | Clients (incl. industry, status) and Employees (incl. join date, active flag) apps. Manager = employee with *Is Manager*. Department left out. Inactive employees cannot log time. |
| FR-002 | Project for a client with exactly one Budget | ✅ | Projects app (draft): `BUDGET` is `Composition of one`; unique project code, budget > 0, end ≥ start; project status and priority |
| FR-003 | Milestones and Tasks with estimated hours | ✅ | milestone/task dates must be inside the parent period, estimated hours > 0; task priority, dates, status incl. *Blocked*; milestone status set automatically |
| FR-004 | Log daily hours, save Draft, submit weekly | ✅ | My Timesheets: daily rows (billable toggle), ≤ 24 h/day, submit locks the week and stamps *Submitted On* |
| FR-005 | Import hours from third-party trackers (CSV/API) | 🟡 | **Import Hours** action: paste CSV rows `date;task;hours;billable;notes`; rows are mapped to tasks, duplicates ignored, unmapped rows reported. (No live API connection to a tracker.) |
| FR-006 | Approve / reject, reason mandatory | ✅ | Approve Timesheets app (bulk approve); approver and *Approved On* recorded; own timesheet cannot be approved |
| FR-007 | Budget updates dynamically | ✅ | approval → Entry → Task → Milestone → Project → Budget in the same request |
| FR-008 | Task burn: warning 80 %, error 100 % | ✅ | `TaskSrv.CRITICALITY` (orange ≥ 80, red ≥ 100), progress bars, task burn shown in the timesheet rows |
| FR-009 | Alerts at configurable thresholds, once per crossing | ✅ | thresholds in the **Settings** app (default 75,90,100); one alert per task/project and threshold. E-mail ⬜ |
| FR-010 | Invoices for Fixed, T&M, Retainer; tax by configuration | ✅ | `generateInvoice`; tax % and payment days in **Settings**; totals = linked entries |
| FR-011 | Invoice lifecycle, no double billing | ✅ | Draft → Issued → Paid (payment date), **Cancel** (hours become billable again), *Overdue* = issued and past due; invoiced timesheets locked. PDF to DIM ⬜ |
| FR-012 | Role-based access, row-level restriction, audit log | ✅ | XSUAA roles Admin / User, `@restrict where EMPLOYEE.email = $user`; **Audit Log** app (user, time, action, object, changed fields); *created/changed by/at* on every entity |

## 3. Roles (FRD §5, §11, PPT slide 5)

| FRD role | Here | Status |
|---|---|---|
| Employee | **User** (`PSA_User`): own timesheets only | ✅ |
| Project Manager, Finance User, Administrator | **Admin** (`PSA_Admin`) | 🟡 merged into one role to keep it simple |
| Department Head | – | ⬜ (no departments) |
| Segregation of duties: no self-approval | ✅ server check (403) |
| Finance cannot edit approved hours | ✅ submitted/approved timesheets are locked |

## 4. Actions and functions (FRD §7.1, PPT slide 8)

| Name | Status | Notes |
|---|---|---|
| submitTimesheet | ✅ | validates entries and 24 h cap, locks, stamps date |
| approveTimesheet | ✅ | stamps approver + date, triggers roll-up (notification ⬜) |
| rejectTimesheet(reason) | ✅ | reason mandatory |
| recalculateBudget | ✅ | button on the project |
| generateInvoice(projectID, periodFrom, periodTo) | ✅ | by billing type |
| issueInvoice | ✅ | Draft → Issued (PDF/DIM, client mail ⬜) |
| markInvoicePaid(paymentDate) | ✅ | stores the payment date |
| getBurnSummary(projectID) | ✅ | budget, hours, burn rate (h/week), projected completion – also shown on the project page |
| *extra:* cancelInvoice, importHours | ✅ | |

## 5. Fiori UI (FRD §9, PPT slides 10–13)

| Screen | Template asked | Here |
|---|---|---|
| Manager Home | ALP: KPI cards *Active Projects, At-Risk Budgets, Pending Approvals*, filters, budget burn per project, drill-down | ✅ Analytical List Page (chart + table, KPI cards, row → project) |
| Project Detail | Object Page: header code, client, status, budget health; facets Budget, Milestones & Tasks, Timesheets, Invoices; Recalculate Budget | ✅ all facets incl. **Timesheets**, plus Alerts and Change Log |
| My Timesheet | Object Page + actions: weekly task-by-day grid, billable toggle, task burn, Save Draft, Submit | 🟡 one row per day and task (not a 7-column grid), billable toggle, task burn, draft save, Submit, Import Hours |
| Timesheet Approvals | List Report + Object Page: filter employee, project, week; Approve / Reject with reason | 🟡 filters employee and week (project is visible per row in the hours), bulk Approve, Reject with reason |
| Billing Workbench | ALP + Object Page: KPI cards *Unbilled Hours, Draft Invoices, Overdue Amount*; Generate, Issue, Mark Paid | ✅ List Report with the three KPI cards, Generate / Issue / Mark Paid / Cancel |
| *extra:* Settings, Audit Log, Clients, Employees | | ✅ |

## 6. Data model (FRD §6)

| FRD entity | Here | Notes |
|---|---|---|
| Client | `master.Clients` | name, contact, e-mail, phone, address, country, industry, status |
| Department, Manager | – / `Employees.isManager` | simplified |
| Employee | `master.Employees` | names, e-mail (= login), phone, job title, join date, cost rate, active, line manager |
| Project | `transaction.Projects` | code, name, description, billing type, dates, status, priority, planned / consumed hours |
| Budget (1:1) | `transaction.Budgets` | amount, billing rate, retainer fee, currency, consumed, remaining, %, status |
| Milestone | `transaction.Milestones` | name, description, dates, completion %, status |
| Task | `transaction.Tasks` | name, description, dates, priority, status, estimated / actual hours, burn % |
| Timesheet | `transaction.Timesheets` | week start/end, total and billable hours, status, submitted / approved date, approver, rejection reason |
| Timesheet Entry | `transaction.TimesheetEntries` | date, task, hours 0.25–24, billable, notes, invoice link |
| Invoice | `transaction.Invoices` | number, period, invoice / due / payment date, hours, net / tax / gross, currency, status |
| *extra* | Alerts, Settings, AuditLog | |
| managed aspect | ✅ | created/changed by/at on all entities |

## 7. Delivery and testing (FRD §14, §15, NFR-006, PPT slide 14)

| Item | Status | Where |
|---|---|---|
| MTA with db, srv, app modules (`mbt build`, `cf deploy`) | ✅ | `mta.yaml`: `psa-application-db-deployer`, `psa-application-srv`, approuter `psa-application` |
| CI/CD pipeline (NFR-006) | 🟡 | `.pipeline/config.yml` for SAP Continuous Integration and Delivery: build + `npm test` on every push; deploy step ready, off until org/space are set. One space instead of DEV / QAS / PROD |
| Unit tests (service logic, roll-up, validations) | ✅ | `test/psa.test.js` – 41 tests with `@cap-js/cds-test` (instead of Jest) |
| UI tests | 🟡 | checked manually in the browser, no automated UI tests |

## 8. Not built (needs paid services or external systems)

Integrations INT-01…05 (HR, S/4HANA finance, tracker API, Document Information Management PDFs,
Alert Notification / e-mail), Destination service, Work Zone, nightly jobs, NFR load tests.
The free tier provides SAP HANA Cloud, XSUAA and Cloud Foundry, which the project uses.
