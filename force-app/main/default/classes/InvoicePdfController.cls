public with sharing class InvoicePdfController {
    public Invoice__c invoice { get; private set; }
    public String primaryColor { get; private set; }
    public String logoUrl { get; private set; }
    public List<TaxSummary> taxSummaries { get; private set; }
    public List<InvoiceLineView> lineViews { get; private set; }

    public Boolean getHasLogo() {
        return String.isNotBlank(logoUrl);
    }

    public Date getServiceDate() {
        return invoice.ServiceDate__c == null ? invoice.IssueDate__c : invoice.ServiceDate__c;
    }

    public String getOperationCategoryLabel() {
        if (invoice.OperationCategory__c == 'Goods') return 'Livraisons de biens';
        if (invoice.OperationCategory__c == 'Mixed') return 'Livraisons de biens et prestations de services';
        return 'Prestations de services';
    }

    public Boolean getHasBillingPeriod() {
        return invoice.BillingPeriodStart__c != null && invoice.BillingPeriodEnd__c != null;
    }

    public String getOriginLabel() {
        if (invoice.DocumentType__c == 'CreditNote') return 'Avoir client';
        if (invoice.Origin__c == 'Quote') return 'Issue d’un devis accepté';
        if (invoice.Origin__c == 'Scheduled') return 'Facturation planifiée';
        return 'Facture directe';
    }

    public String getDocumentTitle() {
        return invoice.DocumentType__c == 'CreditNote' ? 'AVOIR' : 'FACTURE';
    }

    public String getCustomerBlockLabel() {
        return invoice.DocumentType__c == 'CreditNote' ? 'Client concerné' : 'Facturé à';
    }

    public String getGrandTotalLabel() {
        return invoice.DocumentType__c == 'CreditNote' ? 'Total de l’avoir' : 'Total TTC';
    }

    public String getSettlementLabel() {
        return invoice.DocumentType__c == 'CreditNote' ? 'Effet de l’avoir' : 'Règlement';
    }

    public String getSettlementTitle() {
        if (invoice.DocumentType__c == 'CreditNote') {
            return 'Montant porté au crédit du client : ' + getTotalLabel();
        }
        return 'À régler au plus tard le ' + formatDate(invoice.DueDate__c);
    }

    public String getSubtotalLabel() { return formatMoney(invoice.Subtotal__c); }
    public String getTotalLabel() { return formatMoney(invoice.TotalAmount__c); }
    public String getRecoveryFeeLabel() {
        return formatMoney(invoice.BillingEntity__r.RecoveryFeeAmount__c);
    }
    public String getShareCapitalLabel() {
        return formatMoney(invoice.BillingEntity__r.ShareCapital__c);
    }

    public InvoicePdfController(ApexPages.StandardController controller) {
        Id invoiceId = controller.getId();
        invoice = [
            SELECT Id, InvoiceNumber__c, IssueDate__c, DueDate__c, Origin__c,
                   DocumentType__c, CreditReason__c,
                   OriginalInvoice__c, OriginalInvoice__r.InvoiceNumber__c,
                   BillingPeriodStart__c, BillingPeriodEnd__c,
                   CustomerName__c, BillingStreet__c, BillingPostalCode__c,
                   BillingCity__c, BillingCountry__c, CustomerRegistrationNumber__c,
                   CustomerTaxId__c, ServiceDate__c, OperationCategory__c,
                   DeliveryAddress__c, VatOnDebits__c, RecipientType__c,
                   RecipientSiret__c, CommitmentNumber__c, ServiceCode__c,
                   BillingFramework__c,
                   Subtotal__c, TaxAmount__c, TotalAmount__c,
                   BillingEntity__r.Name, BillingEntity__r.LegalForm__c,
                   BillingEntity__r.RegistrationNumber__c, BillingEntity__r.VatNumber__c,
                   BillingEntity__r.Address__c, BillingEntity__r.Email__c,
                   BillingEntity__r.Siret__c, BillingEntity__r.RcsCity__c,
                   BillingEntity__r.ShareCapital__c,
                   BillingEntity__r.PdfPrimaryColor__c,
                   BillingEntity__r.LogoContentDocumentId__c,
                   BillingEntity__r.PaymentInstructions__c,
                   BillingEntity__r.EarlyPaymentTerms__c,
                   BillingEntity__r.LatePaymentPenaltyText__c,
                   BillingEntity__r.RecoveryFeeAmount__c,
                   (SELECT Description__c, Quantity__c, UnitPrice__c,
                           DiscountPercent__c, NetAmount__c, TaxRate__c,
                           TaxAmount__c, GrossAmount__c
                    FROM Lines__r ORDER BY SortOrder__c)
            FROM Invoice__c WHERE Id = :invoiceId
        ];
        primaryColor = safeColor(invoice.BillingEntity__r.PdfPrimaryColor__c);
        logoUrl = resolveLogoUrl(invoice.BillingEntity__r.LogoContentDocumentId__c);
        taxSummaries = buildTaxSummaries(invoice.Lines__r);
        lineViews = buildLineViews(invoice.Lines__r);
    }

    @AuraEnabled
    public static Id generateAndAttach(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('L’identifiant de la facture est requis.');
        }
        BillingSecurity.requireRead(Invoice__c.SObjectType, 'Facture');
        BillingSecurity.requireCreate(ContentVersion.SObjectType, 'Version de fichier');
        BillingSecurity.requireCreate(ContentDocumentLink.SObjectType, 'Lien de fichier');
        BillingSecurity.requireReadableFields(
            new List<Schema.SObjectField>{
                Invoice__c.InvoiceNumber__c,
                Invoice__c.IsLocked__c
            },
            'Facture'
        );
        Invoice__c invoice = [
            SELECT Id, InvoiceNumber__c, IsLocked__c FROM Invoice__c WHERE Id = :invoiceId
        ];
        if (!invoice.IsLocked__c || String.isBlank(invoice.InvoiceNumber__c)) {
            throw new AuraHandledException('La facture doit être émise avant la génération du PDF.');
        }

        Id existingDocumentId;
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :invoice.Id
            ORDER BY SystemModstamp DESC
        ];
        for (ContentDocumentLink link : existingLinks) {
            if (link.ContentDocument.Title == invoice.InvoiceNumber__c &&
                link.ContentDocument.FileType == 'PDF') {
                existingDocumentId = link.ContentDocumentId;
                break;
            }
        }

        try {
            PageReference pageReference = Page.InvoicePdf;
            pageReference.getParameters().put('id', invoice.Id);
            Blob body = Test.isRunningTest()
                ? Blob.valueOf('PDF de test')
                : pageReference.getContentAsPDF();
            if (body == null || body.size() == 0) {
                throw new InvoicePdfException('Le moteur PDF a retourné un document vide.');
            }

            ContentVersion version = new ContentVersion(
                Title = invoice.InvoiceNumber__c,
                PathOnClient = invoice.InvoiceNumber__c + '.pdf',
                VersionData = body,
                ContentDocumentId = existingDocumentId,
                Description = 'PDF de facture généré par Salesforce'
            );
            insert version;
            version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id];
            if (existingDocumentId == null) {
                insert new ContentDocumentLink(
                    ContentDocumentId = version.ContentDocumentId,
                    LinkedEntityId = invoice.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
            }
            return version.ContentDocumentId;
        } catch (Exception error) {
            throw new AuraHandledException('Génération du PDF impossible : ' + error.getMessage());
        }
    }

    private static String safeColor(String value) {
        String color = String.isBlank(value) ? '#0B5CAB' : value.trim().toUpperCase();
        return Pattern.matches('^#[0-9A-F]{6}$', color) ? color : '#0B5CAB';
    }

    private static String resolveLogoUrl(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) return null;
        try {
            ContentDocument document = [
                SELECT LatestPublishedVersionId, FileType
                FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1
            ];
            if (!new Set<String>{ 'PNG', 'JPG', 'JPEG' }.contains(document.FileType)) return null;
            return '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId='
                + EncodingUtil.urlEncode(String.valueOf(document.LatestPublishedVersionId), 'UTF-8');
        } catch (Exception ignored) {
            return null;
        }
    }

    private static List<TaxSummary> buildTaxSummaries(List<InvoiceLine__c> lines) {
        Map<Decimal, TaxSummary> byRate = new Map<Decimal, TaxSummary>();
        for (InvoiceLine__c line : lines) {
            Decimal rate = line.TaxRate__c == null ? 0 : line.TaxRate__c;
            if (!byRate.containsKey(rate)) byRate.put(rate, new TaxSummary(rate));
            byRate.get(rate).taxableAmount += line.NetAmount__c == null ? 0 : line.NetAmount__c;
            byRate.get(rate).taxAmount += line.TaxAmount__c == null ? 0 : line.TaxAmount__c;
        }
        List<Decimal> rates = new List<Decimal>(byRate.keySet());
        rates.sort();
        List<TaxSummary> result = new List<TaxSummary>();
        for (Decimal rate : rates) result.add(byRate.get(rate));
        return result;
    }

    private static List<InvoiceLineView> buildLineViews(List<InvoiceLine__c> lines) {
        List<InvoiceLineView> result = new List<InvoiceLineView>();
        for (InvoiceLine__c line : lines) result.add(new InvoiceLineView(line));
        return result;
    }

    private static String formatMoney(Decimal value) {
        if (value == null) value = 0;
        String raw = String.valueOf(value.setScale(2));
        List<String> parts = raw.split('\\.');
        String integerPart = parts[0];
        Boolean negative = integerPart.startsWith('-');
        if (negative) integerPart = integerPart.substring(1);
        String grouped = '';
        while (integerPart.length() > 3) {
            grouped = ' ' + integerPart.substring(integerPart.length() - 3) + grouped;
            integerPart = integerPart.substring(0, integerPart.length() - 3);
        }
        grouped = (negative ? '-' : '') + integerPart + grouped;
        String decimals = parts.size() > 1 ? parts[1] : '00';
        return grouped + ',' + decimals + ' €';
    }

    private static String formatNumber(Decimal value, Integer scale) {
        if (value == null) value = 0;
        String result = String.valueOf(value.setScale(scale)).replace('.', ',');
        while (result.contains(',') && result.endsWith('0')) result = result.left(result.length() - 1);
        if (result.endsWith(',')) result = result.left(result.length() - 1);
        return result;
    }

    private static String formatDate(Date value) {
        if (value == null) return '';
        String day = value.day() < 10 ? '0' + value.day() : String.valueOf(value.day());
        String month = value.month() < 10 ? '0' + value.month() : String.valueOf(value.month());
        return day + '/' + month + '/' + value.year();
    }

    public class InvoiceLineView {
        public String description { get; set; }
        public String quantityLabel { get; set; }
        public String unitPriceLabel { get; set; }
        public String discountLabel { get; set; }
        public String taxRateLabel { get; set; }
        public String netAmountLabel { get; set; }
        public InvoiceLineView(InvoiceLine__c line) {
            description = line.Description__c;
            quantityLabel = formatNumber(line.Quantity__c, 3);
            unitPriceLabel = formatMoney(line.UnitPrice__c);
            discountLabel = formatNumber(line.DiscountPercent__c, 2) + ' %';
            taxRateLabel = formatNumber(line.TaxRate__c, 2) + ' %';
            netAmountLabel = formatMoney(line.NetAmount__c);
        }
    }

    public class TaxSummary {
        public Decimal rate { get; set; }
        public Decimal taxableAmount { get; set; }
        public Decimal taxAmount { get; set; }
        public String rateLabel { get { return formatNumber(rate, 2) + ' %'; } }
        public String taxAmountLabel { get { return formatMoney(taxAmount); } }
        public TaxSummary(Decimal taxRate) {
            rate = taxRate;
            taxableAmount = 0;
            taxAmount = 0;
        }
    }

    private class InvoicePdfException extends Exception {}
}
