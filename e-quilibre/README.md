[**Batch Linky Pas Quotidien EDELIA** ]()
## [Description]()   
1. Intégration du flux batch R151 dans HBase contenant les événements relèves Electricité.
2. Intégration du flux batch C15 contenant les événements : modifications contractuelles, changement de compteur… 
3. Rebouchage des trous résiduels et fermés d’index suite à l’insertion précédente des données dans la table HBase cible. 
4. Génération des fichiers XML à fournir pour EDELIA à partir de HBase. 
5. Module de gestion des retours de demandes d’abonnement à ENEDIS (flux R151) pour permettre de prendre en compte le retour d’ENEDIS suite à la demande d’abonnement associée au recueil du Consentement LINKY Quotidien.
6.  Module de retrait automatique des consentements Linky Quotidien  pour permettre de résilier en masse les consentements LINKY QUOTIDIEN dans le cas de l’identification d’une résiliation du contrat de fourniture électrique.              

## [Statut et Historique]()
- Retrait-Consentements-1.63-jar-with-dependencies.jar 
- HiveToHBase-1.63-jar-with-dependencies.jar
- imputation-linky-0.0.16-jar-with-dependencies.jars
- HBaseToXML-1.63-jar-with-dependencies.jar
- retour-abo-enedis-1.59-jar-with-dependencies.jar 

## [Informations sur la chaine]()
- Domaine: MM
- Nom de la chaine:LQ   
- Projet GitLab: http://git@gitlab.dn.edf.fr/dco/e-quilibre.git
- Process métier: PM7009
- Compte applicatif: dco_app_simm
- Répertoire d'installation (frontal) : /home/dco_app_simm/scripts/LINKYQ
- Développeur: larbi-externe.kennouche@edf.fr

## [Sources de données]()
- Table Hive ORC ERDF.R151_PRM_EQUILIBRE
- Topic Kafka pour traitement des retours abonnements ENEDIS 
- Table Hive ORC ERDF.C15_RELEVE_LINKYQ_STG 

## [Dépot des données]()
- Table cible HBase `dco_equilibre:faits_linky_pdl`
- Table cible HBase `dco_equilibre:consentements`
- Répertoire de sortie des fichiers XML `EDF_VRN_EDELIA_LINKY_Q_<dateHeureCreation>_increment_YYYYY.xml`: dco_app_simm/work/LINKYQ
- Répertoire de sortie des fichiers XML compressés en tar.gz :  /user/dacc/staging/out/paas , /user/dacc/archive/out/LINKYQ/[année]

## [Architecture Fonctionnelle]()
- Retrait t automatique des consentements Linky Quotidien  pour permettre de résilier en masse les consentements LINKY QUOTIDIEN dans le cas de l’identification d’une résiliation du contrat de fourniture électrique.    
- Réception quotidienne des flux ENEDIS (dont R151 et C15)
- Intégration des flux ENEDIS dans Hive (via tables de Staging)
- Intégration des flux R151 et C15 dans deux tables de Staging dédiées au flux batch Linky Quotidien
- Traitements SPARK de chargement de la table de fait HBase Linky Quotidien à partir des tables de Staging Hive R151 et C15 dédiées.
- Traitements SPARK d’enrichissement du flux et de génération/déploiement XML pour ENEDIA :
  - Chargement des données nécessaires de la table de faits HBase dans un DataFrame
  -	Filtrage des données via la table des Consentements
  - Application de l’algorithme de bouchage de trou sur les données sélectionnées
  - Alimentation de la table de faits HBase avec les données issues du bouchage de trou
  -	Constitution des fichiers XML cibles à destination d’EDELIA (+ compression .tar.gz)
   
- Prise en charge des archives des fichiers XML cibles via WebHDFS par le PAAS
- Exposition d’une archive globale des archives des fichiers XML à EDELIA par l’intermédiaire de PEPSIS  
- Gestion des retours de demandes d’abonnement à ENEDIS (flux R151) pour permettre de prendre en compte le retour d’ENEDIS suite à la demande d’abonnement associée au recueil du Consentement LINKY Quotidien.

## [Build]()
- La librairie JAVA est intégrée à l'UDD et construite dans Jenkins :
    - Integration dans HBase et génération des fichiers XML : http://jenkins.dn.edf.fr:8080/view/DCO/job/e-quilibre/
    - Bouchage des trous : http://jenkins.dn.edf.fr:8080/view/DCO/job/equilibre_imputation_linky/ 
 


## [Installation]()
- Depuis le compte Unix dco_app_simm 

```sh 
oou install  http://<user>@gitlab.dn.edf.fr/dco/e-quilibre.git
``` 
## [Lancement du Workflow et Coordinateur oozie]()
  - Workflow pour spark batch linky quotidien:   

```sh 
oou run equilibre-linkyq-Workflow.xml
```
  - Coordinateur  pour spark batch linky quotidien:

```sh
oou deploy equilibre-linkyq-Coordinator.xml
```

   

- lancement de spark streaming pour le traitement des retours abonnement ENEDIS indépendemment du WF:  depuis le frontal de prod dco_app_simm@noeyy5gs [dco_app_simm]


```sh 
/scripts/LINKYQ/spark/submit_retour_abo.sh
```
