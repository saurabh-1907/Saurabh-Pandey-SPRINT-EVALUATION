using PSAService as service from '../../srv/service';

// Approve Timesheets app (Admin): submitted timesheets, approve / reject with reason
// (the hours table uses the TimesheetEntrySrv line item of app/timesheets)

// ==================================================
// VALUE HELPS + FIELDS
// ==================================================

annotate service.ApprovalSrv with {
    EMPLOYEE @Common.Text: EMPLOYEE.fullName @Common.TextArrangement: #TextOnly;
};

annotate service.ApprovalSrv with {
    NODE_KEY           @UI.Hidden;
    STATUS_CRITICALITY @UI.Hidden;
    WEEK_START         @title: 'Week Start';
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.ApprovalSrv with @(
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
        { Value: BILLABLE_HOURS },
        { Value: SUBMITTED_DATE },
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
// ACTIONS
// ==================================================

annotate service.ApprovalSrv actions {
    rejectTimesheet(reason @title: 'Reason' @UI.MultiLineText);
};

annotate service.ApprovalSrv actions {
    approveTimesheet @(Common.SideEffects: { TargetEntities: ['in'] });
    rejectTimesheet  @(Common.SideEffects: { TargetEntities: ['in'] });
};
