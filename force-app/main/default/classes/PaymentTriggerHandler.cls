public with sharing class PaymentTriggerHandler {
    public static void validate(List<Payment__c> payments) {
        Set<Id> invoiceIds = parentIds(payments);
        Map<Id, Invoice__c> invoices = new Map<Id, Invoice__c>([
            SELECT Id, IsLocked__c, DocumentType__c
            FROM Invoice__c WHERE Id IN :invoiceIds FOR UPDATE
        ]);
        for (Payment__c payment : payments) {
            if (payment.Amount__c == null || payment.Amount__c <= 0) {
                payment.addError('Le montant du paiement doit être strictement positif.');
            } else if (invoices.get(payment.Invoice__c).DocumentType__c == 'CreditNote') {
                payment.addError('Un paiement ne peut pas être enregistré sur un avoir.');
            } else if (!invoices.get(payment.Invoice__c).IsLocked__c) {
                payment.addError('Un paiement ne peut être enregistré que sur une facture émise.');
            }
        }
    }

    public static void refreshInvoices(Set<Id> invoiceIds) {
        invoiceIds.remove(null);
        if (invoiceIds.isEmpty()) return;
        Map<Id, Decimal> paidByInvoice = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Invoice__c invoiceId, SUM(Amount__c) paid
            FROM Payment__c WHERE Invoice__c IN :invoiceIds GROUP BY Invoice__c
        ]) {
            paidByInvoice.put((Id) result.get('invoiceId'), (Decimal) result.get('paid'));
        }
        List<Invoice__c> updates = new List<Invoice__c>();
        for (Invoice__c invoice : [
            SELECT Id, TotalAmount__c, CreditedAmount__c, Status__c
            FROM Invoice__c WHERE Id IN :invoiceIds
        ]) {
            Decimal paid = paidByInvoice.containsKey(invoice.Id) ? paidByInvoice.get(invoice.Id) : 0;
            Decimal credited = invoice.CreditedAmount__c == null ? 0 : invoice.CreditedAmount__c;
            Decimal available = BillingCalculationService.money(invoice.TotalAmount__c - credited);
            Decimal balance = BillingCalculationService.money(available - paid);
            String status = available <= 0
                ? 'Credited'
                : (balance <= 0
                    ? 'Paid'
                    : (paid > 0
                        ? 'PartiallyPaid'
                        : (credited > 0 ? 'PartiallyCredited' : 'Issued')));
            updates.add(new Invoice__c(
                Id = invoice.Id,
                Status__c = status
            ));
        }
        update updates;
    }

    public static Set<Id> parentIds(List<Payment__c> payments) {
        Set<Id> ids = new Set<Id>();
        for (Payment__c payment : payments) ids.add(payment.Invoice__c);
        ids.remove(null);
        return ids;
    }
}
