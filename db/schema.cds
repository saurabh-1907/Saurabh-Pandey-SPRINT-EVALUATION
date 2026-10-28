// Namespace = <company / product>.<layer>: Professional Services Automation, database layer
namespace psa.db;

using { psa.common as cmn } from './common';
using { cuid, managed } from '@sap/cds/common';
using { CDSViews } from './CDSView';

// Client -> Projects -> (1 Budget) + Milestones -> Tasks
// Employees log hours against Tasks through Timesheets
// Approved hours drive budget consumption and Invoices
// Labels: {i18n>KEY} -> db/i18n/i18n.properties (+ _de, _hi)

// ==================================================
// MASTER DATA: clients, employees, settings
// ==================================================
context master {

    entity Clients : cmn.Address, managed {
        key NODE_KEY       : cmn.Guid             @(title: '{i18n>NODE_KEY}');
            CLIENT_NAME    : cmn.String255        @(title: '{i18n>CLIENT_NAME}');
            CONTACT_PERSON : cmn.String64         @(title: '{i18n>CONTACT_PERSON}');
            EMAIL          : cmn.Email            @(title: '{i18n>EMAIL}');
            PHONE          : cmn.PhoneNumber      @(title: '{i18n>PHONE}');
            INDUSTRY       : cmn.String64         @(title: '{i18n>INDUSTRY}');
            STATUS         : cmn.ClientStatus default 'Active' @(title: '{i18n>STATUS}');
    }

    // A manager is an employee with isManager = true
    entity Employees : cuid, managed {
        nameFirst     : cmn.String64              @(title: '{i18n>FIRST_NAME}');
        nameLast      : cmn.String64              @(title: '{i18n>LAST_NAME}');
        email         : cmn.Email                 @(title: '{i18n>EMAIL}');
        phoneNumber   : cmn.PhoneNumber           @(title: '{i18n>PHONE}');
        jobTitle      : cmn.String64              @(title: '{i18n>JOB_TITLE}');
        joinDate      : Date                      @(title: '{i18n>JOIN_DATE}');
        Currency_code : String(3)                 @(title: '{i18n>CURRENCY_CODE}');
        hourlyRate    : cmn.AmountT               @(title: '{i18n>HOURLY_RATE}');
        isManager     : Boolean default false     @(title: '{i18n>IS_MANAGER}');
        isActive      : Boolean default true      @(title: '{i18n>IS_ACTIVE}');
        // Managed association to the same entity (line manager)
        manager       : Association to Employees  @(title: '{i18n>LINE_MANAGER}');
    }

    // Configuration maintained by the Admin (one row, ID = 1)
    entity Settings : managed {
        key ID               : Integer                         @(title: '{i18n>ID}');
            ALERT_THRESHOLDS : String(50) default '75,90,100'  @(title: '{i18n>ALERT_THRESHOLDS}');   // % of estimate / budget
            AT_RISK_PERCENT  : cmn.Percent default 80          @(title: '{i18n>AT_RISK_PERCENT}');    // budget status "At Risk" from here
            TAX_PERCENT      : cmn.Percent default 18          @(title: '{i18n>TAX_PERCENT}');
            PAYMENT_DAYS     : Integer default 30              @(title: '{i18n>PAYMENT_DAYS}');       // due date = invoice date + days
    }
}

// ==================================================
// TRANSACTION DATA: projects, time, invoices
// ==================================================
context transaction {

    entity Projects : managed {
        key NODE_KEY       : cmn.Guid                              @(title: '{i18n>NODE_KEY}');
            PROJECT_CODE   : cmn.String32                          @(title: '{i18n>PROJECT_CODE}');
            PROJECT_NAME   : cmn.String255                         @(title: '{i18n>PROJECT_NAME}');
            DESCRIPTION    : String(500)                           @(title: '{i18n>DESCRIPTION}');
            BILLING_TYPE   : cmn.BillingType                       @(title: '{i18n>BILLING_TYPE}');
            STATUS         : cmn.ProjectStatus default 'Active'    @(title: '{i18n>PROJECT_STATUS}');
            PRIORITY       : cmn.Priority default 'Medium'         @(title: '{i18n>PRIORITY}');
            START_DATE     : Date                                  @(title: '{i18n>START_DATE}');
            END_DATE       : Date                                  @(title: '{i18n>END_DATE}');
            PLANNED_HOURS  : cmn.Hours                             @(title: '{i18n>PLANNED_HOURS}');
            CONSUMED_HOURS : cmn.Hours default 0                   @(title: '{i18n>CONSUMED_HOURS}');
            // Managed associations to master data of the other context
            CLIENT         : Association to master.Clients         @(title: '{i18n>CLIENT}');
            MANAGER        : Association to master.Employees       @(title: '{i18n>PROJECT_MANAGER}');
            // Composition = edited together with the project in Fiori
            BUDGET         : Composition of one Budgets
                                 on BUDGET.PROJECT = $self;
            MILESTONES     : Composition of many Milestones
                                 on MILESTONES.PROJECT = $self;
            // Unmanaged associations - cardinality one to many
            ALERTS         : Association to many Alerts
                                 on ALERTS.PROJECT = $self;
            INVOICES       : Association to many Invoices
                                 on INVOICES.PROJECT = $self;
            // all hours booked on the project (Timesheets facet of the project page)
            TIME_ENTRIES   : Association to many CDSViews.ProjectTimeEntries
                                 on TIME_ENTRIES.PROJECT = $self;
    }

    // One budget per project
    entity Budgets : managed {
        key NODE_KEY         : cmn.Guid                                     @(title: '{i18n>NODE_KEY}');
            BUDGET_AMOUNT    : cmn.AmountT                                  @(title: '{i18n>BUDGET_AMOUNT}');
            BILLING_RATE     : cmn.AmountT                                  @(title: '{i18n>BILLING_RATE}');
            RETAINER_FEE     : cmn.AmountT                                  @(title: '{i18n>RETAINER_FEE}');
            CURRENCY_CODE    : String(5)                                    @(title: '{i18n>CURRENCY_CODE}');
            CONSUMED_AMOUNT  : cmn.AmountT default 0                        @(title: '{i18n>CONSUMED_AMOUNT}');
            REMAINING_AMOUNT : cmn.AmountT                                  @(title: '{i18n>REMAINING_AMOUNT}');
            CONSUMED_PERCENT : cmn.Percent default 0                        @(title: '{i18n>CONSUMED_PERCENT}');
            BUDGET_STATUS    : cmn.BudgetStatus default 'Within Budget'     @(title: '{i18n>BUDGET_STATUS}');
            PROJECT          : Association to Projects                      @(title: '{i18n>PROJECT}');
    }

    entity Milestones : managed {
        key NODE_KEY           : cmn.Guid                                   @(title: '{i18n>NODE_KEY}');
            MILESTONE_NAME     : cmn.String255                              @(title: '{i18n>MILESTONE_NAME}');
            DESCRIPTION        : String(500)                                @(title: '{i18n>MILESTONE_DESCRIPTION}');
            START_DATE         : Date                                       @(title: '{i18n>START_DATE}');
            END_DATE           : Date                                       @(title: '{i18n>END_DATE}');
            COMPLETION_PERCENT : cmn.Percent default 0                      @(title: '{i18n>COMPLETION_PERCENT}');
            STATUS             : cmn.MilestoneStatus default 'Not Started'  @(title: '{i18n>STATUS}');   // set by the roll-up
            PROJECT            : Association to Projects                    @(title: '{i18n>PROJECT}');
            TASKS              : Composition of many Tasks
                                     on TASKS.MILESTONE = $self;
    }

    entity Tasks : managed {
        key NODE_KEY        : cmn.Guid                              @(title: '{i18n>NODE_KEY}');
            TASK_NAME       : cmn.String255                         @(title: '{i18n>TASK_NAME}');
            DESCRIPTION     : String(500)                           @(title: '{i18n>DESCRIPTION}');
            START_DATE      : Date                                  @(title: '{i18n>START_DATE}');
            END_DATE        : Date                                  @(title: '{i18n>END_DATE}');
            PRIORITY        : cmn.Priority default 'Medium'         @(title: '{i18n>PRIORITY}');
            STATUS          : cmn.TaskStatus default 'To Do'        @(title: '{i18n>STATUS}');
            ESTIMATED_HOURS : cmn.Hours                             @(title: '{i18n>ESTIMATED_HOURS}');
            ACTUAL_HOURS    : cmn.Hours default 0                   @(title: '{i18n>ACTUAL_HOURS}');
            BURN_PERCENT    : cmn.Percent default 0                 @(title: '{i18n>BURN_PERCENT}');
            MILESTONE       : Association to Milestones             @(title: '{i18n>MILESTONE_NAME}');
            ASSIGNEE        : Association to master.Employees       @(title: '{i18n>ASSIGNEE}');
    }

    // Header: one employee, one week
    entity Timesheets : managed {
        key NODE_KEY         : cmn.Guid                                 @(title: '{i18n>NODE_KEY}');
            WEEK_START       : Date                                     @(title: '{i18n>WEEK_START}');
            WEEK_END         : Date                                     @(title: '{i18n>WEEK_END}');
            TOTAL_HOURS      : cmn.Hours default 0                      @(title: '{i18n>TOTAL_HOURS}');
            BILLABLE_HOURS   : cmn.Hours default 0                      @(title: '{i18n>BILLABLE_HOURS}');
            STATUS           : cmn.TimesheetStatus default 'Draft'      @(title: '{i18n>STATUS}');
            SUBMITTED_DATE   : Date                                     @(title: '{i18n>SUBMITTED_DATE}');
            APPROVED_DATE    : Date                                     @(title: '{i18n>APPROVED_DATE}');
            REJECTION_REASON : cmn.String255                            @(title: '{i18n>REJECTION_REASON}');
            EMPLOYEE         : Association to master.Employees          @(title: '{i18n>EMPLOYEE}');
            APPROVED_BY      : Association to master.Employees          @(title: '{i18n>APPROVED_BY}');
            Entries          : Composition of many TimesheetEntries
                                   on Entries.PARENT = $self;
    }

    // Item: one day, one task
    entity TimesheetEntries : managed {
        key NODE_KEY    : cmn.Guid                      @(title: '{i18n>NODE_KEY}');
            WORK_DATE   : Date                          @(title: '{i18n>WORK_DATE}');
            HOURS       : Decimal(4, 2)                 @(title: '{i18n>HOURS}');
            IS_BILLABLE : Boolean default true          @(title: '{i18n>IS_BILLABLE}');
            NOTES       : cmn.String255                 @(title: '{i18n>NOTES}');
            PARENT      : Association to Timesheets     @(title: '{i18n>PARENT_KEY}');
            TASK        : Association to Tasks          @(title: '{i18n>TASK_NAME}');
            INVOICE     : Association to Invoices       @(title: '{i18n>INVOICE_NO}');
    }

    entity Invoices : cmn.Amount, managed {
        key NODE_KEY       : cmn.Guid                               @(title: '{i18n>NODE_KEY}');
            INVOICE_NO     : cmn.String32                           @(title: '{i18n>INVOICE_NO}');
            PERIOD_FROM    : Date                                   @(title: '{i18n>PERIOD_FROM}');
            PERIOD_TO      : Date                                   @(title: '{i18n>PERIOD_TO}');
            INVOICE_DATE   : Date                                   @(title: '{i18n>INVOICE_DATE}');
            DUE_DATE       : Date                                   @(title: '{i18n>DUE_DATE}');
            PAYMENT_DATE   : Date                                   @(title: '{i18n>PAYMENT_DATE}');
            BILLABLE_HOURS : cmn.Hours                              @(title: '{i18n>BILLABLE_HOURS}');
            STATUS         : cmn.InvoiceStatus default 'Draft'      @(title: '{i18n>STATUS}');
            PROJECT        : Association to Projects                @(title: '{i18n>PROJECT}');
            Entries        : Association to many TimesheetEntries
                                 on Entries.INVOICE = $self;
    }

    // Audit trail: every write and every status change (who, when, what)
    entity AuditLog {
        key NODE_KEY   : cmn.Guid        @(title: '{i18n>NODE_KEY}');
            TIMESTAMP  : Timestamp       @(title: '{i18n>TIMESTAMP}');
            USER_ID    : cmn.String255   @(title: '{i18n>USER_ID}');
            ACTION     : cmn.String64    @(title: '{i18n>ACTION}');       // CREATE, UPDATE, DELETE, submitTimesheet, ...
            ENTITY     : cmn.String64    @(title: '{i18n>ENTITY}');
            ENTITY_KEY : cmn.String64    @(title: '{i18n>ENTITY_KEY}');
            DETAILS    : String(1000)    @(title: '{i18n>DETAILS}');      // changed values / message
    }

    // Scope-creep alert, raised once per threshold (75 / 90 / 100 %)
    entity Alerts : managed {
        key NODE_KEY         : cmn.Guid                  @(title: '{i18n>NODE_KEY}');
            THRESHOLD        : Integer                   @(title: '{i18n>THRESHOLD}');
            CONSUMED_PERCENT : cmn.Percent               @(title: '{i18n>REACHED_PERCENT}');
            MESSAGE          : cmn.String255             @(title: '{i18n>MESSAGE}');
            PROJECT          : Association to Projects   @(title: '{i18n>PROJECT}');
            TASK             : Association to Tasks      @(title: '{i18n>TASK_NAME}');
    }
}
