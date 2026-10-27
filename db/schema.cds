namespace psa.db;

using { psa.common as common } from './common';
using { managed } from '@sap/cds/common';
using { psa.db.master } from './master';

// Client -> Projects -> (1 Budget) + Milestones -> Tasks
// Employees log hours against Tasks through Timesheets
// Approved hours drive budget consumption and Invoices

context transaction {

    entity Projects : managed {

        key NODE_KEY : common.Guid;

        PROJECT_CODE   : common.String32;
        PROJECT_NAME   : common.String255;
        DESCRIPTION    : String(500);
        BILLING_TYPE   : common.BillingType;
        STATUS         : common.ProjectStatus default 'Active';
        PRIORITY       : common.Priority default 'Medium';
        START_DATE     : Date;
        END_DATE       : Date;
        PLANNED_HOURS  : common.Hours;
        CONSUMED_HOURS : common.Hours default 0;

        CLIENT  : Association to master.Clients;
        MANAGER : Association to master.Employees;

        // Composition = edited together with the project in Fiori
        BUDGET : Composition of one Budgets
                 on BUDGET.PROJECT = $self;

        MILESTONES : Composition of many Milestones
                     on MILESTONES.PROJECT = $self;

        ALERTS : Association to many Alerts
                 on ALERTS.PROJECT = $self;

        INVOICES : Association to many Invoices
                   on INVOICES.PROJECT = $self;

        // all hours booked on the project (Timesheets facet of the project page)
        TIME_ENTRIES : Association to many ProjectTimeEntries
                       on TIME_ENTRIES.PROJECT = $self;
    }

    // One budget per project
    entity Budgets : managed {

        key NODE_KEY : common.Guid;

        BUDGET_AMOUNT    : common.AmountT;
        BILLING_RATE     : common.AmountT;
        RETAINER_FEE     : common.AmountT;
        CURRENCY_CODE    : String(5);

        CONSUMED_AMOUNT  : common.AmountT default 0;
        REMAINING_AMOUNT : common.AmountT;
        CONSUMED_PERCENT : common.Percent default 0;
        BUDGET_STATUS    : common.BudgetStatus default 'Within Budget';

        PROJECT : Association to Projects;
    }

    entity Milestones : managed {

        key NODE_KEY : common.Guid;

        MILESTONE_NAME     : common.String255;
        DESCRIPTION        : String(500);
        START_DATE         : Date;
        END_DATE           : Date;
        COMPLETION_PERCENT : common.Percent default 0;
        STATUS             : common.MilestoneStatus default 'Not Started';   // set by the roll-up

        PROJECT : Association to Projects;

        TASKS : Composition of many Tasks
                on TASKS.MILESTONE = $self;
    }

    entity Tasks : managed {

        key NODE_KEY : common.Guid;

        TASK_NAME       : common.String255;
        DESCRIPTION     : String(500);
        START_DATE      : Date;
        END_DATE        : Date;
        PRIORITY        : common.Priority default 'Medium';
        STATUS          : common.TaskStatus default 'To Do';
        ESTIMATED_HOURS : common.Hours;
        ACTUAL_HOURS    : common.Hours default 0;
        BURN_PERCENT    : common.Percent default 0;

        MILESTONE : Association to Milestones;
        ASSIGNEE  : Association to master.Employees;
    }

    // Header: one employee, one week
    entity Timesheets : managed {

        key NODE_KEY : common.Guid;

        WEEK_START       : Date;
        WEEK_END         : Date;
        TOTAL_HOURS      : common.Hours default 0;
        BILLABLE_HOURS   : common.Hours default 0;
        STATUS           : common.TimesheetStatus default 'Draft';
        SUBMITTED_DATE   : Date;
        APPROVED_DATE    : Date;
        REJECTION_REASON : common.String255;

        EMPLOYEE    : Association to master.Employees;
        APPROVED_BY : Association to master.Employees;

        Entries : Composition of many TimesheetEntries
                  on Entries.PARENT = $self;
    }

    // Item: one day, one task
    entity TimesheetEntries : managed {

        key NODE_KEY : common.Guid;

        WORK_DATE   : Date;
        HOURS       : Decimal(4,2);
        IS_BILLABLE : Boolean default true;
        NOTES       : common.String255;

        PARENT  : Association to Timesheets;
        TASK    : Association to Tasks;
        INVOICE : Association to Invoices;
    }

    entity Invoices : common.Amount, managed {

        key NODE_KEY : common.Guid;

        INVOICE_NO     : common.String32;
        PERIOD_FROM    : Date;
        PERIOD_TO      : Date;
        INVOICE_DATE   : Date;
        DUE_DATE       : Date;
        PAYMENT_DATE   : Date;
        BILLABLE_HOURS : common.Hours;
        STATUS         : common.InvoiceStatus default 'Draft';

        PROJECT : Association to Projects;

        Entries : Association to many TimesheetEntries
                  on Entries.INVOICE = $self;
    }

    // Hours booked on a project: entry + task + timesheet in one row (read-only view)
    entity ProjectTimeEntries as select from TimesheetEntries {
        key NODE_KEY,
            WORK_DATE,
            HOURS,
            IS_BILLABLE,
            NOTES,
            TASK.TASK_NAME           as TASK_NAME,
            PARENT.STATUS            as TIMESHEET_STATUS,
            PARENT.EMPLOYEE.nameFirst || ' ' || PARENT.EMPLOYEE.nameLast as EMPLOYEE_NAME : String(130),
            INVOICE.INVOICE_NO       as INVOICE_NO,
            TASK.MILESTONE.PROJECT   as PROJECT
    };

    // Audit trail: every write and every status change (who, when, what)
    entity AuditLog {

        key NODE_KEY : common.Guid;

        TIMESTAMP  : Timestamp;
        USER_ID    : common.String255;
        ACTION     : common.String64;      // CREATE, UPDATE, DELETE, submitTimesheet, ...
        ENTITY     : common.String64;
        ENTITY_KEY : common.String64;
        DETAILS    : String(1000);         // changed values / message
    }

    // Scope-creep alert, raised once per threshold (75 / 90 / 100 %)
    entity Alerts : managed {

        key NODE_KEY : common.Guid;

        THRESHOLD        : Integer;
        CONSUMED_PERCENT : common.Percent;
        MESSAGE          : common.String255;

        PROJECT : Association to Projects;
        TASK    : Association to Tasks;
    }
}
