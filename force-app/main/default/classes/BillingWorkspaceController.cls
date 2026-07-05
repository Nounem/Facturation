public with sharing class BillingWorkspaceController {
    public class WorkspaceData {
        @AuraEnabled public String opportunityName;
        @AuraEnabled public List<Quote> quotes;
        @AuraEnabled public List<Invoice__c> invoices;
    }

    // This method is called immediately after mutations. It must not be cacheable,
    // otherwise Lightning can return the pre-mutation workspace snapshot.
    @AuraEnabled
    public static WorkspaceData load(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('L’identifiant de l’opportunité est requis.');
        }
        Opportunity opportunity = [
            SELECT Id, Name FROM Opportunity WHERE Id = :opportunityId
        ];
        WorkspaceData result = new WorkspaceData();
        result.opportunityName = opportunity.Name;
        result.quotes = [
            SELECT Id, Name, QuoteNumber, Status, ExpirationDate, TotalPrice,
                   TaxAmount__c, TotalIncludingTax__c, BillingEntity__c
            FROM Quote WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC LIMIT 100
        ];
        result.invoices = [
            SELECT Id, Name, InvoiceNumber__c, Status__c, IssueDate__c, DueDate__c,
                   TotalAmount__c, BalanceDue__c, IsLocked__c, Origin__c,
                   BillingPeriodStart__c, BillingPeriodEnd__c, BillingRule__c
            FROM Invoice__c WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC LIMIT 100
        ];
        return result;
    }

    @AuraEnabled
    public static Id createQuoteFromOpportunity(Id opportunityId) {
        Opportunity opportunity = [
            SELECT Id, Name, AccountId, Pricebook2Id, Account.BillingRecipientType__c,
                   Account.BillingSiret__c,
                   (SELECT Id, PricebookEntryId, Quantity, UnitPrice, Discount,
                           Product2.Name, Product2.Description
                    FROM OpportunityLineItems)
            FROM Opportunity WHERE Id = :opportunityId
        ];
        if (opportunity.Pricebook2Id == null) {
            throw new AuraHandledException('L’opportunité doit avoir un catalogue de prix.');
        }
        if (opportunity.AccountId == null) {
            throw new AuraHandledException('Associez un compte client à l’opportunité avant de créer un devis.');
        }
        if (opportunity.OpportunityLineItems.isEmpty()) {
            throw new AuraHandledException('Ajoutez au moins un produit à l’opportunité.');
        }

        List<BillingEntity__c> entities = [
            SELECT Id FROM BillingEntity__c WHERE IsDefault__c = true LIMIT 1
        ];
        Decimal defaultTax = 20;
        List<TaxRate__c> taxes = [
            SELECT Rate__c FROM TaxRate__c WHERE IsActive__c = true AND IsDefault__c = true LIMIT 1
        ];
        if (!taxes.isEmpty()) defaultTax = taxes[0].Rate__c;

        Quote quote = new Quote(
            Name = 'Devis - ' + opportunity.Name,
            OpportunityId = opportunity.Id,
            Pricebook2Id = opportunity.Pricebook2Id,
            ExpirationDate = Date.today().addDays(30),
            BillingEntity__c = entities.isEmpty() ? null : entities[0].Id,
            RecipientType__c = recipientTypeOrDefault(opportunity.Account.BillingRecipientType__c),
            RecipientSiret__c = opportunity.Account.BillingSiret__c
        );
        try {
            insert quote;
        } catch (DmlException error) {
            throw detailedDmlError('Création du devis impossible', error);
        }

        List<QuoteLineItem> lines = new List<QuoteLineItem>();
        for (OpportunityLineItem source : opportunity.OpportunityLineItems) {
            lines.add(new QuoteLineItem(
                QuoteId = quote.Id,
                PricebookEntryId = source.PricebookEntryId,
                Quantity = source.Quantity,
                UnitPrice = source.UnitPrice,
                Discount = source.Discount,
                Description = String.isBlank(source.Product2.Description)
                    ? source.Product2.Name
                    : source.Product2.Description,
                TaxRate__c = defaultTax
            ));
        }
        try {
            insert lines;
        } catch (DmlException error) {
            throw detailedDmlError('Ajout des lignes du devis impossible', error);
        }
        return quote.Id;
    }

    @TestVisible
    private static String recipientTypeOrDefault(String recipientType) {
        return String.isBlank(recipientType) ? 'PrivateBusiness' : recipientType;
    }

    private static AuraHandledException detailedDmlError(String context, DmlException error) {
        String detail = error.getNumDml() > 0 ? error.getDmlMessage(0) : error.getMessage();
        return new AuraHandledException(context + ' : ' + detail);
    }

    @AuraEnabled
    public static Id convertQuoteToInvoice(Id quoteId) {
        try {
            return InvoiceService.convertQuote(quoteId);
        } catch (Exception error) {
            throw new AuraHandledException(error.getMessage());
        }
    }

    @AuraEnabled
    public static Id createInvoiceFromOpportunity(Id opportunityId) {
        try {
            return InvoiceService.createDirectFromOpportunity(opportunityId);
        } catch (Exception error) {
            throw new AuraHandledException(error.getMessage());
        }
    }

    @AuraEnabled
    public static Invoice__c issueInvoice(Id invoiceId) {
        try {
            return InvoiceService.issue(invoiceId);
        } catch (Exception error) {
            throw new AuraHandledException(error.getMessage());
        }
    }

    @AuraEnabled
    public static EInvoiceTransmission__c prepareElectronicInvoice(Id invoiceId) {
        try {
            return EInvoiceService.prepare(invoiceId);
        } catch (Exception error) {
            throw new AuraHandledException(error.getMessage());
        }
    }
}
