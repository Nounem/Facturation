# Facturation Salesforce

Application Salesforce native de gestion des devis, factures directes, factures
planifiées et avoirs.

[![Valider ou déployer dans Salesforce](https://img.shields.io/badge/Salesforce-Valider%20ou%20déployer-0B5CAB?logo=salesforce&amp;logoColor=white)](https://github.com/Nounem/Facturation/actions/workflows/deploy.yml)

Le bouton ouvre un workflow GitHub manuel. Il valide d’abord les métadonnées et
les tests sans modifier l’organisation. Le déploiement nécessite ensuite la
confirmation explicite `DEPLOY`.

Si la facturation quotidienne est déjà planifiée, activez auparavant dans
**Setup > Deployment Settings** l’option autorisant les déploiements lorsque des
tâches Apex sont en attente ou en cours.

## Documentation

- [Guide utilisateur](docs/guide-utilisateur.md)
- [Architecture technique](docs/architecture-technique.md)
- [Guide de validation et de déploiement](docs/guide-deploiement.md)
- [Présentation du projet avec notes orateur](docs/presentation.md)
- [Présentation PowerPoint](docs/presentation-facturation-salesforce.pptx)
- [Audit du raccordement Chorus Pro](docs/chorus-pro-audit.md)

Le PowerPoint est éditable et contient les notes orateur. Pour le régénérer :

```bash
python3 -m pip install -r requirements-docs.txt
python3 scripts/generate_presentation.py
```

## Modèle

- Devis : objets standards `Quote` et `QuoteLineItem`.
- Factures et avoirs : `Invoice__c` et `InvoiceLine__c`, avec type de document,
  facture d'origine, motif, numérotation et solde crédité.
- Règles : `BillingRule__c` (ponctuelle, mensuelle, trimestrielle, semestrielle
  ou annuelle ; à échoir ou à terme échu ; échéance et jour de facturation).
- Configuration : `BillingEntity__c`, `TaxRate__c` et `NumberingSequence__c`.
- Paiements : `Payment__c`.
- Facturation électronique : `EInvoiceTransmission__c`, avec routage Chorus Pro
  pour le secteur public et Plateforme Agréée pour les autres flux.

## Déploiement

La procédure recommandée est le
[workflow GitHub avec validation préalable](https://github.com/Nounem/Facturation/actions/workflows/deploy.yml).
La configuration des environnements et du secret est décrite dans le
[guide de déploiement](docs/guide-deploiement.md).

Pour une installation locale contrôlée :

```bash
sf project deploy start --source-dir force-app
sf org assign permset --name Facturation_Admin
sf apex run --file scripts/apex/setup.apex
sf apex run --file scripts/apex/configureBillingRules.apex
sf apex run test --test-level RunLocalTests --wait 20
```

L'organisation Salesforce cible doit avoir la fonctionnalité Quotes activée.

Ajoutez ensuite le composant **Espace devis et factures** à la page Lightning
de l'objet Opportunité. Le script d'initialisation crée une configuration de
démonstration ; renseignez les vraies mentions légales avant toute émission.

## Utilisation

Dans **Espace devis et factures**, le bouton **Facture directe** crée une facture
brouillon et ses lignes sans imposer de devis. Après contrôle, l'action **Émettre**
valide d'abord les données juridiques, attribue le numéro définitif et verrouille
le document ; l'action **PDF** génère ensuite une nouvelle version du fichier
attaché à la facture ou à l'avoir.

Depuis une facture émise, **Créer un avoir** prépare un document brouillon qui
reprend les lignes. Elles peuvent être réduites pour un avoir partiel. L'émission
utilise une séquence `AV`, crédite la facture d'origine et recalcule son statut et
son solde sans modifier le document comptable initial.

Le panneau **Règle et automatisation** permet d'affecter une règle à l'opportunité,
de choisir la prochaine date et d'activer la génération. Le traitement
`Facturation quotidienne` s'exécute à 02:00. Sa clé de génération unique évite
une seconde facture pour la même opportunité et la même échéance.

Le logo, la couleur du PDF et les mentions de règlement se configurent depuis
l'action **Configurer le PDF** de l'entité de facturation.

La livraison du 5 juillet 2026 est protégée par 26 méthodes de test Apex : 100 %
de réussite et 83 % de couverture sur le périmètre applicatif. Le run Salesforce
de référence est `707KB000027XkfR`.

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

Calendrier officiel : réception obligatoire pour toutes les entreprises et
émission pour les grandes entreprises/ETI au 1er septembre 2026 ; émission pour
les PME et micro-entreprises au 1er septembre 2027. Un PDF ordinaire ne constitue
pas à lui seul une facture électronique conforme.
