#!/bin/bash
## 该脚本用于检测后端服务器端口连接状态
## 该脚本部署在中转服务器

help_doc="Usage: `basename $0` -k SSH秘钥 -x SSH主机名 -u SSH用户 -p SSH端口 -v 检测端口"

while getopts "k:x:u:p:v:" arg;do
    case $arg in
        k)
            SSH_KEY=$OPTARG
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
        v)
            PROJ_PORT=$OPTARG
        ;;
        *)
            echo -e $help_doc
            exit 65
        ;;
    esac
done

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$PROJ_PORT" ] || [ -z $SSH_KEY ] || [ -z $SSH_PORT ];then
    echo -e $help_doc 
    exit 66
fi

SSH_LOGN="/usr/bin/ssh -i $SSH_KEY -o StrictHostKeyChecking=no -p$SSH_PORT $SSH_USER@$SSH_HOST"

while true;do
    NOW_LINK=`$SSH_LOGN "/usr/sbin/ss -nt" | awk -F '[:| ]+' -vp=$PROJ_PORT -vt="ESTAB" 'BEGIN{num=0}$5==p&&$1==t{num++}END{print num}'`

    if [ $NOW_LINK -ne 0 ];then
        echo -e "当前服务器($SSH_HOST)端口(PORT:$PROJ_PORT)有${NOW_LINK}个链接, 发布等待(如果链接一直存在,请手动终止该项目). "
        sleep 5
    else
        echo -e "当前服务器($SSH_HOST)端口(PORT:$PROJ_PORT)有${NOW_LINK}个链接, 发布继续. "
        break
    fi
done

echo;echo

exit 0
