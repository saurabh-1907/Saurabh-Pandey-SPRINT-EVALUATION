using PSAService as service from '../../srv/service';

// Projects app (Admin): Project -> Budget + Milestones -> Tasks
// Field labels come from the data model (db/i18n/i18n.properties)

// ==================================================
// VALUE HELPS (drop-downs)
// ==================================================

annotate service.ProjectSrv with {
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

annotate service.TaskSrv with {
    ASSIGNEE @Common.Text: ASSIGNEE.fullName @Common.TextArrangement: #TextOnly
             @Common.ValueList: { CollectionPath: 'EmployeeSrv', Parameters: [
                 { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: ASSIGNEE_ID, ValueListProperty: 'ID' },
                 { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'fullName' }
             ]};
};

// ==================================================
// FIELDS
// ==================================================

annotate service.ProjectSrv with {
    NODE_KEY      @UI.Hidden;
    PROJECT_CODE  @mandatory;
    PROJECT_NAME  @mandatory;
    CLIENT        @mandatory;
    BILLING_TYPE  @Common.QuickInfo: 'Fixed, T&M or Retainer';
    DESCRIPTION   @UI.MultiLineText;
    STATUS        @Common.QuickInfo: 'Draft, Active, On Hold, Completed or Cancelled';
    HOURS_PERCENT @title: 'Hours Used %'  @Measures.Unit: '%';
    BURN_RATE     @title: 'Burn Rate (h / week)';
    PROJECTED_END @title: 'Projected Completion';
};

annotate service.BudgetSrv with {
    NODE_KEY         @UI.Hidden;
    CRITICALITY      @UI.Hidden;
    BUDGET_AMOUNT    @mandatory;
    CONSUMED_PERCENT @Measures.Unit: '%';
};

annotate service.MilestoneSrv with {
    NODE_KEY           @UI.Hidden;
    STATUS_CRITICALITY @UI.Hidden;
    MILESTONE_NAME     @mandatory;
    COMPLETION_PERCENT @Measures.Unit: '%';
    DESCRIPTION        @UI.MultiLineText;
    STATUS             @Common.QuickInfo: 'Set automatically: Not Started, In Progress, Completed or Delayed';
};

annotate service.TaskSrv with {
    NODE_KEY        @UI.Hidden;
    CRITICALITY     @UI.Hidden;
    TASK_NAME       @mandatory;
    ESTIMATED_HOURS @mandatory;
    STATUS          @Common.QuickInfo: 'To Do, In Progress, Done or Blocked';
    DESCRIPTION     @UI.MultiLineText;
    BURN_PERCENT    @Measures.Unit: '%';
    PROJECT_CODE    @title: 'Project';
};

annotate service.AlertSrv with {
    NODE_KEY    @UI.Hidden;
    CRITICALITY @UI.Hidden;
};

// a project code in the URL opens that project directly (drill-down from Manager Home)
annotate service.ProjectSrv with @Common.SemanticKey: [ PROJECT_CODE ];

// ==================================================
// LIST REPORT + OBJECT PAGES
// ==================================================

annotate service.ProjectSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Project',
        TypeNamePlural : 'Projects',
        TypeImageUrl   : 'sap-icon://project-definition-triangle-2',
        Title          : { Value: PROJECT_NAME },
        Description    : { Value: PROJECT_CODE }
    },
    UI.SelectionFields: [ PROJECT_CODE, CLIENT_NODE_KEY, STATUS, BILLING_TYPE, MANAGER_ID, PRIORITY ],
    UI.PresentationVariant: { SortOrder: [{ Property: PROJECT_CODE }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: PROJECT_CODE,    ![@UI.Importance]: #High },
        { Value: PROJECT_NAME,    ![@UI.Importance]: #High },
        { Value: CLIENT_NODE_KEY, ![@UI.Importance]: #High },
        { Value: STATUS,          ![@UI.Importance]: #Medium },
        { Value: PRIORITY,        ![@UI.Importance]: #Low },
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
        { Value: STATUS },
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
        { Value: DESCRIPTION },
        { Value: CLIENT_NODE_KEY },
        { Value: MANAGER_ID },
        { Value: BILLING_TYPE },
        { Value: STATUS },
        { Value: PRIORITY }
    ]},
    UI.FieldGroup #Schedule: { Data: [
        { Value: START_DATE },
        { Value: END_DATE },
        { Value: PLANNED_HOURS },
        { Value: CONSUMED_HOURS },
        { Value: BURN_RATE },
        { Value: PROJECTED_END }
    ]},
    UI.FieldGroup #Admin: { Data: [
        { Value: createdBy },
        { Value: createdAt },
        { Value: modifiedBy },
        { Value: modifiedAt }
    ]},
    UI.Facets: [
        { $Type: 'UI.CollectionFacet', ID: 'Overview', Label: 'Overview', Facets: [
            { $Type: 'UI.ReferenceFacet', Label: 'General',  Target: '@UI.FieldGroup#General' },
            { $Type: 'UI.ReferenceFacet', Label: 'Schedule', Target: '@UI.FieldGroup#Schedule' },
            { $Type: 'UI.ReferenceFacet', Label: 'Budget',   Target: 'BUDGET/@UI.FieldGroup#Budget' }
        ]},
        { $Type: 'UI.ReferenceFacet', Label: 'Milestones & Tasks', Target: 'MILESTONES/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Timesheets',         Target: 'TIME_ENTRIES/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Scope-Creep Alerts', Target: 'ALERTS/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Invoices',           Target: 'INVOICES/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Change Log',         Target: '@UI.FieldGroup#Admin' }
    ]
);

// hours booked on the project (Timesheets facet)
annotate service.ProjectTimeSrv with @(
    UI.PresentationVariant: { SortOrder: [{ Property: WORK_DATE, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: WORK_DATE },
        { Value: EMPLOYEE_NAME },
        { Value: TASK_NAME },
        { Value: HOURS },
        { Value: IS_BILLABLE },
        { Value: TIMESHEET_STATUS },
        { Value: INVOICE_NO },
        { Value: NOTES }
    ]
) {
    NODE_KEY @UI.Hidden;
    PROJECT  @UI.Hidden;
};

annotate service.BudgetSrv with @(
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

annotate service.MilestoneSrv with @(
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
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon },
        { $Type: 'UI.DataFieldForAnnotation', Target: '@UI.DataPoint#Completion', Label: 'Completed' }
    ],
    UI.DataPoint #Completion: {
        Value         : COMPLETION_PERCENT,
        TargetValue   : 100,
        Visualization : #Progress,
        Title         : 'Tasks Done'
    },
    UI.DataPoint #Status: { Value: STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Completion' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: MILESTONE_NAME },
        { Value: DESCRIPTION },
        { Value: START_DATE },
        { Value: END_DATE },
        { Value: COMPLETION_PERCENT },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Milestone', Target: '@UI.FieldGroup#General' },
        { $Type: 'UI.ReferenceFacet', Label: 'Tasks',     Target: 'TASKS/@UI.LineItem' }
    ]
);

annotate service.TaskSrv with @(
    UI.LineItem: [
        { Value: TASK_NAME },
        { Value: ASSIGNEE_ID },
        { Value: STATUS },
        { Value: PRIORITY,   ![@UI.Importance]: #Low },
        { Value: START_DATE, ![@UI.Importance]: #Low },
        { Value: END_DATE,   ![@UI.Importance]: #Low },
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

annotate service.AlertSrv with @(
    UI.PresentationVariant: { SortOrder: [{ Property: THRESHOLD, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: THRESHOLD, Criticality: CRITICALITY, CriticalityRepresentation: #WithIcon },
        { Value: CONSUMED_PERCENT },
        { Value: MESSAGE }
    ]
);

// ==================================================
// ACTIONS: only enabled when they make sense, refresh the page afterwards
// ==================================================

annotate service.ProjectSrv actions {
    recalculateBudget @(
        Core.OperationAvailable: { $edmJson: { $Path: 'in/IsActiveEntity' } },
        Common.SideEffects: { TargetEntities: ['in', 'in/BUDGET', 'in/MILESTONES', 'in/ALERTS'] }
    );
};
