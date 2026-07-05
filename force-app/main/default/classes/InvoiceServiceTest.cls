@IsTest
private class InvoiceServiceTest {
    @TestSetup
    static void setupData() {
        Account account = new Account(
            Name = 'Client Test',
            BillingStreet = '1 rue du Test',
            BillingPostalCode = '75001',
            BillingCity = 'Paris',
            BillingCountry = 'France',
            BillingRecipientType__c = 'PrivateBusiness',
            BillingSiret__c = '12345678900012'
        );
        insert account;

        BillingEntity__c entity = new BillingEntity__c(
            Name = 'Société Test',
            RegistrationNumber__c = '123456789',
            Address__c = '10 avenue Salesforce, 75002 Paris',
            IsDefault__c = true,
            DefaultPaymentTermsDays__c = 30
        );
        insert entity;
        insert new NumberingSequence__c(
            Name = entity.Id + '-Invoice-' + Date.today().year(),
            BillingEntity__c = entity.Id,
            DocumentType__c = 'Invoice',
            Year__c = Date.today().year(),
            Prefix__c = 'FAC',
            NextNumber__c = 1,
            Padding__c = 5
        );

        Id pricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(Name = 'Conseil', Description = 'Journée de conseil', IsActive = true);
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert entry;

        Opportunity opportunity = new Opportunity(
            Name = 'Projet Test',
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
            UnitPrice = 1000,
            Discount = 10
        );
        Quote quote = new Quote(
            Name = 'Devis Test',
            Status = 'Accepted',
            OpportunityId = opportunity.Id,
            Pricebook2Id = pricebookId,
            ExpirationDate = Date.today().addDays(30),
            BillingEntity__c = entity.Id
        );
        insert quote;
        insert new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = entry.Id,
            Quantity = 2,
            UnitPrice = 1000,
            Discount = 10,
            TaxRate__c = 20
        );
    }

    @IsTest
    static void convertsAndIssuesQuote() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        Invoice__c issued = InvoiceService.issue(invoiceId);
        Test.stopTest();

        Invoice__c invoice = [
            SELECT InvoiceNumber__c, Status__c, IsLocked__c, Subtotal__c,
                   TaxAmount__c, TotalAmount__c, BalanceDue__c, DueDate__c,
                   (SELECT NetAmount__c, TaxAmount__c, GrossAmount__c FROM Lines__r)
            FROM Invoice__c WHERE Id = :issued.Id
        ];
        System.assertEquals('FAC-' + Date.today().year() + '-00001', invoice.InvoiceNumber__c);
        System.assertEquals('Issued', invoice.Status__c);
        System.assertEquals(true, invoice.IsLocked__c);
        System.assertEquals(1800, invoice.Subtotal__c);
        System.assertEquals(360, invoice.TaxAmount__c);
        System.assertEquals(2160, invoice.TotalAmount__c);
        System.assertEquals(2160, invoice.BalanceDue__c);
        System.assertEquals(Date.today().addDays(30), invoice.DueDate__c);
    }

    @IsTest
    static void conversionIsIdempotent() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id firstId = InvoiceService.convertQuote(quote.Id);
        Id secondId = InvoiceService.convertQuote(quote.Id);
        System.assertEquals(firstId, secondId);
        System.assertEquals(1, [SELECT COUNT() FROM Invoice__c WHERE SourceQuote__c = :quote.Id]);
    }

    @IsTest
    static void createsDirectInvoiceWithoutQuote() {
        Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Id invoiceId = InvoiceService.createDirectFromOpportunity(opportunity.Id);
        Test.stopTest();

        Invoice__c invoice = [
            SELECT Origin__c, SourceQuote__c, Status__c, DueDate__c,
                   BillingPeriodStart__c, BillingPeriodEnd__c, Subtotal__c,
                   (SELECT Id FROM Lines__r)
            FROM Invoice__c WHERE Id = :invoiceId
        ];
        System.assertEquals('Direct', invoice.Origin__c);
        System.assertEquals(null, invoice.SourceQuote__c);
        System.assertEquals('Draft', invoice.Status__c);
        System.assertEquals(Date.today().addDays(30), invoice.DueDate__c);
        System.assertEquals(Date.today(), invoice.BillingPeriodStart__c);
        System.assertEquals(Date.today(), invoice.BillingPeriodEnd__c);
        System.assertEquals(1800, invoice.Subtotal__c);
        System.assertEquals(1, invoice.Lines__r.size());
    }

    @IsTest
    static void appliesBillingRuleToDirectInvoice() {
        BillingEntity__c entity = [SELECT Id FROM BillingEntity__c LIMIT 1];
        BillingRule__c rule = new BillingRule__c(
            Name = 'Mensuelle à échoir',
            Active__c = true,
            BillingFrequency__c = 'Monthly',
            BillingType__c = 'Advance',
            PeriodBoundary__c = 'Calendar',
            BillingDay__c = 1,
            PaymentTermsDays__c = 15,
            BillingEntity__c = entity.Id
        );
        insert rule;
        Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
        opportunity.BillingRule__c = rule.Id;
        update opportunity;

        InvoiceService.CreationOptions options = new InvoiceService.CreationOptions();
        options.billingDate = Date.newInstance(2026, 7, 1);
        options.generationKey = BillingRuleEngine.generationKey(opportunity.Id, options.billingDate);
        options.scheduled = true;
        InvoiceService.CreationResult result = InvoiceService.createFromOpportunity(opportunity.Id, options);

        Invoice__c invoice = [
            SELECT Origin__c, BillingRule__c, BillingPeriodStart__c,
                   BillingPeriodEnd__c, DueDate__c, GenerationKey__c
            FROM Invoice__c WHERE Id = :result.invoiceId
        ];
        System.assertEquals('Scheduled', invoice.Origin__c);
        System.assertEquals(rule.Id, invoice.BillingRule__c);
        System.assertEquals(Date.newInstance(2026, 7, 1), invoice.BillingPeriodStart__c);
        System.assertEquals(Date.newInstance(2026, 7, 31), invoice.BillingPeriodEnd__c);
        System.assertEquals(Date.newInstance(2026, 7, 16), invoice.DueDate__c);
        System.assertEquals(Date.newInstance(2026, 8, 1), result.nextBillingDate);
    }

    @IsTest
    static void issuedInvoiceCannotBeAltered() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);

        Invoice__c invoice = [SELECT CustomerName__c FROM Invoice__c WHERE Id = :invoiceId];
        invoice.CustomerName__c = 'Client modifié';
        Database.SaveResult result = Database.update(invoice, false);

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('immuable'));
    }

    @IsTest
    static void paymentUpdatesBalanceAndStatus() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);

        insert new Payment__c(
            Invoice__c = invoiceId,
            Amount__c = 500,
            PaymentDate__c = Date.today(),
            Method__c = 'BankTransfer'
        );

        Invoice__c invoice = [
            SELECT AmountPaid__c, BalanceDue__c, Status__c FROM Invoice__c WHERE Id = :invoiceId
        ];
        System.assertEquals(500, invoice.AmountPaid__c);
        System.assertEquals(1660, invoice.BalanceDue__c);
        System.assertEquals('PartiallyPaid', invoice.Status__c);
    }

    @IsTest
    static void generatesInvoicePdfFile() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);

        Test.startTest();
        Id documentId = InvoicePdfController.generateAndAttach(invoiceId);
        Id existingDocumentId = InvoicePdfController.generateAndAttach(invoiceId);
        Test.stopTest();

        System.assertNotEquals(null, documentId);
        System.assertEquals(documentId, existingDocumentId);
        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :invoiceId AND ContentDocumentId = :documentId
        ]);
        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :invoiceId
        ]);
    }

    @IsTest
    static void pdfRequiresAnIssuedInvoice() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);

        Boolean rejected = false;
        try {
            InvoicePdfController.generateAndAttach(invoiceId);
        } catch (AuraHandledException error) {
            rejected = true;
        }

        System.assertEquals(true, rejected);
        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :invoiceId
        ]);
    }

    @IsTest
    static void loadsInvoiceDataForThePdfPage() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);
        Invoice__c invoice = [
            SELECT Id, BillingEntity__c FROM Invoice__c WHERE Id = :invoiceId
        ];
        ContentVersion logo = new ContentVersion(
            Title = 'logo-pdf',
            PathOnClient = 'logo-pdf.png',
            VersionData = Blob.valueOf('image-test'),
            FirstPublishLocationId = invoice.BillingEntity__c
        );
        insert logo;
        logo = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :logo.Id];
        update new BillingEntity__c(
            Id = invoice.BillingEntity__c,
            LogoContentDocumentId__c = logo.ContentDocumentId,
            PdfPrimaryColor__c = '#C23934'
        );

        Test.setCurrentPage(Page.InvoicePdf);
        ApexPages.StandardController standardController =
            new ApexPages.StandardController(invoice);
        InvoicePdfController controller =
            new InvoicePdfController(standardController);

        System.assertEquals(invoiceId, controller.invoice.Id);
        System.assertEquals(1, controller.invoice.Lines__r.size());
        System.assertEquals('#C23934', controller.primaryColor);
        System.assertEquals(true, controller.getHasLogo());
        System.assertEquals(1, controller.taxSummaries.size());
    }

    @IsTest
    static void preparesPrivateElectronicInvoiceForAccreditedPlatform() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);

        Test.startTest();
        EInvoiceTransmission__c transmission = EInvoiceService.prepare(invoiceId);
        Test.stopTest();

        System.assertEquals('AccreditedPlatform', transmission.Provider__c);
        System.assertEquals('Prepared', transmission.Status__c);
        System.assertNotEquals(null, transmission.PayloadDocumentId__c);
        System.assertEquals(transmission.Id, EInvoiceService.prepare(invoiceId).Id);
    }

    @IsTest
    static void routesPublicInvoiceToChorusPro() {
        Quote quote = [
            SELECT Id, RecipientType__c, RecipientSiret__c, BillingFramework__c
            FROM Quote LIMIT 1
        ];
        quote.RecipientType__c = 'PublicSector';
        quote.RecipientSiret__c = '13002526500013';
        quote.BillingFramework__c = 'A1';
        update quote;
        Id invoiceId = InvoiceService.convertQuote(quote.Id);
        InvoiceService.issue(invoiceId);

        EInvoiceTransmission__c transmission = EInvoiceService.prepare(invoiceId);

        System.assertEquals('ChorusPro', transmission.Provider__c);
        System.assertEquals('Prepared', transmission.Status__c);
    }
}
