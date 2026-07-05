@IsTest
private class BillingRunSchedulerTest {
    @IsTest
    static void generatesOnlyOneInvoiceForADuePeriod() {
        Account account = new Account(
            Name = 'Client récurrent',
            BillingRecipientType__c = 'PrivateBusiness'
        );
        insert account;
        BillingEntity__c entity = new BillingEntity__c(
            Name = 'Société planification',
            RegistrationNumber__c = '987654321',
            Address__c = 'Paris',
            IsDefault__c = true,
            DefaultPaymentTermsDays__c = 30
        );
        insert entity;
        BillingRule__c rule = new BillingRule__c(
            Name = 'Mensuelle test',
            Active__c = true,
            BillingFrequency__c = 'Monthly',
            BillingType__c = 'Arrears',
            PeriodBoundary__c = 'Calendar',
            BillingDay__c = 5,
            PaymentTermsDays__c = 20,
            BillingEntity__c = entity.Id,
            AutoIssue__c = false
        );
        insert rule;
        Id pricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(Name = 'Abonnement', IsActive = true);
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert entry;
        Opportunity opportunity = new Opportunity(
            Name = 'Contrat mensuel',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Pricebook2Id = pricebookId,
            BillingRule__c = rule.Id,
            BillingGenerationActive__c = true,
            NextBillingDate__c = Date.today()
        );
        insert opportunity;
        insert new OpportunityLineItem(
            OpportunityId = opportunity.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        Database.executeBatch(new BillingDueBatch(Date.today()), 1);
        Test.stopTest();

        Invoice__c invoice = [
            SELECT Origin__c, GenerationKey__c, BillingPeriodStart__c,
                   BillingPeriodEnd__c FROM Invoice__c
            WHERE Opportunity__c = :opportunity.Id
        ];
        Opportunity updated = [
            SELECT LastBilledDate__c, NextBillingDate__c,
                   BillingGenerationActive__c, LastBillingError__c
            FROM Opportunity WHERE Id = :opportunity.Id
        ];
        System.assertEquals('Scheduled', invoice.Origin__c);
        System.assertEquals(BillingRuleEngine.generationKey(opportunity.Id, Date.today()), invoice.GenerationKey__c);
        System.assertEquals(Date.today(), updated.LastBilledDate__c);
        System.assertEquals(Date.today().addMonths(1).toStartOfMonth().addDays(4), updated.NextBillingDate__c);
        System.assertEquals(true, updated.BillingGenerationActive__c);
        System.assertEquals(null, updated.LastBillingError__c);
    }
}
