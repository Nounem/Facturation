trigger InvoiceTrigger on Invoice__c (before update, before delete) {
    if (Trigger.isUpdate) InvoiceTriggerHandler.protectIssued(Trigger.new, Trigger.oldMap);
    if (Trigger.isDelete) InvoiceTriggerHandler.protectDelete(Trigger.old);
}
