#!/bin/bash


. profil.tarGz_file.sh

. include.oozie.sh
. include.commun.sh
. include.logging.sh

fin()
{
       rm  *.stdout
       archiveLOG
       exit 0
}

DT=$(date +%Y%m%d%H%M%S)
IDXTAR=1

if [ $# -ne 6 ]
then
       echo "ERROR: 6 parametres attendus" >&2
       addLogError "M0001" "ERREUR LORS DE LANCEMENT DE SCRIPT "
       exit 1
fi

INPUT_HDFS_PATH=$1 #/user/dco_app_simm/work/ENEDIS/LINKYQ/tmp
PAAS_PATH=$2 #/user/dacc/staging/out/paas
ARCHIVE_PATH=$3 #/user/dacc/archive/out/LINKYQ/2017
PREFIX_FILE=$4 #EDF_VRN_EDELIA_LINKY_Q_
XML_SIZE=$5 #3000
BATCH_SIZE=$6 #1000


LOCAL_WORKDIR=./tmpeq #local work dir on any worker
NB_PRM=0
NB_XML=0
NB_TAR=0


addLogInfo "M0001" "TEST DE L'EXISTENCE DU REPERTOIRE $INPUT_HDFS_PATH"
hadoop fs -test -d $INPUT_HDFS_PATH &> "$STDOUT__"
if [[ $? -ne 0 ]]
then
        addLogError "M0001" "LE REPERTOIRE $INPUT_HDFS_PATH N'EXISTE PAS."
        echo "error_message=le repertoire $INPUT_HDFS_PATH n existe pas" >&2
        echo "last_hadoop_command= hadoop fs -test -d" >&2

        fin
fi

addLogInfo "M0002" "TEST DE L'EXISTENCE DU REPERTOIRE PAAS  $PAAS_PATH"
hadoop fs -test -d $PAAS_PATH &> "$STDOUT__"
if [[ $? -ne 0 ]]
then
        addLogError "M0002" "LE REPERTOIRE PAAS $PAAS_PATH N'EXISTE PAS."
        echo "error_message=le repertoire PAAS $PAAS_PATH n existe pas" >&2
        echo "last_hadoop_command= hadoop fs -test -d" >&2
        fin
fi

addLogInfo "M0003" "TEST DE L'EXISTENCE DU REPERTOIRE ARCHIVE  $ARCHIVE_PATH"
hadoop fs -test -d $ARCHIVE_PATH &> "$STDOUT__"
if [[ $? -ne 0 ]]
then
        addLogError "M0003" "LE REPERTOIRE ARCHIVE $ARCHIVE_PATH N'EXISTE PAS."
        echo "error_message=le repertoire ARCHIVE $ARCHIVE_PATH n'existe pas" >&2
        echo "last_hadoop_command= hadoop fs -test -d" >&2
        fin
fi


addLogInfo "M0004" "TEST DE L'EXISTENCE DE FICHIERS DANS LE REPERTOIRE $INPUT_HDFS_PATH"
fichiers=`hadoop fs -ls $INPUT_HDFS_PATH/ | awk '{print $8}'`
 if [[ $fichiers != *\.xml ]]
        then
              addLogWarning "M0004" "LE REPERTOIRE $INPUT_HDFS_PATH est vide ou pas de fichier .xml "
              echo "Warning_message=le repertoire $INPUT_HDFS_PATH est vide ou pas de fichier .xml" >&2
        else
        addLogInfo "M0004" "COMPRESSION des fichiers qui sont dans $INPUT_HDFS_PATH et envoi dans $ARCHIVE_PATH et $PAAS_PATH"
        addLogInfo "M0004" "RECUPERATION DES FICHIERS data CONTENUS DANS $INPUT_HDFS_PATH"

        if [ ! -d $LOCAL_WORKDIR ]
        then
            mkdir $LOCAL_WORKDIR
        else
            rm -rf $LOCAL_WORKDIR/*
        fi
        hadoop fs -get $INPUT_HDFS_PATH/* $LOCAL_WORKDIR &> "$STDOUT__"

        if [[ $? -ne 0 ]]
        then
                 addLogError "M0004" "ERREUR LORS DE LA RECUPERATION DES FICHIERS DE $INPUT_HDFS_PATH"
                 echo "error_message= erreur lors de la recuperation des fichiers de $INPUT_HDFS_PATH" >&2
                 echo "last_hadoop_command= hadoop fs -get" >&2
        # Il est necessaire d'echapper chaque caractere spéciaux xml pour que le workflow oozie reste valide.
                if [[ -s $STDOUT__ ]]
                   then
                        echo `cat $STDOUT__ | sed -e '1 s/^/command_output=/' -e 's~&~\&amp;~g' -e 's~>~\&gt;~g' -e 's~\"~\&quot;~g' -e "s~'~\&apos;~g"` >&2
                   fi
                   fin
        fi

        cd $LOCAL_WORKDIR

		# recupere les PRM de chaque fichier dans full.xml
		for file in $(ls *.xml)
		do
			cat $file | sed -e "s/<PRM>/\n<PRM>/g" > tmp.xml
			[[ -z $HEADER ]] && HEADER=$(head -1 tmp.xml)
			cat tmp.xml | sed -e "1d" -e '$s/<\/LQ>//' >> full.xml
			echo "" >> full.xml
			rm -f $file
		done
		FOOTER="</LQ>"
		rm -f tmp.xml
		NB_PRM=$(cat full.xml | wc -l)

		split -dl $XML_SIZE full.xml
		rm -f full.xml

		# calcul du nombre de fichiers total
		NB_XML=$(ls x* | wc -l)
		nbcar=$(expr length $NB_XML)
		TOTAL=$NB_XML
		while [ $nbcar -lt 5 ]
		do #completion idx a 5 chiffres
			TOTAL=0$TOTAL
    		nbcar=$(expr $nbcar + 1)
		done

		# reconstruit les fichiers XML de 3000 PRM
		IDXFILE=1
		for x in $(ls x*)
		do
			nbcar=$(expr length $IDXFILE)
			IDXFINAL=$IDXFILE
    		while [ $nbcar -lt 5 ]
    		do #completion idx a 5 chiffres
				IDXFINAL=0$IDXFINAL
        		nbcar=$(expr $nbcar + 1)
    		done

        	#PREFIX=$(echo $x | cut -c1-38) 	# racine du fichier
            #SUFFIX=$(echo $x | cut -c44-53) 	# fin du nom du fichier
            #IDEFIX=$(echo $x | cut -c39-43 | sed -e "s/^0*//") # index du fichier sans les 0

            filename=${PREFIX_FILE}$(date +%Y%m%d%H%M%S)_${IDXFINAL}_${TOTAL}.xml
			echo $HEADER | sed -e "s/<LQ/\n<LQ/" -e "s/<En_Tete_Flux>/\n<En_Tete_Flux>/" > $filename
			cat $x >> $filename
			echo $FOOTER >> $filename

            IDXFILE=$(expr $IDXFILE + 1)
            rm -f $x
		done

		# Generation des tar.gz de 1000 fichiers max
		echo `ls ./*` | sed -e "s/ /\\n/g" | grep $PREFIX_FILE | split -dl $BATCH_SIZE #> ./liste.txt
        #split -dl $BATCH_SIZE ./liste.txt
        NB_TAR=$(ls ./x* | wc -l)
        NBTAR=$NB_TAR
        if [ $(expr length $NBTAR) == 1 ]
        then
        	NBTAR=0$NBTAR
        fi

        for bloc in $(ls x*)
        do
          	if [ $(expr length $IDXTAR) == 1 ]
            then
            	IDXTAR=0$IDXTAR
            fi
          	NOMTAR="${PREFIX_FILE}${DT}_${IDXTAR}_${NBTAR}.tar"

          	tar cvf ./$NOMTAR --files-from /dev/null

          	for xml in $(cat $bloc)
          	do
            	tar -rvf ./$NOMTAR $(basename $xml .xml).xml
          	done
          	gzip ./$NOMTAR
          	IDXTAR=$(expr $IDXTAR + 1)
          	addLogInfo "M0005" "ENVOIE DES FICHIERS tar.gz  DANS $PAAS_PATH et $ARCHIVE_PATH"
          	hdfs dfs -put ./$NOMTAR.gz $PAAS_PATH &> "$STDOUT__"
          	hdfs dfs -put ./$NOMTAR.gz $ARCHIVE_PATH &> "$STDOUT__"
          	if [[ $? -ne 0 ]]
            then
            	addLogError "M0004" "ERREUR LORS DE L'envoie DES FICHIERS Dans $PAAS_PATH et $ARCHIVE_PATH"
                echo "error_message= ERREUR LORS DE L'envoie DES FICHIERS Dans $PAAS_PATH et $ARCHIVE_PATH" >&2
                echo "last_hadoop_command= hadoop fs -put" >&2
            fi
		done

		# Cleaning
		addLogInfo "M0004" "suppression des fichiers xml dans  $INPUT_HDFS_PATH"
        hadoop fs -rm $INPUT_HDFS_PATH/* &> "$STDOUT__"

        if [[ $? -ne 0 ]]
        then
                addLogError "M0004" "ERREUR LORS DE LA suppression des FICHIERS dans $INPUT_HDFS_PATH"
                echo "error_message= ERREUR LORS DE LA suppression des FICHIERS dans $INPUT_HDFS_PATH" >&2
                echo "last_hadoop_command= hadoop fs -rm" >&2
        		# Il est necessaire d'echapper chaque caractere spéciaux xml pour que le workflow oozie reste valide.
                if [[ -s $STDOUT__ ]]
                then
                	echo `cat $STDOUT__ | sed -e '1 s/^/command_output=/' -e 's~&~\&amp;~g' -e 's~>~\&gt;~g' -e 's~\"~\&quot;~g' -e "s~'~\&apos;~g"` >&2
                fi
                fin
        fi

fi


addLogInfo "M0006" "TRAITEMENT TERMINE. le repertoire $path_out est � jour"
addLogInfo "SUIVI" "PRM=$NB_PRM, XML=$NB_XML, TAR=$NB_TAR"

# oozie capture-output
echo "PRM=$NB_PRM"
echo "XML=$NB_XML"
echo "TAR=$NB_TAR"

fin