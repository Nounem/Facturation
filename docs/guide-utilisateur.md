# Guide utilisateur — Facturation Salesforce

Public : commerciaux, gestionnaires de facturation et administrateurs fonctionnels.

## 1. Avant de commencer

Pour créer un document, l’opportunité doit être associée à un compte et contenir
au moins un produit avec quantité et prix. Le compte doit comporter l’adresse de
facturation et, pour une entreprise, son SIREN.

Avant toute première émission, l’administrateur renseigne sur l’entité de
facturation : raison sociale, adresse, SIREN, SIRET, conditions d’escompte,
pénalités de retard, indemnité de recouvrement, logo et couleur du PDF.

## 2. Utiliser l’espace de facturation

Le composant **Espace devis et factures** se trouve sur la page Opportunité. Il
présente les devis, les factures et les avoirs sans rechargement manuel de la
page. La recherche porte sur le numéro, le nom et le statut du document.

Les actions terminées actualisent automatiquement les compteurs et les lignes.
En cas d’échec, le bandeau rouge et le toast affichent le message métier transmis
par Salesforce, y compris le champ obligatoire à corriger.

## 3. Créer un devis

1. Vérifier les produits de l’opportunité.
2. Cliquer **Nouveau devis**.
3. Ouvrir le devis créé pour contrôler les lignes, remises et taux de TVA.
4. Faire évoluer son statut selon le processus commercial.
5. Passer le devis au statut **Accepté** avant de cliquer **Facturer**.

Une seconde tentative de conversion du même devis retourne la facture existante
et ne crée pas de doublon.

## 4. Créer une facture sans devis

1. Cliquer **Facture directe** depuis l’opportunité.
2. Ouvrir le brouillon et contrôler le client, les dates et les lignes.
3. Corriger les données sources ou le brouillon si nécessaire.
4. Cliquer **Émettre**.

L’émission effectue les contrôles légaux, attribue le numéro définitif et
verrouille le document. Aucun numéro n’est consommé lorsque les contrôles échouent.

## 5. Générer le PDF

Le bouton **PDF** est disponible après émission. Il génère un fichier Salesforce
Files et ouvre son aperçu. Une nouvelle génération ajoute une version au fichier
existant au lieu de créer plusieurs pièces jointes portant le même numéro.

Le logo et la couleur se configurent avec l’action **Configurer le PDF** depuis
l’entité de facturation.

## 6. Corriger une facture par avoir

Une facture émise n’est jamais modifiée. Pour la corriger :

1. cliquer **Créer un avoir** sur la facture concernée ;
2. ouvrir le brouillon d’avoir ;
3. renseigner ou confirmer le motif ;
4. conserver toutes les lignes pour un avoir complet, ou réduire les quantités
   et supprimer les lignes non concernées pour un avoir partiel ;
5. cliquer **Émettre**, puis **PDF**.

L’avoir reçoit un numéro `AV-AAAA-NNNNN`. La facture d’origine conserve son
historique et passe à **Partiellement créditée** ou **Annulée par avoir**. Le
montant restant à encaisser est recalculé automatiquement.

## 7. Enregistrer un paiement

Créer le paiement depuis la facture émise en renseignant le montant, la date, le
mode et la référence bancaire. Le total payé, le solde et le statut de facture
sont recalculés. Un paiement ne peut pas être enregistré sur un avoir.

## 8. Planifier une facturation

Dans **Règle et automatisation** :

1. sélectionner une règle ;
2. renseigner la prochaine date ;
3. activer la génération ;
4. enregistrer.

Le traitement **Facturation quotidienne** s’exécute à 02:00. Après un succès, la
prochaine date est calculée. Une clé unique empêche deux factures pour la même
opportunité et la même échéance. Une erreur est enregistrée sur l’opportunité et
n’empêche pas le traitement des autres dossiers.

## 9. Comprendre les principaux statuts

| Statut | Signification |
|---|---|
| Brouillon | Document modifiable, sans numéro définitif |
| Émise | Document numéroté et verrouillé |
| Partiellement payée | Un règlement inférieur au solde a été enregistré |
| Payée | Le solde restant est nul |
| Partiellement créditée | Une partie de la facture a été corrigée par avoir |
| Annulée par avoir | La totalité de la facture a été créditée |

## 10. Facturation électronique

**Préparer la e-facture** génère le document et une transmission traçable. Les
clients publics sont orientés vers Chorus Pro et les clients privés vers une
Plateforme Agréée.

Cette action ne réalise pas encore l’envoi externe. Le raccordement OAuth/PISTE,
le contrat API et la conformité EN 16931/Factur-X doivent être validés avant une
utilisation réelle.

Au 1er septembre 2026, toutes les entreprises doivent pouvoir recevoir des
factures électroniques ; les grandes entreprises et ETI doivent aussi les
émettre. L’émission devient obligatoire pour les PME et micro-entreprises au
1er septembre 2027. Un PDF ordinaire, même généré par l’application, ne suffit
pas à satisfaire cette obligation sans transmission par une Plateforme Agréée.

## 11. Résoudre une émission refusée

Lire le message complet du toast, corriger chaque donnée citée puis relancer
l’émission. Les causes les plus courantes sont :

- SIREN ou SIRET absent ou mal formé ;
- adresse client incomplète ;
- mentions de paiement absentes sur l’entité ;
- date de prestation ou catégorie d’opération absente ;
- ligne sans description, quantité positive, prix ou taux de TVA ;
- séquence de numérotation manquante pour l’année courante ;
- montant d’avoir supérieur au montant restant à créditer.
