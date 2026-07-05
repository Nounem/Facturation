trigger PaymentTrigger on Payment__c (
    before insert, before update, after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) PaymentTriggerHandler.validate(Trigger.new);
    if (Trigger.isAfter) {
        Set<Id> invoiceIds = new Set<Id>();
        if (Trigger.new != null) invoiceIds.addAll(PaymentTriggerHandler.parentIds(Trigger.new));
        if (Trigger.old != null) invoiceIds.addAll(PaymentTriggerHandler.parentIds(Trigger.old));
        PaymentTriggerHandler.refreshInvoices(invoiceIds);
    }
}
