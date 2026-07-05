---
marp: true
theme: default
paginate: true
title: Facturation Salesforce
description: Présentation fonctionnelle et technique du projet
style: |
  section { font-family: Arial, sans-serif; color: #17202e; }
  h1, h2 { color: #0b5cab; }
  strong { color: #0b5cab; }
  table { font-size: 22px; }
---

<!-- _class: lead -->

# Facturation Salesforce

## Du devis à la facture électronique, dans un espace unique

Devis · Facture directe · Récurrence · Avoirs · PDF · Paiements · E-facture

<!--
Notes orateur — 30 secondes
Présenter le projet comme une application native Salesforce conçue pour supprimer
les doubles saisies et couvrir aussi les clients qui facturent sans devis.
-->

---

# Le problème métier

- Les devis et factures sont souvent gérés dans des outils séparés.
- Certains clients ne produisent jamais de devis.
- Les ressaisies créent des erreurs de prix, TVA et adresse.
- La facturation récurrente exige une exécution fiable et traçable.
- Le PDF et la facture électronique ajoutent des contraintes réglementaires.

> Objectif : un parcours simple pour l’utilisateur, contrôlé pour la comptabilité.

<!--
Notes orateur — 45 secondes
Insister sur les deux parcours : vente avec devis et facturation directe. Expliquer
que l’outil doit rester simple sans sacrifier la numérotation ni l’historique.
-->

---

# La solution

| Besoin | Réponse |
|---|---|
| Devis | Objets standards Salesforce |
| Facture sans devis | Action **Facture directe** |
| Récurrence | Règles inspirées de Revenue Cloud |
| Document client | PDF versionné et personnalisable |
| Encaissement | Paiements, solde et statut |
| Correction comptable | Avoir complet ou partiel, sans altérer la facture |
| Secteur public | Préparation du routage Chorus Pro |

<!--
Notes orateur — 50 secondes
Le choix important est de conserver Quote standard mais d’utiliser un modèle de
facture dédié, plus adapté à l’immuabilité et aux données comptables figées.
-->

---

# Une expérience intégrée à l’opportunité

- Indicateurs devis, factures et solde à encaisser.
- Recherche et actions dans une interface Lightning responsive.
- Création puis rafraîchissement immédiat, sans recharger la page.
- Messages d’erreur métier complets dans les toasts.
- Accès direct aux documents et fichiers.

**Une seule page pour le commercial et l’équipe facturation.**

<!--
Notes orateur — 45 secondes
Afficher le composant sur une opportunité. Montrer les deux boutons Nouveau devis
et Facture directe, puis les onglets et les indicateurs.
-->

---

# Trois chemins vers la facture, puis l’avoir

```text
Devis accepté ────────────────┐
                             ├──> Facture brouillon -> Émission -> PDF
Produits de l’opportunité ────┤
                             │
Règle + prochaine date ───────┘

Facture émise ───────────────────> Avoir brouillon -> Émission -> PDF
```

- **Quote** : traçabilité du devis d’origine.
- **Direct** : aucun devis imposé.
- **Scheduled** : génération automatique et contrôlée.

<!--
Notes orateur — 45 secondes
Expliquer que les trois chemins arrivent sur le même modèle de facture. Le cycle
d’émission, PDF et paiement reste donc identique.
-->

---

# Des règles inspirées de Revenue Cloud

- Fréquence : ponctuelle, mensuelle, trimestrielle, semestrielle, annuelle.
- Facturation à échoir ou à terme échu.
- Période civile ou date anniversaire.
- Jour de facturation et délai de paiement.
- Émission automatique facultative.
- Prochaine date calculée après chaque succès.

**Protection anti-doublon :** une clé unique par opportunité et échéance.

<!--
Notes orateur — 60 secondes
Donner un exemple : le 1er juillet, une règle mensuelle à terme échu facture la
période du 1er au 30 juin et place la prochaine date au 1er août.
-->

---

# Une facture juridiquement stable

1. Les informations du client sont copiées sur la facture.
2. Les montants HT, TVA et TTC sont recalculés par le serveur.
3. Le numéro définitif est attribué uniquement à l’émission.
4. La facture émise est verrouillée.
5. Toute correction passe par un avoir numéroté et traçable.
6. Chaque régénération PDF ajoute une version au même fichier.

**Résultat :** historique lisible, numérotation protégée et document reproductible.

<!--
Notes orateur — 50 secondes
Préciser que modifier ensuite l’adresse du compte ne réécrit pas l’ancienne
facture. C’est la raison du snapshot client.
-->

---

# PDF personnalisable

- Logo stocké dans Salesforce Files.
- Couleur principale configurable par entité.
- Coordonnées vendeur et client.
- Dates, période facturée et nature de l’opération.
- Tableau stable des lignes et totaux français.
- Paiement, pénalités, indemnité et mentions légales.
- Bloc de routage Chorus Pro pour le secteur public.
- Mise en page dédiée aux avoirs avec facture d’origine et motif.

<!--
Notes orateur — 40 secondes
Ouvrir une facture émise puis cliquer PDF. Montrer l’aperçu Salesforce Files et
expliquer le versionnement lorsque le document est régénéré.
-->

---

# Facturation électronique

```text
Client public  -> Chorus Pro
Client privé   -> Plateforme Agréée
```

Aujourd’hui :

- création d’une transmission traçable ;
- génération et rattachement du document ;
- statut, fournisseur, référence et erreurs historisés.

Avant production : OAuth PISTE, contrat API, EN 16931 et Factur-X/PDF-A3.

<!--
Notes orateur — 55 secondes
Être transparent : la préparation et le routage sont présents, mais l’envoi réel
reste bloqué tant que la connexion et la conformité ne sont pas certifiées.
-->

---

# Architecture et qualité

- LWC pour l’expérience utilisateur.
- Services Apex pour les règles métier.
- Triggers groupés pour les calculs et agrégations.
- Scheduler + Batch pour la récurrence.
- Visualforce pour le PDF serveur.
- Permission Set unique pour l’administration.
- Contrôles CRUD/FLS aux frontières Lightning.
- Validation des mentions obligatoires avant toute numérotation.
- **26 tests projet réussis à 100 %**, avec environ **83 % de couverture** des
  classes applicatives.

<!--
Notes orateur — 45 secondes
Souligner la séparation interface/service/données. Elle permet de faire évoluer
le LWC ou le connecteur externe sans réécrire les calculs de facture.
-->

---

# Déploiement maîtrisé par GitHub

```text
Commit Git -> Validation sans écriture -> Tests -> Approbation -> Déploiement
```

- Workflow lancé manuellement.
- Secret d’authentification isolé par environnement.
- `VALIDATE` ne modifie jamais l’organisation.
- Le mot `DEPLOY` est obligatoire pour continuer.
- Protection et reviewer supplémentaires pour la production.
- Contrôle Salesforce des jobs Apex actifs avant livraison.

[Ouvrir le workflow](https://github.com/Nounem/Facturation/actions/workflows/deploy.yml)

<!--
Notes orateur — 45 secondes
Montrer que GitHub est la source de vérité. La validation est un garde-fou avant
la production et laisse une trace de la version, des tests et de l’approbation.
-->

---

# Démonstration proposée

1. Ouvrir une opportunité contenant des produits.
2. Créer une facture directe.
3. Vérifier les lignes et émettre la facture.
4. Générer le PDF.
5. Ajouter un paiement et observer le solde.
6. Créer un avoir partiel et observer le nouveau solde.
7. Configurer une règle mensuelle.
8. Montrer l’historique des transmissions électroniques.

**Durée cible : 6 minutes.**

<!--
Notes orateur — 30 secondes
Préparer avant la présentation un compte, une opportunité et deux produits. Éviter
de dépendre d’un appel Chorus réel pendant la démonstration.
-->

---

# Prochaines étapes

### Court terme

- renseigner les vraies mentions juridiques et le logo ;
- recette métier avec la comptabilité ;
- finaliser le raccordement Plateforme Agréée / Chorus Pro.

### Évolutions

- contrats et dates de facturation par ligne ;
- relances et prélèvements ;
- portail client et suivi de paiement.

<!--
Notes orateur — 40 secondes
Conclure sur un socle utilisable immédiatement, avec un périmètre d’évolution
identifié. Ne pas présenter le raccordement externe comme déjà certifié.
-->

---

<!-- _class: lead -->

# Merci

## Questions ?

Documentation : `docs/architecture-technique.md`<br/>
Déploiement : `docs/guide-deploiement.md`

<!--
Notes orateur
Garder ouvertes la page Opportunité, une facture émise et la page GitHub Actions
pour répondre aux questions avec des preuves concrètes.
-->
