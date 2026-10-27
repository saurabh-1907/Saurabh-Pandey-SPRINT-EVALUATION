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

    // ---------------- KPI numbers for the launchpad tiles ----------------

    type Kpis {
        // ---- own time (every user) ----
        myEmployeeID     : UUID;
        myOpenTimesheets : Integer;          // own Draft / Rejected timesheets
        mySubmitted      : Integer;          // own timesheets waiting for approval
        myWeekStart      : Date;             // Monday of the current week
        myWeekKey        : UUID;             // timesheet of the current week (if any)
        myWeekIsDraft    : Boolean;          // ... only an unsaved draft so far
        myWeekStatus     : String(10);
        myWeekHours      : Decimal(10,2);
        // ---- admin ----
        atRiskTasks      : Integer;          // burn >= 80 % and not Done
        pendingApprovals : Integer;          // Admin only (others: null)
        atRiskBudgets    : Integer;
        activeProjects   : Integer;
        draftInvoices    : Integer;
        unbilledHours    : Decimal(10,2);
        overdueInvoices  : Integer;          // Issued and past the due date
        overdueAmount    : Decimal(15,2);
        clients          : Integer;
        employees        : Integer;
    }

    function kpis() returns Kpis;

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
