using PSAService as service from '../../srv/service';

// Employees app (Admin): master data, a manager is an employee with "Is Manager"

// ==================================================
// VALUE HELPS (drop-downs)
// ==================================================

annotate service.EmployeeSrv with {
    manager @Common.Text: manager.fullName @Common.TextArrangement: #TextOnly
            @Common.ValueList: { CollectionPath: 'EmployeeSrv', Parameters: [
                { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: manager_ID, ValueListProperty: 'ID' },
                { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'fullName' },
                { $Type: 'Common.ValueListParameterConstant', ValueListProperty: 'isManager', Constant: 'true' }
            ]};
};

// ==================================================
// FIELDS
// ==================================================

annotate service.EmployeeSrv with {
    ID        @UI.Hidden;
    nameFirst @mandatory;
    nameLast  @mandatory;
    fullName  @title: 'Name';
};

// ==================================================
// LIST REPORT + OBJECT PAGE
// ==================================================

annotate service.EmployeeSrv with @(
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
        { Value: joinDate },
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
