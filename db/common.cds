namespace psa.common;

using { Currency } from '@sap/cds/common';

type Guid        : UUID;
type PhoneNumber : String(32);
type Email       : String(255);
type String32    : String(32);
type String64    : String(64);
type String255   : String(255);

type AmountT : Decimal(15,2);
type Hours   : Decimal(10,2);
type Percent : Decimal(7,2);

type BillingType : String(10) enum {
    fixed    = 'Fixed';
    tm       = 'T&M';
    retainer = 'Retainer';
};

type ProjectStatus : String(15) enum {
    draft     = 'Draft';
    active    = 'Active';
    onHold    = 'On Hold';
    completed = 'Completed';
    cancelled = 'Cancelled';
};

type Priority : String(10) enum {
    low      = 'Low';
    medium   = 'Medium';
    high     = 'High';
    critical = 'Critical';
};

type MilestoneStatus : String(15) enum {
    notStarted = 'Not Started';
    inProgress = 'In Progress';
    completed  = 'Completed';
    delayed    = 'Delayed';
};

type ClientStatus : String(10) enum {
    active   = 'Active';
    inactive = 'Inactive';
    prospect = 'Prospect';
};

type BudgetStatus : String(15) enum {
    within   = 'Within Budget';
    atRisk   = 'At Risk';
    breached = 'Breached';
};

type TaskStatus : String(15) enum {
    toDo       = 'To Do';
    inProgress = 'In Progress';
    done       = 'Done';
    blocked    = 'Blocked';
};

type TimesheetStatus : String(10) enum {
    draft     = 'Draft';
    submitted = 'Submitted';
    approved  = 'Approved';
    rejected  = 'Rejected';
    invoiced  = 'Invoiced';
};

type InvoiceStatus : String(10) enum {
    draft  = 'Draft';
    issued = 'Issued';
    paid      = 'Paid';
    cancelled = 'Cancelled';      // "Overdue" = Issued and past the due date (calculated)
};

aspect Amount {
    GROSS_AMOUNT : AmountT;
    NET_AMOUNT   : AmountT;
    TAX_AMOUNT   : AmountT;
    CURRENCY     : Currency;
}

aspect Address {
    STREET      : String255;
    POSTAL_CODE : String(12);
    CITY        : String255;
    COUNTRY     : String255;
    BUILDING    : String255;
}
