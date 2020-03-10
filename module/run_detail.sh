#!/bin/bash

SCRIPTS_PATH=/opt/jenkins/scripts/prod/

$SCRIPTS_PATH/run.sh							\
-d		/opt/jenkins						\
-e		prod							\
-k              /opt/jenkins/scripts/prod/keys/jenkins.ppk      	\
-n		uenrms							\
-t		war							\
-j		8280							\
-x		"10.10.21.77"						\
-y		"10.10.21.77"						\
-u              uenpay                                          	\
-p              22                                              	\
-h              /opt/software/tomcat-uenrms				\
-v              uenpay                                          	\
-Z		"192.168.1.228"						\
-U		uenpay							\
-P		22							\
-F              /data/software/nginx/conf/vhost/ups_stream_list.conf	\
-L              uenrms_8280						\
-D		git@10.10.21.100:operations/conf/daemon.git		\
-C		git@10.10.21.100:operations/conf/prod1.git
