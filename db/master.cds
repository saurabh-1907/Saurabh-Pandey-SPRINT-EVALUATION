namespace psa.db;

using { cuid } from '@sap/cds/common';
using { psa.common as common } from './common';

// Master data (clients and employees) kept in its own file
context master {

    entity Clients : common.Address {

        key NODE_KEY : common.Guid;

        CLIENT_NAME    : common.String255;
        CONTACT_PERSON : common.String64;
        EMAIL          : common.Email;
        PHONE          : common.PhoneNumber;
    }

    // A manager is an employee with isManager = true
    entity Employees : cuid {

        nameFirst     : common.String64;
        nameLast      : common.String64;

        email         : common.Email;
        phoneNumber   : common.PhoneNumber;
        jobTitle      : common.String64;

        Currency_code : String(3);
        hourlyRate    : common.AmountT;

        isManager     : Boolean default false;
        isActive      : Boolean default true;

        manager       : Association to Employees;
    }
}
