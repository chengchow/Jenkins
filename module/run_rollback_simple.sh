#!/bin/bash

SCRIPTS_PATH=/opt/jenkins/scripts/prod/

$SCRIPTS_PATH/run_rollback.sh						\
-e			prod						\
-n			rms 						\
-t			jar 						\
-j			9013 						\
-x			"10.10.21.77"					\
-y			"10.10.21.77"					\
-Z			"192.168.1.228"
