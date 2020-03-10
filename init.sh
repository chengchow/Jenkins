#!/bin/bash
## 该脚本用于第一次发布时初始化项目, 该脚本适应性较小，针对每一个公司不同情况重写
## 该脚本部署在中转服务器

help_doc="Usage: `basename $0` -d jenkins转存目录 -e (prod|dev) -k SSH秘钥 -n 项目名称 -t (war|jar) -j 项目端口 -x SSH主机名 -u SSH用户 -p SSH端口 -h 项目路径 -v 项目用户 -D 启动脚本git地址 -C 配置文件git地址"

while getopts "d:e:k:n:t:j:x:u:p:h:v:D:C:" arg;do
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
        D)
            DAEMON_GIT_ADDR=$OPTARG
        ;;
        C)
            CONFIG_GIT_ADDR=$OPTARG
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
if [ -z $JKS_ROOT ] || [ -z $PROJ_ENV ] || [ -z $SSH_KEY ] || [ -z $PROJ_NAME ] || [ -z $PROJ_TYPE ] || [ -z $PROJ_PORT ] || [ -z $SSH_HOST ] || [ -z $SSH_USER ] || [ -z $SSH_PORT ] || [ -z $PROJ_PATH ] || [ -z $PROJ_USER ] || [ -z $DAEMON_GIT_ADDR ] || [ -z $CONFIG_GIT_ADDR ];then
    echo -e $help_doc 
    exit 66
fi

[ -z $SSH_GROUP ] && SSH_GROUP=$SSH_USER

if [ $PROJ_TYPE != "war" ] && [ $PROJ_TYPE != 'jar' ];then
    echo -e "项目类型只能是(jar|war). "
    exit 67
fi

remote_comm_exec (){
    TIME=$(date +%s)
    [ ! -z "$1" ] && $SSH_LOGN "$1" >/dev/null 2>&1 || exit 68
    RETURN=$?
    END_TIME=$(date +%s)
    let DIFF_TIME=$END_TIME-$TIME
    if [ $RETURN = 0 ];then
        echo -e "[ 成功 ]\n耗时: $DIFF_TIME(s)"
    else
        echo -e "[ 失败 ]"
        exit 69
    fi
}

comm_exec () {
    if [ $1 = 0 ];then
        echo "[ 成功 ]"
        echo
    else
        echo "[ 失败 ]"
        echo
        exit 70
    fi
}

SSH_LOGN="/usr/bin/ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p$SSH_PORT $SSH_USER@$SSH_HOST"
NOW_TIME=$(date +%Y-%m-%d_%H-%M-%S)
APP=${PROJ_NAME}.${PROJ_TYPE}
PROJ_GROUP=$PROJ_USER
ENV_PATH=$JKS_ROOT/$PROJ_ENV


DAEMON_LABEL=$(basename $DAEMON_GIT_ADDR | sed -r 's/\.git//g')
DAEMON_PATH=$ENV_PATH/$DAEMON_LABEL
CONFIG_LABEL=$(basename $CONFIG_GIT_ADDR | sed -r 's/\.git//g')
CONFIG_PATH=$ENV_PATH/$CONFIG_LABEL

## 确认后端主机正确
$SSH_LOGN "[ -d $PROJ_PATH ]"
if [ `echo $?` != 0 ];then
    echo "后端服务($SSH_HOST)目录($PROJ_PATH)不存在, 请手动创建. "
    exit 71
fi

## 安装git
echo -en "正在检查缓存服务器(`hostname -i`)上git客户端安装 ...... "
git --version > /dev/null 2>&1 || sudo yum -y install git > /dev/null
comm_exec $?

## 创建环境目录
echo -en "正在创建目录($ENV_PATH)在服务器(`hostname -i`)上 ...... "
[ -d "$ENV_PATH" ] ||  mkdir -p $ENV_PATH
comm_exec $?

## 获取最新启动脚本
if [ ! -d $DAEMON_PATH ];then
    sudo chown -R $PROJ_USER:$PROJ_GROUP $ENV_PATH
    echo -en "正在获取最新的启动脚本, 在服务器(`hostname -i`) ...... "
    cd $ENV_PATH && git clone $DAEMON_GIT_ADDR > /dev/null
    comm_exec $?
else
    echo -en "正在获取最新的启动脚本, 在服务器(`hostname -i`) ...... "
    cd $DAEMON_PATH && git pull > /dev/null
    comm_exec $?
fi

## 获取最新配置文件
if [ ! -d $CONFIG_PATH ];then
    sudo chown -R $PROJ_USER:$PROJ_GROUP $ENV_PATH
    echo -en "正在获取$PORJ_ENV环境最新的配置文件, 在服务器(`hostname -i`) ...... "
    cd $ENV_PATH && git clone $CONFIG_GIT_ADDR > /dev/null
    comm_exec $?
else
    echo -en "正在获取$PORJ_ENV环境最新的配置文件, 在服务器(`hostname -i`) ...... "
    cd $CONFIG_PATH && git pull > /dev/null
    comm_exec $?
fi

## 检测环境变量文件存在
NOW_ENV_FILE=$CONFIG_PATH/$PROJ_NAME/env.sh
DST_ENV_FILE=$PROJ_PATH/env.sh

NOW_ENV_MD5=$(/usr/bin/md5sum $NOW_ENV_FILE 2>&1 | awk '{print $1}')
DST_ENV_MD5=$($SSH_LOGN "/usr/bin/md5sum $DST_ENV_FILE" 2>&1 | awk '{print $1}')

if [ $NOW_ENV_MD5 != $DST_ENV_MD5 ];then
    $SSH_LOGN "sudo chown -R $SSH_USER $PROJ_PATH"
    echo -en "正在更新项目环境变量文件($DST_ENV_FILE), 在服务器($SSH_HOST)上 ...... "
    /usr/bin/rsync -arqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_ENV_FILE $SSH_USER@$SSH_HOST:$DST_ENV_FILE > /dev/null
    comm_exec $?
fi

## 检测启动脚本
NOW_INIT_FILE=$DAEMON_PATH/${PROJ_NAME}
DST_INIT_FILE=/etc/init.d/${PROJ_NAME}

NOW_INIT_MD5=$(/usr/bin/md5sum $NOW_INIT_FILE 2>&1 | awk '{print $1}')
DST_INIT_MD5=$($SSH_LOGN "/usr/bin/md5sum $DST_INIT_FILE" 2>&1 | awk '{print $1}')

if [ $NOW_INIT_MD5 != $DST_INIT_MD5 ];then
    echo -en "正在上传启动脚本到服务器$SSH_HOST:/tmp ...... "
    /usr/bin/rsync -arpqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_INIT_FILE $SSH_USER@$SSH_HOST:/tmp > /dev/null
    comm_exec $?

    echo -en "正在拷贝启动脚本到/etc/init.d/$PROJ_NAME ...... "
    $SSH_LOGN "sudo mv /tmp/$PROJ_NAME /etc/init.d/ && chmod +x /etc/init.d/$PROJ_NAME" > /dev/null
    comm_exec $?
fi

## 检测字体安装
NOW_FONT_PATH=$DAEMON_PATH/fonts
for font in `ls $NOW_FONT_PATH/*.tt[cf]`;do
    NOW_FONT_FILE=$NOW_FONT_PATH/`basename $font`
    DST_FONT_FILE=/usr/share/fonts/dejavu/`basename $font`

    NOW_FONT_MD5=$(/usr/bin/md5sum $NOW_FONT_FILE 2>&1 | awk '{print $1}')
    DST_FONT_MD5=$($SSH_LOGN "/usr/bin/md5sum $DST_FONT_FILE" 2>&1 | awk '{print $1}')

    if [ "$NOW_FONT_MD5" != "$DST_FONT_MD5" ];then
        echo -en "正在上传字体`basename $font`到$SSH_HOST:/tmp ...... "
        /usr/bin/rsync -arpqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_FONT_FILE $SSH_USER@$SSH_HOST:/tmp > /dev/null
        comm_exec $?

        echo -en "正在拷贝字体到`basename $font`/usr/share/fonts/dejavu/目录 ...... "
        $SSH_LOGN "sudo mkdir -p /usr/share/fonts/dejavu && sudo mv /tmp/`basename $font` /usr/share/fonts/dejavu/" > /dev/null
        comm_exec $?
    fi
done

## 检测库文件
NOW_LIB_PATH=$DAEMON_PATH/lib
for lib in `ls $NOW_LIB_PATH/*.so*`;do
    NOW_LIB_FILE=$NOW_LIB_PATH/`basename $lib`
    DST_LIB_FILE=/usr/lib/`basename $lib`

    NOW_LIB_MD5=$(/usr/bin/md5sum $NOW_LIB_FILE 2>&1 | awk '{print $1}')
    DST_LIB_MD5=$($SSH_LOGN "/usr/bin/md5sum $DST_LIB_FILE" 2>&1 | awk '{print $1}')

    if [ "$NOW_LIB_MD5" != "$DST_LIB_MD5" ];then
        echo -en "正在上传库文件`basename $lib`到$SSH_HOST:/tmp ...... "
        /usr/bin/rsync -arpqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_LIB_FILE $SSH_USER@$SSH_HOST:/tmp > /dev/null
        comm_exec $?

        echo -en "正在拷贝库文件`basename $lib`到/usr/lib/目录 ...... "
        $SSH_LOGN "sudo mv /tmp/`basename $lib` /usr/lib/" > /dev/null
        comm_exec $?
    fi
done

## 检测java安装(只安装不更新)
NOW_JAVA_FILE=$DAEMON_PATH/software/java.tar.gz
DST_JAVA_PATH=/opt/software/java

$SSH_LOGN "[ -x $DST_JAVA_PATH/bin/java ]"
if [ `echo $?` != 0 ];then
    echo -en "正在上传java安装包到$SSH_HOST:/tmp ...... "
    /usr/bin/rsync -arpqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_JAVA_FILE $SSH_USER@$SSH_HOST:/tmp >/dev/null
    comm_exec $?
  
    echo -en "正在安装java到$DST_JAVA_PATH ...... "
    $SSH_LOGN "sudo /bin/tar zxf /tmp/java.tar.gz -C $DST_JAVA_PATH"
    comm_exec $?
else
    echo -e "java已经安装. "
    echo 
fi

## 检测tomcat安装(只安装不更新)
NOW_TOMCAT_FILE=$DAEMON_PATH/software/tomcat.tar.gz
DST_TOMCAT_PATH=$PROJ_PATH

if [ $PROJ_TYPE = "war" ];then
    $SSH_LOGN "[ -x $DST_TOMCAT_PATH/bin/catalina.sh ]"
    if [ `echo $?` != 0 ];then
        echo -en "正在上传tomcat安装包到$SSH_HOST:/tmp ...... "
        /usr/bin/rsync -arpqz -e "ssh -p $SSH_PORT -i $SSH_KEY" --port=$SSH_PORT $NOW_TOMCAT_FILE $SSH_USER@$SSH_HOST:/tmp
        comm_exec $?

        echo -en "正在安装tomcat到$PROJ_PATH ...... "
        $SSH_LOGN "sudo /bin/tar zxf /tmp/tomcat.tar.gz -C /tmp && sudo /bin/cp -rpf /tmp/tomcat/* $PROJ_PATH/. && sudo chown -R $PROJ_USER:$PROJ_GROUP $PROJ_PATH"    
        comm_exec $?


#        let JMX_PORT=$PROJ_PORT+10000 

#        echo -en "正在初始化catalina.sh文件 ...... "
#        $SSH_LOGN " /bin/sed -ri \"/^JAVA_OPTS/{s/00000/$JMX_PORT/g;s/XXXXX/$PROJ_NAME/g}\" $PROJ_PATH/bin/catalina.sh"
#        comm_exec $?
    else
        echo -e "tomcat已经安装"
        echo
    fi
fi

