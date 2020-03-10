#!/bin/bash
## 该脚本用于切换nginx负载均衡
## 该脚本部署在中转服务器

help_doc="Usage: `basename $0` -k SSH秘钥 -Z SSH主机名 -U SSH用户 -P SSH端口 -B 后台标签 -L 集群标签 -T (on|off) -F 配置文件位置 "

while getopts "k:Z:U:P:B:L:T:F:" arg;do
    case $arg in
        k)
            SSH_KEY=$OPTARG
        ;;
        Z)
            SSH_HOST=$OPTARG
        ;;
        U)
            SSH_USER=$OPTARG
        ;;
        P)
            SSH_PORT=$OPTARG
        ;;
        B)
            BACKGROUND_LABEL=$OPTARG
        ;;
        L)
            CLUSTER_LABEL=$OPTARG
        ;;
        T)
            TYPE=$OPTARG
        ;;
        F)
            CONF_FILE=$OPTARG
        ;;
        *)
            echo -e $help_doc 
            exit 65
        ;;
    esac
done

DAEMON="service nginx "

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$BACKGROUND_LABEL" ] || [ -z "$CLUSTER_LABEL" ] || [ -z "$TYPE" ] || [ -z "$CONF_FILE" ] || [ -z $SSH_KEY ] || [ -z $SSH_PORT ];then
    echo -e $help_doc 
    exit 66
fi

if [ $TYPE != "on" ] && [ $TYPE != "off" ];then
    echo -e "参数错误. \"处理方法\"只能是(on|off). "
    exit 67
fi

case $TYPE in
    off)
        for i in $(echo $SSH_HOST);do
            SSH_LOGN="/usr/bin/ssh -i $SSH_KEY -o StrictHostKeyChecking=no -p$SSH_PORT $SSH_USER@$i"
            for j in $(echo $BACKGROUND_LABEL);do
                echo -en "正在nginx服务器${i}上关闭后端服务器$j ...... "
                $SSH_LOGN "sudo sed -ri \"/upstream.*$CLUSTER_LABEL/,/}/{s/^[^#].*$j.*/#&/}\" $CONF_FILE" > /dev/null
                if [ `echo $?` = 0 ];then
                    echo -e "[ 成功 ]"
                else
                    echo -e "[ 失败 ]"
                    exit 68
                fi
            done
        done
    ;;
    on)
        for i in $(echo $SSH_HOST);do
            SSH_LOGN="/usr/bin/ssh -i $SSH_KEY -o StrictHostKeyChecking=no -p$SSH_PORT $SSH_USER@$i"
            for j in $(echo $BACKGROUND_LABEL);do
                echo -en "正在nginx服务器${i}上开启后端服务器$j ...... "
                $SSH_LOGN "sudo sed -ri \"/upstream.*$CLUSTER_LABEL/,/}/{s/^#+(.*$j.*)$/\1/}\" $CONF_FILE" > /dev/null
                if [ `echo $?` = 0 ];then
                    echo -e "[ 成功 ]"
                else
                    echo -e "[ 失败 ]"
                    exit 68
                fi
            done
        done
        ;;
esac

echo -en "正在服务器${i}上平滑重启Nginx ......  "
$SSH_LOGN "sudo $DAEMON reload" > /dev/null
if [ `echo $?` = 0 ];then
    echo -e "[ 成功 ]"
else
    echo -e "[ 失败 ]"
    exit 69
fi

echo;echo
