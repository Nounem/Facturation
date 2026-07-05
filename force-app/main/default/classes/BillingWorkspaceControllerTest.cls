@IsTest
private class BillingWorkspaceControllerTest {
    @TestSetup
    static void setupWorkspace() {
        Account account = new Account(
            Name = 'Client Workspace',
            BillingStreet = '1 rue du Test',
            BillingPostalCode = '75001',
            BillingCity = 'Paris',
            BillingCountry = 'France',
            BillingRecipientType__c = 'PrivateBusiness',
            BillingSiret__c = '12345678900012'
        );
        insert account;

        insert new BillingEntity__c(
            Name = 'Société Workspace',
            RegistrationNumber__c = '123456789',
            Address__c = '10 avenue Salesforce, 75002 Paris',
            IsDefault__c = true,
            DefaultPaymentTermsDays__c = 30
        );
        insert new TaxRate__c(
            Name = 'TVA 20 %',
            Rate__c = 20,
            IsActive__c = true,
            IsDefault__c = true
        );

        Id pricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(
            Name = 'Conseil',
            Description = 'Journée de conseil',
            IsActive = true
        );
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert entry;

        Opportunity opportunity = new Opportunity(
            Name = 'Projet Workspace',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pricebookId
        );
        insert opportunity;
        insert new OpportunityLineItem(
            OpportunityId = opportunity.Id,
            PricebookEntryId = entry.Id,
            Quantity = 2,
            UnitPrice = 1000
        );
    }

    @IsTest
    static void defaultsMissingRecipientTypeToPrivateBusiness() {
        System.assertEquals(
            'PrivateBusiness',
            BillingWorkspaceController.recipientTypeOrDefault(null)
        );
        System.assertEquals(
            'PrivateBusiness',
            BillingWorkspaceController.recipientTypeOrDefault('')
        );
        System.assertEquals(
            'PublicSector',
            BillingWorkspaceController.recipientTypeOrDefault('PublicSector')
        );
    }

    @IsTest
    static void refreshesWorkspaceAfterQuoteAndInvoiceCreation() {
        Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Id quoteId = BillingWorkspaceController.createQuoteFromOpportunity(opportunity.Id);
        BillingWorkspaceController.WorkspaceData afterQuote =
            BillingWorkspaceController.load(opportunity.Id);

        Quote quote = [SELECT Id, Status FROM Quote WHERE Id = :quoteId];
        quote.Status = 'Accepted';
        update quote;
        Id invoiceId = BillingWorkspaceController.convertQuoteToInvoice(quoteId);
        BillingWorkspaceController.WorkspaceData afterInvoice =
            BillingWorkspaceController.load(opportunity.Id);
        Test.stopTest();

        System.assertEquals(1, afterQuote.quotes.size());
        System.assertEquals(0, afterQuote.invoices.size());
        System.assertEquals(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId]);
        System.assertEquals(1, afterInvoice.quotes.size());
        System.assertEquals(1, afterInvoice.invoices.size());
        System.assertEquals(invoiceId, afterInvoice.invoices[0].Id);
    }
}
