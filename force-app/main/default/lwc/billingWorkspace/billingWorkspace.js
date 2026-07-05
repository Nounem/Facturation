import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import load from '@salesforce/apex/BillingWorkspaceController.load';
import createQuoteFromOpportunity from '@salesforce/apex/BillingWorkspaceController.createQuoteFromOpportunity';
import createInvoiceFromOpportunity from '@salesforce/apex/BillingWorkspaceController.createInvoiceFromOpportunity';
import convertQuoteToInvoice from '@salesforce/apex/BillingWorkspaceController.convertQuoteToInvoice';
import createCreditNote from '@salesforce/apex/BillingWorkspaceController.createCreditNote';
import issueInvoice from '@salesforce/apex/BillingWorkspaceController.issueInvoice';
import generateInvoicePdf from '@salesforce/apex/InvoicePdfController.generateAndAttach';
import prepareElectronicInvoice from '@salesforce/apex/BillingWorkspaceController.prepareElectronicInvoice';

const INVOICE_STATUS_LABELS = {
    Draft: 'Brouillon',
    Issued: 'Émise',
    Sent: 'Envoyée',
    PartiallyPaid: 'Partiellement payée',
    Paid: 'Payée',
    Credited: 'Annulée par avoir',
    PartiallyCredited: 'Partiellement créditée'
};

const QUOTE_STATUS_LABELS = {
    Draft: 'Brouillon',
    'Needs Review': 'À vérifier',
    'In Review': 'En vérification',
    Approved: 'Approuvé',
    Rejected: 'Rejeté',
    Presented: 'Présenté',
    Accepted: 'Accepté',
    Denied: 'Refusé'
};

export default class BillingWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    quotes = [];
    invoices = [];
    opportunityName;
    errorMessage;
    searchTerm = '';
    activeView = 'quotes';
    lastUpdatedLabel;
    isLoading = false;
    isRefreshing = false;
    requestSequence = 0;
    currencyCode = 'EUR';

    connectedCallback() {
        this.refresh();
    }

    get hasRecord() {
        return Boolean(this.recordId);
    }

    get isBusy() {
        return this.isLoading || this.isRefreshing;
    }

    get isQuotesActive() {
        return this.activeView === 'quotes';
    }

    get isInvoicesActive() {
        return this.activeView === 'invoices';
    }

    get quotesTabClass() {
        return `view-tab${this.isQuotesActive ? ' active' : ''}`;
    }

    get invoicesTabClass() {
        return `view-tab${this.isInvoicesActive ? ' active' : ''}`;
    }

    get quoteCount() {
        return this.quotes.length;
    }

    get acceptedQuoteCount() {
        return this.quotes.filter((quote) => quote.Status === 'Accepted').length;
    }

    get invoiceCount() {
        return this.invoices.filter((invoice) => invoice.DocumentType__c !== 'CreditNote').length;
    }

    get billingDocumentCount() {
        return this.invoices.length;
    }

    get outstandingBalance() {
        return this.invoices.reduce((total, invoice) => total + (invoice.BalanceDue__c || 0), 0);
    }

    get filteredQuotes() {
        return this.filterRecords(this.quotes, ['displayNumber', 'Name', 'statusLabel']);
    }

    get filteredInvoices() {
        return this.filterRecords(this.invoices, ['displayNumber', 'statusLabel']);
    }

    get hasFilteredQuotes() {
        return this.filteredQuotes.length > 0;
    }

    get hasFilteredInvoices() {
        return this.filteredInvoices.length > 0;
    }

    get hasSearchTerm() {
        return Boolean(this.searchTerm.trim());
    }

    get quoteEmptyTitle() {
        return this.searchTerm ? 'Aucun devis trouvé' : 'Aucun devis pour cette opportunité';
    }

    get invoiceEmptyTitle() {
        return this.searchTerm ? 'Aucune facture trouvée' : 'Aucune facture pour cette opportunité';
    }

    get searchPlaceholder() {
        return this.isQuotesActive ? 'Rechercher un devis…' : 'Rechercher une facture…';
    }

    async refresh({ showSpinner = true } = {}) {
        if (!this.recordId) return;

        const requestId = ++this.requestSequence;
        if (showSpinner) this.isLoading = true;
        else this.isRefreshing = true;
        this.errorMessage = undefined;

        try {
            const data = await load({ opportunityId: this.recordId });
            if (requestId !== this.requestSequence) return;

            this.opportunityName = data.opportunityName;
            this.quotes = (data.quotes || []).map((quote) => this.decorateQuote(quote));
            this.invoices = (data.invoices || []).map((invoice) => this.decorateInvoice(invoice));
            this.lastUpdatedLabel = new Intl.DateTimeFormat('fr-FR', {
                hour: '2-digit',
                minute: '2-digit'
            }).format(new Date());
        } catch (error) {
            this.handleError(error);
        } finally {
            if (requestId === this.requestSequence) {
                this.isLoading = false;
                this.isRefreshing = false;
            }
        }
    }

    decorateQuote(quote) {
        return {
            ...quote,
            displayNumber: quote.QuoteNumber || quote.Name,
            statusLabel: QUOTE_STATUS_LABELS[quote.Status] || quote.Status,
            statusClass: this.statusClass(quote.Status),
            displayTotal: quote.TotalIncludingTax__c ?? quote.TotalPrice ?? 0,
            canConvert: quote.Status === 'Accepted'
        };
    }

    decorateInvoice(invoice) {
        const sourceLabels = {
            Quote: 'Issue d’un devis',
            Direct: 'Facture directe',
            Scheduled: 'Facturation planifiée'
        };
        const isCreditNote = invoice.DocumentType__c === 'CreditNote';
        const creditedAmount = invoice.CreditedAmount__c || 0;
        return {
            ...invoice,
            displayNumber: invoice.InvoiceNumber__c || invoice.Name,
            statusLabel: INVOICE_STATUS_LABELS[invoice.Status__c] || invoice.Status__c,
            statusClass: this.statusClass(invoice.Status__c),
            sourceLabel: isCreditNote
                ? `Avoir sur ${invoice.OriginalInvoice__r?.InvoiceNumber__c || 'facture'}`
                : (sourceLabels[invoice.Origin__c] || 'Facture'),
            canIssue: !invoice.IsLocked__c,
            canGenerateDocuments: invoice.IsLocked__c,
            canCreateCreditNote: !isCreditNote && invoice.IsLocked__c &&
                creditedAmount < (invoice.TotalAmount__c || 0)
        };
    }

    statusClass(status) {
        if (['Accepted', 'Approved', 'Paid'].includes(status)) return 'status status-success';
        if (['Rejected', 'Denied'].includes(status)) return 'status status-error';
        if (['Needs Review', 'In Review', 'PartiallyPaid', 'PartiallyCredited'].includes(status)) {
            return 'status status-warning';
        }
        if (['Issued', 'Sent', 'Presented'].includes(status)) return 'status status-info';
        return 'status status-neutral';
    }

    filterRecords(records, fields) {
        const term = this.searchTerm.trim().toLocaleLowerCase('fr-FR');
        if (!term) return records;
        return records.filter((record) =>
            fields.some((field) => String(record[field] || '').toLocaleLowerCase('fr-FR').includes(term))
        );
    }

    handleViewChange(event) {
        this.activeView = event.currentTarget.dataset.view;
        this.searchTerm = '';
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleManualRefresh() {
        this.refresh({ showSpinner: false });
    }

    clearError() {
        this.errorMessage = undefined;
    }

    handleScheduleSaved() {
        this.toast('Planification enregistrée', 'La règle de facturation de l’opportunité est à jour.', 'success');
        this.refresh({ showSpinner: false });
    }

    handleScheduleError(event) {
        this.handleError(event.detail || event);
    }

    async handleCreateQuote() {
        const quoteId = await this.runAction(
            () => createQuoteFromOpportunity({ opportunityId: this.recordId }),
            'Le devis et ses lignes ont été créés.'
        );
        if (quoteId) this.activeView = 'quotes';
    }

    async handleCreateInvoice() {
        const invoiceId = await this.runAction(
            () => createInvoiceFromOpportunity({ opportunityId: this.recordId }),
            'La facture brouillon et ses lignes ont été créées.'
        );
        if (invoiceId) this.activeView = 'invoices';
    }

    handleOpenQuote(event) {
        this.navigateToRecord(event.currentTarget.dataset.id, 'Quote');
    }

    handleOpenInvoice(event) {
        this.navigateToRecord(event.currentTarget.dataset.id, 'Invoice__c');
    }

    async handleConvertQuote(event) {
        const quoteId = event.currentTarget.dataset.id;
        const invoiceId = await this.runAction(
            () => convertQuoteToInvoice({ quoteId }),
            'La facture brouillon est disponible.'
        );
        if (invoiceId) this.activeView = 'invoices';
    }

    async handleCreateCreditNote(event) {
        const creditNoteId = await this.runAction(
            () => createCreditNote({ invoiceId: event.currentTarget.dataset.id }),
            'L’avoir brouillon est prêt. Contrôlez son motif et ses lignes avant émission.'
        );
        if (creditNoteId) this.activeView = 'invoices';
    }

    async handleIssueInvoice(event) {
        await this.runAction(
            () => issueInvoice({ invoiceId: event.currentTarget.dataset.id }),
            'La facture a été émise et verrouillée.'
        );
    }

    async handleGeneratePdf(event) {
        const invoiceId = event.currentTarget.dataset.id;
        const documentId = await this.runAction(
            () => generateInvoicePdf({ invoiceId }),
            'Le PDF est prêt et va s’ouvrir.'
        );
        if (documentId) {
            this.openFilePreview(documentId);
        }
    }

    async handlePrepareElectronicInvoice(event) {
        await this.runAction(
            () => prepareElectronicInvoice({ invoiceId: event.currentTarget.dataset.id }),
            'La transmission électronique est prête.'
        );
    }

    async runAction(action, successMessage) {
        if (this.isBusy) return null;
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const result = await action();
            await this.refresh({ showSpinner: false });
            this.toast('Terminé', successMessage, 'success');
            return result?.Id || result;
        } catch (error) {
            this.handleError(error);
            return null;
        } finally {
            this.isLoading = false;
            this.isRefreshing = false;
        }
    }

    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName, actionName: 'view' }
        });
    }

    openFilePreview(documentId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: documentId }
        });
    }

    handleError(error) {
        const messages = this.extractErrorMessages(error);
        this.errorMessage = messages.length ? messages.join(' — ') : 'Une erreur est survenue.';
        this.toast('Action impossible', this.errorMessage, 'error');
    }

    extractErrorMessages(error) {
        const messages = [];
        const body = error?.body;
        if (Array.isArray(body)) {
            body.forEach((item) => messages.push(item?.message));
        } else if (body) {
            messages.push(body.message);
            (body.pageErrors || []).forEach((item) => messages.push(item?.message));
            Object.values(body.fieldErrors || {}).forEach((errors) =>
                errors.forEach((item) => messages.push(item?.message))
            );
            (body.output?.errors || []).forEach((item) => messages.push(item?.message));
            Object.values(body.output?.fieldErrors || {}).forEach((errors) =>
                errors.forEach((item) => messages.push(item?.message))
            );
        }
        messages.push(error?.message);
        return [...new Set(messages.filter(Boolean))];
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
