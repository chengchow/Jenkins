#!/bin/bash

##该脚本应用于同步缓存服务器到WEB服务器
##该脚本部署在中转服务器

help_doc="Usage: publish.sh -d jenkins转存目录 -e (prod|dev) -k SSH秘钥 -n 项目名称 -t (war|jar) -u SSH用户 -x SSH主机名 -p SSH端口 -h 项目路径 -v 项目用户"

while getopts "d:e:k:n:t:u:x:p:h:v:" arg;do
    case $arg in
        d)
            JKS_ROOT=$OPTARG
        ;;
        e)
            PROJ_ENV=$OPTARG
        ;;
        k)
            SSH_KEY=$OPTARG
        ;;
        n)
            PROJ_NAME=$OPTARG
        ;;
        t)
            PROJ_TYPE=$OPTARG
        ;;
        u)
            SSH_USER=$OPTARG
        ;;
        x)
            SSH_HOST=$OPTARG
        ;;
        p)
            SSH_PORT=$OPTARG        
        ;;
        h)
            PROJ_PATH=$OPTARG
        ;;
        v)  
            PROJ_USER=$OPTARG
        ;;
        *)
            echo -e $help_doc
            exit 65
        ;;
    esac
done

##定义常量参数
# [ -z $JKS_ROOT ] && JKS_ROOT=/opt/jenkins/

##规范输入参数
if [ -z $PROJ_ENV ] || [ -z $PROJ_NAME ] || [ -z $SSH_USER ] || [ -z $SSH_HOST ] ||[ -z $PROJ_PATH ] || [ -z $PROJ_TYPE ] || [ -z $PROJ_USER ] || [ -z $SSH_KEY ] || [ -z $SSH_PORT ];then
    echo -e $help_doc 
    exit 66
fi

PROJ_GROUP=$PROJ_USER
TMP_PATH=$JKS_ROOT/$PROJ_ENV/$PROJ_NAME/tmp
BACKUP_PATH=$JKS_ROOT/$PROJ_ENV/$PROJ_NAME/backup

remote_comm_exec (){
    TIME=$(date +%s)
    [ ! -z "$1" ] && $SSH_LOGN "$1" >/dev/null || exit 67
    RETURN=$?
    END_TIME=$(date +%s)
    let DIFF_TIME=$END_TIME-$TIME
    if [ $RETURN = 0 ];then
        echo -e "[ 成功 ]\n耗时: $DIFF_TIME(s)"
    else
        echo -e "[ 失败 ]"
        exit 68
    fi
}

SSH_LOGN="/usr/bin/ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p$SSH_PORT $SSH_USER@$SSH_HOST"
NOW_TIME=$(date +%Y-%m-%d_%H-%M-%S)
APP=${PROJ_NAME}.${PROJ_TYPE}

if [ $PROJ_TYPE = 'jar' ];then
    PRE_PROJ_LIST="-f $PROJ_PATH/$APP"
elif [ $PROJ_TYPE = 'war' ];then
    PROJ_PATH=$PROJ_PATH/webapps
    PRE_PROJ_LIST="-rf $PROJ_PATH/$APP $PROJ_PATH/$PROJ_NAME"
else
    echo "项目类型只能是(war|jar). "
    exit 69
fi

SSH_COMM="sudo mkdir -p $BACKUP_PATH"
echo -en "正在创建项目备份目录 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="sudo chown -R $SSH_USER:$SSH_GROUP $JKS_ROOT"
echo -en "正在修改jenkins缓存目录权限 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="
    [ -f $BACKUP_PATH/$APP ] && /bin/mv -f $BACKUP_PATH/$APP $BACKUP_PATH/${APP}-${NOW_TIME}
    echo 0 > $(dirname $BACKUP_PATH)/rollback.status
"
echo -en "正在创建回滚标识文件 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="
    if [ -f $PROJ_PATH/$APP ];then
        /bin/cp -f $PROJ_PATH/$APP $BACKUP_PATH/$APP && echo 1 > $(dirname $BACKUP_PATH)/rollback.status
    fi
"
echo -en "正在备份之前项目文件 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="sudo /etc/init.d/$PROJ_NAME stop"
echo -en "正在关闭项目服务 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="/bin/rm $PRE_PROJ_LIST"
echo -en "正在清理之前的项目文件 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="type rsync > /dev/null 2>&1 || sudo /bin/yum -y install rsync"
echo -en "正在安装rsync插件 ...... "
remote_comm_exec "$SSH_COMM"

echo -en "正在上传项目文件 ...... "
TIME=$(date +%s)
/usr/bin/rsync -arqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $TMP_PATH/target/*.$PROJ_TYPE $SSH_USER@$SSH_HOST:$PROJ_PATH/$APP > /dev/null
if [ `echo $?` = 0 ];then
    echo -e "[ 成功 ]"
else
    echo -e "[ 失败 ]"
    exit 70
fi
END_TIME=$(date +%s)
let DIFF_TIME=$END_TIME-$TIME
echo -e "耗时: $DIFF_TIME(s)"

SSH_COMM="sudo chown -R $PROJ_USER:$PROJ_GROUP $PROJ_PATH"
echo -en "正在处理项目文件权限 ...... "
remote_comm_exec "$SSH_COMM"

SSH_COMM="sudo /etc/init.d/$PROJ_NAME start"
echo -en "正在启动项目 ...... "
#$SSH_LOGN "$SSH_COMM"
remote_comm_exec "$SSH_COMM"

SSH_COMM="sudo /sbin/chkconfig $PROJ_NAME on"
echo -en "正在设置项目开机启动 ...... "
remote_comm_exec "$SSH_COMM"
