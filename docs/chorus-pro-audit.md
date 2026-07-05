# Audit du raccordement Chorus Pro

Date de l’audit : 4 juillet 2026.

## Éléments existants dans l’organisation

- Named Credential `ChorusPro`, pointant vers `https://api.chorus-pro.gouv.fr`.
- External Credential `ChorusPro_OAuth`, déclaré avec le protocole `Custom`, sans paramètre d’authentification configuré.
- Custom Metadata `PDP_Config__mdt.ChorusPro`, actif et défini par défaut.
- Services Apex `PdpCalloutService`, `PdpRouterService`, `FacturXXmlBuilder`, `FacturXPdfService` et `FactureStatusPoller`.

## Écarts bloquants avant un envoi réel

1. L’authentification PISTE/OAuth n’est pas complète dans l’External Credential.
2. Le service existant utilise les routes historiques `/cpro/factures/v1/...`; le contrat d’interface doit être rapproché du Swagger et de l’annexe API actuellement habilités dans PISTE.
3. `padSiret()` transforme un SIREN en SIRET par ajout de zéros. Cette valeur n’est pas un SIRET juridique valide et ne doit pas être envoyée.
4. Le générateur existant produit un PDF et un XML CII séparés, pas un PDF/A-3 Factur-X avec XML embarqué.
5. Le payload existant encode directement le XML alors que les flux API récents peuvent exiger une archive `tar.gz`, un checksum et un code interface selon l’API habilitée.
6. Le XML CII doit être validé EN 16931/Factur-X avant tout dépôt réel.

## Décision d’architecture

Le module de facturation prépare et trace actuellement la e-facture sans effectuer de dépôt externe. Le raccordement existant sera réutilisé après validation de l’application PISTE, du compte technique, de l’API réellement souscrite et de ses secrets. Aucun second jeu d’identifiants ne doit être créé.

Références officielles :

- [Spécifications externes Chorus Pro](https://portail.chorus-pro.gouv.fr/aife_documentation?id=kb_article_view&sysparm_article=KB0011471)
- [Raccordement API/OAuth Chorus Pro](https://communaute.chorus-pro.gouv.fr/documentation/connection-to-chorus-pro/)
- [Dépôt et suivi par API G2B](https://portail.chorus-pro.gouv.fr/aife_documentation?id=kb_article_view&sys_kb_id=055f29a13b758350278c8c8aa4e45adf)
