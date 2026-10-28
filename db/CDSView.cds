using { psa.db.transaction } from './schema';

// Read-only views on top of the tables (HANA: SQL views, no own data)
context CDSViews {

    // Hours booked on a project: entry + task + timesheet + invoice in one row
    // (Timesheets facet of the project page)
    define view ![ProjectTimeEntries] as select from transaction.TimesheetEntries {
        key NODE_KEY,
            WORK_DATE,
            HOURS,
            IS_BILLABLE,
            NOTES,
            TASK.TASK_NAME             as ![TASK_NAME],
            @title: '{i18n>TIMESHEET_STATUS}'
            PARENT.STATUS              as ![TIMESHEET_STATUS],
            @title: '{i18n>EMPLOYEE}'
            PARENT.EMPLOYEE.nameFirst || ' ' || PARENT.EMPLOYEE.nameLast as ![EMPLOYEE_NAME] : String(130),
            @title: '{i18n>INVOICE}'
            INVOICE.INVOICE_NO         as ![INVOICE_NO],
            TASK.MILESTONE.PROJECT     as ![PROJECT]
    };
}
