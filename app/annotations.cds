using PSAService from '../srv/psa-service';

// ==================================================
// VALUE HELPS (drop-downs)
// ==================================================

annotate PSAService.ProjectSrv with {
    CLIENT  @Common.Text: CLIENT.CLIENT_NAME  @Common.TextArrangement: #TextOnly
            @Common.ValueList: { CollectionPath: 'ClientSrv', Parameters: [
                { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: CLIENT_NODE_KEY, ValueListProperty: 'NODE_KEY' },
                { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'CLIENT_NAME' }
            ]};
    MANAGER @Common.Text: MANAGER.fullName @Common.TextArrangement: #TextOnly
            @Common.ValueList: { CollectionPath: 'EmployeeSrv', Parameters: [
                { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: MANAGER_ID, ValueListProperty: 'ID' },
                { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'fullName' },
                { $Type: 'Common.ValueListParameterConstant', ValueListProperty: 'isManager', Constant: 'true' }
            ]};
};

annotate PSAService.TaskSrv with {
    ASSIGNEE @Common.Text: ASSIGNEE.fullName @Common.TextArrangement: #TextOnly
             @Common.ValueList: { CollectionPath: 'EmployeeSrv', Parameters: [
                 { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: ASSIGNEE_ID, ValueListProperty: 'ID' },
                 { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'fullName' }
             ]};
};

annotate PSAService.EmployeeSrv with {
    manager @Common.Text: manager.fullName @Common.TextArrangement: #TextOnly
            @Common.ValueList: { CollectionPath: 'EmployeeSrv', Parameters: [
                { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: manager_ID, ValueListProperty: 'ID' },
                { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'fullName' },
                { $Type: 'Common.ValueListParameterConstant', ValueListProperty: 'isManager', Constant: 'true' }
            ]};
};

annotate PSAService.TimesheetEntrySrv with {
    TASK @Common.Text: TASK.TASK_NAME @Common.TextArrangement: #TextOnly
         @Common.ValueList: { CollectionPath: 'TaskSrv', Parameters: [
             { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: TASK_NODE_KEY, ValueListProperty: 'NODE_KEY' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'TASK_NAME' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'PROJECT_CODE' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'STATUS' }
         ]};
};

annotate PSAService.TimesheetSrv with {
    EMPLOYEE    @Common.Text: EMPLOYEE.fullName    @Common.TextArrangement: #TextOnly;
    APPROVED_BY @Common.Text: APPROVED_BY.fullName @Common.TextArrangement: #TextOnly;
};

annotate PSAService.ApprovalSrv with {
    EMPLOYEE @Common.Text: EMPLOYEE.fullName @Common.TextArrangement: #TextOnly;
};

annotate PSAService.InvoiceSrv with {
    PROJECT @Common.Text: PROJECT.PROJECT_NAME @Common.TextArrangement: #TextOnly;
};

annotate PSAService.generateInvoice with (
    projectID  @title: 'Project'
               @Common.ValueList: { CollectionPath: 'ProjectSrv', Parameters: [
                   { $Type: 'Common.ValueListParameterOut', LocalDataProperty: projectID, ValueListProperty: 'NODE_KEY' },
                   { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'PROJECT_CODE' },
                   { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'PROJECT_NAME' },
                   { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'BILLING_TYPE' }
               ]},
    periodFrom @title: 'Period From',
    periodTo   @title: 'Period To'
);

annotate PSAService.ApprovalSrv actions {
    rejectTimesheet(reason @title: 'Reason' @UI.MultiLineText);
};

// ==================================================
// FIELD LABELS
// ==================================================

annotate PSAService.ProjectSrv with {
    NODE_KEY       @UI.Hidden;
    PROJECT_CODE   @title: 'Project Code'   @mandatory;
    PROJECT_NAME   @title: 'Project Name'   @mandatory;
    CLIENT         @title: 'Client'         @mandatory;
    MANAGER        @title: 'Project Manager';
    BILLING_TYPE   @title: 'Billing Type'   @Common.QuickInfo: 'Fixed, T&M or Retainer';
    START_DATE     @title: 'Start Date';
    END_DATE       @title: 'End Date';
    PLANNED_HOURS  @title: 'Planned Hours';
    CONSUMED_HOURS @title: 'Approved Hours';
};

annotate PSAService.BudgetSrv with {
    NODE_KEY         @UI.Hidden;
    BUDGET_AMOUNT    @title: 'Budget Amount' @mandatory;
    BILLING_RATE     @title: 'Billing Rate / Hour';
    RETAINER_FEE     @title: 'Retainer Fee (per period)';
    CURRENCY_CODE    @title: 'Currency';
    CONSUMED_AMOUNT  @title: 'Consumed';
    REMAINING_AMOUNT @title: 'Remaining';
    CONSUMED_PERCENT @title: 'Consumed %'  @Measures.Unit: '%';
    BUDGET_STATUS    @title: 'Budget Status';
};

annotate PSAService.MilestoneSrv with {
    NODE_KEY           @UI.Hidden;
    MILESTONE_NAME     @title: 'Milestone' @mandatory;
    START_DATE         @title: 'Start Date';
    END_DATE           @title: 'End Date';
    COMPLETION_PERCENT @title: 'Complete %'  @Measures.Unit: '%';
};

annotate PSAService.TaskSrv with {
    NODE_KEY        @UI.Hidden;
    TASK_NAME       @title: 'Task' @mandatory;
    ASSIGNEE        @title: 'Assigned To';
    STATUS          @title: 'Status'        @Common.QuickInfo: 'To Do, In Progress or Done';
    ESTIMATED_HOURS @title: 'Estimated Hours' @mandatory;
    ACTUAL_HOURS    @title: 'Actual Hours';
    BURN_PERCENT    @title: 'Burn %'  @Measures.Unit: '%';
    PROJECT_CODE    @title: 'Project';
};

annotate PSAService.TimesheetSrv with {
    NODE_KEY         @UI.Hidden;
    EMPLOYEE         @title: 'Employee';
    WEEK_START       @title: 'Week Start (Monday)' @mandatory;
    WEEK_END         @title: 'Week End';
    TOTAL_HOURS      @title: 'Total Hours';
    STATUS           @title: 'Status';
    APPROVED_BY      @title: 'Approved By';
    REJECTION_REASON @title: 'Rejection Reason';
};

annotate PSAService.ApprovalSrv with {
    NODE_KEY         @UI.Hidden;
    EMPLOYEE         @title: 'Employee';
    WEEK_START       @title: 'Week Start';
    WEEK_END         @title: 'Week End';
    TOTAL_HOURS      @title: 'Total Hours';
    STATUS           @title: 'Status';
};

annotate PSAService.TimesheetEntrySrv with {
    NODE_KEY    @UI.Hidden;
    WORK_DATE   @title: 'Date'  @mandatory;
    TASK        @title: 'Task'  @mandatory;
    HOURS       @title: 'Hours' @mandatory;
    IS_BILLABLE @title: 'Billable';
    NOTES       @title: 'Notes';
};

annotate PSAService.InvoiceSrv with {
    NODE_KEY       @UI.Hidden;
    INVOICE_NO     @title: 'Invoice No';
    PROJECT        @title: 'Project';
    PERIOD_FROM    @title: 'Period From';
    PERIOD_TO      @title: 'Period To';
    INVOICE_DATE   @title: 'Invoice Date';
    DUE_DATE       @title: 'Due Date';
    BILLABLE_HOURS @title: 'Billable Hours';
    NET_AMOUNT     @title: 'Net Amount';
    TAX_AMOUNT     @title: 'Tax (18%)';
    GROSS_AMOUNT   @title: 'Total Amount';
    STATUS         @title: 'Status';
};

annotate PSAService.ClientSrv with {
    NODE_KEY       @UI.Hidden;
    CLIENT_NAME    @title: 'Client Name' @mandatory;
    CONTACT_PERSON @title: 'Contact Person';
    EMAIL          @title: 'Email';
    PHONE          @title: 'Phone';
    STREET         @title: 'Street';
    BUILDING       @title: 'Building';
    CITY           @title: 'City';
    POSTAL_CODE    @title: 'Postal Code';
    COUNTRY        @title: 'Country';
};

annotate PSAService.EmployeeSrv with {
    ID          @UI.Hidden;
    nameFirst   @title: 'First Name' @mandatory;
    nameLast    @title: 'Last Name'  @mandatory;
    fullName    @title: 'Name';
    email       @title: 'Email';
    phoneNumber @title: 'Phone';
    jobTitle    @title: 'Job Title';
    hourlyRate  @title: 'Cost Rate / Hour';
    isManager   @title: 'Is Manager';
    isActive    @title: 'Active';
    manager     @title: 'Line Manager';
};

annotate PSAService.AlertSrv with {
    THRESHOLD        @title: 'Threshold %';
    CONSUMED_PERCENT @title: 'Reached %';
    MESSAGE          @title: 'Message';
};

// ==================================================
// TECHNICAL FIELDS (colours / progress) - not shown as columns
// ==================================================

annotate PSAService.BudgetSrv    with { CRITICALITY        @UI.Hidden; };
annotate PSAService.TaskSrv      with { CRITICALITY        @UI.Hidden; };
annotate PSAService.AlertSrv     with { CRITICALITY        @UI.Hidden; NODE_KEY @UI.Hidden; };
annotate PSAService.TimesheetSrv with { STATUS_CRITICALITY @UI.Hidden; IS_LOCKED @UI.Hidden; };
annotate PSAService.ApprovalSrv  with { STATUS_CRITICALITY @UI.Hidden; };
annotate PSAService.InvoiceSrv   with { STATUS_CRITICALITY @UI.Hidden; };
annotate PSAService.ProjectSrv   with { HOURS_PERCENT      @title: 'Hours Used %'  @Measures.Unit: '%'; };

// ==================================================
// PROJECTS APP (Admin): Project -> Budget + Milestones -> Tasks
// ==================================================

annotate PSAService.ProjectSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Project',
        TypeNamePlural : 'Projects',
        TypeImageUrl   : 'sap-icon://project-definition-triangle-2',
        Title          : { Value: PROJECT_NAME },
        Description    : { Value: PROJECT_CODE }
    },
    UI.SelectionFields: [ PROJECT_CODE, CLIENT_NODE_KEY, BILLING_TYPE, MANAGER_ID ],
    UI.PresentationVariant: { SortOrder: [{ Property: PROJECT_CODE }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: PROJECT_CODE,    ![@UI.Importance]: #High },
        { Value: PROJECT_NAME,    ![@UI.Importance]: #High },
        { Value: CLIENT_NODE_KEY, ![@UI.Importance]: #High },
        { Value: BILLING_TYPE,    ![@UI.Importance]: #Low },
        { $Type: 'UI.DataFieldForAnnotation', Target: 'BUDGET/@UI.DataPoint#Burn', Label: 'Budget Used', ![@UI.Importance]: #High },
        { $Type: 'UI.DataFieldForAnnotation', Target: '@UI.DataPoint#Hours',      Label: 'Hours Used',  ![@UI.Importance]: #High },
        { Value: BUDGET.BUDGET_STATUS, Label: 'Budget Status', Criticality: BUDGET.CRITICALITY, CriticalityRepresentation: #WithIcon, ![@UI.Importance]: #High },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.recalculateBudget', Label: 'Recalculate Budget' }
    ],
    UI.DataPoint #Hours: {
        Value         : HOURS_PERCENT,
        TargetValue   : 100,
        Visualization : #Progress,
        Title         : 'Hours Used'
    },
    UI.FieldGroup #HeaderInfo: { Data: [
        { Value: CLIENT_NODE_KEY },
        { Value: MANAGER_ID },
        { Value: BILLING_TYPE }
    ]},
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.FieldGroup#HeaderInfo', Label: 'Project' },
        { $Type: 'UI.ReferenceFacet', Target: 'BUDGET/@UI.DataPoint#Burn' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Hours' },
        { $Type: 'UI.ReferenceFacet', Target: 'BUDGET/@UI.DataPoint#Status' },
        { $Type: 'UI.ReferenceFacet', Target: 'BUDGET/@UI.DataPoint#Remaining' }
    ],
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.recalculateBudget', Label: 'Recalculate Budget' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: PROJECT_CODE },
        { Value: PROJECT_NAME },
        { Value: CLIENT_NODE_KEY },
        { Value: MANAGER_ID },
        { Value: BILLING_TYPE }
    ]},
    UI.FieldGroup #Schedule: { Data: [
        { Value: START_DATE },
        { Value: END_DATE },
        { Value: PLANNED_HOURS },
        { Value: CONSUMED_HOURS }
    ]},
    UI.Facets: [
        { $Type: 'UI.CollectionFacet', ID: 'Overview', Label: 'Overview', Facets: [
            { $Type: 'UI.ReferenceFacet', Label: 'General',  Target: '@UI.FieldGroup#General' },
            { $Type: 'UI.ReferenceFacet', Label: 'Schedule', Target: '@UI.FieldGroup#Schedule' },
            { $Type: 'UI.ReferenceFacet', Label: 'Budget',   Target: 'BUDGET/@UI.FieldGroup#Budget' }
        ]},
        { $Type: 'UI.ReferenceFacet', Label: 'Milestones & Tasks', Target: 'MILESTONES/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Scope-Creep Alerts', Target: 'ALERTS/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Invoices',           Target: 'INVOICES/@UI.LineItem' }
    ]
);

annotate PSAService.BudgetSrv with @(
    UI.DataPoint #Burn: {
        Value         : CONSUMED_PERCENT,
        TargetValue   : 100,
        Visualization : #Progress,
        Criticality   : CRITICALITY,
        Title         : 'Budget Used'
    },
    UI.DataPoint #Status: {
        Value       : BUDGET_STATUS,
        Criticality : CRITICALITY,
        Title       : 'Budget Status'
    },
    UI.DataPoint #Remaining: {
        Value : REMAINING_AMOUNT,
        Title : 'Remaining Budget'
    },
    UI.FieldGroup #Budget: { Data: [
        { Value: BUDGET_AMOUNT },
        { Value: BILLING_RATE },
        { Value: RETAINER_FEE },
        { Value: CURRENCY_CODE },
        { Value: CONSUMED_AMOUNT },
        { Value: REMAINING_AMOUNT },
        { Value: CONSUMED_PERCENT },
        { Value: BUDGET_STATUS, Criticality: CRITICALITY, CriticalityRepresentation: #WithIcon }
    ]}
) {
    BUDGET_AMOUNT    @Measures.ISOCurrency: CURRENCY_CODE;
    BILLING_RATE     @Measures.ISOCurrency: CURRENCY_CODE;
    RETAINER_FEE     @Measures.ISOCurrency: CURRENCY_CODE;
    CONSUMED_AMOUNT  @Measures.ISOCurrency: CURRENCY_CODE;
    REMAINING_AMOUNT @Measures.ISOCurrency: CURRENCY_CODE;
};

annotate PSAService.MilestoneSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Milestone',
        TypeNamePlural : 'Milestones',
        TypeImageUrl   : 'sap-icon://flag',
        Title          : { Value: MILESTONE_NAME },
        Description    : { Value: 'Milestone' }
    },
    UI.LineItem: [
        { Value: MILESTONE_NAME },
        { Value: START_DATE },
        { Value: END_DATE },
        { $Type: 'UI.DataFieldForAnnotation', Target: '@UI.DataPoint#Completion', Label: 'Completed' }
    ],
    UI.DataPoint #Completion: {
        Value         : COMPLETION_PERCENT,
        TargetValue   : 100,
        Visualization : #Progress,
        Title         : 'Tasks Done'
    },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Completion' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: MILESTONE_NAME },
        { Value: START_DATE },
        { Value: END_DATE },
        { Value: COMPLETION_PERCENT }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Milestone', Target: '@UI.FieldGroup#General' },
        { $Type: 'UI.ReferenceFacet', Label: 'Tasks',     Target: 'TASKS/@UI.LineItem' }
    ]
);

annotate PSAService.TaskSrv with @(
    UI.LineItem: [
        { Value: TASK_NAME },
        { Value: ASSIGNEE_ID },
        { Value: STATUS },
        { Value: ESTIMATED_HOURS },
        { Value: ACTUAL_HOURS },
        { $Type: 'UI.DataFieldForAnnotation', Target: '@UI.DataPoint#Burn', Label: 'Burn (actual / estimate)' }
    ],
    UI.DataPoint #Burn: {
        Value         : BURN_PERCENT,
        TargetValue   : 100,
        Visualization : #Progress,
        Criticality   : CRITICALITY,
        Title         : 'Burn'
    }
);

annotate PSAService.AlertSrv with @(
    UI.PresentationVariant: { SortOrder: [{ Property: THRESHOLD, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: THRESHOLD, Criticality: CRITICALITY, CriticalityRepresentation: #WithIcon },
        { Value: CONSUMED_PERCENT },
        { Value: MESSAGE }
    ]
);

// ==================================================
// MY TIMESHEETS APP (User + Admin)
// ==================================================

annotate PSAService.TimesheetSrv with @(
    // submitted / approved / invoiced timesheets are read-only
    UI.UpdateHidden : IS_LOCKED,
    UI.DeleteHidden : IS_LOCKED,
    UI.HeaderInfo: {
        TypeName       : 'Timesheet',
        TypeNamePlural : 'My Timesheets',
        TypeImageUrl   : 'sap-icon://time-entry-request',
        Title          : { Value: WEEK_START },
        Description    : { Value: EMPLOYEE.fullName }
    },
    UI.SelectionFields: [ STATUS, WEEK_START ],
    UI.PresentationVariant: { SortOrder: [{ Property: WEEK_START, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: EMPLOYEE_ID },
        { Value: TOTAL_HOURS },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon },
        { Value: REJECTION_REASON },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.submitTimesheet', Label: 'Submit for Approval' }
    ],
    UI.DataPoint #Hours:  { Value: TOTAL_HOURS, Title: 'Total Hours' },
    UI.DataPoint #Status: { Value: STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Hours' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' }
    ],
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.submitTimesheet', Label: 'Submit for Approval' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: EMPLOYEE_ID },
        { Value: APPROVED_BY_ID },
        { Value: REJECTION_REASON }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Hours', Target: 'Entries/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Week',  Target: '@UI.FieldGroup#General' }
    ]
);

annotate PSAService.TimesheetEntrySrv with @(
    UI.PresentationVariant: { SortOrder: [{ Property: WORK_DATE }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: WORK_DATE },
        { Value: TASK_NODE_KEY },
        { Value: HOURS },
        { Value: IS_BILLABLE },
        { Value: NOTES }
    ]
);

// ==================================================
// APPROVALS APP (Admin)
// ==================================================

annotate PSAService.ApprovalSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Timesheet',
        TypeNamePlural : 'Timesheets waiting for approval',
        TypeImageUrl   : 'sap-icon://approvals',
        Title          : { Value: EMPLOYEE.fullName },
        Description    : { Value: WEEK_START }
    },
    UI.SelectionFields: [ EMPLOYEE_ID, WEEK_START ],
    UI.PresentationVariant: { SortOrder: [{ Property: WEEK_START }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: EMPLOYEE_ID },
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: TOTAL_HOURS },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.approveTimesheet', Label: 'Approve' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.rejectTimesheet',  Label: 'Reject' }
    ],
    UI.DataPoint #Hours: { Value: TOTAL_HOURS, Title: 'Total Hours' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Hours' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: EMPLOYEE_ID },
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: TOTAL_HOURS },
        { Value: STATUS }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Hours', Target: 'Entries/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Week',  Target: '@UI.FieldGroup#General' }
    ]
);

// ==================================================
// INVOICES APP (Admin) - billing workbench
// ==================================================

annotate PSAService.InvoiceSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Invoice',
        TypeNamePlural : 'Invoices',
        TypeImageUrl   : 'sap-icon://receipt',
        Title          : { Value: INVOICE_NO },
        Description    : { Value: PROJECT.PROJECT_NAME }
    },
    UI.SelectionFields: [ STATUS, PROJECT_NODE_KEY, INVOICE_DATE ],
    UI.PresentationVariant: { SortOrder: [{ Property: INVOICE_NO, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.EntityContainer/generateInvoice', Label: 'Generate Invoice' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.issueInvoice',    Label: 'Issue' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.markInvoicePaid', Label: 'Mark as Paid' },
        { Value: INVOICE_NO,       ![@UI.Importance]: #High },
        { Value: PROJECT_NODE_KEY, ![@UI.Importance]: #High },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon, ![@UI.Importance]: #High },
        { Value: GROSS_AMOUNT,     ![@UI.Importance]: #High },
        { Value: DUE_DATE },
        { Value: PERIOD_FROM },
        { Value: PERIOD_TO },
        { Value: BILLABLE_HOURS }
    ],
    UI.DataPoint #Total:  { Value: GROSS_AMOUNT, Title: 'Total Amount' },
    UI.DataPoint #Status: { Value: STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.DataPoint #Due:    { Value: DUE_DATE, Title: 'Due Date' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Total' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Due' }
    ],
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.issueInvoice',    Label: 'Issue' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.markInvoicePaid', Label: 'Mark as Paid' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: INVOICE_NO },
        { Value: PROJECT_NODE_KEY },
        { Value: PERIOD_FROM },
        { Value: PERIOD_TO },
        { Value: INVOICE_DATE },
        { Value: DUE_DATE },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon }
    ]},
    UI.FieldGroup #Amounts: { Data: [
        { Value: BILLABLE_HOURS },
        { Value: NET_AMOUNT },
        { Value: TAX_AMOUNT },
        { Value: GROSS_AMOUNT }
    ]},
    UI.Facets: [
        { $Type: 'UI.CollectionFacet', ID: 'InvoiceDetails', Label: 'Invoice', Facets: [
            { $Type: 'UI.ReferenceFacet', Label: 'Details', Target: '@UI.FieldGroup#General' },
            { $Type: 'UI.ReferenceFacet', Label: 'Amounts', Target: '@UI.FieldGroup#Amounts' }
        ]},
        { $Type: 'UI.ReferenceFacet', Label: 'Billed Hours', Target: 'Entries/@UI.LineItem' }
    ]
) {
    NET_AMOUNT   @Measures.ISOCurrency: CURRENCY_code;
    TAX_AMOUNT   @Measures.ISOCurrency: CURRENCY_code;
    GROSS_AMOUNT @Measures.ISOCurrency: CURRENCY_code;
};

// ==================================================
// CLIENTS APP (Admin)
// ==================================================

annotate PSAService.ClientSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Client',
        TypeNamePlural : 'Clients',
        TypeImageUrl   : 'sap-icon://customer',
        Title          : { Value: CLIENT_NAME },
        Description    : { Value: CITY }
    },
    UI.SelectionFields: [ CLIENT_NAME, COUNTRY ],
    UI.PresentationVariant: { SortOrder: [{ Property: CLIENT_NAME }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: CLIENT_NAME },
        { Value: CONTACT_PERSON },
        { Value: EMAIL },
        { Value: PHONE },
        { Value: CITY },
        { Value: COUNTRY }
    ],
    UI.FieldGroup #Contact: { Data: [
        { Value: CLIENT_NAME },
        { Value: CONTACT_PERSON },
        { Value: EMAIL },
        { Value: PHONE }
    ]},
    UI.FieldGroup #Address: { Data: [
        { Value: STREET },
        { Value: BUILDING },
        { Value: CITY },
        { Value: POSTAL_CODE },
        { Value: COUNTRY }
    ]},
    UI.Facets: [
        { $Type: 'UI.CollectionFacet', ID: 'ClientDetails', Label: 'Client', Facets: [
            { $Type: 'UI.ReferenceFacet', Label: 'Contact', Target: '@UI.FieldGroup#Contact' },
            { $Type: 'UI.ReferenceFacet', Label: 'Address', Target: '@UI.FieldGroup#Address' }
        ]}
    ]
) {
    EMAIL @Communication.IsEmailAddress;
    PHONE @Communication.IsPhoneNumber;
};

// ==================================================
// EMPLOYEES APP (Admin)
// ==================================================

annotate PSAService.EmployeeSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Employee',
        TypeNamePlural : 'Employees',
        TypeImageUrl   : 'sap-icon://employee',
        Title          : { Value: fullName },
        Description    : { Value: jobTitle }
    },
    UI.SelectionFields: [ nameFirst, nameLast, isManager, isActive ],
    UI.PresentationVariant: { SortOrder: [{ Property: nameFirst }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: fullName },
        { Value: jobTitle },
        { Value: email },
        { Value: manager_ID },
        { Value: isManager },
        { Value: isActive }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: nameFirst },
        { Value: nameLast },
        { Value: jobTitle },
        { Value: manager_ID }
    ]},
    UI.FieldGroup #Contact: { Data: [
        { Value: email },
        { Value: phoneNumber }
    ]},
    UI.FieldGroup #Work: { Data: [
        { Value: hourlyRate },
        { Value: isManager },
        { Value: isActive }
    ]},
    UI.Facets: [
        { $Type: 'UI.CollectionFacet', ID: 'EmployeeDetails', Label: 'Employee', Facets: [
            { $Type: 'UI.ReferenceFacet', Label: 'General',  Target: '@UI.FieldGroup#General' },
            { $Type: 'UI.ReferenceFacet', Label: 'Contact',  Target: '@UI.FieldGroup#Contact' },
            { $Type: 'UI.ReferenceFacet', Label: 'Work',     Target: '@UI.FieldGroup#Work' }
        ]}
    ]
) {
    email       @Communication.IsEmailAddress;
    phoneNumber @Communication.IsPhoneNumber;
    hourlyRate  @Measures.ISOCurrency: Currency_code;
};

// ==================================================
// ACTIONS: only enabled when they make sense, refresh the page afterwards
// ==================================================

annotate PSAService.TimesheetSrv actions {
    submitTimesheet @(
        Core.OperationAvailable: { $edmJson: { $And: [
            { $Path: 'in/IsActiveEntity' },
            { $Or: [
                { $Eq: [ { $Path: 'in/STATUS' }, 'Draft' ] },
                { $Eq: [ { $Path: 'in/STATUS' }, 'Rejected' ] }
            ] }
        ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
};

annotate PSAService.ApprovalSrv actions {
    approveTimesheet @(Common.SideEffects: { TargetEntities: ['in'] });
    rejectTimesheet  @(Common.SideEffects: { TargetEntities: ['in'] });
};

annotate PSAService.InvoiceSrv actions {
    issueInvoice @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Draft' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
    markInvoicePaid @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Issued' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
};

annotate PSAService.ProjectSrv actions {
    recalculateBudget @(
        Core.OperationAvailable: { $edmJson: { $Path: 'in/IsActiveEntity' } },
        Common.SideEffects: { TargetEntities: ['in', 'in/BUDGET', 'in/MILESTONES', 'in/ALERTS'] }
    );
};

// ==================================================
// MANAGER HOME (Analytical List Page, Admin) - FRD 9
// KPI cards: Active Projects, At-Risk Budgets, Pending Approvals
// chart + table: budget burn per project, drill-down to the project
// ==================================================

annotate PSAService.ProjectAnalytics with @(
    // the entity can be grouped and summed ($apply)
    Aggregation.ApplySupported: {
        Transformations       : ['aggregate', 'topcount', 'bottomcount', 'identity', 'concat', 'groupby', 'filter', 'search'],
        GroupableProperties   : [PROJECT_CODE, PROJECT_NAME, CLIENT_NAME, BILLING_TYPE, BUDGET_STATUS, CURRENCY_CODE],
        AggregatableProperties: [
            { Property: BUDGET_AMOUNT },
            { Property: CONSUMED_AMOUNT },
            { Property: REMAINING_AMOUNT },
            { Property: PLANNED_HOURS },
            { Property: CONSUMED_HOURS },
            { Property: ACTIVE_COUNT },
            { Property: AT_RISK_COUNT }
        ]
    },
    // measures (sum)
    Aggregation.CustomAggregate #BUDGET_AMOUNT   : 'Edm.Decimal',
    Aggregation.CustomAggregate #CONSUMED_AMOUNT : 'Edm.Decimal',
    Aggregation.CustomAggregate #REMAINING_AMOUNT: 'Edm.Decimal',
    Aggregation.CustomAggregate #PLANNED_HOURS   : 'Edm.Decimal',
    Aggregation.CustomAggregate #CONSUMED_HOURS  : 'Edm.Decimal',
    Aggregation.CustomAggregate #ACTIVE_COUNT    : 'Edm.Int32',
    Aggregation.CustomAggregate #AT_RISK_COUNT   : 'Edm.Int32',
    Aggregation.CustomAggregate #CURRENCY_CODE   : 'Edm.String',   // unit of the amounts

    UI.HeaderInfo: {
        TypeName       : 'Project',
        TypeNamePlural : 'Budget burn per project',
        TypeImageUrl   : 'sap-icon://business-objects-experience',
        Title          : { Value: PROJECT_NAME },
        Description    : { Value: PROJECT_CODE }
    },
    UI.SelectionFields: [ CLIENT_NAME, BILLING_TYPE, BUDGET_STATUS ],

    // chart: budget vs. consumed per project
    UI.Chart: {
        $Type      : 'UI.ChartDefinitionType',
        Title      : 'Budget burn per project',
        ChartType  : #Bar,
        Dimensions : [ PROJECT_NAME ],
        Measures   : [ BUDGET_AMOUNT, CONSUMED_AMOUNT ],
        DimensionAttributes: [{ Dimension: PROJECT_NAME, Role: #Category }],
        MeasureAttributes  : [
            { Measure: BUDGET_AMOUNT,   Role: #Axis1 },
            { Measure: CONSUMED_AMOUNT, Role: #Axis1 }
        ]
    },
    UI.LineItem: [
        // buttons to the other apps (launchpad navigation)
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Approval',  Action: 'manage',  Label: 'Approvals',         RequiresContext: false },
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Invoice',   Action: 'manage',  Label: 'Billing Workbench', RequiresContext: false },
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Timesheet', Action: 'manage',  Label: 'My Timesheets',     RequiresContext: false },
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Client',    Action: 'manage',  Label: 'Clients',           RequiresContext: false },
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Employee',  Action: 'manage',  Label: 'Employees',         RequiresContext: false },
        { Value: PROJECT_CODE,     ![@HTML5.CssDefaults]: { width: '8.5rem' } },
        { Value: PROJECT_NAME,     ![@HTML5.CssDefaults]: { width: '13rem' } },
        { Value: CLIENT_NAME,      ![@HTML5.CssDefaults]: { width: '10rem' } },
        { Value: BILLING_TYPE,     ![@HTML5.CssDefaults]: { width: '6.5rem' } },
        { Value: BUDGET_AMOUNT,    ![@HTML5.CssDefaults]: { width: '9rem' } },
        { Value: CONSUMED_AMOUNT,  ![@HTML5.CssDefaults]: { width: '9rem' } },
        { Value: REMAINING_AMOUNT, ![@HTML5.CssDefaults]: { width: '9rem' } },
        { Value: CONSUMED_HOURS,   ![@HTML5.CssDefaults]: { width: '7.5rem' } },
        { Value: BUDGET_STATUS, Criticality: CRITICALITY, CriticalityRepresentation: #WithIcon, ![@HTML5.CssDefaults]: { width: '9rem' } }
    ],
    UI.PresentationVariant: {
        Visualizations: [ '@UI.Chart', '@UI.LineItem' ],
        SortOrder     : [{ Property: PROJECT_CODE }]
    },

    // ---- KPI card: Active Projects ----
    UI.Chart #ActiveProjects: {
        ChartType : #Column,
        Dimensions: [ BILLING_TYPE ],
        Measures  : [ ACTIVE_COUNT ],
        DimensionAttributes: [{ Dimension: BILLING_TYPE, Role: #Category }],
        MeasureAttributes  : [{ Measure: ACTIVE_COUNT, Role: #Axis1 }]
    },
    UI.KPI #ActiveProjects: {
        DataPoint       : { Value: ACTIVE_COUNT, Title: 'Active Projects', Criticality: #Neutral },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#ActiveProjects' ] } }
    },

    // ---- KPI card: At-Risk Budgets ----
    UI.Chart #AtRiskBudgets: {
        ChartType : #Column,
        Dimensions: [ BUDGET_STATUS ],
        Measures  : [ AT_RISK_COUNT ],
        DimensionAttributes: [{ Dimension: BUDGET_STATUS, Role: #Category }],
        MeasureAttributes  : [{ Measure: AT_RISK_COUNT, Role: #Axis1 }]
    },
    UI.KPI #AtRiskBudgets: {
        DataPoint       : {
            Value                 : AT_RISK_COUNT,
            Title                 : 'At-Risk Budgets',
            CriticalityCalculation: { ImprovementDirection: #Minimize, ToleranceRangeHighValue: 0, DeviationRangeHighValue: 1 }
        },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#AtRiskBudgets' ] } }
    }
);

annotate PSAService.ProjectAnalytics with {
    NODE_KEY         @UI.Hidden;
    CRITICALITY      @UI.Hidden;
    ACTIVE_COUNT     @title: 'Active Projects'   @Aggregation.default: #SUM;
    AT_RISK_COUNT    @title: 'At-Risk Budgets'   @Aggregation.default: #SUM;
    PROJECT_CODE     @title: 'Project Code';
    PROJECT_NAME     @title: 'Project';
    CLIENT_NAME      @title: 'Client';
    BILLING_TYPE     @title: 'Billing Type';
    BUDGET_STATUS    @title: 'Budget Status';
    CURRENCY_CODE    @title: 'Currency'          @Aggregation.default: #MAX;
    START_DATE       @title: 'Start Date';
    END_DATE         @title: 'End Date';
    BUDGET_AMOUNT    @title: 'Budget'            @Aggregation.default: #SUM  @Measures.ISOCurrency: CURRENCY_CODE;
    CONSUMED_AMOUNT  @title: 'Consumed'          @Aggregation.default: #SUM  @Measures.ISOCurrency: CURRENCY_CODE;
    REMAINING_AMOUNT @title: 'Remaining'         @Aggregation.default: #SUM  @Measures.ISOCurrency: CURRENCY_CODE;
    CONSUMED_PERCENT @title: 'Consumed %'        @Measures.Unit: '%';
    PLANNED_HOURS    @title: 'Planned Hours'     @Aggregation.default: #SUM;
    CONSUMED_HOURS   @title: 'Approved Hours'    @Aggregation.default: #SUM;
};

// ---- KPI card: Pending Approvals (submitted timesheets) ----
annotate PSAService.TimesheetAnalytics with @(
    Aggregation.ApplySupported: {
        Transformations       : ['aggregate', 'groupby', 'filter'],
        GroupableProperties   : [WEEK_START, STATUS],
        AggregatableProperties: [{ Property: PENDING_COUNT }]
    },
    Aggregation.CustomAggregate #PENDING_COUNT: 'Edm.Int32',
    UI.Chart #PendingApprovals: {
        ChartType : #Column,
        Dimensions: [ WEEK_START ],
        Measures  : [ PENDING_COUNT ],
        DimensionAttributes: [{ Dimension: WEEK_START, Role: #Category }],
        MeasureAttributes  : [{ Measure: PENDING_COUNT, Role: #Axis1 }]
    },
    UI.KPI #PendingApprovals: {
        DataPoint       : {
            Value                 : PENDING_COUNT,
            Title                 : 'Pending Approvals',
            CriticalityCalculation: { ImprovementDirection: #Minimize, ToleranceRangeHighValue: 0, DeviationRangeHighValue: 5 }
        },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#PendingApprovals' ] } }
    }
);

annotate PSAService.TimesheetAnalytics with {
    WEEK_START    @title: 'Week Start';
    STATUS        @title: 'Status';
    PENDING_COUNT @title: 'Pending Approvals'  @Aggregation.default: #SUM;
};

// ==================================================
// BILLING WORKBENCH KPI cards - FRD 9
// Unbilled Hours, Draft Invoices, Overdue Amount
// ==================================================

annotate PSAService.EntryAnalytics with @(
    Aggregation.ApplySupported: {
        Transformations       : ['aggregate', 'groupby', 'filter'],
        GroupableProperties   : [PROJECT_NAME, WORK_DATE],
        AggregatableProperties: [{ Property: UNBILLED_HOURS }]
    },
    Aggregation.CustomAggregate #UNBILLED_HOURS: 'Edm.Decimal',
    UI.Chart #UnbilledHours: {
        ChartType : #Bar,
        Dimensions: [ PROJECT_NAME ],
        Measures  : [ UNBILLED_HOURS ],
        DimensionAttributes: [{ Dimension: PROJECT_NAME, Role: #Category }],
        MeasureAttributes  : [{ Measure: UNBILLED_HOURS, Role: #Axis1 }]
    },
    UI.KPI #UnbilledHours: {
        DataPoint       : { Value: UNBILLED_HOURS, Title: 'Unbilled Hours', Criticality: #Neutral },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#UnbilledHours' ] } }
    }
);

annotate PSAService.EntryAnalytics with {
    PROJECT_NAME   @title: 'Project';
    WORK_DATE      @title: 'Date';
    UNBILLED_HOURS @title: 'Unbilled Hours'  @Aggregation.default: #SUM  @Measures.Unit: 'h';
};

annotate PSAService.InvoiceAnalytics with @(
    Aggregation.ApplySupported: {
        Transformations       : ['aggregate', 'groupby', 'filter'],
        GroupableProperties   : [PROJECT_NAME, STATUS, CURRENCY_CODE],
        AggregatableProperties: [{ Property: DRAFT_COUNT }, { Property: OVERDUE_AMOUNT }]
    },
    Aggregation.CustomAggregate #DRAFT_COUNT   : 'Edm.Int32',
    Aggregation.CustomAggregate #CURRENCY_CODE : 'Edm.String',     // unit of the amount KPI
    Aggregation.CustomAggregate #OVERDUE_AMOUNT: 'Edm.Decimal',
    UI.Chart #DraftInvoices: {
        ChartType : #Bar,
        Dimensions: [ PROJECT_NAME ],
        Measures  : [ DRAFT_COUNT ],
        DimensionAttributes: [{ Dimension: PROJECT_NAME, Role: #Category }],
        MeasureAttributes  : [{ Measure: DRAFT_COUNT, Role: #Axis1 }]
    },
    UI.KPI #DraftInvoices: {
        DataPoint       : {
            Value                 : DRAFT_COUNT,
            Title                 : 'Draft Invoices',
            CriticalityCalculation: { ImprovementDirection: #Minimize, ToleranceRangeHighValue: 0, DeviationRangeHighValue: 3 }
        },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#DraftInvoices' ] } }
    },
    UI.Chart #OverdueAmount: {
        ChartType : #Bar,
        Dimensions: [ PROJECT_NAME ],
        Measures  : [ OVERDUE_AMOUNT ],
        DimensionAttributes: [{ Dimension: PROJECT_NAME, Role: #Category }],
        MeasureAttributes  : [{ Measure: OVERDUE_AMOUNT, Role: #Axis1 }]
    },
    UI.KPI #OverdueAmount: {
        DataPoint       : {
            Value                 : OVERDUE_AMOUNT,
            Title                 : 'Overdue Amount',
            CriticalityCalculation: { ImprovementDirection: #Minimize, ToleranceRangeHighValue: 0, DeviationRangeHighValue: 1 }
        },
        SelectionVariant: { SelectOptions: [] },
        Detail          : { DefaultPresentationVariant: { Visualizations: [ '@UI.Chart#OverdueAmount' ] } }
    }
);

annotate PSAService.InvoiceAnalytics with {
    INVOICE_NO     @title: 'Invoice No';
    PROJECT_NAME   @title: 'Project';
    STATUS         @title: 'Status';
    CURRENCY_CODE  @title: 'Currency'        @Aggregation.default: #MAX;
    DRAFT_COUNT    @title: 'Draft Invoices'  @Aggregation.default: #SUM;
    OVERDUE_AMOUNT @title: 'Overdue Amount'  @Aggregation.default: #SUM  @Measures.ISOCurrency: CURRENCY_CODE;
};

// a project code in the URL opens that project directly (drill-down from Manager Home)
annotate PSAService.ProjectSrv with @Common.SemanticKey: [ PROJECT_CODE ];
