public with sharing class InvoiceLineTriggerHandler {
    public static void beforeSave(List<InvoiceLine__c> lines) {
        protectLockedInvoices(lines);
        BillingCalculationService.calculateInvoiceLines(lines);
    }

    public static void beforeDelete(List<InvoiceLine__c> lines) {
        protectLockedInvoices(lines);
    }

    private static void protectLockedInvoices(List<InvoiceLine__c> lines) {
        Set<Id> invoiceIds = parentIds(lines);
        if (invoiceIds.isEmpty()) return;
        Set<Id> lockedIds = new Map<Id, Invoice__c>([
            SELECT Id FROM Invoice__c WHERE Id IN :invoiceIds AND IsLocked__c = true
        ]).keySet();
        for (InvoiceLine__c line : lines) {
            if (lockedIds.contains(line.Invoice__c)) {
                line.addError('Les lignes d’une facture émise sont verrouillées. Créez un avoir.');
            }
        }
    }

    public static Set<Id> parentIds(List<InvoiceLine__c> lines) {
        Set<Id> ids = new Set<Id>();
        for (InvoiceLine__c line : lines) ids.add(line.Invoice__c);
        ids.remove(null);
        return ids;
    }
}
