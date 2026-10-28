namespace psa.common;

using { Currency } from '@sap/cds/common';

// Reusable types
type Guid        : UUID;
type PhoneNumber : String(32);
type Email       : String(255);
type String32    : String(32);
type String64    : String(64);
type String255   : String(255);

type AmountT : Decimal(15,2);
type Hours   : Decimal(10,2);
type Percent : Decimal(7,2);

// Enumerators (value lists)
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

// Reusable aspects - a group of fields added to an entity (entity X : Amount { ... })
aspect Amount {
    GROSS_AMOUNT : AmountT  @(title: '{i18n>GROSS_AMOUNT}');
    NET_AMOUNT   : AmountT  @(title: '{i18n>NET_AMOUNT}');
    TAX_AMOUNT   : AmountT  @(title: '{i18n>TAX_AMOUNT}');
    CURRENCY     : Currency @(title: '{i18n>CURRENCY_CODE}');
}

aspect Address {
    STREET      : String255  @(title: '{i18n>STREET}');
    POSTAL_CODE : String(12) @(title: '{i18n>POSTAL_CODE}');
    CITY        : String255  @(title: '{i18n>CITY}');
    COUNTRY     : String255  @(title: '{i18n>COUNTRY}');
    BUILDING    : String255  @(title: '{i18n>BUILDING}');
}
