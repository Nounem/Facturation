trigger QuoteLineItemTrigger on QuoteLineItem (
    before insert, before update, after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        QuoteLineTriggerHandler.beforeSave(Trigger.new);
    }
    if (Trigger.isAfter) {
        Set<Id> quoteIds = new Set<Id>();
        if (Trigger.new != null) quoteIds.addAll(QuoteLineTriggerHandler.parentIds(Trigger.new));
        if (Trigger.old != null) quoteIds.addAll(QuoteLineTriggerHandler.parentIds(Trigger.old));
        QuoteLineTriggerHandler.refreshQuotes(quoteIds);
    }
}
