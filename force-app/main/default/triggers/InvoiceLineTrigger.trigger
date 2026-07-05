trigger InvoiceLineTrigger on InvoiceLine__c (
    before insert, before update, before delete
) {
    if (Trigger.isBefore && Trigger.isDelete) {
        InvoiceLineTriggerHandler.beforeDelete(Trigger.old);
    } else if (Trigger.isBefore) {
        InvoiceLineTriggerHandler.beforeSave(Trigger.new);
    }
}
