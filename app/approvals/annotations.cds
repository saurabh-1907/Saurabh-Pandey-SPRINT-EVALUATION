using PSAService as service from '../../srv/service';

// Approve Timesheets app (Admin): submitted timesheets, approve / reject with reason
// Approve / Reject: table toolbar (select rows) or the header of the opened timesheet
// (the hours table uses the TimesheetEntrySrv line item of app/timesheets)

// ==================================================
// VALUE HELPS + FIELDS
// ==================================================

annotate service.ApprovalSrv with {
    EMPLOYEE    @Common.Text: EMPLOYEE.fullName    @Common.TextArrangement: #TextOnly;
    APPROVED_BY @Common.Text: APPROVED_BY.fullName @Common.TextArrangement: #TextOnly;
};

annotate service.ApprovalSrv with {
    NODE_KEY           @UI.Hidden;
    STATUS_CRITICALITY @UI.Hidden;
    WEEK_START         @title: 'Week Start';
    STATUS             @Common.FilterDefaultValue: 'Submitted';   // list opens with the timesheets to approve
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.ApprovalSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Timesheet',
        TypeNamePlural : 'Timesheets',
        TypeImageUrl   : 'sap-icon://approvals',
        Title          : { Value: EMPLOYEE.fullName },
        Description    : { Value: WEEK_START }
    },
    UI.SelectionFields: [ STATUS, EMPLOYEE_ID, WEEK_START ],
    UI.PresentationVariant: { SortOrder: [{ Property: WEEK_START }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: EMPLOYEE_ID,    ![@UI.Importance]: #High },
        { Value: WEEK_START,     ![@UI.Importance]: #High },
        { Value: STATUS, Criticality: STATUS_CRITICALITY, CriticalityRepresentation: #WithIcon, ![@UI.Importance]: #High },
        { Value: TOTAL_HOURS,    ![@UI.Importance]: #High },
        { Value: WEEK_END },
        { Value: BILLABLE_HOURS },
        { Value: SUBMITTED_DATE },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.approveTimesheet', Label: 'Approve' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.rejectTimesheet',  Label: 'Reject' }
    ],
    UI.DataPoint #Hours:  { Value: TOTAL_HOURS, Title: 'Total Hours' },
    UI.DataPoint #Status: { Value: STATUS, Criticality: STATUS_CRITICALITY, Title: 'Status' },
    UI.HeaderFacets: [
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Hours' },
        { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Status' }
    ],
    // buttons in the header of the opened timesheet
    UI.Identification: [
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.approveTimesheet', Label: 'Approve' },
        { $Type: 'UI.DataFieldForAction', Action: 'PSAService.rejectTimesheet',  Label: 'Reject' }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: EMPLOYEE_ID },
        { Value: WEEK_START },
        { Value: WEEK_END },
        { Value: TOTAL_HOURS },
        { Value: STATUS },
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

// ==================================================
// ACTIONS
// ==================================================

annotate service.ApprovalSrv actions {
    rejectTimesheet(reason @title: 'Reason' @UI.MultiLineText);
};

// only a Submitted timesheet can be approved or rejected; refresh the row / page afterwards
annotate service.ApprovalSrv actions {
    approveTimesheet @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Submitted' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
    rejectTimesheet @(
        Core.OperationAvailable: { $edmJson: { $Eq: [ { $Path: 'in/STATUS' }, 'Submitted' ] } },
        Common.SideEffects: { TargetEntities: ['in'] }
    );
};
