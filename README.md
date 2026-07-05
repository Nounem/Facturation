# Facturation Salesforce

Application Salesforce native de gestion des devis et factures.

## Modèle

- Devis : objets standards `Quote` et `QuoteLineItem`.
- Factures : `Invoice__c` et `InvoiceLine__c`.
- Configuration : `BillingEntity__c`, `TaxRate__c` et `NumberingSequence__c`.
- Paiements : `Payment__c`.
- Facturation électronique : `EInvoiceTransmission__c`, avec routage Chorus Pro
  pour le secteur public et Plateforme Agréée pour les autres flux.

## Déploiement

```bash
sf project deploy start --source-dir force-app
sf org assign permset --name Facturation_Admin
sf apex run --file scripts/apex/setup.apex
sf apex run test --test-level RunLocalTests --wait 20
```

L'organisation Salesforce cible doit avoir la fonctionnalité Quotes activée.

Ajoutez ensuite le composant **Espace devis et factures** à la page Lightning
de l'objet Opportunité. Le script d'initialisation crée une configuration de
démonstration ; renseignez les vraies mentions légales avant toute émission.

## Facturation électronique

Renseignez sur chaque compte le type de destinataire et son SIRET. Les champs
Chorus (numéro d'engagement, code service et cadre de facturation) sont copiés
du devis vers la facture. L'action **Préparer la e-facture** crée le PDF et une
transmission traçable.

Le dépôt API n'est volontairement pas activé tant que le raccordement PISTE,
le compte technique et le contrat d'interface ne sont pas validés. L'organisation
contient déjà une première infrastructure Chorus Pro ; son audit et les écarts
à corriger sont documentés dans [docs/chorus-pro-audit.md](docs/chorus-pro-audit.md).
Le connecteur final réutilisera ces credentials après sécurisation, Chorus Pro
pour le secteur public et la Plateforme Agréée retenue pour le B2B privé.
