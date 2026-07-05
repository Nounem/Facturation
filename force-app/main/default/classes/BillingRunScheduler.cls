public with sharing class BillingRunScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        // The service deliberately performs full validation for each opportunity.
        // A small scope keeps every transaction comfortably inside query limits.
        Database.executeBatch(new BillingDueBatch(Date.today()), 5);
    }
}
