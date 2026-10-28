const cds = require('@sap/cds');
const { randomUUID } = require('crypto');

const { INSERT, SELECT, UPDATE } = cds.ql;

// ==================================================
// SETTINGS
// ==================================================

// defaults - the Admin can change them in the Settings app (table Settings, ID = 1)
const DEFAULT_SETTINGS = {
    ALERT_THRESHOLDS: '75,90,100',   // % of estimate / budget
    AT_RISK_PERCENT : 80,
    TAX_PERCENT     : 18,
    PAYMENT_DAYS    : 30
};

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

module.exports = cds.service.impl(async function () {

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
        AlertSrv,
        SettingsSrv,
        AuditLogSrv
    } = this.entities;

    // current settings (thresholds, tax, payment terms)
    async function settings() {
        const row = await SELECT.one.from(SettingsSrv).where({ ID: 1 });
        const value = { ...DEFAULT_SETTINGS, ...(row ?? {}) };
        return {
            alertThresholds: String(value.ALERT_THRESHOLDS).split(',').map(Number).filter(n => n > 0).sort((a, b) => a - b),
            atRiskPercent  : Number(value.AT_RISK_PERCENT),
            taxRate        : Number(value.TAX_PERCENT) / 100,
            paymentDays    : Number(value.PAYMENT_DAYS)
        };
    }

    // ==================================================
    // AUDIT LOG (FR-012): who changed what and when
    // ==================================================

    async function audit(req, action, entity, key, details) {
        await INSERT.into(AuditLogSrv).entries({
            NODE_KEY  : randomUUID(),
            TIMESTAMP : new Date().toISOString(),
            USER_ID   : req.user?.id ?? 'system',
            ACTION    : action,
            ENTITY    : entity,
            ENTITY_KEY: key ? String(key) : null,
            DETAILS   : details ? String(details).slice(0, 1000) : null
        });
    }

    // every saved create / update / delete (drafts are only saved when activated)
    this.after(['CREATE', 'UPDATE', 'DELETE'], async (_, req) => {

        const entity = req.target?.name?.split('.').pop();
        if (!entity || entity.endsWith('drafts') || entity === 'AuditLogSrv') return;

        const key = req.data?.NODE_KEY ?? req.data?.ID ?? Object.values(req.params?.[0] ?? {})[0];
        const changed = Object.keys(req.data ?? {})
            .filter(field => !['NODE_KEY', 'ID', 'IsActiveEntity', 'HasActiveEntity', 'HasDraftEntity', 'DraftAdministrativeData_DraftUUID'].includes(field)
                && !field.startsWith('created') && !field.startsWith('modified'));

        await audit(req, req.event, entity, key, changed.length ? 'Fields: ' + changed.join(', ') : null);
    });

    // ==================================================
    // BUDGET ROLL-UP + ALERTS
    // Approved hours -> Task -> Milestone -> Project -> Budget
    // ==================================================

    async function recalculateProject(projectKey) {

        const { alertThresholds, atRiskPercent } = await settings();

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

        // ---- milestones: % of tasks done + status ----
        for (const milestone of milestones) {

            const mTasks = tasks.filter(t => t.MILESTONE_NODE_KEY === milestone.NODE_KEY);
            const done = mTasks.filter(t => t.STATUS === 'Done').length;
            const completion = mTasks.length ? round2(done / mTasks.length * 100) : 0;
            const started = completion > 0 || mTasks.some(t => t.ACTUAL_HOURS > 0 || t.STATUS === 'In Progress');

            let STATUS = 'Not Started';
            if (completion >= 100) STATUS = 'Completed';
            else if (milestone.END_DATE && milestone.END_DATE < today()) STATUS = 'Delayed';
            else if (started) STATUS = 'In Progress';

            await UPDATE(MilestoneSrv)
                .set({ COMPLETION_PERCENT: completion, STATUS })
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
            else if (consumedPercent >= atRiskPercent) BUDGET_STATUS = 'At Risk';

            await UPDATE(BudgetSrv)
                .set({ CONSUMED_AMOUNT, REMAINING_AMOUNT, CONSUMED_PERCENT: consumedPercent, BUDGET_STATUS })
                .where({ NODE_KEY: budget.NODE_KEY });
        }

        // ---- scope-creep alerts: one per threshold crossing ----
        const existing = await SELECT.from(AlertSrv).where({ PROJECT_NODE_KEY: projectKey });

        const alreadyRaised = (taskKey, threshold) =>
            existing.some(a => (a.TASK_NODE_KEY || null) === taskKey && a.THRESHOLD === threshold);

        const newAlerts = [];

        for (const threshold of alertThresholds) {

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
            .columns('HOURS', 'IS_BILLABLE')
            .where({ PARENT_NODE_KEY: timesheetKey });
        const sum = (list) => round2(list.reduce((total, e) => total + Number(e.HOURS), 0));

        await UPDATE(TimesheetSrv)
            .set({ TOTAL_HOURS: sum(entries), BILLABLE_HOURS: sum(entries.filter(e => e.IS_BILLABLE)) })
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
            checkMilestone(req, milestone, req.data);
            for (const task of milestone.TASKS ?? []) checkTask(req, task, milestone);
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

    // FR-003: dates fall within the parent period
    const outside = (child, parent) =>
        (child.START_DATE && parent.START_DATE && child.START_DATE < parent.START_DATE) ||
        (child.END_DATE && parent.END_DATE && child.END_DATE > parent.END_DATE);

    function checkMilestone(req, milestone, project) {
        if (milestone.START_DATE && milestone.END_DATE && milestone.END_DATE < milestone.START_DATE) {
            req.reject(400, `Milestone "${milestone.MILESTONE_NAME}": end date must be on or after start date.`);
        }
        if (project && outside(milestone, project)) {
            req.reject(400, `Milestone "${milestone.MILESTONE_NAME}": dates must be inside the project period.`);
        }
    }

    function checkTask(req, task, milestone) {
        if (!(Number(task.ESTIMATED_HOURS) > 0)) {
            req.reject(400, `Task "${task.TASK_NAME ?? ''}": estimated hours must be greater than 0.`);
        }
        if (task.START_DATE && task.END_DATE && task.END_DATE < task.START_DATE) {
            req.reject(400, `Task "${task.TASK_NAME ?? ''}": end date must be on or after start date.`);
        }
        if (milestone && outside(task, milestone)) {
            req.reject(400, `Task "${task.TASK_NAME ?? ''}": dates must be inside the milestone period.`);
        }
    }

    // FRD 7.1 getBurnSummary: burn rate = approved hours per week since the start,
    // projected end = today + remaining planned hours / burn rate
    function burn(project) {

        const consumed = Number(project.CONSUMED_HOURS ?? 0);
        const planned = Number(project.PLANNED_HOURS ?? 0);
        if (!project.START_DATE || project.START_DATE > today()) {
            return { burnRate: 0, projectedEnd: null };
        }

        const until = project.END_DATE && project.END_DATE < today() ? project.END_DATE : today();
        const weeks = Math.max(1, (new Date(until) - new Date(project.START_DATE)) / (7 * 24 * 3600 * 1000));
        const burnRate = round2(consumed / weeks);

        let projectedEnd = null;
        if (consumed >= planned && planned > 0) projectedEnd = today();
        else if (burnRate > 0) projectedEnd = addDays(today(), Math.ceil((planned - consumed) / burnRate * 7));

        return { burnRate, projectedEnd };
    }

    this.on('getBurnSummary', async (req) => {

        const project = await SELECT.one.from(ProjectSrv).where({ NODE_KEY: req.data.projectID });
        if (!project) {
            return req.reject(404, 'Project not found');
        }
        const budget = await SELECT.one.from(BudgetSrv).where({ PROJECT_NODE_KEY: project.NODE_KEY }) ?? {};
        const { burnRate, projectedEnd } = burn(project);

        return {
            projectCode    : project.PROJECT_CODE,
            budgetAmount   : budget.BUDGET_AMOUNT ?? 0,
            consumedAmount : budget.CONSUMED_AMOUNT ?? 0,
            remainingAmount: budget.REMAINING_AMOUNT ?? 0,
            consumedPercent: budget.CONSUMED_PERCENT ?? 0,
            budgetStatus   : budget.BUDGET_STATUS ?? null,
            plannedHours   : project.PLANNED_HOURS ?? 0,
            consumedHours  : project.CONSUMED_HOURS ?? 0,
            burnRate,
            projectedEnd,
            currency       : budget.CURRENCY_CODE ?? null
        };
    });

    // burn rate + projected end shown on the project page
    this.after('READ', [ProjectSrv, ProjectSrv.drafts], async (result, req) => {

        const columns = req.query?.SELECT?.columns;
        const wanted = !columns || columns.some(c => c === '*' || ['BURN_RATE', 'PROJECTED_END'].includes(c.ref?.[0]));
        if (!wanted) return;

        const rows = Array.isArray(result) ? result : result ? [result] : [];
        for (const row of rows) {
            if (!row?.NODE_KEY) continue;

            const project = await SELECT.one.from(ProjectSrv)
                .columns('START_DATE', 'END_DATE', 'PLANNED_HOURS', 'CONSUMED_HOURS')
                .where({ NODE_KEY: row.NODE_KEY });
            if (!project) continue;

            const { burnRate, projectedEnd } = burn(project);
            row.BURN_RATE = burnRate;
            row.PROJECTED_END = projectedEnd;
        }
    });

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
            .set({ STATUS: 'Submitted', REJECTION_REASON: null, SUBMITTED_DATE: today() })
            .where({ NODE_KEY: key });

        await audit(req, 'submitTimesheet', 'TimesheetSrv', key, `Week ${timesheet.WEEK_START}`);
        req.notify('Timesheet submitted for approval.');
        return 'Timesheet submitted for approval';
    });

    // ==================================================
    // IMPORT HOURS FROM A TIME TRACKER (FR-005)
    // one row per line: date;task;hours;billable;notes  (also , or tab)
    // the task is its name, or "PROJECT_CODE / task name" if the name is not unique
    // ==================================================

    this.on('importHours', TimesheetSrv, async (req) => {

        const key = req.params[0].NODE_KEY;
        const timesheet = await SELECT.one.from(TimesheetSrv).where({ NODE_KEY: key });
        if (!timesheet) {
            return req.reject(404, 'Timesheet not found');
        }
        if (!isEditable(timesheet)) {
            return req.reject(409, `Timesheet is ${timesheet.STATUS} and locked.`);
        }

        const tasks = await SELECT.from(TaskSrv).columns('NODE_KEY', 'TASK_NAME', 'PROJECT_CODE');
        const existing = await SELECT.from(TimesheetEntrySrv).where({ PARENT_NODE_KEY: key });
        const accepted = [];
        const problems = [];
        let duplicates = 0;

        const lines = String(req.data.rows ?? '').split(/\r?\n/);
        lines.forEach((line, i) => { lines[i] = { no: i + 1, text: line.trim() }; });

        for (const { no, text } of lines) {

            if (!text || /^date[;,\t]/i.test(text)) continue;          // empty line or header
            const [date, taskText = '', hours, billable = '', ...notes] = text.split(/[;\t]|,(?=(?:[^"]*"[^"]*")*[^"]*$)/).map(v => v.trim());

            // map the tracker's task to a PSA task
            const [code, name] = taskText.includes('/') ? taskText.split('/').map(v => v.trim()) : [null, taskText];
            const matches = tasks.filter(t => t.TASK_NAME?.toLowerCase() === name.toLowerCase()
                && (!code || t.PROJECT_CODE?.toLowerCase() === code.toLowerCase()));
            if (matches.length !== 1) {
                problems.push(`line ${no}: task "${taskText}" ${matches.length ? 'is not unique - use PROJECT_CODE / task' : 'not found'}`);
                continue;
            }

            const entry = {
                NODE_KEY: randomUUID(),
                PARENT_NODE_KEY: key,
                TASK_NODE_KEY: matches[0].NODE_KEY,
                WORK_DATE: date,
                HOURS: Number(String(hours).replace(',', '.')),
                IS_BILLABLE: !/^(no|n|false|0|non-billable)$/i.test(billable),
                NOTES: notes.join(' ').replace(/^"|"$/g, '') || null
            };

            // same task on the same day already booked -> ignore
            if ([...existing, ...accepted].some(e => e.TASK_NODE_KEY === entry.TASK_NODE_KEY && e.WORK_DATE === entry.WORK_DATE)) {
                duplicates++;
                continue;
            }

            const error = await checkEntries(timesheet, [...existing, ...accepted, entry]);
            if (error) {
                problems.push(`line ${no}: ${error}`);
                continue;
            }
            accepted.push(entry);
        }

        if (accepted.length) {
            await INSERT.into(TimesheetEntrySrv).entries(accepted);
            await updateTimesheetTotal(key);
        }

        const summary = `${accepted.length} row(s) imported, ${duplicates} duplicate(s) ignored, ${problems.length} row(s) not imported.`;
        await audit(req, 'importHours', 'TimesheetSrv', key, summary);

        if (problems.length) {
            req.warn(summary + ' ' + problems.join('; '));
        } else {
            req.notify(summary);
        }
        return summary;
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
            .set({ STATUS: 'Approved', APPROVED_BY_ID: timesheet.approverID, APPROVED_DATE: today() })
            .where({ NODE_KEY: timesheet.NODE_KEY });
        await audit(req, 'approveTimesheet', 'TimesheetSrv', timesheet.NODE_KEY, `Week ${timesheet.WEEK_START}`);

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
            .set({ STATUS: 'Rejected', APPROVED_BY_ID: timesheet.approverID, REJECTION_REASON: req.data.reason, APPROVED_DATE: null })
            .where({ NODE_KEY: timesheet.NODE_KEY });
        await audit(req, 'rejectTimesheet', 'TimesheetSrv', timesheet.NODE_KEY, `Reason: ${req.data.reason}`);

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
                STATUS: { '!=': 'Cancelled' },
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
                const previous = await SELECT.from(InvoiceSrv).columns('NET_AMOUNT')
                    .where({ PROJECT_NODE_KEY: projectID, STATUS: { '!=': 'Cancelled' } });
                const alreadyBilled = previous.reduce((sum, i) => sum + Number(i.NET_AMOUNT), 0);

                net = Math.min(net, budget.BUDGET_AMOUNT - alreadyBilled);
                if (net <= 0) {
                    return req.reject(409, 'The fixed contract amount is already fully billed.');
                }
            }
        }

        const { taxRate, paymentDays } = await settings();
        net = round2(net);
        const tax = round2(net * taxRate);
        const count = (await SELECT.from(InvoiceSrv).columns('NODE_KEY')).length;

        const invoice = {
            NODE_KEY: randomUUID(),
            INVOICE_NO: `INV-${today().slice(0, 4)}-${String(count + 1).padStart(4, '0')}`,
            PROJECT_NODE_KEY: projectID,
            PERIOD_FROM: periodFrom,
            PERIOD_TO: periodTo,
            INVOICE_DATE: today(),
            DUE_DATE: addDays(today(), paymentDays),
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

        await audit(req, 'generateInvoice', 'InvoiceSrv', invoice.NODE_KEY,
            `${invoice.INVOICE_NO}: ${hours} h, gross ${invoice.GROSS_AMOUNT} ${invoice.CURRENCY_code}`);
        return SELECT.one.from(InvoiceSrv).where({ NODE_KEY: invoice.NODE_KEY });
    });

    // ==================================================
    // INVOICE STATUS: Draft -> Issued -> Paid
    // ==================================================

    async function moveInvoice(req, from, to, extra = {}) {

        const key = req.params[0].NODE_KEY;
        const allowed = [].concat(from);

        const invoice = await SELECT.one.from(InvoiceSrv).where({ NODE_KEY: key });
        if (!invoice) {
            return req.reject(404, 'Invoice not found');
        }
        if (!allowed.includes(invoice.STATUS)) {
            return req.reject(409, `Invoice is ${invoice.STATUS}; only ${allowed.join(' or ')} invoices can be set to ${to}.`);
        }

        await UPDATE(InvoiceSrv).set({ STATUS: to, ...extra }).where({ NODE_KEY: key });
        await audit(req, `invoice ${invoice.STATUS} -> ${to}`, 'InvoiceSrv', key, invoice.INVOICE_NO);

        req.notify(`Invoice ${invoice.INVOICE_NO} is now ${to}.`);
        return invoice;
    }

    this.on('issueInvoice', InvoiceSrv, async (req) => {
        const invoice = await moveInvoice(req, 'Draft', 'Issued');
        return invoice && `Invoice ${invoice.INVOICE_NO} moved from Draft to Issued`;
    });

    this.on('markInvoicePaid', InvoiceSrv, async (req) => {

        const paymentDate = req.data.paymentDate ?? today();
        if (paymentDate > today()) {
            return req.reject(400, 'The payment date cannot be in the future.');
        }

        const invoice = await moveInvoice(req, 'Issued', 'Paid', { PAYMENT_DATE: paymentDate });
        return invoice && `Invoice ${invoice.INVOICE_NO} paid on ${paymentDate}`;
    });

    // cancel a Draft or Issued invoice: its hours can be billed again
    this.on('cancelInvoice', InvoiceSrv, async (req) => {

        const invoice = await moveInvoice(req, ['Draft', 'Issued'], 'Cancelled');
        if (!invoice) return;

        const entries = await SELECT.from(TimesheetEntrySrv).columns('PARENT_NODE_KEY')
            .where({ INVOICE_NODE_KEY: invoice.NODE_KEY });

        await UPDATE(TimesheetEntrySrv).set({ INVOICE_NODE_KEY: null }).where({ INVOICE_NODE_KEY: invoice.NODE_KEY });
        for (const timesheetKey of new Set(entries.map(e => e.PARENT_NODE_KEY))) {
            await UPDATE(TimesheetSrv).set({ STATUS: 'Approved' }).where({ NODE_KEY: timesheetKey, STATUS: 'Invoiced' });
        }

        return `Invoice ${invoice.INVOICE_NO} cancelled`;
    });

});
