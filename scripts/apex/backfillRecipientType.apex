List<Account> accountsToUpdate = [
    SELECT Id, BillingRecipientType__c
    FROM Account
    WHERE BillingRecipientType__c = null
];
for (Account account : accountsToUpdate) {
    account.BillingRecipientType__c = 'PrivateBusiness';
}
if (!accountsToUpdate.isEmpty()) {
    update accountsToUpdate;
}
System.debug('Comptes mis à jour : ' + accountsToUpdate.size());
