using PSAService as service from '../../srv/service';

// Settings app (Admin): thresholds, tax, payment terms (FR-009, FR-010)

annotate service.SettingsSrv with @(
    // one settings row: it can be edited, not created or deleted
    Capabilities.InsertRestrictions.Insertable: false,
    Capabilities.DeleteRestrictions.Deletable : false,
    UI.HeaderInfo: {
        TypeName       : 'Settings',
        TypeNamePlural : 'Settings',
        TypeImageUrl   : 'sap-icon://action-settings',
        Title          : { Value: 'PSA Settings' },
        Description    : { Value: 'Used by alerts, budget status and invoices' }
    },
    UI.LineItem: [
        { Value: ALERT_THRESHOLDS },
        { Value: AT_RISK_PERCENT },
        { Value: TAX_PERCENT },
        { Value: PAYMENT_DAYS },
        { Value: modifiedBy },
        { Value: modifiedAt }
    ],
    UI.FieldGroup #Alerts: { Data: [
        { Value: ALERT_THRESHOLDS },
        { Value: AT_RISK_PERCENT }
    ]},
    UI.FieldGroup #Billing: { Data: [
        { Value: TAX_PERCENT },
        { Value: PAYMENT_DAYS }
    ]},
    UI.Facets: [
        { $Type: 'UI.ReferenceFacet', Label: 'Scope-Creep Alerts', Target: '@UI.FieldGroup#Alerts' },
        { $Type: 'UI.ReferenceFacet', Label: 'Invoicing',          Target: '@UI.FieldGroup#Billing' }
    ]
) {
    ID               @UI.Hidden;
    ALERT_THRESHOLDS @Common.QuickInfo: 'Comma separated, e.g. 75,90,100';
};
