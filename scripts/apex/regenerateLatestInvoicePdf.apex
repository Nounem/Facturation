Invoice__c latestInvoice = [
    SELECT Id FROM Invoice__c
    WHERE IsLocked__c = true
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];
Id documentId = InvoicePdfController.generateAndAttach(latestInvoice.Id);
System.debug('PDF ContentDocumentId : ' + documentId);
