using PSAService as service from '../../srv/service';

// Clients app (Admin): master data

// ==================================================
// FIELDS
// ==================================================

annotate service.ClientSrv with {
    NODE_KEY    @UI.Hidden;
    CLIENT_NAME @mandatory;
    STATUS      @Common.QuickInfo: 'Active, Inactive or Prospect';
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.ClientSrv with @(
    UI.HeaderInfo: {
        TypeName       : 'Client',
        TypeNamePlural : 'Clients',
        TypeImageUrl   : 'sap-icon://customer',
        Title          : { Value: CLIENT_NAME },
        Description    : { Value: CITY }
    },
    UI.SelectionFields: [ CLIENT_NAME, INDUSTRY, STATUS, COUNTRY ],
    UI.PresentationVariant: { SortOrder: [{ Property: CLIENT_NAME }], Visualizations: ['@UI.LineItem'] },
    UI.LineItem: [
        { Value: CLIENT_NAME },
        { Value: INDUSTRY },
        { Value: STATUS },
        { Value: CONTACT_PERSON },
        { Value: EMAIL },
        { Value: PHONE },
        { Value: CITY },
        { Value: COUNTRY }
    ],
    UI.FieldGroup #Contact: { Data: [
        { Value: CLIENT_NAME },
        { Value: INDUSTRY },
        { Value: STATUS },
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
