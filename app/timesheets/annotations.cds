using PSAService as service from '../../srv/service';

// My Timesheets app (User + Admin): weekly timesheet with daily rows

// ==================================================
// VALUE HELPS (drop-downs)
// ==================================================

annotate service.TimesheetEntrySrv with {
    TASK @Common.Text: TASK.TASK_NAME @Common.TextArrangement: #TextOnly
         @Common.ValueList: { CollectionPath: 'TaskSrv', Parameters: [
             { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: TASK_NODE_KEY, ValueListProperty: 'NODE_KEY' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'TASK_NAME' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'PROJECT_CODE' },
             { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'STATUS' }
         ]};
};

annotate service.TimesheetSrv with {
    EMPLOYEE    @Common.Text: EMPLOYEE.fullName    @Common.TextArrangement: #TextOnly;
    APPROVED_BY @Common.Text: APPROVED_BY.fullName @Common.TextArrangement: #TextOnly;
};

// ==================================================
// FIELDS
// ==================================================

annotate service.TimesheetSrv with {
    NODE_KEY           @UI.Hidden;
    STATUS_CRITICALITY @UI.Hidden;
    IS_LOCKED          @UI.Hidden;
    WEEK_START         @mandatory;
};

annotate service.TimesheetEntrySrv with {
    NODE_KEY  @UI.Hidden;
    WORK_DATE @mandatory;
    TASK      @mandatory;
    HOURS     @mandatory;
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.TimesheetSrv with @(
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
        { Value: BILLABLE_HOURS },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon },
        { Value: SUBMITTED_DATE },
        { Value: REJECTION_REASON },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.submitTimesheet', Label: 'Submit for Approval' }
    ],
    UI.DataPoint #Hours:    { Value: TOTAL_HOURS,    Title: 'Total Hours' },
    UI.DataPoint #Billable: { Value: BILLABLE_HOURS, Title: 'Billable Hours' },
    UI.DataPoint #Status:   { Value: STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Hours' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Billable' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' }
    ],
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.importHours',     Label: 'Import Hours' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.submitTimesheet', Label: 'Submit for Approval' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: EMPLOYEE_ID },
        { Value: SUBMITTED_DATE },
        { Value: APPROVED_BY_ID },
        { Value: APPROVED_DATE },
        { Value: REJECTION_REASON }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Hours', Target: 'Entries/@UI.LineItem' },
        { $Type: 'UI.ReferenceFacet', Label: 'Week',  Target: '@UI.FieldGroup#General' }
    ]
);

annotate service.TimesheetEntrySrv with @(
    UI.PresentationVariant: { SortOrder: [{ Property: WORK_DATE }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: WORK_DATE },
        { Value: TASK_NODE_KEY },
        { Value: HOURS },
        { Value: IS_BILLABLE },
        { Value: NOTES },
        // task burn so far (approved hours / estimate) - FRD 9 "task burn"
        { Value: TASK.BURN_PERCENT, Label: 'Task Burn %', Criticality: TASK.CRITICALITY, CriticalityRepresentation: #WithIcon }
    ]
);

// ==================================================
// ACTIONS: only enabled when they make sense, refresh the page afterwards
// ==================================================

annotate service.TimesheetSrv actions {
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
    importHours @(
        Core.OperationAvailable: { $edmJson: { $And: [
            { $Path: 'in/IsActiveEntity' },
            { $Or: [
                { $Eq: [ { $Path: 'in/STATUS' }, 'Draft' ] },
                { $Eq: [ { $Path: 'in/STATUS' }, 'Rejected' ] }
            ] }
        ] } },
        Common.SideEffects: { TargetEntities: ['in', 'in/Entries'] }
    );
    importHours(rows @title: 'Rows from your time tracker: date;task;hours;billable;notes (one per line)');
};
