import cds from '@sap/cds';
import { randomUUID } from 'crypto';

const { INSERT, SELECT, UPDATE } = cds.ql;

// ==================================================
// SETTINGS
// ==================================================

const ALERT_THRESHOLDS = [75, 90, 100];   // % of estimate / budget
const AT_RISK_PERCENT  = 80;
const TAX_RATE         = 0.18;
const PAYMENT_DAYS     = 30;

// Only APPROVED hours count against the budget
const COUNTED = ['Approved', 'Invoiced'];

// ==================================================
// SMALL HELPERS
// ==================================================

const round2 = (n) => Math.round(Number(n || 0) * 100) / 100;
const today = () => new Date().toISOString().slice(0, 10);

const addDays = (date, days) => {
    const d = new Date(date + 'T00:00:00Z');
    d.setUTCDate(d.getUTCDate() + days);
    return d.toISOString().slice(0, 10);
};

// Monday of the week the given date is in
const mondayOf = (date) => {
    const day = new Date(date + 'T00:00:00Z').getUTCDay();   // 0 = Sunday
    return addDays(date, day === 0 ? -6 : 1 - day);
};

export default cds.service.impl(async function () {

    const {
        EmployeeSrv,
        ProjectSrv,
        BudgetSrv,
        MilestoneSrv,
        TaskSrv,
        TimesheetSrv,
        TimesheetEntrySrv,
        ApprovalSrv,
        InvoiceSrv,
        AlertSrv
    } = this.entities;

    // ==================================================
    // BUDGET ROLL-UP + ALERTS
    // Approved hours -> Task -> Milestone -> Project -> Budget
    // ==================================================

    async function recalculateProject(projectKey) {

        const project = await SELECT.one.from(ProjectSrv).where({ NODE_KEY: projectKey });
        if (!project) return;

        const budget = await SELECT.one.from(BudgetSrv).where({ PROJECT_NODE_KEY: projectKey });
        const milestones = await SELECT.from(MilestoneSrv).where({ PROJECT_NODE_KEY: projectKey });
        const tasks = await SELECT.from(TaskSrv)
            .where({ MILESTONE_NODE_KEY: { in: milestones.map(m => m.NODE_KEY).concat('none') } });

        // approved hours booked on this project's tasks
        const entries = await SELECT.from(TimesheetEntrySrv)
            .columns('TASK_NODE_KEY', 'HOURS', 'IS_BILLABLE')
            .where`TASK.MILESTONE.PROJECT.NODE_KEY = ${projectKey} and PARENT.STATUS in ${COUNTED}`;

        // ---- tasks: actual hours and burn % ----
        for (const task of tasks) {

            const hours = entries
                .filter(e => e.TASK_NODE_KEY === task.NODE_KEY)
                .reduce((sum, e) => sum + Number(e.HOURS), 0);

            task.ACTUAL_HOURS = round2(hours);
            task.BURN_PERCENT = task.ESTIMATED_HOURS > 0
                ? round2(task.ACTUAL_HOURS / task.ESTIMATED_HOURS * 100)
                : 0;

            await UPDATE(TaskSrv)
                .set({ ACTUAL_HOURS: task.ACTUAL_HOURS, BURN_PERCENT: task.BURN_PERCENT })
                .where({ NODE_KEY: task.NODE_KEY });
        }

        // ---- milestones: % of tasks done ----
        for (const milestone of milestones) {

            const mTasks = tasks.filter(t => t.MILESTONE_NODE_KEY === milestone.NODE_KEY);
            const done = mTasks.filter(t => t.STATUS === 'Done').length;

            await UPDATE(MilestoneSrv)
                .set({ COMPLETION_PERCENT: mTasks.length ? round2(done / mTasks.length * 100) : 0 })
                .where({ NODE_KEY: milestone.NODE_KEY });
        }

        // ---- project: consumed hours ----
        const CONSUMED_HOURS = round2(tasks.reduce((sum, t) => sum + t.ACTUAL_HOURS, 0));

        await UPDATE(ProjectSrv)
            .set({ CONSUMED_HOURS })
            .where({ NODE_KEY: projectKey });

        // ---- budget: billable hours x billing rate ----
        let consumedPercent = 0;

        if (budget) {

            const billableHours = entries
                .filter(e => e.IS_BILLABLE)
                .reduce((sum, e) => sum + Number(e.HOURS), 0);

            const CONSUMED_AMOUNT  = round2(billableHours * budget.BILLING_RATE);
            const REMAINING_AMOUNT = round2(budget.BUDGET_AMOUNT - CONSUMED_AMOUNT);
            consumedPercent = budget.BUDGET_AMOUNT > 0
                ? round2(CONSUMED_AMOUNT / budget.BUDGET_AMOUNT * 100)
                : 0;

            let BUDGET_STATUS = 'Within Budget';
            if (consumedPercent > 100) BUDGET_STATUS = 'Breached';
            else if (consumedPercent >= AT_RISK_PERCENT) BUDGET_STATUS = 'At Risk';

            await UPDATE(BudgetSrv)
                .set({ CONSUMED_AMOUNT, REMAINING_AMOUNT, CONSUMED_PERCENT: consumedPercent, BUDGET_STATUS })
                .where({ NODE_KEY: budget.NODE_KEY });
        }

        // ---- scope-creep alerts: one per threshold crossing ----
        const existing = await SELECT.from(AlertSrv).where({ PROJECT_NODE_KEY: projectKey });

        const alreadyRaised = (taskKey, threshold) =>
            existing.some(a => (a.TASK_NODE_KEY || null) === taskKey && a.THRESHOLD === threshold);

        const newAlerts = [];

        for (const threshold of ALERT_THRESHOLDS) {

            if (budget && consumedPercent >= threshold && !alreadyRaised(null, threshold)) {
                newAlerts.push({
                    NODE_KEY: randomUUID(),
                    PROJECT_NODE_KEY: projectKey,
                    TASK_NODE_KEY: null,
                    THRESHOLD: threshold,
                    CONSUMED_PERCENT: consumedPercent,
                    MESSAGE: `Project ${project.PROJECT_CODE} has used ${consumedPercent}% of its budget`
                });
            }

            for (const task of tasks) {
                if (task.BURN_PERCENT >= threshold && !alreadyRaised(task.NODE_KEY, threshold)) {
                    newAlerts.push({
                        NODE_KEY: randomUUID(),
                        PROJECT_NODE_KEY: projectKey,
                        TASK_NODE_KEY: task.NODE_KEY,
                        THRESHOLD: threshold,
                        CONSUMED_PERCENT: task.BURN_PERCENT,
                        MESSAGE: `Task "${task.TASK_NAME}" has used ${task.BURN_PERCENT}% of its estimate`
                    });
                }
            }
        }

        if (newAlerts.length) {
            await INSERT.into(AlertSrv).entries(newAlerts);
        }
    }

    async function projectsOfTimesheet(timesheetKey) {

        const rows = await SELECT.from(TimesheetEntrySrv)
            .columns('TASK.MILESTONE.PROJECT.NODE_KEY as projectKey')
            .where({ PARENT_NODE_KEY: timesheetKey });

        return [...new Set(rows.map(r => r.projectKey))];
    }

    async function updateTimesheetTotal(timesheetKey) {

        const entries = await SELECT.from(TimesheetEntrySrv)
            .columns('HOURS')
            .where({ PARENT_NODE_KEY: timesheetKey });

        await UPDATE(TimesheetSrv)
            .set({ TOTAL_HOURS: round2(entries.reduce((sum, e) => sum + Number(e.HOURS), 0)) })
            .where({ NODE_KEY: timesheetKey });
    }

    // Seed data: compute all calculated fields once at start-up
    cds.once('served', async () => {

        for (const t of await SELECT.from(TimesheetSrv).columns('NODE_KEY')) {
            await updateTimesheetTotal(t.NODE_KEY);
        }
        for (const p of await SELECT.from(ProjectSrv).columns('NODE_KEY')) {
            await recalculateProject(p.NODE_KEY);
        }
    });

    // ==================================================
    // LOGGED-IN USER (XSUAA login e-mail -> Employees.email)
    // ==================================================

    // claims of the XSUAA token (empty in tests)
    const tokenPayload = (req) =>
        req.user?.authInfo?.token?.payload ?? req.user?.tokenInfo?.getPayload?.() ?? {};

    async function currentEmployee(req) {
        const login = String(tokenPayload(req).email ?? req.user.id).toLowerCase();
        return SELECT.one.from(EmployeeSrv).where`tolower(email) = ${login}`;
    }

    this.on('kpis', async (req) => {

        const count = async (entity, where) => {
            const row = await SELECT.one.from(entity).columns('count(1) as n').where(where);
            return Number(row?.n ?? 0);
        };

        const employee = await currentEmployee(req);
        const weekStart = mondayOf(today());

        // the current week's timesheet: saved one first, otherwise a new unsaved draft
        let week = null, weekIsDraft = false;
        if (employee) {
            week = await SELECT.one.from(TimesheetSrv).where({ EMPLOYEE_ID: employee.ID, WEEK_START: weekStart });
            if (!week) {
                week = await SELECT.one.from(TimesheetSrv.drafts).where({ EMPLOYEE_ID: employee.ID, WEEK_START: weekStart });
                weekIsDraft = !!week;
            }
        }

        const result = {
            myEmployeeID: employee?.ID ?? null,
            myOpenTimesheets: employee
                ? await count(TimesheetSrv, { EMPLOYEE_ID: employee.ID, STATUS: { in: ['Draft', 'Rejected'] } })
                : 0,
            mySubmitted: employee ? await count(TimesheetSrv, { EMPLOYEE_ID: employee.ID, STATUS: 'Submitted' }) : 0,
            myWeekStart: weekStart,
            myWeekKey: week?.NODE_KEY ?? null,
            myWeekIsDraft: weekIsDraft,
            myWeekStatus: week?.STATUS ?? null,
            myWeekHours: round2(week?.TOTAL_HOURS),
            // admin numbers stay empty for users
            atRiskTasks: null,
            pendingApprovals: null, atRiskBudgets: null, activeProjects: null,
            draftInvoices: null, unbilledHours: null, overdueInvoices: null, overdueAmount: null,
            clients: null, employees: null
        };

        if (req.user.is('Admin')) {
            const unbilled = await SELECT.one.from(TimesheetEntrySrv).columns('sum(HOURS) as h')
                .where`PARENT.STATUS = 'Approved' and IS_BILLABLE = true and INVOICE.NODE_KEY is null`;
            const overdue = await SELECT.one.from(InvoiceSrv).columns('count(1) as n', 'sum(GROSS_AMOUNT) as amount')
                .where({ STATUS: 'Issued', DUE_DATE: { '<': today() } });

            Object.assign(result, {
                pendingApprovals: await count(TimesheetSrv, { STATUS: 'Submitted' }),
                atRiskTasks: await count(TaskSrv, { BURN_PERCENT: { '>=': AT_RISK_PERCENT }, STATUS: { '!=': 'Done' } }),
                atRiskBudgets: await count(BudgetSrv, { BUDGET_STATUS: { in: ['At Risk', 'Breached'] } }),
                activeProjects: await count(ProjectSrv, { END_DATE: { '>=': today() } }),
                draftInvoices: await count(InvoiceSrv, { STATUS: 'Draft' }),
                unbilledHours: round2(unbilled?.h),
                overdueInvoices: Number(overdue?.n ?? 0),
                overdueAmount: round2(overdue?.amount),
                clients: await count(this.entities.ClientSrv, {}),
                employees: await count(EmployeeSrv, { isActive: true })
            });
        }
        return result;
    });

    this.on('whoAmI', async (req) => {

        const payload = tokenPayload(req);
        const employee = await currentEmployee(req);

        const tokenName = [req.user.attr?.givenName, req.user.attr?.familyName].filter(Boolean).join(' ');

        return {
            user: req.user.id,
            name: employee ? `${employee.nameFirst} ${employee.nameLast}` : (tokenName || req.user.id),
            email: payload.email ?? null,
            origin: payload.origin ?? null,
            isAdmin: req.user.is('Admin'),
            isUser: req.user.is('User'),
            scopes: payload.scope ?? Object.keys(req.user.roles ?? {}),
            employee: employee ? `${employee.nameFirst} ${employee.nameLast} (${employee.email})` : null
        };
    });

    // login e-mails are compared in lower case
    this.before(['CREATE', 'UPDATE'], EmployeeSrv, (req) => {
        if (req.data.email) req.data.email = req.data.email.trim().toLowerCase();
    });

    // ==================================================
    // PROJECT VALIDATION (incl. Budget, Milestones, Tasks)
    // ==================================================

    // new project in Fiori: start with an empty budget so its fields can be filled in
    this.before('NEW', ProjectSrv.drafts, (req) => {
        req.data.BILLING_TYPE ??= 'T&M';
        req.data.BUDGET ??= { NODE_KEY: randomUUID(), CURRENCY_CODE: 'USD' };
    });

    this.before(['CREATE', 'UPDATE'], ProjectSrv, async (req) => {

        const { NODE_KEY, START_DATE, END_DATE, PROJECT_CODE, BUDGET, MILESTONES } = req.data;

        if (START_DATE && END_DATE && END_DATE < START_DATE) {
            req.reject(400, 'End date must be on or after start date.');
        }

        if (PROJECT_CODE) {
            const duplicate = await SELECT.one.from(ProjectSrv)
                .where({ PROJECT_CODE, NODE_KEY: { '!=': NODE_KEY ?? '' } });
            if (duplicate) {
                req.reject(409, `Project code ${PROJECT_CODE} already exists.`);
            }
        }

        // budget, milestones and tasks arrive together when saved from Fiori
        if (BUDGET) {
            checkBudget(req, BUDGET);
            BUDGET.REMAINING_AMOUNT ??= BUDGET.BUDGET_AMOUNT;
        } else if (req.event === 'CREATE' && BUDGET !== undefined) {
            req.reject(400, 'A project needs a budget.');
        }

        for (const milestone of MILESTONES ?? []) {
            checkMilestone(req, milestone);
            for (const task of milestone.TASKS ?? []) checkTask(req, task);
        }
    });

    this.after(['CREATE', 'UPDATE'], ProjectSrv, async (project, req) => {
        await recalculateProject(project?.NODE_KEY ?? req.data.NODE_KEY);
    });

    function checkBudget(req, budget) {
        if (!(Number(budget.BUDGET_AMOUNT) > 0)) {
            req.reject(400, 'Budget amount must be greater than 0.');
        }
    }

    function checkMilestone(req, milestone) {
        if (milestone.START_DATE && milestone.END_DATE && milestone.END_DATE < milestone.START_DATE) {
            req.reject(400, `Milestone "${milestone.MILESTONE_NAME}": end date must be on or after start date.`);
        }
    }

    function checkTask(req, task) {
        if (!(Number(task.ESTIMATED_HOURS) > 0)) {
            req.reject(400, `Task "${task.TASK_NAME ?? ''}": estimated hours must be greater than 0.`);
        }
    }

    this.on('recalculateBudget', ProjectSrv, async (req) => {

        await recalculateProject(req.params[0].NODE_KEY);

        req.notify('Budget recalculated.');
        return 'Budget recalculated successfully';
    });

    // ==================================================
    // TIMESHEET ENTRY VALIDATION
    // ==================================================

    // Checks a full set of entries of one timesheet; returns an error text or null
    async function checkEntries(timesheet, entries) {

        const perDay = {};
        const seen = new Set();

        for (const e of entries) {

            if (!e.TASK_NODE_KEY) {
                return 'Please select a task for every entry.';
            }

            if (!(e.HOURS >= 0.25 && e.HOURS <= 24)) {
                return 'Hours must be between 0.25 and 24.';
            }

            if (!e.WORK_DATE || e.WORK_DATE < timesheet.WEEK_START || e.WORK_DATE > timesheet.WEEK_END) {
                return `Work date ${e.WORK_DATE ?? ''} is outside the timesheet week (${timesheet.WEEK_START} - ${timesheet.WEEK_END}).`;
            }

            const key = e.TASK_NODE_KEY + e.WORK_DATE;
            if (seen.has(key)) {
                return `Duplicate entry for the same task on ${e.WORK_DATE}.`;
            }
            seen.add(key);

            perDay[e.WORK_DATE] = (perDay[e.WORK_DATE] || 0) + Number(e.HOURS);
            if (perDay[e.WORK_DATE] > 24) {
                return `More than 24 hours booked on ${e.WORK_DATE}.`;
            }

            const task = await SELECT.one.from(TaskSrv).where({ NODE_KEY: e.TASK_NODE_KEY });
            if (!task) {
                return `Task ${e.TASK_NODE_KEY} does not exist.`;
            }
            if (task.STATUS === 'Done') {
                return `Task "${task.TASK_NAME}" is Done - no more time can be booked.`;
            }
        }

        return null;
    }

    const isEditable = (timesheet) => ['Draft', 'Rejected'].includes(timesheet.STATUS);

    // ==================================================
    // TIMESHEET VALIDATION
    // ==================================================

    // new timesheet in Fiori: for the logged-in employee, current week
    this.before('NEW', TimesheetSrv.drafts, async (req) => {
        req.data.EMPLOYEE_ID = (await currentEmployee(req))?.ID;
        req.data.STATUS = 'Draft';
        req.data.WEEK_START ??= mondayOf(today());
    });

    // new row in the hours table: first day of the week, 8 billable hours
    this.before('NEW', TimesheetEntrySrv.drafts, async (req) => {
        const parentKey = req.data.PARENT_NODE_KEY ?? req.params?.[0]?.NODE_KEY;
        const parent = parentKey && await SELECT.one.from(TimesheetSrv.drafts).columns('WEEK_START').where({ NODE_KEY: parentKey });
        req.data.WORK_DATE ??= parent?.WEEK_START ?? today();
        req.data.HOURS ??= 8;
        req.data.IS_BILLABLE ??= true;
    });

    // a submitted / approved timesheet can not be edited any more
    this.before('EDIT', TimesheetSrv, async (req) => {

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: req.params[0].NODE_KEY });

        if (!isEditable(timesheet)) {
            req.reject(409, `Timesheet is ${timesheet.STATUS} and locked.`);
        }
    });

    // only a Draft / Rejected timesheet can be deleted (approved hours are in the budget)
    this.before('DELETE', TimesheetSrv, async (req) => {

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: req.data.NODE_KEY });

        if (timesheet && !isEditable(timesheet)) {
            req.reject(409, `Timesheet is ${timesheet.STATUS} and can not be deleted.`);
        }
    });

    this.before('CREATE', TimesheetSrv, async (req) => {

        const { WEEK_START } = req.data;

        const employee = await currentEmployee(req);
        if (!employee) {
            req.reject(403, `Your login ${req.user.id} is not linked to an employee (Employees.email).`);
        }
        const EMPLOYEE_ID = employee.ID;
        if (!employee.isActive) {
            req.reject(400, 'Inactive employees cannot log time.');
        }

        if (!WEEK_START) {
            req.reject(400, 'Please enter the week.');
        }

        // any day of the week can be entered - the timesheet always runs Monday to Sunday
        const monday = mondayOf(WEEK_START);

        const duplicate = await SELECT.one.from(TimesheetSrv).where({ EMPLOYEE_ID, WEEK_START: monday });
        if (duplicate) {
            req.reject(409, `You already have a timesheet for the week of ${monday} - please open it from the list.`);
        }

        req.data.EMPLOYEE_ID = EMPLOYEE_ID;
        req.data.WEEK_START = monday;
        req.data.WEEK_END = addDays(monday, 6);
        req.data.STATUS = 'Draft';

        // entries saved together with the timesheet (Fiori)
        if (req.data.Entries) {
            const error = await checkEntries(req.data, req.data.Entries);
            if (error) req.reject(400, error);
        }
    });

    this.before('UPDATE', TimesheetSrv, async (req) => {

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: req.data.NODE_KEY });

        if (!isEditable(timesheet)) {
            req.reject(409, `Timesheet is ${timesheet.STATUS} and locked.`);
        }

        // the week can not be changed after creation
        delete req.data.WEEK_START;

        if (req.data.Entries) {
            const error = await checkEntries(timesheet, req.data.Entries);
            if (error) req.reject(400, error);
        }
    });

    this.after(['CREATE', 'UPDATE'], TimesheetSrv, async (timesheet, req) => {
        await updateTimesheetTotal(timesheet?.NODE_KEY ?? req.data.NODE_KEY);
    });

    // single entries through the API
    this.before(['CREATE', 'UPDATE'], TimesheetEntrySrv, async (req) => {

        // on update: merge with the stored entry
        const old = await SELECT.one.from(TimesheetEntrySrv).where({ NODE_KEY: req.data.NODE_KEY });
        const entry = { ...old, ...req.data };

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: entry.PARENT_NODE_KEY });
        if (!timesheet) {
            req.reject(400, 'Timesheet not found.');
        }
        if (timesheet.EMPLOYEE_ID !== (await currentEmployee(req))?.ID && !req.user.is('Admin')) {
            req.reject(403, 'You can only book time in your own timesheet.');
        }
        if (!isEditable(timesheet)) {
            req.reject(409, `Timesheet is ${timesheet.STATUS} and locked.`);
        }

        // validate together with the other entries of the same timesheet
        const all = await SELECT.from(TimesheetEntrySrv).where({ PARENT_NODE_KEY: timesheet.NODE_KEY });
        const others = all.filter(o => o.NODE_KEY !== entry.NODE_KEY);

        const error = await checkEntries(timesheet, [...others, entry]);
        if (error) {
            req.reject(400, error);
        }

        req.timesheetKey = timesheet.NODE_KEY;
    });

    this.after(['CREATE', 'UPDATE'], TimesheetEntrySrv, async (_, req) => {
        await updateTimesheetTotal(req.timesheetKey);
    });

    this.before('DELETE', TimesheetEntrySrv, async (req) => {

        const entry = await SELECT.one.from(TimesheetEntrySrv).where({ NODE_KEY: req.data.NODE_KEY });
        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: entry?.PARENT_NODE_KEY });

        if (timesheet && !isEditable(timesheet)) {
            req.reject(409, `Timesheet is ${timesheet.STATUS} and locked.`);
        }

        req.timesheetKey = entry?.PARENT_NODE_KEY;
    });

    this.after('DELETE', TimesheetEntrySrv, async (_, req) => {
        if (req.timesheetKey) await updateTimesheetTotal(req.timesheetKey);
    });

    // ==================================================
    // SUBMIT TIMESHEET (User)
    // ==================================================

    this.on('submitTimesheet', TimesheetSrv, async (req) => {

        const key = req.params[0].NODE_KEY;

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: key });
        if (!timesheet) {
            return req.reject(404, 'Timesheet not found');
        }
        if (!isEditable(timesheet)) {
            return req.reject(409, `Timesheet is already ${timesheet.STATUS}.`);
        }

        const entries = await SELECT.from(TimesheetEntrySrv).where({ PARENT_NODE_KEY: key });
        if (!entries.length) {
            return req.reject(400, 'Cannot submit an empty timesheet.');
        }

        const error = await checkEntries(timesheet, entries);
        if (error) {
            return req.reject(400, error);
        }

        await UPDATE(TimesheetSrv)
            .set({ STATUS: 'Submitted', REJECTION_REASON: null })
            .where({ NODE_KEY: key });

        req.notify('Timesheet submitted for approval.');
        return 'Timesheet submitted for approval';
    });

    // ==================================================
    // APPROVE / REJECT TIMESHEET (Admin)
    // ==================================================

    async function checkApproval(req) {

        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: req.params[0].NODE_KEY });
        if (!timesheet) {
            return req.reject(404, 'Timesheet not found');
        }

        const approver = await currentEmployee(req);
        if (approver && timesheet.EMPLOYEE_ID === approver.ID) {
            return req.reject(403, 'You cannot approve your own timesheet.');
        }

        if (timesheet.STATUS !== 'Submitted') {
            return req.reject(409, `Only Submitted timesheets can be approved or rejected (current: ${timesheet.STATUS}).`);
        }

        timesheet.approverID = approver?.ID ?? null;
        return timesheet;
    }

    this.on('approveTimesheet', ApprovalSrv, async (req) => {

        const timesheet = await checkApproval(req);

        await UPDATE(TimesheetSrv)
            .set({ STATUS: 'Approved', APPROVED_BY_ID: timesheet.approverID })
            .where({ NODE_KEY: timesheet.NODE_KEY });

        // approved hours now count -> update budgets in real time
        for (const projectKey of await projectsOfTimesheet(timesheet.NODE_KEY)) {
            await recalculateProject(projectKey);
        }

        req.notify('Timesheet approved - budget updated.');
        return 'Timesheet approved';
    });

    this.on('rejectTimesheet', ApprovalSrv, async (req) => {

        if (!req.data.reason?.trim()) {
            return req.reject(400, 'A rejection reason is required.');
        }

        const timesheet = await checkApproval(req);

        await UPDATE(TimesheetSrv)
            .set({ STATUS: 'Rejected', APPROVED_BY_ID: timesheet.approverID, REJECTION_REASON: req.data.reason })
            .where({ NODE_KEY: timesheet.NODE_KEY });

        req.notify('Timesheet rejected.');
        return 'Timesheet rejected';
    });

    // ==================================================
    // GENERATE INVOICE from approved billable hours
    // ==================================================

    this.on('generateInvoice', async (req) => {

        const { projectID, periodFrom, periodTo } = req.data;

        if (!periodFrom || !periodTo || periodTo < periodFrom) {
            return req.reject(400, 'Please provide a valid period (periodFrom <= periodTo).');
        }

        const project = await SELECT.one.from(ProjectSrv).where({ NODE_KEY: projectID });
        if (!project) {
            return req.reject(404, 'Project not found');
        }

        const budget = await SELECT.one.from(BudgetSrv).where({ PROJECT_NODE_KEY: projectID });
        if (!budget) {
            return req.reject(400, 'Project has no budget.');
        }

        // approved, billable and not yet invoiced
        const entries = await SELECT.from(TimesheetEntrySrv)
            .columns('NODE_KEY', 'HOURS', 'PARENT_NODE_KEY')
            .where`TASK.MILESTONE.PROJECT.NODE_KEY = ${projectID}
               and PARENT.STATUS = 'Approved'
               and IS_BILLABLE = true
               and INVOICE.NODE_KEY is null
               and WORK_DATE >= ${periodFrom} and WORK_DATE <= ${periodTo}`;

        const hours = round2(entries.reduce((sum, e) => sum + Number(e.HOURS), 0));
        let net;

        if (project.BILLING_TYPE === 'Retainer') {

            // flat fee per period, each period billed only once
            const overlap = await SELECT.one.from(InvoiceSrv).where({
                PROJECT_NODE_KEY: projectID,
                PERIOD_FROM: { '<=': periodTo },
                PERIOD_TO: { '>=': periodFrom }
            });
            if (overlap) {
                return req.reject(409, `This period is already billed in ${overlap.INVOICE_NO}.`);
            }

            net = budget.RETAINER_FEE;

        } else {

            if (!entries.length) {
                return req.reject(409, 'No approved, un-invoiced billable hours in this period.');
            }

            net = hours * budget.BILLING_RATE;

            if (project.BILLING_TYPE === 'Fixed') {
                // never bill more than the fixed contract amount
                const previous = await SELECT.from(InvoiceSrv).columns('NET_AMOUNT').where({ PROJECT_NODE_KEY: projectID });
                const alreadyBilled = previous.reduce((sum, i) => sum + Number(i.NET_AMOUNT), 0);

                net = Math.min(net, budget.BUDGET_AMOUNT - alreadyBilled);
                if (net <= 0) {
                    return req.reject(409, 'The fixed contract amount is already fully billed.');
                }
            }
        }

        net = round2(net);
        const tax = round2(net * TAX_RATE);
        const count = (await SELECT.from(InvoiceSrv).columns('NODE_KEY')).length;

        const invoice = {
            NODE_KEY: randomUUID(),
            INVOICE_NO: `INV-${today().slice(0, 4)}-${String(count + 1).padStart(4, '0')}`,
            PROJECT_NODE_KEY: projectID,
            PERIOD_FROM: periodFrom,
            PERIOD_TO: periodTo,
            INVOICE_DATE: today(),
            DUE_DATE: addDays(today(), PAYMENT_DAYS),
            BILLABLE_HOURS: hours,
            NET_AMOUNT: net,
            TAX_AMOUNT: tax,
            GROSS_AMOUNT: round2(net + tax),
            CURRENCY_code: budget.CURRENCY_CODE,
            STATUS: 'Draft'
        };

        await INSERT.into(InvoiceSrv).entries(invoice);

        // link the hours to the invoice so they can never be billed twice
        if (entries.length) {
            await UPDATE(TimesheetEntrySrv)
                .set({ INVOICE_NODE_KEY: invoice.NODE_KEY })
                .where({ NODE_KEY: { in: entries.map(e => e.NODE_KEY) } });
        }

        // a timesheet becomes "Invoiced" when all its billable hours are billed
        for (const timesheetKey of new Set(entries.map(e => e.PARENT_NODE_KEY))) {

            const open = await SELECT.one.from(TimesheetEntrySrv)
                .where({ PARENT_NODE_KEY: timesheetKey, IS_BILLABLE: true, INVOICE_NODE_KEY: null });

            if (!open) {
                await UPDATE(TimesheetSrv).set({ STATUS: 'Invoiced' }).where({ NODE_KEY: timesheetKey });
            }
        }

        return SELECT.one.from(InvoiceSrv).where({ NODE_KEY: invoice.NODE_KEY });
    });

    // ==================================================
    // INVOICE STATUS: Draft -> Issued -> Paid
    // ==================================================

    async function moveInvoice(req, from, to) {

        const key = req.params[0].NODE_KEY;

        const invoice = await SELECT.one.from(InvoiceSrv).where({ NODE_KEY: key });
        if (!invoice) {
            return req.reject(404, 'Invoice not found');
        }
        if (invoice.STATUS !== from) {
            return req.reject(409, `Invoice is ${invoice.STATUS}; only ${from} invoices can be set to ${to}.`);
        }

        await UPDATE(InvoiceSrv).set({ STATUS: to }).where({ NODE_KEY: key });

        req.notify(`Invoice ${invoice.INVOICE_NO} is now ${to}.`);
        return `Invoice ${invoice.INVOICE_NO} moved from ${from} to ${to}`;
    }

    this.on('issueInvoice', InvoiceSrv, (req) => moveInvoice(req, 'Draft', 'Issued'));

    this.on('markInvoicePaid', InvoiceSrv, (req) => moveInvoice(req, 'Issued', 'Paid'));

});
