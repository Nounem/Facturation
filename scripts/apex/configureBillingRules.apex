BillingEntity__c entity = [
    SELECT Id FROM BillingEntity__c WHERE IsDefault__c = true LIMIT 1
];
Set<String> names = new Set<String>{
    'Facturation ponctuelle',
    'Mensuelle à échoir',
    'Mensuelle à terme échu',
    'Trimestrielle à terme échu'
};
Set<String> existingNames = new Set<String>();
for (BillingRule__c existing : [
    SELECT Name FROM BillingRule__c WHERE Name IN :names
]) {
    existingNames.add(existing.Name);
}
List<BillingRule__c> rules = new List<BillingRule__c>();
if (!existingNames.contains('Facturation ponctuelle')) {
    rules.add(new BillingRule__c(
        Name = 'Facturation ponctuelle', Active__c = true,
        BillingFrequency__c = 'OneTime', BillingType__c = 'Advance',
        PeriodBoundary__c = 'Anniversary', BillingDay__c = 1,
        PaymentTermsDays__c = 30, BillingEntity__c = entity.Id,
        Description__c = 'Une facture unique, créée directement ou à la date planifiée.'
    ));
}
if (!existingNames.contains('Mensuelle à échoir')) {
    rules.add(new BillingRule__c(
        Name = 'Mensuelle à échoir', Active__c = true,
        BillingFrequency__c = 'Monthly', BillingType__c = 'Advance',
        PeriodBoundary__c = 'Calendar', BillingDay__c = 1,
        PaymentTermsDays__c = 30, BillingEntity__c = entity.Id,
        Description__c = 'Facture en début de mois pour le mois à venir.'
    ));
}
if (!existingNames.contains('Mensuelle à terme échu')) {
    rules.add(new BillingRule__c(
        Name = 'Mensuelle à terme échu', Active__c = true,
        BillingFrequency__c = 'Monthly', BillingType__c = 'Arrears',
        PeriodBoundary__c = 'Calendar', BillingDay__c = 1,
        PaymentTermsDays__c = 30, BillingEntity__c = entity.Id,
        Description__c = 'Facture le mois écoulé au début du mois suivant.'
    ));
}
if (!existingNames.contains('Trimestrielle à terme échu')) {
    rules.add(new BillingRule__c(
        Name = 'Trimestrielle à terme échu', Active__c = true,
        BillingFrequency__c = 'Quarterly', BillingType__c = 'Arrears',
        PeriodBoundary__c = 'Calendar', BillingDay__c = 1,
        PaymentTermsDays__c = 30, BillingEntity__c = entity.Id,
        Description__c = 'Facture le trimestre civil écoulé.'
    ));
}
if (!rules.isEmpty()) insert rules;

List<CronTrigger> jobs = [
    SELECT Id FROM CronTrigger
    WHERE CronJobDetail.Name = 'Facturation quotidienne'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
    LIMIT 1
];
if (jobs.isEmpty()) {
    System.schedule('Facturation quotidienne', '0 0 2 * * ?', new BillingRunScheduler());
}
System.debug('Règles ajoutées : ' + rules.size());
