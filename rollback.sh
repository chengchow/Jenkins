#!/bin/bash
## 该脚本用于项目回滚
## 该脚本部署在jenkins缓存服务器上
## 回滚只能回滚到上一次发布，上一次之前的发布请手动回滚

help_doc="Usage: $(basename $0) -d jenkins转存目录 -e (prod|dev) -k SSH秘钥 -n 项目名称 -t (war|jar) -x SSH主机 -u SSH用户 -p SSH端口 -h 项目路径 -v 项目用户"

while getopts "d:e:k:n:t:x:u:p:h:v:" arg;do
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
        x)
            SSH_HOST=$OPTARG
        ;;
        u)
            SSH_USER=$OPTARG
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
            echo $help_doc 
            exit 65
        ;;
    esac
done

#规范输入参数

if [ -z $JKS_ROOT ] || [ -z $PROJ_ENV ] || [ -z $SSH_KEY ] || [ -z $PROJ_NAME ] || [ -z $PROJ_TYPE ] || [ -z $SSH_HOST ] || [ -z $SSH_USER ] || [ -z $SSH_PORT ] || [ -z $PROJ_PATH ] || [ -z $PROJ_USER ];then
    echo -e $help_doc 
    exit 66
fi

[ -z $PROJ_GROUP ] && PROJ_GROUP=$PROJ_USER
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
APP=${PROJ_NAME}.${PROJ_TYPE}
STATUS_FILE=$JKS_ROOT/$PROJ_ENV/$PROJ_NAME/rollback.status

if [ $PROJ_TYPE = 'jar' ];then
    PRE_PROJ_LIST="-f $PROJ_PATH/$APP"
elif [ $PROJ_TYPE = 'war' ];then
    PROJ_PATH=$PROJ_PATH/webapps
    PRE_PROJ_LIST="-rf $PROJ_PATH/$APP $PROJ_PATH/$PROJ_NAME"
else
    echo "项目类型只能是(war|jar). "
    exit 69
fi


if [ ! -f $STATUS_FILE ];then
    echo -e "在主机${SSH_HOST}未发现回滚标识文件，请手动回滚!!!!!!"
    exit 70
else
    STATUS=$(cat $STATUS_FILE)
fi

if [ $STATUS = 1 ];then
    SSH_COMM="sudo /etc/init.d/$PROJ_NAME stop"
    echo -en "正在主机${SSH_HOST}上关闭项目服务 ...... "
    remote_comm_exec "$SSH_COMM"

    SSH_COMM="/bin/rm $PRE_PROJ_LIST"
    echo -en "正在主机${SSH_HOST}上清理之前的项目文件 ...... "
    remote_comm_exec "$SSH_COMM"

    SSH_COMM="if [ -f $BACKUP_PATH/$APP ];then
                   /bin/cp -f $BACKUP_PATH/$APP $PROJ_PATH/$APP && echo 0 > $(dirname $BACKUP_PATH)/rollback.status
               else
                   exit 1
               fi
              "
    echo -en "正在主机${SSH_HOST}上回滚项目文件 ...... "
    remote_comm_exec "$SSH_COMM"

    SSH_COMM="sudo chown -R $PROJ_USER:$PROJ_GROUP $PROJ_PATH"
    echo -en "正在主机${SSH_HOST}上处理项目文件权限 ...... "
    remote_comm_exec "$SSH_COMM"

    SSH_COMM="sudo /etc/init.d/$PROJ_NAME start"
    echo -en "正在主机${SSH_HOST}上启动项目 ...... "
    remote_comm_exec "$SSH_COMM"
    
    SSH_COMM="sudo /sbin/chkconfig $PROJ_NAME on"
    echo -en "正在主机${SSH_HOST}上设置项目开机启动 ...... "
    remote_comm_exec "$SSH_COMM"
elif [ $STATUS != 0 ];then
    echo -e "主机${SSH_HOST}回滚标识文件内容无法识别, 请手动回滚!!!!!!"
    exit 71
fi

exit 0
