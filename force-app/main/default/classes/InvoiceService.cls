public with sharing class InvoiceService {
    public class BillingException extends Exception {}

    public class CreationOptions {
        public Date billingDate;
        public String generationKey;
        public Boolean scheduled = false;
    }

    public class CreationResult {
        public Id invoiceId;
        public Date nextBillingDate;
    }

    public static Id convertQuote(Id quoteId) {
        List<Invoice__c> existing = [
            SELECT Id FROM Invoice__c WHERE SourceQuote__c = :quoteId LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Quote quote = [
            SELECT Id, Status, OpportunityId, Opportunity.CloseDate,
                   Opportunity.AccountId, Opportunity.Account.Name,
                   Opportunity.Account.BillingStreet, Opportunity.Account.BillingPostalCode,
                   Opportunity.Account.BillingCity, Opportunity.Account.BillingCountry,
                   Opportunity.Account.BillingRegistrationNumber__c,
                   Opportunity.Account.BillingTaxId__c,
                   BillingEntity__c, RecipientType__c, RecipientSiret__c,
                   CommitmentNumber__c, ServiceCode__c, BillingFramework__c,
                   (SELECT Id, Product2Id, Product2.Name, Description, Quantity, UnitPrice,
                           Discount, TaxRate__c
                    FROM QuoteLineItems ORDER BY SortOrder)
            FROM Quote WHERE Id = :quoteId
        ];
        if (quote.QuoteLineItems.isEmpty()) {
            throw new BillingException('Le devis ne contient aucune ligne.');
        }
        if (quote.Status != 'Accepted') {
            throw new BillingException('Seul un devis au statut Accepté peut être facturé.');
        }

        Id entityId = quote.BillingEntity__c;
        if (entityId == null) {
            List<BillingEntity__c> defaults = [
                SELECT Id FROM BillingEntity__c WHERE IsDefault__c = true LIMIT 1
            ];
            if (defaults.isEmpty()) {
                throw new BillingException('Configurez une entité de facturation par défaut.');
            }
            entityId = defaults[0].Id;
        }

        Account account = quote.Opportunity.Account;
        Invoice__c invoice = new Invoice__c(
            Account__c = account.Id,
            Opportunity__c = quote.OpportunityId,
            SourceQuote__c = quote.Id,
            BillingEntity__c = entityId,
            Status__c = 'Draft',
            CustomerName__c = account.Name,
            BillingStreet__c = account.BillingStreet,
            BillingPostalCode__c = account.BillingPostalCode,
            BillingCity__c = account.BillingCity,
            BillingCountry__c = account.BillingCountry,
            CustomerRegistrationNumber__c = account.BillingRegistrationNumber__c,
            CustomerTaxId__c = account.BillingTaxId__c,
            RecipientType__c = quote.RecipientType__c,
            RecipientSiret__c = quote.RecipientSiret__c,
            CommitmentNumber__c = quote.CommitmentNumber__c,
            ServiceCode__c = quote.ServiceCode__c,
            BillingFramework__c = quote.BillingFramework__c,
            ServiceDate__c = quote.Opportunity.CloseDate,
            OperationCategory__c = 'Services',
            Origin__c = 'Quote'
        );
        insert invoice;

        List<InvoiceLine__c> invoiceLines = new List<InvoiceLine__c>();
        Integer position = 0;
        for (QuoteLineItem quoteLine : quote.QuoteLineItems) {
            position++;
            invoiceLines.add(new InvoiceLine__c(
                Invoice__c = invoice.Id,
                Product__c = quoteLine.Product2Id,
                Description__c = String.isBlank(quoteLine.Description)
                    ? quoteLine.Product2.Name
                    : quoteLine.Description,
                Quantity__c = quoteLine.Quantity,
                UnitPrice__c = quoteLine.UnitPrice,
                DiscountPercent__c = quoteLine.Discount == null ? 0 : quoteLine.Discount,
                TaxRate__c = quoteLine.TaxRate__c,
                SortOrder__c = position
            ));
        }
        insert invoiceLines;
        return invoice.Id;
    }

    public static Id createDirectFromOpportunity(Id opportunityId) {
        CreationOptions options = new CreationOptions();
        options.billingDate = Date.today();
        return createFromOpportunity(opportunityId, options).invoiceId;
    }

    public static CreationResult createFromOpportunity(
        Id opportunityId,
        CreationOptions options
    ) {
        if (opportunityId == null) throw new BillingException('L’opportunité est requise.');
        if (options == null) options = new CreationOptions();
        Date billingDate = options.billingDate == null ? Date.today() : options.billingDate;

        Opportunity opportunity = [
            SELECT Id, Name, AccountId, CloseDate, BillingRule__c,
                   Account.Name, Account.BillingStreet, Account.BillingPostalCode,
                   Account.BillingCity, Account.BillingCountry,
                   Account.BillingRegistrationNumber__c, Account.BillingTaxId__c,
                   Account.BillingRecipientType__c, Account.BillingSiret__c,
                   (SELECT Id, PricebookEntry.Product2Id, Product2.Name,
                           Product2.Description, Quantity, UnitPrice, Discount
                    FROM OpportunityLineItems ORDER BY SortOrder)
            FROM Opportunity WHERE Id = :opportunityId
        ];
        if (opportunity.AccountId == null) {
            throw new BillingException('Associez un compte client à l’opportunité.');
        }
        if (opportunity.OpportunityLineItems.isEmpty()) {
            throw new BillingException('Ajoutez au moins un produit à l’opportunité.');
        }

        BillingRule__c rule;
        if (opportunity.BillingRule__c != null) {
            rule = [
                SELECT Id, Active__c, BillingFrequency__c, BillingType__c,
                       BillingDay__c, PaymentTermsDays__c, PeriodBoundary__c,
                       AutoIssue__c, BillingEntity__c
                FROM BillingRule__c WHERE Id = :opportunity.BillingRule__c
            ];
            if (!rule.Active__c) {
                throw new BillingException('La règle de facturation affectée est inactive.');
            }
        }

        CreationResult result = new CreationResult();
        result.nextBillingDate = rule == null
            ? null
            : BillingRuleEngine.nextBillingDate(rule, billingDate);
        if (String.isNotBlank(options.generationKey)) {
            List<Invoice__c> existing = [
                SELECT Id FROM Invoice__c
                WHERE GenerationKey__c = :options.generationKey LIMIT 1
            ];
            if (!existing.isEmpty()) {
                result.invoiceId = existing[0].Id;
                return result;
            }
        }

        Id entityId = rule == null ? null : rule.BillingEntity__c;
        if (entityId == null) {
            List<BillingEntity__c> entities = [
                SELECT Id, DefaultPaymentTermsDays__c
                FROM BillingEntity__c WHERE IsDefault__c = true LIMIT 1
            ];
            if (entities.isEmpty()) {
                throw new BillingException('Configurez une entité de facturation par défaut.');
            }
            entityId = entities[0].Id;
        }
        BillingEntity__c entity = [
            SELECT Id, DefaultPaymentTermsDays__c
            FROM BillingEntity__c WHERE Id = :entityId
        ];

        Integer paymentTerms = rule != null && rule.PaymentTermsDays__c != null
            ? Integer.valueOf(rule.PaymentTermsDays__c)
            : Integer.valueOf(entity.DefaultPaymentTermsDays__c == null
                ? 30
                : entity.DefaultPaymentTermsDays__c);
        BillingRuleEngine.BillingPeriod period = rule == null
            ? new BillingRuleEngine.BillingPeriod(billingDate, billingDate)
            : BillingRuleEngine.periodFor(rule, billingDate);
        Account account = opportunity.Account;
        Invoice__c invoice = new Invoice__c(
            Account__c = account.Id,
            Opportunity__c = opportunity.Id,
            BillingEntity__c = entityId,
            BillingRule__c = rule == null ? null : rule.Id,
            Status__c = 'Draft',
            Origin__c = options.scheduled ? 'Scheduled' : 'Direct',
            GenerationKey__c = options.generationKey,
            IssueDate__c = billingDate,
            DueDate__c = billingDate.addDays(paymentTerms),
            ServiceDate__c = rule != null && rule.BillingType__c == 'Arrears'
                ? period.endDate
                : period.startDate,
            BillingPeriodStart__c = period.startDate,
            BillingPeriodEnd__c = period.endDate,
            OperationCategory__c = 'Services',
            CustomerName__c = account.Name,
            BillingStreet__c = account.BillingStreet,
            BillingPostalCode__c = account.BillingPostalCode,
            BillingCity__c = account.BillingCity,
            BillingCountry__c = account.BillingCountry,
            CustomerRegistrationNumber__c = account.BillingRegistrationNumber__c,
            CustomerTaxId__c = account.BillingTaxId__c,
            RecipientType__c = String.isBlank(account.BillingRecipientType__c)
                ? 'PrivateBusiness'
                : account.BillingRecipientType__c,
            RecipientSiret__c = account.BillingSiret__c
        );
        insert invoice;

        Decimal defaultTax = 20;
        List<TaxRate__c> taxes = [
            SELECT Rate__c FROM TaxRate__c
            WHERE IsActive__c = true AND IsDefault__c = true LIMIT 1
        ];
        if (!taxes.isEmpty()) defaultTax = taxes[0].Rate__c;

        List<InvoiceLine__c> lines = new List<InvoiceLine__c>();
        Integer position = 0;
        for (OpportunityLineItem source : opportunity.OpportunityLineItems) {
            position++;
            lines.add(new InvoiceLine__c(
                Invoice__c = invoice.Id,
                Product__c = source.PricebookEntry.Product2Id,
                Description__c = String.isBlank(source.Product2.Description)
                    ? source.Product2.Name
                    : source.Product2.Description,
                Quantity__c = source.Quantity,
                UnitPrice__c = source.UnitPrice,
                DiscountPercent__c = source.Discount == null ? 0 : source.Discount,
                TaxRate__c = defaultTax,
                SortOrder__c = position
            ));
        }
        insert lines;
        result.invoiceId = invoice.Id;

        if (options.scheduled && rule != null && rule.AutoIssue__c) {
            issue(invoice.Id);
        }
        return result;
    }

    public static Invoice__c issue(Id invoiceId) {
        Invoice__c invoice = [
            SELECT Id, BillingEntity__c, Status__c, InvoiceNumber__c, IsLocked__c,
                   IssueDate__c, DueDate__c, TotalAmount__c,
                   BillingEntity__r.DefaultPaymentTermsDays__c,
                   (SELECT Id FROM Lines__r LIMIT 1)
            FROM Invoice__c WHERE Id = :invoiceId FOR UPDATE
        ];
        if (invoice.IsLocked__c) {
            return invoice;
        }
        if (invoice.Lines__r.isEmpty()) {
            throw new BillingException('Une facture doit contenir au moins une ligne.');
        }
        Date issueDate = invoice.IssueDate__c == null ? Date.today() : invoice.IssueDate__c;
        Integer terms = invoice.BillingEntity__r.DefaultPaymentTermsDays__c == null
            ? 30
            : Integer.valueOf(invoice.BillingEntity__r.DefaultPaymentTermsDays__c);
        invoice.InvoiceNumber__c = NumberingService.nextInvoiceNumber(invoice.BillingEntity__c, issueDate);
        invoice.IssueDate__c = issueDate;
        invoice.DueDate__c = invoice.DueDate__c == null ? issueDate.addDays(terms) : invoice.DueDate__c;
        invoice.Status__c = 'Issued';
        invoice.IsLocked__c = true;
        update invoice;
        return invoice;
    }
}
