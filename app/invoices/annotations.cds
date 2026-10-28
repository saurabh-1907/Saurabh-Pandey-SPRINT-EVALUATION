using PSAService as service from '../../srv/service';

// Billing Workbench app (Admin): generate, issue, mark paid, cancel invoices

// ==================================================
// VALUE HELPS (drop-downs)
// ==================================================

annotate service.InvoiceSrv with {
    PROJECT @Common.Text: PROJECT.PROJECT_NAME @Common.TextArrangement: #TextOnly;
};

annotate service.generateInvoice with (
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

// ==================================================
// FIELDS
// ==================================================

annotate service.InvoiceSrv with {
    NODE_KEY           @UI.Hidden;
    STATUS_CRITICALITY @UI.Hidden;
    PAYMENT_STATUS     @title: 'Status';
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.InvoiceSrv with @(
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
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.cancelInvoice',   Label: 'Cancel' },
        { Value: INVOICE_NO,       ![@UI.Importance]: #High },
        { Value: PROJECT_NODE_KEY, ![@UI.Importance]: #High },
        { Value: PAYMENT_STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon, ![@UI.Importance]: #High },
        { Value: GROSS_AMOUNT,     ![@UI.Importance]: #High },
        { Value: DUE_DATE },
        { Value: PERIOD_FROM },
        { Value: PERIOD_TO },
        { Value: BILLABLE_HOURS }
    ],
    UI.DataPoint #Total:  { Value: GROSS_AMOUNT, Title: 'Total Amount' },
    UI.DataPoint #Status: { Value: PAYMENT_STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.DataPoint #Due:    { Value: DUE_DATE, Title: 'Due Date' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Total' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Due' }
    ],
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.issueInvoice',    Label: 'Issue' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.markInvoicePaid', Label: 'Mark as Paid' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.cancelInvoice',   Label: 'Cancel' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: INVOICE_NO },
        { Value: PROJECT_NODE_KEY },
        { Value: PERIOD_FROM },
        { Value: PERIOD_TO },
        { Value: INVOICE_DATE },
        { Value: DUE_DATE },
        { Value: PAYMENT_DATE },
        { Value: PAYMENT_STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon }
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
// ACTIONS: only enabled when they make sense, refresh the page afterwards
// ==================================================

annotate service.InvoiceSrv actions {
    issueInvoice @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Draft' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
    markInvoicePaid @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Issued' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
    markInvoicePaid(paymentDate @title: 'Payment Date (empty = today)');
    cancelInvoice @(
        Core.OperationAvailable: { $edmJson: { $Or: [
            { $Eq: [ { $Path: 'in/STATUS' }, 'Draft' ] },
            { $Eq: [ { $Path: 'in/STATUS' }, 'Issued' ] }
        ] } },
        Common.SideEffects: { TargetEntities: ['in', 'in/Entries'] }
    );
};

// ==================================================
// KPI cards - FRD 9: Unbilled Hours, Draft Invoices, Overdue Amount
// ==================================================

annotate service.EntryAnalytics with @(
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

annotate service.EntryAnalytics with {
    PROJECT_NAME   @title: 'Project';
    WORK_DATE      @title: 'Date';
    UNBILLED_HOURS @title: 'Unbilled Hours'  @Aggregation.default: #SUM  @Measures.Unit: 'h';
};

annotate service.InvoiceAnalytics with @(
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

annotate service.InvoiceAnalytics with {
    INVOICE_NO     @title: 'Invoice No';
    PROJECT_NAME   @title: 'Project';
    STATUS         @title: 'Status';
    CURRENCY_CODE  @title: 'Currency'        @Aggregation.default: #MAX;
    DRAFT_COUNT    @title: 'Draft Invoices'  @Aggregation.default: #SUM;
    OVERDUE_AMOUNT @title: 'Overdue Amount'  @Aggregation.default: #SUM  @Measures.ISOCurrency: CURRENCY_CODE;
};
