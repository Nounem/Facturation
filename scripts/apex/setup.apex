// À adapter avant l'exécution dans une organisation de production.
List<BillingEntity__c> entities = [
    SELECT Id FROM BillingEntity__c WHERE IsDefault__c = true LIMIT 1
];
BillingEntity__c entity;
if (entities.isEmpty()) {
    entity = new BillingEntity__c(
        Name = 'Ma société',
        RegistrationNumber__c = 'À CONFIGURER',
        Address__c = 'Adresse à configurer',
        IsDefault__c = true,
        DefaultPaymentTermsDays__c = 30
    );
    insert entity;
} else {
    entity = entities[0];
}

if ([SELECT COUNT() FROM TaxRate__c WHERE IsDefault__c = true] == 0) {
    insert new TaxRate__c(Name = 'TVA 20 %', Rate__c = 20, IsActive__c = true, IsDefault__c = true);
}

Integer currentYear = Date.today().year();
if ([
    SELECT COUNT() FROM NumberingSequence__c
    WHERE BillingEntity__c = :entity.Id AND DocumentType__c = 'Invoice' AND Year__c = :currentYear
] == 0) {
    insert new NumberingSequence__c(
        Name = 'Factures ' + currentYear,
        BillingEntity__c = entity.Id,
        DocumentType__c = 'Invoice',
        Year__c = currentYear,
        Prefix__c = 'FAC',
        NextNumber__c = 1,
        Padding__c = 5
    );
}

if ([
    SELECT COUNT() FROM NumberingSequence__c
    WHERE BillingEntity__c = :entity.Id AND DocumentType__c = 'CreditNote' AND Year__c = :currentYear
] == 0) {
    insert new NumberingSequence__c(
        Name = 'Avoirs ' + currentYear,
        BillingEntity__c = entity.Id,
        DocumentType__c = 'CreditNote',
        Year__c = currentYear,
        Prefix__c = 'AV',
        NextNumber__c = 1,
        Padding__c = 5
    );
}
