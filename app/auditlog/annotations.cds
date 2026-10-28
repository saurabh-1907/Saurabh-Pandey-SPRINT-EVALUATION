using PSAService as service from '../../srv/service';

// Audit Log app (Admin, read-only) - FR-012

annotate service.AuditLogSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Audit Entry',
        TypeNamePlural : 'Audit Log',
        TypeImageUrl   : 'sap-icon://history',
        Title          : { Value: ACTION },
        Description    : { Value: ENTITY }
    },
    UI.SelectionFields: [ USER_ID, ACTION, ENTITY, TIMESTAMP ],
    UI.PresentationVariant: { SortOrder: [{ Property: TIMESTAMP, Descending: true }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: TIMESTAMP, ![@UI.Importance]: #High },
        { Value: USER_ID,   ![@UI.Importance]: #High },
        { Value: ACTION,    ![@UI.Importance]: #High },
        { Value: ENTITY,    ![@UI.Importance]: #High },
        { Value: DETAILS,   ![@UI.Importance]: #High },
        { Value: ENTITY_KEY }
    ],
    UI.FieldGroup #General: { Data: [
        { Value: TIMESTAMP },
        { Value: USER_ID },
        { Value: ACTION },
        { Value: ENTITY },
        { Value: ENTITY_KEY },
        { Value: DETAILS }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Entry', Target: '@UI.FieldGroup#General' }
    ]
) {
    NODE_KEY @UI.Hidden;
};
