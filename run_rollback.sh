#!/bin/bash

# Usage: build.sh -f pom文件路径 [ -m mvn命令全路径 -a 编译参数 -l 缓存主机名称 ]
# Usage: nginx.sh -k SSH秘钥 -Z SSH主机名 -U SSH用户 -P SSH端口 -B 后台标签 -L 集群标签 -T (on|off) -F 配置文件位置
# Usage: check_tcp.sh -k SSH秘钥 -x SSH主机名 -u SSH用户 -p SSH端口 -v 检测端口
# Usage: rollback.sh -d jenkins转存目录 -e (prod|dev) -k SSH秘钥 -n 项目名称 -t (war|jar) -x SSH主机 -u SSH用户 -p SSH端口 -h 项目路径 -v 项目用户

help_doc="Usage: `basename $0` 
[ -d jenkins转存目录 ] -e (prod|dev) [ -k SSH秘钥 ] -n 项目名称 -t (war|jar) -j 项目端口 -x 后端服务器1 -y 后端服务器2 [ -u 后端SSH用户 ] [ -p 后端SSH端口 ] [ -h 项目路径 ] [ -H 项目路径 ] [ -v 项目用户 ] -Z Nginx服务器 -i Nginx服务器 [ -U Nginx SSH用户 ] [ -P Nginx SSH端口 ] [ -F Nginx Upstream文件位置 ] [ -c Nginx Upstream文件位置 ] [ -L 集群标签 ] [ -l 集群标签 ]
"
while getopts "d:e:k:n:t:j:x:y:u:p:h:v:Z:U:P:F:L:D:C:" arg;do
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
        j)
            PROJ_PORT=$OPTARG
        ;;
        x)
            WEB_SSH_HOST1=$OPTARG
        ;;
        y)
            WEB_SSH_HOST2=$OPTARG
        ;;
        u)
            WEB_SSH_USER=$OPTARG
        ;;
        p)
            WEB_SSH_PORT=$OPTARG
        ;;
        h)
            PUBLISH_PATH=$OPTARG
        ;;
        v)
            PROJ_USER=$OPTARG
        ;;
        Z)
            NGX_SSH_HOST=$OPTARG
        ;;
        U)
            NGX_SSH_USER=$OPTARG
        ;;
        P)
            NGX_SSH_PORT=$OPTARG
        ;;
        F)
            NGX_UPSSTEAM_CONF=$OPTARG
        ;;
        L)
            CLASTER_LABEL=$OPTARG
        ;;
        *)
            echo -e $help_doc 
            exit 100
        ;;
    esac
done

## 规范必选变量
if [ -z $PROJ_NAME ] || [ -z $PROJ_TYPE ] || [ -z $PROJ_ENV ] || [ -z $NGX_SSH_HOST ] || [ -z $PROJ_PORT ] || [ -z $WEB_SSH_HOST1 ] || [ -z $WEB_SSH_HOST2 ];then
    echo $help_doc
    exit 101
fi

## 可选变量初始化
NOW_PATH=$(cd `dirname $0`;pwd)
DEFEALT_JKS_ROOT=$(dirname $NOW_PATH)
DEFEALT_SSH_KEY="$NOW_PATH/keys/jenkins.ppk"
DEFEALT_WEB_SSH_USER=uenpay
DEFEALT_PROJ_USER=uenpay
DEFEALT_WEB_SSH_PORT=22
DEFEALT_NGX_SSH_USER=$DEFEALT_WEB_SSH_USER
DEFEALT_NGX_SSH_PORT=$DEFEALT_WEB_SSH_PORT
DEFEALT_NGX_UPSSTEAM_CONF="/data/software/nginx/conf/vhost/ups_stream_list.conf"
DEFEALT_CLASTER_LABEL=${PROJ_NAME}_${PROJ_PORT}

if [ $PROJ_TYPE = "jar" ];then
    DEFEALT_PUBLISH_PATH=/opt/software/$PROJ_NAME
elif [ $PROJ_TYPE = "war" ];then
    DEFEALT_PUBLISH_PATH=/opt/software/tomcat-$PROJ_NAME
else
    echo -e "项目类型只能是(war|jar). "
fi

## 修正可选变量
[ -z $JKS_ROOT ] && JKS_ROOT=$DEFEALT_JKS_ROOT
[ -z $SSH_KEY ] && SSH_KEY=$DEFEALT_SSH_KEY
[ -z $WEB_SSH_USER ] && WEB_SSH_USER=$DEFEALT_WEB_SSH_USER
[ -z $WEB_SSH_PORT ] && WEB_SSH_PORT=$DEFEALT_WEB_SSH_PORT
[ -z $NGX_SSH_USER ] && NGX_SSH_USER=$DEFEALT_NGX_SSH_USER
[ -z $NGX_SSH_PORT ] && NGX_SSH_PORT=$DEFEALT_NGX_SSH_PORT
[ -z $NGX_UPSSTEAM_CONF ] && NGX_UPSSTEAM_CONF=$DEFEALT_NGX_UPSSTEAM_CONF
[ -z $PUBLISH_PATH ] && PUBLISH_PATH=$DEFEALT_PUBLISH_PATH
[ -z $CLASTER_LABEL ] && CLASTER_LABEL=$DEFEALT_CLASTER_LABEL
[ -z $PROJ_USER ] && PROJ_USER=$DEFEALT_PROJ_USER
[ -z $DAEMON_GIT_ADDR ] && DAEMON_GIT_ADDR=$DEFEALT_DAEMON_GIT_ADDR

[ ! -d $JKS_ROOT ] && echo -e "这个路径($JKS_ROOT)不存在. " && exit 102
[ ! -f $SSH_KEY ] && echo -e "这个文件($SSH_KEY)不存在. " && exit 103

NGX_SSH_KEY=$SSH_KEY
WEB_SSH_KEY=$SSH_KEY
TMP_PATH=$JKS_ROOT/$PROJ_ENV/$PROJ_NAME/tmp
BACK_PATH=$JKS_ROOT/$PROJ_ENV/$PROJ_NAME/backup
SCRIPTS_PATH=$JKS_ROOT/scripts
POM_FILE=$TMP_PATH/pom.xml

########
comm_exec (){
    RETURN=$1
    if [ $RETURN != 0 ];then
        exit 104
    fi
}

### 回滚1
if [ "$(echo $WEB_SSH_HOST1 | tr A-Z a-z)" != "none" ];then
    ## 关闭后端1
    WEB_SSH_HOST=$WEB_SSH_HOST1
    if [ "$(echo $NGX_SSH_HOST | tr A-Z a-z)" != "none" ];then
        for i in $(echo $NGX_SSH_HOST);do
            for j in $(echo $WEB_SSH_HOST);do
                BG_LABEL=$j:$PROJ_PORT
                $SCRIPTS_PATH/nginx.sh -k $NGX_SSH_KEY -Z $i -U $NGX_SSH_USER -P $NGX_SSH_PORT -B $BG_LABEL -L $CLASTER_LABEL -T off -F $NGX_UPSSTEAM_CONF
                comm_exec `echo $?`
            done
        done
    
        ## 检测后端1连接
        for i in $(echo $WEB_SSH_HOST);do
            $SCRIPTS_PATH/check_tcp.sh -k $WEB_SSH_KEY -x $i -u $WEB_SSH_USER -p $WEB_SSH_PORT -v $PROJ_PORT
            comm_exec `echo $?`
        done
    fi
    
    ## 正在回滚后端1服务
    for i in $(echo $WEB_SSH_HOST);do
        $SCRIPTS_PATH/rollback.sh -d $JKS_ROOT -e $PROJ_ENV -k $WEB_SSH_KEY -n $PROJ_NAME -t $PROJ_TYPE -u $WEB_SSH_USER -x $i -p $WEB_SSH_PORT -h $PUBLISH_PATH -v $PROJ_USER
        comm_exec `echo $?`
    done
    
    ### 回滚2
    ## 开启后端1服务
    if [ "$(echo $NGX_SSH_HOST | tr A-Z a-z)" != "none" ];then
        for i in $(echo $NGX_SSH_HOST);do
            for j in $(echo $WEB_SSH_HOST);do
                BG_LABEL=$j:$PROJ_PORT
                $SCRIPTS_PATH/nginx.sh -k $NGX_SSH_KEY -Z $i -U $NGX_SSH_USER -P $NGX_SSH_PORT -B $BG_LABEL -L $CLASTER_LABEL -T on -F $NGX_UPSSTEAM_CONF
                comm_exec `echo $?`
            done
        done
    fi
fi

if [ "$(echo $WEB_SSH_HOST2 | tr A-Z a-z)" != "none" ];then
    ## 关闭后端2服务
    WEB_SSH_HOST=$WEB_SSH_HOST2
    if [ "$(echo $NGX_SSH_HOST | tr A-Z a-z)" != "none" ];then
        for i in $(echo $NGX_SSH_HOST);do
            for j in $(echo $WEB_SSH_HOST);do
                BG_LABEL=$j:$PROJ_PORT
                $SCRIPTS_PATH/nginx.sh -k $NGX_SSH_KEY -Z $i -U $NGX_SSH_USER -P $NGX_SSH_PORT -B $BG_LABEL -L $CLASTER_LABEL -T off -F $NGX_UPSSTEAM_CONF
                comm_exec `echo $?`
            done
        done
        
        ## 检测后端2连接
        for i in $(echo $WEB_SSH_HOST);do
            $SCRIPTS_PATH/check_tcp.sh -k $WEB_SSH_KEY -x $i -u $WEB_SSH_USER -p $WEB_SSH_PORT -v $PROJ_PORT
            comm_exec `echo $?`
        done
    fi
    
    ## 正在发布后端2服务
    for i in $(echo $WEB_SSH_HOST);do
        $SCRIPTS_PATH/rollback.sh -d $JKS_ROOT -e $PROJ_ENV -k $WEB_SSH_KEY -n $PROJ_NAME -t $PROJ_TYPE -u $WEB_SSH_USER -x $i -p $WEB_SSH_PORT -h $PUBLISH_PATH -v $PROJ_USER
        comm_exec `echo $?`
    done
    
    ## 开启后端2服务
    if [ "$(echo $NGX_SSH_HOST | tr A-Z a-z)" != "none" ];then
        for i in $(echo $NGX_SSH_HOST);do
            for j in $(echo $WEB_SSH_HOST);do
                BG_LABEL=$j:$PROJ_PORT
                $SCRIPTS_PATH/nginx.sh -k $NGX_SSH_KEY -Z $i -U $NGX_SSH_USER -P $NGX_SSH_PORT -B $BG_LABEL -L $CLASTER_LABEL -T on -F $NGX_UPSSTEAM_CONF
                comm_exec `echo $?`
            done
        done
    fi
fi

exit 0
