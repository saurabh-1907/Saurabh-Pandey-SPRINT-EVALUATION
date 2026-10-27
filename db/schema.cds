namespace psa.db;

using { psa.common as common } from './common';
using { psa.db.master } from './master';

// Client -> Projects -> (1 Budget) + Milestones -> Tasks
// Employees log hours against Tasks through Timesheets
// Approved hours drive budget consumption and Invoices

context transaction {

    entity Projects {

        key NODE_KEY : common.Guid;

        PROJECT_CODE   : common.String32;
        PROJECT_NAME   : common.String255;
        BILLING_TYPE   : common.BillingType;
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
    }

    // One budget per project
    entity Budgets {

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

    entity Milestones {

        key NODE_KEY : common.Guid;

        MILESTONE_NAME     : common.String255;
        START_DATE         : Date;
        END_DATE           : Date;
        COMPLETION_PERCENT : common.Percent default 0;

        PROJECT : Association to Projects;

        TASKS : Composition of many Tasks
                on TASKS.MILESTONE = $self;
    }

    entity Tasks {

        key NODE_KEY : common.Guid;

        TASK_NAME       : common.String255;
        STATUS          : common.TaskStatus default 'To Do';
        ESTIMATED_HOURS : common.Hours;
        ACTUAL_HOURS    : common.Hours default 0;
        BURN_PERCENT    : common.Percent default 0;

        MILESTONE : Association to Milestones;
        ASSIGNEE  : Association to master.Employees;
    }

    // Header: one employee, one week
    entity Timesheets {

        key NODE_KEY : common.Guid;

        WEEK_START       : Date;
        WEEK_END         : Date;
        TOTAL_HOURS      : common.Hours default 0;
        STATUS           : common.TimesheetStatus default 'Draft';
        REJECTION_REASON : common.String255;

        EMPLOYEE    : Association to master.Employees;
        APPROVED_BY : Association to master.Employees;

        Entries : Composition of many TimesheetEntries
                  on Entries.PARENT = $self;
    }

    // Item: one day, one task
    entity TimesheetEntries {

        key NODE_KEY : common.Guid;

        WORK_DATE   : Date;
        HOURS       : Decimal(4,2);
        IS_BILLABLE : Boolean default true;
        NOTES       : common.String255;

        PARENT  : Association to Timesheets;
        TASK    : Association to Tasks;
        INVOICE : Association to Invoices;
    }

    entity Invoices : common.Amount {

        key NODE_KEY : common.Guid;

        INVOICE_NO     : common.String32;
        PERIOD_FROM    : Date;
        PERIOD_TO      : Date;
        INVOICE_DATE   : Date;
        DUE_DATE       : Date;
        BILLABLE_HOURS : common.Hours;
        STATUS         : common.InvoiceStatus default 'Draft';

        PROJECT : Association to Projects;

        Entries : Association to many TimesheetEntries
                  on Entries.INVOICE = $self;
    }

    // Scope-creep alert, raised once per threshold (75 / 90 / 100 %)
    entity Alerts {

        key NODE_KEY : common.Guid;

        THRESHOLD        : Integer;
        CONSUMED_PERCENT : common.Percent;
        MESSAGE          : common.String255;

        PROJECT : Association to Projects;
        TASK    : Association to Tasks;
    }
}
