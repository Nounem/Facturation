public with sharing class InvoiceTriggerHandler {
    public static void protectIssued(List<Invoice__c> currentRecords, Map<Id, Invoice__c> oldMap) {
        for (Invoice__c currentRecord : currentRecords) {
            Invoice__c oldRecord = oldMap.get(currentRecord.Id);
            if (!oldRecord.IsLocked__c) continue;
            Boolean protectedDataChanged =
                currentRecord.Account__c != oldRecord.Account__c ||
                currentRecord.BillingEntity__c != oldRecord.BillingEntity__c ||
                currentRecord.Opportunity__c != oldRecord.Opportunity__c ||
                currentRecord.SourceQuote__c != oldRecord.SourceQuote__c ||
                currentRecord.DocumentType__c != oldRecord.DocumentType__c ||
                currentRecord.OriginalInvoice__c != oldRecord.OriginalInvoice__c ||
                currentRecord.CreditReason__c != oldRecord.CreditReason__c ||
                currentRecord.RecipientType__c != oldRecord.RecipientType__c ||
                currentRecord.RecipientSiret__c != oldRecord.RecipientSiret__c ||
                currentRecord.CommitmentNumber__c != oldRecord.CommitmentNumber__c ||
                currentRecord.ServiceCode__c != oldRecord.ServiceCode__c ||
                currentRecord.BillingFramework__c != oldRecord.BillingFramework__c ||
                currentRecord.CustomerName__c != oldRecord.CustomerName__c ||
                currentRecord.CustomerRegistrationNumber__c != oldRecord.CustomerRegistrationNumber__c ||
                currentRecord.CustomerTaxId__c != oldRecord.CustomerTaxId__c ||
                currentRecord.BillingStreet__c != oldRecord.BillingStreet__c ||
                currentRecord.BillingPostalCode__c != oldRecord.BillingPostalCode__c ||
                currentRecord.BillingCity__c != oldRecord.BillingCity__c ||
                currentRecord.BillingCountry__c != oldRecord.BillingCountry__c ||
                currentRecord.InvoiceNumber__c != oldRecord.InvoiceNumber__c ||
                currentRecord.IssueDate__c != oldRecord.IssueDate__c ||
                currentRecord.DueDate__c != oldRecord.DueDate__c ||
                currentRecord.ServiceDate__c != oldRecord.ServiceDate__c ||
                currentRecord.OperationCategory__c != oldRecord.OperationCategory__c ||
                currentRecord.DeliveryAddress__c != oldRecord.DeliveryAddress__c ||
                currentRecord.VatOnDebits__c != oldRecord.VatOnDebits__c ||
                currentRecord.Subtotal__c != oldRecord.Subtotal__c ||
                currentRecord.TaxAmount__c != oldRecord.TaxAmount__c ||
                currentRecord.TotalAmount__c != oldRecord.TotalAmount__c ||
                currentRecord.IsLocked__c != oldRecord.IsLocked__c;
            if (protectedDataChanged) {
                currentRecord.addError('Une facture émise est immuable. Utilisez un avoir pour la corriger.');
            }
        }
    }

    public static void protectDelete(List<Invoice__c> records) {
        for (Invoice__c invoice : records) {
            if (invoice.IsLocked__c) {
                invoice.addError('Une facture émise ne peut pas être supprimée.');
            }
        }
    }
}
