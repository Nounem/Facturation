@IsTest
private class BillingSecurityTest {
    @IsTest
    static void acceptsAccessibleStandardObjectsAndFields() {
        BillingSecurity.requireRead(Account.SObjectType, 'Compte');
        BillingSecurity.requireCreate(Account.SObjectType, 'Compte');
        BillingSecurity.requireUpdate(Account.SObjectType, 'Compte');
        BillingSecurity.requireReadableFields(
            new List<Schema.SObjectField>{ Account.Name, Account.BillingCity },
            'Compte'
        );
        BillingSecurity.requireCreateableFields(
            new List<Schema.SObjectField>{ Account.Name, Account.BillingCity },
            'Compte'
        );
        BillingSecurity.requireUpdateableFields(
            new List<Schema.SObjectField>{ Account.Name, Account.BillingCity },
            'Compte'
        );
    }
}
