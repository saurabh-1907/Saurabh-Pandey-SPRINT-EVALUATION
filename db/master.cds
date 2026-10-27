namespace psa.db;

using { cuid, managed } from '@sap/cds/common';
using { psa.common as common } from './common';

// Master data (clients and employees) kept in its own file
context master {

    entity Clients : common.Address, managed {

        key NODE_KEY : common.Guid;

        CLIENT_NAME    : common.String255;
        CONTACT_PERSON : common.String64;
        EMAIL          : common.Email;
        PHONE          : common.PhoneNumber;
        INDUSTRY       : common.String64;
        STATUS         : common.ClientStatus default 'Active';
    }

    // A manager is an employee with isManager = true
    entity Employees : cuid, managed {

        nameFirst     : common.String64;
        nameLast      : common.String64;

        email         : common.Email;
        phoneNumber   : common.PhoneNumber;
        jobTitle      : common.String64;
        joinDate      : Date;

        Currency_code : String(3);
        hourlyRate    : common.AmountT;

        isManager     : Boolean default false;
        isActive      : Boolean default true;

        manager       : Association to Employees;
    }

    // Configuration maintained by the Admin (one row, ID = 1)
    entity Settings : managed {

        key ID : Integer;

        ALERT_THRESHOLDS : String(50) default '75,90,100';   // % of estimate / budget
        AT_RISK_PERCENT  : common.Percent default 80;        // budget status "At Risk" from here
        TAX_PERCENT      : common.Percent default 18;
        PAYMENT_DAYS     : Integer default 30;               // due date = invoice date + days
    }
}
