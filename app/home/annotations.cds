using PSAService as service from '../../srv/service';

// Manager Home (Analytical List Page, Admin) - FRD 9
// KPI cards: Active Projects, At-Risk Budgets, Pending Approvals
// chart + table: budget burn per project, drill-down to the project

annotate service.ProjectAnalytics with @(
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
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'Settings',  Action: 'manage',  Label: 'Settings',          RequiresContext: false },
        { $Type: 'UI.DataFieldForIntentBasedNavigation', SemanticObject: 'AuditLog',  Action: 'display', Label: 'Audit Log',         RequiresContext: false },
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

annotate service.ProjectAnalytics with {
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
annotate service.TimesheetAnalytics with @(
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

annotate service.TimesheetAnalytics with {
    WEEK_START    @title: 'Week Start';
    STATUS        @title: 'Status';
    PENDING_COUNT @title: 'Pending Approvals'  @Aggregation.default: #SUM;
};
