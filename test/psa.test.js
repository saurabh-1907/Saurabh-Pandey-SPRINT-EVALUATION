const cds = require('@sap/cds');
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { GET, POST, PATCH, DELETE } = cds.test(__dirname + '/..');
const { UPDATE } = cds.ql;

const S = '/odata/v4/psa';

// test logins (package.json -> cds.requires.[development].auth); in BTP the login comes from XSUAA
const ADMIN = { auth: { username: 'meera.iyer@psa-demo.com',   password: 'admin' } };   // Admin role
const USER  = { auth: { username: 'rahul.sharma@psa-demo.com', password: 'user'  } };   // User role

// seed data keys
const MEERA = '20000000-0000-4000-8000-000000000001';
const RAHUL = '20000000-0000-4000-8000-000000000003';
const CLIENT1 = '30000000-0000-4000-8000-000000000001';
const P1 = '40000000-0000-4000-8000-000000000001';      // T&M
const P3 = '40000000-0000-4000-8000-000000000003';      // Retainer
const B1 = '45000000-0000-4000-8000-000000000001';      // budget of P1
const M1 = '50000000-0000-4000-8000-000000000001';      // milestone with 1 Done task
const T1 = '60000000-0000-4000-8000-000000000001';      // Done
const T2 = '60000000-0000-4000-8000-000000000002';      // Data migration (est 60)
const T3 = '60000000-0000-4000-8000-000000000003';      // Integration build (est 16), Priya
const T6 = '60000000-0000-4000-8000-000000000006';      // Cutover planning, unassigned
const TS2 = '70000000-0000-4000-8000-000000000002';     // Rahul, Submitted
const TS3 = '70000000-0000-4000-8000-000000000003';     // Priya, Submitted
const TS4 = '70000000-0000-4000-8000-000000000004';     // Rahul, Draft (week 12 Oct)
const M2 = '50000000-0000-4000-8000-000000000002';      // Build (in progress)
const TODAY = new Date().toISOString().slice(0, 10);

// expects the request to fail with the given status
async function fails(request, status) {
    try { await request; } catch (err) { return assert.equal(err.response.status, status); }
    assert.fail(`expected HTTP ${status}`);
}

const active = (entity, key) => `${S}/${entity}(NODE_KEY=${key},IsActiveEntity=true)`;
const draft  = (entity, key) => `${S}/${entity}(NODE_KEY=${key},IsActiveEntity=false)`;

const getProject = async (key) => (await GET(`${active('ProjectSrv', key)}?$expand=BUDGET`, ADMIN)).data;
const getTimesheet = async (key) => (await GET(active('TimesheetSrv', key), ADMIN)).data;

describe('Login and roles', () => {

    it('requires a login', async () => {
        await fails(GET(`${S}/ProjectSrv`), 401);
        await fails(GET(`${S}/ProjectSrv`, { auth: { username: 'rahul.sharma@psa-demo.com', password: 'wrong' } }), 401);
        await fails(GET(`${S}/ProjectSrv`, { auth: { username: 'alice', password: '' } }), 401);
    });

    it('whoAmI shows the login, roles and linked employee', async () => {
        const { data: admin } = await GET(`${S}/whoAmI()`, ADMIN);
        assert.equal(admin.isAdmin, true);
        assert.equal(admin.employee, 'Meera Iyer (meera.iyer@psa-demo.com)');

        const { data: user } = await GET(`${S}/whoAmI()`, USER);
        assert.equal(user.isAdmin, false);
        assert.equal(user.isUser, true);
    });

    it('User does not see projects, budgets, clients or other employees', async () => {
        await fails(GET(`${S}/ProjectSrv`, USER), 403);
        await fails(GET(`${S}/BudgetSrv`, USER), 403);
        await fails(GET(`${S}/ClientSrv`, USER), 403);

        const { data: employees } = await GET(`${S}/EmployeeSrv?$filter=IsActiveEntity eq true`, USER);
        assert.deepEqual(employees.value.map(e => e.email), ['rahul.sharma@psa-demo.com']);
    });

    it('User can pick any task for the timesheet', async () => {
        const { data } = await GET(`${S}/TaskSrv?$filter=IsActiveEntity eq true`, USER);
        assert.ok(data.value.some(t => t.NODE_KEY === T3));
    });

    it('KPI cards: the analytics entities sum their counters ($apply)', async () => {
        const sum = async (entity, measure) => {
            const { data } = await GET(`${S}/${entity}?$apply=aggregate(${measure})`, ADMIN);
            return Number(data.value[0][measure]);
        };
        assert.equal(await sum('ProjectAnalytics', 'ACTIVE_COUNT'), 3);       // Active Projects
        assert.equal(await sum('ProjectAnalytics', 'AT_RISK_COUNT'), 0);      // At-Risk Budgets
        assert.equal(await sum('TimesheetAnalytics', 'PENDING_COUNT'), 2);    // Pending Approvals: TS2 + TS3
        assert.equal(await sum('EntryAnalytics', 'UNBILLED_HOURS'), 34);      // approved billable hours of TS1
        assert.equal(await sum('InvoiceAnalytics', 'DRAFT_COUNT'), 0);        // Draft Invoices
        assert.equal(await sum('InvoiceAnalytics', 'OVERDUE_AMOUNT'), 0);     // only invoice is already Paid

        // chart of the Manager Home: budget vs. consumed per project
        const { data } = await GET(`${S}/ProjectAnalytics?$apply=groupby((PROJECT_NAME),aggregate(BUDGET_AMOUNT,CONSUMED_AMOUNT))`, ADMIN);
        assert.equal(data.value.length, 3);
    });

    it('User cannot read the Manager Home analytics', async () => {
        await fails(GET(`${S}/ProjectAnalytics`, USER), 403);
        await fails(GET(`${S}/TimesheetAnalytics`, USER), 403);
        await fails(GET(`${S}/InvoiceAnalytics`, USER), 403);
        await fails(GET(`${S}/EntryAnalytics`, USER), 403);
    });

    it('User has no access to approvals, invoices and alerts', async () => {
        await fails(GET(`${S}/ApprovalSrv`, USER), 403);
        await fails(GET(`${S}/InvoiceSrv`, USER), 403);
        await fails(GET(`${S}/AlertSrv`, USER), 403);
        await fails(POST(`${S}/generateInvoice`, { projectID: P1, periodFrom: '2026-09-01', periodTo: '2026-10-31' }, USER), 403);
    });

    it('User only sees own timesheets, Admin sees all', async () => {
        const { data: own } = await GET(`${S}/TimesheetSrv?$filter=IsActiveEntity eq true`, USER);
        assert.ok(own.value.length > 0);
        assert.ok(own.value.every(t => t.EMPLOYEE_ID === RAHUL));
        await fails(GET(active('TimesheetSrv', TS3), USER), 404);

        const { data: all } = await GET(`${S}/TimesheetSrv?$filter=IsActiveEntity eq true`, ADMIN);
        assert.ok(all.value.some(t => t.EMPLOYEE_ID !== RAHUL));
    });
});

describe('Seed data roll-up (only approved hours count)', () => {

    it('calculates project hours and budget consumption', async () => {
        const p = await getProject(P1);
        assert.equal(Number(p.CONSUMED_HOURS), 26);            // approved: 24 (T1) + 2 (T2, non-billable)
        assert.equal(Number(p.BUDGET.CONSUMED_AMOUNT), 2400);  // 24 billable h x 100
        assert.equal(Number(p.BUDGET.CONSUMED_PERCENT), 12);
        assert.equal(p.BUDGET.BUDGET_STATUS, 'Within Budget');
    });

    it('calculates milestone completion from task status', async () => {
        const { data } = await GET(`${S}/MilestoneSrv(${M1})`, ADMIN);
        assert.equal(Number(data.COMPLETION_PERCENT), 100);
    });
});

describe('Project insight (FRD 6.4, 7.1, 9)', () => {

    it('milestone status follows its tasks and dates', async () => {
        const { data } = await GET(`${S}/MilestoneSrv?$filter=NODE_KEY eq ${M1} or NODE_KEY eq ${M2}&$orderby=START_DATE`, ADMIN);
        assert.equal(data.value[0].STATUS, 'Completed');                  // Blueprint: all tasks Done
        assert.ok(['In Progress', 'Delayed'].includes(data.value[1].STATUS));
    });

    it('getBurnSummary returns budget, hours, burn rate and projected end', async () => {
        const { data } = await GET(`${S}/getBurnSummary(projectID=${P1})`, ADMIN);
        assert.equal(data.projectCode, 'PRJ-2026-001');
        assert.equal(Number(data.budgetAmount), 20000);
        assert.ok(Number(data.burnRate) > 0);
        assert.ok(data.projectedEnd >= TODAY);
        await fails(GET(`${S}/getBurnSummary(projectID=${P1})`, USER), 403);
    });

    it('the project page shows burn rate, projected end and all booked hours', async () => {
        const { data } = await GET(`${active('ProjectSrv', P1)}?$select=BURN_RATE,PROJECTED_END,STATUS,PRIORITY&$expand=TIME_ENTRIES`, ADMIN);
        assert.ok(Number(data.BURN_RATE) > 0);
        assert.ok(data.PROJECTED_END);
        assert.equal(data.STATUS, 'Active');
        assert.equal(data.PRIORITY, 'High');
        assert.ok(data.TIME_ENTRIES.length >= 5);
        assert.ok(data.TIME_ENTRIES.every(e => e.EMPLOYEE_NAME && e.TASK_NAME));
    });
});

describe('Admin creates a project in Fiori (draft)', () => {

    let key;

    it('a new project starts with an empty budget', async () => {
        const { data } = await POST(`${S}/ProjectSrv`, {}, ADMIN);
        key = data.NODE_KEY;
        const { data: d } = await GET(`${draft('ProjectSrv', key)}?$expand=BUDGET`, ADMIN);
        assert.ok(d.BUDGET?.NODE_KEY);
    });

    it('cannot be saved without a valid budget', async () => {
        await PATCH(draft('ProjectSrv', key), {
            PROJECT_CODE: 'PRJ-2026-010', PROJECT_NAME: 'New Portal', CLIENT_NODE_KEY: CLIENT1,
            START_DATE: '2026-11-01', END_DATE: '2026-12-31', PLANNED_HOURS: 100
        }, ADMIN);
        await fails(POST(`${draft('ProjectSrv', key)}/PSAService.draftActivate`, {}, ADMIN), 400);
    });

    it('saves project, budget, milestone and task together', async () => {
        const { data: d } = await GET(`${draft('ProjectSrv', key)}?$expand=BUDGET`, ADMIN);
        await PATCH(draft('BudgetSrv', d.BUDGET.NODE_KEY), { BUDGET_AMOUNT: 10000, BILLING_RATE: 100 }, ADMIN);

        const { data: m } = await POST(`${draft('ProjectSrv', key)}/MILESTONES`, { MILESTONE_NAME: 'Build' }, ADMIN);
        await POST(`${draft('MilestoneSrv', m.NODE_KEY)}/TASKS`, { TASK_NAME: 'API', ESTIMATED_HOURS: 40 }, ADMIN);

        await POST(`${draft('ProjectSrv', key)}/PSAService.draftActivate`, {}, ADMIN);

        const p = await getProject(key);
        assert.equal(p.PROJECT_CODE, 'PRJ-2026-010');
        assert.equal(Number(p.BUDGET.REMAINING_AMOUNT), 10000);
    });

    it('project codes are unique', async () => {
        const { data } = await POST(`${S}/ProjectSrv`, {}, ADMIN);
        await PATCH(draft('ProjectSrv', data.NODE_KEY), { PROJECT_CODE: 'PRJ-2026-001', PROJECT_NAME: 'Copy', CLIENT_NODE_KEY: CLIENT1 }, ADMIN);
        const { data: d } = await GET(`${draft('ProjectSrv', data.NODE_KEY)}?$expand=BUDGET`, ADMIN);
        await PATCH(draft('BudgetSrv', d.BUDGET.NODE_KEY), { BUDGET_AMOUNT: 100 }, ADMIN);
        await fails(POST(`${draft('ProjectSrv', data.NODE_KEY)}/PSAService.draftActivate`, {}, ADMIN), 409);
    });
});

describe('FR-003: dates fall within the parent period', () => {

    // project 1 Nov - 31 Dec with a valid budget, saved as draft
    async function newProject(code) {
        const { data } = await POST(`${S}/ProjectSrv`, {}, ADMIN);
        await PATCH(draft('ProjectSrv', data.NODE_KEY), {
            PROJECT_CODE: code, PROJECT_NAME: 'Date check', CLIENT_NODE_KEY: CLIENT1,
            START_DATE: '2026-11-01', END_DATE: '2026-12-31', PLANNED_HOURS: 50
        }, ADMIN);
        const { data: d } = await GET(`${draft('ProjectSrv', data.NODE_KEY)}?$expand=BUDGET`, ADMIN);
        await PATCH(draft('BudgetSrv', d.BUDGET.NODE_KEY), { BUDGET_AMOUNT: 5000, BILLING_RATE: 100 }, ADMIN);
        return data.NODE_KEY;
    }

    it('a milestone outside the project period is rejected', async () => {
        const key = await newProject('PRJ-2026-020');
        await POST(`${draft('ProjectSrv', key)}/MILESTONES`, {
            MILESTONE_NAME: 'Too early', START_DATE: '2026-10-01', END_DATE: '2026-11-15'
        }, ADMIN);

        await fails(POST(`${draft('ProjectSrv', key)}/PSAService.draftActivate`, {}, ADMIN), 400);
        await DELETE(draft('ProjectSrv', key), ADMIN);
    });

    it('a task outside the milestone period is rejected', async () => {
        const key = await newProject('PRJ-2026-021');
        const { data: milestone } = await POST(`${draft('ProjectSrv', key)}/MILESTONES`, {
            MILESTONE_NAME: 'Build', START_DATE: '2026-11-01', END_DATE: '2026-11-30'
        }, ADMIN);
        await POST(`${draft('MilestoneSrv', milestone.NODE_KEY)}/TASKS`, {
            TASK_NAME: 'Late task', ESTIMATED_HOURS: 8, START_DATE: '2026-11-20', END_DATE: '2026-12-10'
        }, ADMIN);

        await fails(POST(`${draft('ProjectSrv', key)}/PSAService.draftActivate`, {}, ADMIN), 400);
        await DELETE(draft('ProjectSrv', key), ADMIN);
    });

    it('dates inside the parent periods are accepted', async () => {
        const key = await newProject('PRJ-2026-022');
        const { data: milestone } = await POST(`${draft('ProjectSrv', key)}/MILESTONES`, {
            MILESTONE_NAME: 'Build', START_DATE: '2026-11-01', END_DATE: '2026-11-30'
        }, ADMIN);
        await POST(`${draft('MilestoneSrv', milestone.NODE_KEY)}/TASKS`, {
            TASK_NAME: 'On time', ESTIMATED_HOURS: 8, START_DATE: '2026-11-02', END_DATE: '2026-11-20'
        }, ADMIN);

        await POST(`${draft('ProjectSrv', key)}/PSAService.draftActivate`, {}, ADMIN);
        const { data } = await GET(`${active('ProjectSrv', key)}?$expand=MILESTONES($expand=TASKS)`, ADMIN);
        assert.equal(data.MILESTONES[0].TASKS[0].TASK_NAME, 'On time');
        assert.equal(data.MILESTONES[0].STATUS, 'Not Started');
    });
});

describe('User logs time in Fiori (draft) and submits', () => {

    let key;

    it('a new timesheet always belongs to the logged-in user', async () => {
        const { data } = await POST(`${S}/TimesheetSrv`, { EMPLOYEE_ID: MEERA }, USER);
        key = data.NODE_KEY;
        assert.equal(data.EMPLOYEE_ID, RAHUL);
        assert.equal(data.STATUS, 'Draft');
        assert.equal(new Date(data.WEEK_START + 'T00:00:00Z').getUTCDay(), 1);   // defaults to this week's Monday
    });

    it('a new row defaults to the first day of the week and 8 billable hours', async () => {
        await PATCH(draft('TimesheetSrv', key), { WEEK_START: '2026-10-19' }, USER);
        const { data } = await POST(`${draft('TimesheetSrv', key)}/Entries`, {}, USER);
        assert.equal(data.WORK_DATE, '2026-10-19');
        assert.equal(Number(data.HOURS), 8);
        assert.equal(data.IS_BILLABLE, true);
        await DELETE(draft('TimesheetEntrySrv', data.NODE_KEY), USER);
    });

    it('any day can be entered as week start - it becomes the Monday', async () => {
        const { data } = await POST(`${S}/TimesheetSrv`, {}, USER);
        await PATCH(draft('TimesheetSrv', data.NODE_KEY), { WEEK_START: '2026-10-29' }, USER);   // Thursday
        await POST(`${draft('TimesheetSrv', data.NODE_KEY)}/Entries`, { TASK_NODE_KEY: T2, WORK_DATE: '2026-10-29', HOURS: 2 }, USER);
        await POST(`${draft('TimesheetSrv', data.NODE_KEY)}/PSAService.draftActivate`, {}, USER);
        const ts = await getTimesheet(data.NODE_KEY);
        assert.equal(ts.WEEK_START, '2026-10-26');
        assert.equal(ts.WEEK_END, '2026-11-01');
    });

    it('validates the entries on save', async () => {
        await PATCH(draft('TimesheetSrv', key), { WEEK_START: '2026-10-19' }, USER);
        const entry = (e) => POST(`${draft('TimesheetSrv', key)}/Entries`, e, USER);

        const { data: e1 } = await entry({ TASK_NODE_KEY: T2, WORK_DATE: '2026-10-19', HOURS: 8 });
        const { data: e2 } = await entry({ TASK_NODE_KEY: T2, WORK_DATE: '2026-10-19', HOURS: 2 });   // duplicate
        await fails(POST(`${draft('TimesheetSrv', key)}/PSAService.draftActivate`, {}, USER), 400);

        await PATCH(draft('TimesheetEntrySrv', e2.NODE_KEY), { TASK_NODE_KEY: T1 }, USER);            // task is Done
        await fails(POST(`${draft('TimesheetSrv', key)}/PSAService.draftActivate`, {}, USER), 400);

        await PATCH(draft('TimesheetEntrySrv', e2.NODE_KEY), { TASK_NODE_KEY: T6, HOURS: 17 }, USER); // > 24 h a day
        await fails(POST(`${draft('TimesheetSrv', key)}/PSAService.draftActivate`, {}, USER), 400);

        await PATCH(draft('TimesheetEntrySrv', e2.NODE_KEY), { WORK_DATE: '2026-10-20', HOURS: 2 }, USER);
        await POST(`${draft('TimesheetSrv', key)}/PSAService.draftActivate`, {}, USER);

        const ts = await getTimesheet(key);
        assert.equal(Number(ts.TOTAL_HOURS), 10);
        assert.equal(ts.WEEK_END, '2026-10-25');
        assert.ok(e1.NODE_KEY);
    });

    it('submitting locks the timesheet but does not touch the budget yet', async () => {
        const before = await getProject(P1);

        const { data } = await POST(`${active('TimesheetSrv', key)}/PSAService.submitTimesheet`, {}, USER);
        assert.equal(data.value, 'Timesheet submitted for approval');
        const submitted = await getTimesheet(key);
        assert.equal(submitted.STATUS, 'Submitted');
        assert.equal(submitted.SUBMITTED_DATE, TODAY);                    // FR-004: submit stamps the date

        assert.equal((await getProject(P1)).CONSUMED_HOURS, before.CONSUMED_HOURS);

        await fails(POST(`${active('TimesheetSrv', key)}/PSAService.draftEdit`, { PreserveChanges: true }, USER), 409);
        await fails(POST(`${active('TimesheetSrv', key)}/PSAService.submitTimesheet`, {}, USER), 409);
    });

    it('Admin approves -> task, project and budget update in real time', async () => {
        const before = await getProject(P1);

        await POST(`${S}/ApprovalSrv(${key})/PSAService.approveTimesheet`, {}, ADMIN);

        const after = await getProject(P1);
        assert.equal(Number(after.CONSUMED_HOURS) - Number(before.CONSUMED_HOURS), 10);
        assert.equal(Number(after.BUDGET.CONSUMED_AMOUNT) - Number(before.BUDGET.CONSUMED_AMOUNT), 1000);

        const ts = await getTimesheet(key);
        assert.equal(ts.STATUS, 'Approved');
        assert.equal(ts.APPROVED_BY_ID, MEERA);
        assert.equal(ts.APPROVED_DATE, TODAY);                           // FR-006: approver and date recorded
    });
});

describe('Import hours from a time tracker (FR-005)', () => {

    it('imports valid rows, ignores duplicates and reports unmapped rows', async () => {
        const rows = [
            'date;task;hours;billable;notes',
            '2026-10-14;Integration build;2;yes;API mapping',
            '2026-10-14;Integration build;2;yes;API mapping',          // duplicate
            '2026-10-14;Unknown task;1;yes;',                          // not mapped
            '2026-10-20;Integration build;1;no;',                      // outside the week
            '2026-10-15;Requirements workshops;1;yes;'                 // task is Done
        ].join('\n');

        const { data } = await POST(`${active('TimesheetSrv', TS4)}/PSAService.importHours`, { rows }, USER);
        assert.equal(data.value, '1 row(s) imported, 1 duplicate(s) ignored, 3 row(s) not imported.');

        const ts = await getTimesheet(TS4);
        assert.equal(Number(ts.TOTAL_HOURS), 14);                         // 12 + 2
        assert.equal(Number(ts.BILLABLE_HOURS), 14);
    });

    it('a submitted timesheet cannot import', async () => {
        await fails(POST(`${active('TimesheetSrv', TS3)}/PSAService.importHours`, { rows: '2026-10-06;UX design;1;yes;' }, ADMIN), 409);
    });
});

describe('Approval (Admin)', () => {

    it('a submitted timesheet is locked: no edit, no delete', async () => {
        const { data } = await GET(`${active('TimesheetSrv', TS2)}?$select=IS_LOCKED`, USER);
        assert.equal(data.IS_LOCKED, true);
        await fails(POST(`${active('TimesheetSrv', TS2)}/PSAService.draftEdit`, {}, USER), 409);
        await fails(DELETE(active('TimesheetSrv', TS2), USER), 409);
    });

    it('Admin cannot approve own timesheet', async () => {
        const { data } = await POST(`${S}/TimesheetSrv`, {}, ADMIN);
        await PATCH(draft('TimesheetSrv', data.NODE_KEY), { WEEK_START: '2026-10-19' }, ADMIN);
        await POST(`${draft('TimesheetSrv', data.NODE_KEY)}/Entries`, { TASK_NODE_KEY: T6, WORK_DATE: '2026-10-19', HOURS: 1 }, ADMIN);
        await POST(`${draft('TimesheetSrv', data.NODE_KEY)}/PSAService.draftActivate`, {}, ADMIN);
        await POST(`${active('TimesheetSrv', data.NODE_KEY)}/PSAService.submitTimesheet`, {}, ADMIN);

        await fails(POST(`${S}/ApprovalSrv(${data.NODE_KEY})/PSAService.approveTimesheet`, {}, ADMIN), 403);
    });

    it('rejecting needs a reason; the user can correct and re-submit', async () => {
        await fails(POST(`${S}/ApprovalSrv(${TS2})/PSAService.rejectTimesheet`, { reason: '' }, ADMIN), 400);
        await POST(`${S}/ApprovalSrv(${TS2})/PSAService.rejectTimesheet`, { reason: 'Split hours by object' }, ADMIN);
        assert.equal((await getTimesheet(TS2)).STATUS, 'Rejected');

        await POST(`${active('TimesheetSrv', TS2)}/PSAService.submitTimesheet`, {}, USER);
        await POST(`${S}/ApprovalSrv(${TS2})/PSAService.approveTimesheet`, {}, ADMIN);
        assert.equal((await getTimesheet(TS2)).STATUS, 'Approved');

        const p = await getProject(P1);
        assert.equal(Number(p.BUDGET.CONSUMED_AMOUNT), 6400);   // 24 + 10 + 30 billable h x 100
    });
});

describe('Scope-creep alerts', () => {

    it('raises a task alert when approved hours pass 75% of the estimate', async () => {
        await POST(`${S}/ApprovalSrv(${TS3})/PSAService.approveTimesheet`, {}, ADMIN);   // 14 of 16 h on T3
        const { data } = await GET(`${S}/AlertSrv?$filter=TASK_NODE_KEY eq ${T3}`, ADMIN);
        assert.deepEqual(data.value.map(a => a.THRESHOLD), [75]);
    });

    // budget is changed like in Fiori: Edit project -> change budget -> Save
    const changeBudget = async (amount) => {
        await POST(`${active('ProjectSrv', P1)}/PSAService.draftEdit`, { PreserveChanges: true }, ADMIN);
        await PATCH(draft('BudgetSrv', B1), { BUDGET_AMOUNT: amount }, ADMIN);
        return POST(`${draft('ProjectSrv', P1)}/PSAService.draftActivate`, {}, ADMIN);
    };

    it('marks the budget At Risk / Breached and alerts once per threshold', async () => {
        // P1 now: 78 billable h x 100 = 7800
        await changeBudget(9000);    // 87 %
        assert.equal((await getProject(P1)).BUDGET.BUDGET_STATUS, 'At Risk');

        await changeBudget(7000);    // 111 %
        assert.equal((await getProject(P1)).BUDGET.BUDGET_STATUS, 'Breached');

        await POST(`${active('ProjectSrv', P1)}/PSAService.recalculateBudget`, {}, ADMIN);   // no duplicates
        const { data } = await GET(`${S}/AlertSrv?$filter=PROJECT_NODE_KEY eq ${P1} and TASK_NODE_KEY eq null`, ADMIN);
        assert.deepEqual(data.value.map(a => a.THRESHOLD).sort((a, b) => a - b), [75, 90, 100]);
    });

    it('rejects an invalid budget', async () => {
        await fails(changeBudget(0), 400);
        await DELETE(draft('ProjectSrv', P1), ADMIN);   // discard the draft
    });
});

describe('Invoicing (Admin)', () => {

    let invoice;

    it('T&M: approved billable hours x rate + 18% tax', async () => {
        const { data } = await POST(`${S}/generateInvoice`, { projectID: P1, periodFrom: '2026-09-01', periodTo: '2026-10-31' }, ADMIN);
        invoice = data;
        assert.equal(Number(data.BILLABLE_HOURS), 78);   // 24 + 30 + 10 (Rahul) + 14 (Priya)
        assert.equal(Number(data.NET_AMOUNT), 7800);
        assert.equal(Number(data.TAX_AMOUNT), 1404);
        assert.equal(Number(data.GROSS_AMOUNT), 9204);
        assert.equal(data.STATUS, 'Draft');
    });

    it('the same hours are never billed twice', async () => {
        await fails(POST(`${S}/generateInvoice`, { projectID: P1, periodFrom: '2026-09-01', periodTo: '2026-10-31' }, ADMIN), 409);
    });

    it('Retainer: flat fee, each period only once', async () => {
        const { data } = await POST(`${S}/generateInvoice`, { projectID: P3, periodFrom: '2026-10-01', periodTo: '2026-10-31' }, ADMIN);
        assert.equal(Number(data.NET_AMOUNT), 8000);

        // TS2 had hours on P1 and P3 - now all of them are billed
        assert.equal((await getTimesheet(TS2)).STATUS, 'Invoiced');

        await fails(POST(`${S}/generateInvoice`, { projectID: P3, periodFrom: '2026-10-15', periodTo: '2026-11-15' }, ADMIN), 409);
    });

    it('cancelling an invoice releases its hours to be billed again', async () => {
        const { data: list } = await GET(`${S}/InvoiceSrv?$filter=PROJECT_NODE_KEY eq ${P3} and STATUS eq 'Draft'`, ADMIN);
        const retainer = list.value[0];

        await POST(`${S}/InvoiceSrv(${retainer.NODE_KEY})/cancelInvoice`, {}, ADMIN);
        assert.equal((await GET(`${S}/InvoiceSrv(${retainer.NODE_KEY})`, ADMIN)).data.STATUS, 'Cancelled');
        assert.equal((await getTimesheet(TS2)).STATUS, 'Approved');            // its P3 hours are open again
        await fails(POST(`${S}/InvoiceSrv(${retainer.NODE_KEY})/issueInvoice`, {}, ADMIN), 409);

        // the same period can be billed again
        await POST(`${S}/generateInvoice`, { projectID: P3, periodFrom: '2026-10-01', periodTo: '2026-10-31' }, ADMIN);
        assert.equal((await getTimesheet(TS2)).STATUS, 'Invoiced');
    });

    it('status flow Draft -> Issued -> Paid', async () => {
        const url = `${S}/InvoiceSrv(${invoice.NODE_KEY})`;
        await fails(POST(`${url}/markInvoicePaid`, {}, ADMIN), 409);
        await POST(`${url}/issueInvoice`, {}, ADMIN);
        assert.equal((await GET(url, ADMIN)).data.STATUS, 'Issued');

        // past the due date -> shown as Overdue and counted in the KPI
        await cds.run(UPDATE('psa.db.transaction.Invoices').set({ DUE_DATE: '2026-01-31' }).where({ NODE_KEY: invoice.NODE_KEY }));
        assert.equal((await GET(url, ADMIN)).data.PAYMENT_STATUS, 'Overdue');
        const { data: kpi } = await GET(`${S}/InvoiceAnalytics?$apply=aggregate(OVERDUE_AMOUNT)`, ADMIN);
        assert.equal(Number(kpi.value[0].OVERDUE_AMOUNT), 9204);

        await fails(POST(`${url}/markInvoicePaid`, { paymentDate: '2999-01-01' }, ADMIN), 400);
        await POST(`${url}/markInvoicePaid`, { paymentDate: TODAY }, ADMIN);
        const paid = (await GET(url, ADMIN)).data;
        assert.equal(paid.STATUS, 'Paid');
        assert.equal(paid.PAYMENT_DATE, TODAY);
        await fails(POST(`${url}/cancelInvoice`, {}, ADMIN), 409);           // paid invoices stay
    });
});

describe('Settings and audit log (Admin)', () => {

    it('Admin can change thresholds and tax; a User cannot', async () => {
        const url = `${S}/SettingsSrv(ID=1,IsActiveEntity=true)`;
        assert.equal(Number((await GET(url, ADMIN)).data.TAX_PERCENT), 18);

        await POST(`${url}/PSAService.draftEdit`, { PreserveChanges: true }, ADMIN);
        await PATCH(`${S}/SettingsSrv(ID=1,IsActiveEntity=false)`, { TAX_PERCENT: 5 }, ADMIN);
        await POST(`${S}/SettingsSrv(ID=1,IsActiveEntity=false)/PSAService.draftActivate`, {}, ADMIN);
        assert.equal(Number((await GET(url, ADMIN)).data.TAX_PERCENT), 5);

        await fails(GET(url, USER), 403);
    });

    it('every write and status change is in the audit log', async () => {
        const { data } = await GET(`${S}/AuditLogSrv?$orderby=TIMESTAMP`, ADMIN);
        const actions = data.value.map(a => a.ACTION);
        for (const action of ['CREATE', 'submitTimesheet', 'approveTimesheet', 'rejectTimesheet', 'importHours', 'generateInvoice']) {
            assert.ok(actions.includes(action), `audit log has ${action}`);
        }
        assert.ok(data.value.every(a => a.USER_ID && a.TIMESTAMP));
        await fails(GET(`${S}/AuditLogSrv`, USER), 403);
    });
});
