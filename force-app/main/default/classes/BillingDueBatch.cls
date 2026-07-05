public with sharing class BillingDueBatch implements Database.Batchable<SObject> {
    private Date targetDate;

    public BillingDueBatch(Date targetDate) {
        this.targetDate = targetDate == null ? Date.today() : targetDate;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, NextBillingDate__c
            FROM Opportunity
            WHERE BillingGenerationActive__c = true
              AND BillingRule__c != null
              AND BillingRule__r.Active__c = true
              AND NextBillingDate__c <= :targetDate
        ]);
    }

    public void execute(Database.BatchableContext context, List<Opportunity> opportunities) {
        List<Opportunity> updates = new List<Opportunity>();
        for (Opportunity opportunity : opportunities) {
            Opportunity updateRecord = new Opportunity(Id = opportunity.Id);
            try {
                InvoiceService.CreationOptions options = new InvoiceService.CreationOptions();
                options.billingDate = opportunity.NextBillingDate__c;
                options.generationKey = BillingRuleEngine.generationKey(
                    opportunity.Id,
                    opportunity.NextBillingDate__c
                );
                options.scheduled = true;
                InvoiceService.CreationResult result =
                    InvoiceService.createFromOpportunity(opportunity.Id, options);
                updateRecord.LastBilledDate__c = opportunity.NextBillingDate__c;
                updateRecord.NextBillingDate__c = result.nextBillingDate;
                updateRecord.BillingGenerationActive__c = result.nextBillingDate != null;
                updateRecord.LastBillingError__c = null;
            } catch (Exception error) {
                updateRecord.LastBillingError__c = error.getMessage().left(32768);
            }
            updates.add(updateRecord);
        }
        if (!updates.isEmpty()) update updates;
    }

    public void finish(Database.BatchableContext context) {}
}
