using { psa.db as database } from '../db/schema';

// Login via XSUAA. The login e-mail ($user) links a user to an Employees record.
// Two roles:
//   Admin - maintains clients, employees, projects; approves timesheets; creates invoices
//   User  - logs time in own timesheets and submits them; sees nothing else
@requires: 'authenticated-user'
service PSAService {

    // ---------------- Login check: what does the server see? ----------------

    type WhoAmI {
        user     : String;
        name     : String;
        email    : String;
        origin   : String;          // identity provider used for the login
        isAdmin  : Boolean;
        isUser   : Boolean;
        scopes   : many String;     // roles inside the XSUAA token
        employee : String;          // Employees record linked by e-mail
    }

    function whoAmI() returns WhoAmI;

    // ---------------- Master data ----------------

    @odata.draft.enabled
    @restrict: [{ grant: '*', to: 'Admin' }]
    entity ClientSrv
    as projection on database.master.Clients;

    @odata.draft.enabled
    @restrict: [
        { grant: 'READ', to: 'User', where: 'email = $user' },   // only own record
        { grant: '*',    to: 'Admin' }
    ]
    entity EmployeeSrv
    as projection on database.master.Employees {
        *,
        nameFirst || ' ' || nameLast as fullName : String(130)
    };

    // ---------------- Projects (with Budget, Milestones, Tasks) ----------------

    @odata.draft.enabled
    @restrict: [{ grant: '*', to: 'Admin' }]
    entity ProjectSrv
    as projection on database.transaction.Projects {
        *,
        case
            when PLANNED_HOURS > 0 then CONSUMED_HOURS * 100 / PLANNED_HOURS
            else 0
        end as HOURS_PERCENT : Decimal(7,2)
    } actions {

        action recalculateBudget()
            returns String;
    };

    // CRITICALITY = colour in Fiori (1 red, 2 orange, 3 green)
    @restrict: [{ grant: '*', to: 'Admin' }]
    entity BudgetSrv
    as projection on database.transaction.Budgets {
        *,
        case
            when BUDGET_STATUS = 'Breached' then 1
            when BUDGET_STATUS = 'At Risk'  then 2
            else 3
        end as CRITICALITY : Integer
    };

    @restrict: [{ grant: '*', to: 'Admin' }]
    entity MilestoneSrv
    as projection on database.transaction.Milestones;

    @restrict: [
        { grant: 'READ', to: 'User' },   // to pick a task in the timesheet
        { grant: '*',    to: 'Admin' }
    ]
    entity TaskSrv
    as projection on database.transaction.Tasks {
        *,
        MILESTONE.PROJECT.PROJECT_CODE as PROJECT_CODE,
        case
            when BURN_PERCENT >= 100 then 1
            when BURN_PERCENT >= 80  then 2
            else 3
        end as CRITICALITY : Integer
    };

    // ---------------- Time tracking (User: only own timesheets) ----------------

    @odata.draft.enabled
    @restrict: [
        { grant: ['READ', 'WRITE', 'submitTimesheet'], to: 'User', where: 'EMPLOYEE.email = $user' },
        { grant: '*', to: 'Admin' }
    ]
    entity TimesheetSrv
    as projection on database.transaction.Timesheets {
        *,
        case
            when STATUS = 'Rejected'  then 1
            when STATUS = 'Submitted' then 2
            when STATUS = 'Draft'     then 0
            else 3
        end as STATUS_CRITICALITY : Integer,
        case
            when STATUS = 'Draft' or STATUS = 'Rejected' then false
            else true
        end as IS_LOCKED : Boolean          // hides Edit / Delete after submit
    } actions {

        action submitTimesheet()
            returns String;
    };

    @restrict: [
        { grant: ['READ', 'WRITE'], to: 'User', where: 'PARENT.EMPLOYEE.email = $user' },
        { grant: '*', to: 'Admin' }
    ]
    entity TimesheetEntrySrv
    as projection on database.transaction.TimesheetEntries;

    // ---------------- Approvals (Admin): submitted timesheets ----------------

    @readonly
    @cds.redirection.target: false
    @restrict: [{ grant: '*', to: 'Admin' }]
    entity ApprovalSrv
    as projection on database.transaction.Timesheets {
        *,
        Entries : redirected to TimesheetEntrySrv on Entries.PARENT.NODE_KEY = NODE_KEY,
        2 as STATUS_CRITICALITY : Integer
    }
    where STATUS = 'Submitted' actions {

        action approveTimesheet()
            returns String;

        action rejectTimesheet(reason : String)
            returns String;
    };

    // ---------------- Billing (Admin) ----------------

    @readonly
    @restrict: [{ grant: '*', to: 'Admin' }]
    entity InvoiceSrv
    as projection on database.transaction.Invoices {
        *,
        case
            when STATUS = 'Paid'   then 3
            when STATUS = 'Issued' then 2
            else 0
        end as STATUS_CRITICALITY : Integer
    } actions {

        action issueInvoice()
            returns String;

        action markInvoicePaid()
            returns String;
    };

    @requires: 'Admin'
    action generateInvoice(
        projectID  : UUID,
        periodFrom : Date,
        periodTo   : Date
    ) returns InvoiceSrv;

    // ---------------- Manager Home (Analytical List Page, Admin) ----------------
    // one row per project with its budget, so Fiori can group, sum and chart it

    @readonly
    @cds.redirection.target: false
    @restrict: [{ grant: 'READ', to: 'Admin' }]
    entity ProjectAnalytics
    as projection on database.transaction.Projects {
        key NODE_KEY,
            PROJECT_CODE,
            PROJECT_NAME,
            BILLING_TYPE,
            START_DATE,
            END_DATE,
            CLIENT.CLIENT_NAME      as CLIENT_NAME      : String(255),
            BUDGET.CURRENCY_CODE    as CURRENCY_CODE    : String(5),
            BUDGET.BUDGET_STATUS    as BUDGET_STATUS    : String(15),
            BUDGET.BUDGET_AMOUNT    as BUDGET_AMOUNT    : Decimal(15,2),
            BUDGET.CONSUMED_AMOUNT  as CONSUMED_AMOUNT  : Decimal(15,2),
            BUDGET.REMAINING_AMOUNT as REMAINING_AMOUNT : Decimal(15,2),
            BUDGET.CONSUMED_PERCENT as CONSUMED_PERCENT : Decimal(7,2),
            PLANNED_HOURS,
            CONSUMED_HOURS,
            case
                when BUDGET.BUDGET_STATUS = 'Breached' then 1
                when BUDGET.BUDGET_STATUS = 'At Risk'  then 2
                else 3
            end as CRITICALITY : Integer,
            // counters (summed by Fiori for the KPI cards)
            case when END_DATE >= current_date then 1 else 0 end as ACTIVE_COUNT : Integer,
            case
                when BUDGET.BUDGET_STATUS = 'At Risk' or BUDGET.BUDGET_STATUS = 'Breached' then 1
                else 0
            end as AT_RISK_COUNT : Integer
    };

    // KPI "Pending Approvals" (Manager Home)
    @readonly
    @cds.redirection.target: false
    @restrict: [{ grant: 'READ', to: 'Admin' }]
    entity TimesheetAnalytics
    as projection on database.transaction.Timesheets {
        key NODE_KEY,
            WEEK_START,
            STATUS,
            case when STATUS = 'Submitted' then 1 else 0 end as PENDING_COUNT : Integer
    };

    // KPIs "Draft Invoices" and "Overdue Amount" (Billing Workbench)
    @readonly
    @cds.redirection.target: false
    @restrict: [{ grant: 'READ', to: 'Admin' }]
    entity InvoiceAnalytics
    as projection on database.transaction.Invoices {
        key NODE_KEY,
            INVOICE_NO,
            STATUS,
            CURRENCY.code        as CURRENCY_CODE : String(3),
            PROJECT.PROJECT_NAME as PROJECT_NAME  : String(255),
            case when STATUS = 'Draft' then 1 else 0 end as DRAFT_COUNT : Integer,
            case
                when STATUS = 'Issued' and DUE_DATE < current_date then GROSS_AMOUNT
                else 0
            end as OVERDUE_AMOUNT : Decimal(15,2)
    };

    // KPI "Unbilled Hours" (Billing Workbench): approved, billable, not invoiced
    @readonly
    @cds.redirection.target: false
    @restrict: [{ grant: 'READ', to: 'Admin' }]
    entity EntryAnalytics
    as projection on database.transaction.TimesheetEntries {
        key NODE_KEY,
            WORK_DATE,
            TASK.MILESTONE.PROJECT.PROJECT_NAME as PROJECT_NAME : String(255),
            case
                when PARENT.STATUS = 'Approved' and IS_BILLABLE = true and INVOICE.NODE_KEY is null then HOURS
                else 0
            end as UNBILLED_HOURS : Decimal(10,2)
    };

    // ---------------- Scope-creep alerts (Admin) ----------------

    @readonly
    @restrict: [{ grant: 'READ', to: 'Admin' }]
    entity AlertSrv
    as projection on database.transaction.Alerts {
        *,
        case when THRESHOLD >= 100 then 1 else 2 end as CRITICALITY : Integer
    };
}

// ---------------- Fields filled by the system (not editable) ----------------

annotate PSAService.ProjectSrv with {
    CONSUMED_HOURS @readonly;
    BILLING_TYPE   @assert.range;
};

annotate PSAService.BudgetSrv with {
    CONSUMED_AMOUNT  @readonly;
    REMAINING_AMOUNT @readonly;
    CONSUMED_PERCENT @readonly;
    BUDGET_STATUS    @readonly;
};

annotate PSAService.MilestoneSrv with {
    COMPLETION_PERCENT @readonly;
};

annotate PSAService.TaskSrv with {
    STATUS       @assert.range;
    ACTUAL_HOURS @readonly;
    BURN_PERCENT @readonly;
};

annotate PSAService.TimesheetSrv with {
    EMPLOYEE         @readonly;
    APPROVED_BY      @readonly;
    WEEK_END         @readonly;
    TOTAL_HOURS      @readonly;
    STATUS           @readonly;
    REJECTION_REASON @readonly;
};

annotate PSAService.TimesheetEntrySrv with {
    INVOICE @readonly;
};
