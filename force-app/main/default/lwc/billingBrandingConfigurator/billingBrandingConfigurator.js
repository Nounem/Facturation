import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfig from '@salesforce/apex/BillingBrandingController.getConfig';
import selectLogo from '@salesforce/apex/BillingBrandingController.selectLogo';
import savePrimaryColor from '@salesforce/apex/BillingBrandingController.savePrimaryColor';
import clearLogo from '@salesforce/apex/BillingBrandingController.clearLogo';

export default class BillingBrandingConfigurator extends LightningElement {
    _recordId;
    config = { entityName: 'cette entité', primaryColor: '#0B5CAB' };
    primaryColor = '#0B5CAB';
    isLoading = true;

    @api
    set recordId(value) {
        this._recordId = value;
        if (value) this.loadConfig();
    }

    get recordId() {
        return this._recordId;
    }

    get hasLogo() {
        return Boolean(this.config?.logoDocumentId);
    }

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg'];
    }

    async loadConfig() {
        this.isLoading = true;
        try {
            this.applyConfig(await getConfig({ billingEntityId: this.recordId }));
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleColorChange(event) {
        this.primaryColor = event.target.value.toUpperCase();
    }

    async handleSaveColor() {
        this.isLoading = true;
        try {
            const config = await savePrimaryColor({
                billingEntityId: this.recordId,
                primaryColor: this.primaryColor
            });
            this.applyConfig(config);
            this.toast('Identité visuelle mise à jour.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFinished(event) {
        const documentId = event.detail.files?.[0]?.documentId;
        if (!documentId) return;
        this.isLoading = true;
        try {
            this.applyConfig(await selectLogo({
                billingEntityId: this.recordId,
                contentDocumentId: documentId
            }));
            this.toast('Logo sélectionné pour les prochains PDF.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleClearLogo() {
        this.isLoading = true;
        try {
            this.applyConfig(await clearLogo({ billingEntityId: this.recordId }));
            this.toast('Logo retiré de la configuration PDF.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    applyConfig(config) {
        this.config = config;
        this.primaryColor = config.primaryColor;
    }

    showError(error) {
        this.toast(error?.body?.message || error?.message || 'Une erreur est survenue.', 'error');
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Configuration PDF', message, variant }));
    }
}
