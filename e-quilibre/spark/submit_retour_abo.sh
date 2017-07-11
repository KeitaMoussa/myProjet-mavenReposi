#!/bin/bash
KRBUSER=dco_app_simm
APPDIR=$HOME/scripts/ENEDIS/LINKYQ
COMMONDIR=/home/dco_app/usr

SPARKCONF=$(grep '^spark.' $APPDIR/config/LINKYQ.properties | sed "s/^/--conf /g" | xargs)
mainjar=$(ls -t $APPDIR/lib/retour-abo-enedis-1.63*-jar-with-dependencies.jar | head -1 |awk '{print $1}')


(cat>jaas.conf)<<EOF
KafkaClient {
  com.sun.security.auth.module.Krb5LoginModule required
  doNotPrompt=true
  useTicketCache=false
  useKeyTab=true
  principal="$KRBUSER@$SITE_REALM"
  keyTab="$KRBUSER.keytab"
  serviceName="kafka";
};
EOF

files=$COMMONDIR/conf/hbase-site.xml,$COMMONDIR/conf/hive-site.xml,$COMMONDIR/kerberos/krb5.conf,$HOME/keytabs/$KRBUSER.keytab,/etc/kafka/conf/truststore,jaas.conf
jars=$COMMONDIR/lib/hdfs/HDFSLogger-2.6.0.jar

for f in $APPDIR/config/*.properties
do files="$files,$f"
done


spark-submit $SITE_SPARKOPTS $SPARKCONF \
--jars $jars \
--class fr.edf.dco.kafka2hbase.spark.SparkCopy \
--name retour-enedis-abo \
--master yarn-cluster \
--queue dco_fast \
--conf "spark.executor.extraJavaOptions=-Djava.security.auth.login.config=./jaas.conf" \
--conf "spark.driver.extraJavaOptions=-Djava.security.auth.login.config=./jaas.conf" \
--conf spark.speculation=true \
--conf spark.speculation.interval=30s \
--conf spark.speculation.multiplier=4 \
--conf spark.speculation.quantile=0.75 \
--files $files \
file://$mainjar \
-converter_name  fr.edf.dco.kafka2hbase.converter.RetourAbConverter \
-checkpoint_repository /user/dco_app_simm/work/LINKY/EQUILIBRE \
-auto_offset_reset latest \
-micro_batch_duration $(grep "duration=" $APPDIR/config/LINKYQ.properties | cut -c 10-) \
-brokers $SITE_KAFKA_SECURE \
-topic  $(grep "nomTopic=" $APPDIR/config/LINKYQ.properties | cut -c 10-) \
-zookeeper_list $SITE_ZOOKEEPER \
-code_retour_assimile $(grep "codeRetourAssimile=" $APPDIR/config/LINKYQ.properties | cut -c 20-) \
-inputs_tables  $(grep "inputTables=" $APPDIR/config/LINKYQ.properties | cut -c 13-) \
-columns_families $(grep "columnfamilies=" $APPDIR/config/LINKYQ.properties | cut -c 16-) \
-krb_principal $KRBUSER@$SITE_REALM \
-krb_keytab hdfs://torval/user/$KRBUSER/$KRBUSER.keytab