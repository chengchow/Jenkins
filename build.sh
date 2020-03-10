#!/bin/bash
## 该脚本用于在缓存服务器上编译项目
## 需指定项目pom文件位置，其他参数可选，没有指定则为默认值
## 需要预先在缓存服务器上配置java和maven环境 
## 该脚本部署在中转服务器

help_doc="Usage: `basename $0` -f pom文件路径 [ -m mvn命令全路径 -a 编译参数 -l 缓存主机名称 ]"

while getopts "m:f:a:l:" arg;do
    case $arg in
        m)
            MVN=$OPTARG
        ;;
        f)
            POM_FILE=$OPTARG
        ;;
        a)
            ARG=$OPTARG
        ;;
        l)
            HOST_NAME=$OPTARG
        ;;
        *)
            echo -e $help_doc 
            exit 65
        ;;
    esac
done

if [ -z $MVN ];then
    MVN=mvn
fi 

if [ -z $ARG ];then
    ARG=" install -Dmaven.test.skip=true"
fi

if [ -z $HOST_NAME ];then
    HOST_NAME=$(hostname -i)
fi

if [ -z $POM_FILE ];then
    echo -e $help_doc
    exit 66
elif [ ! -f $POM_FILE ];then
    echo -e "这个pom文件($POM_FILE)不存在, 在服务器$HOST_NAME上. "
    exit 67
fi

POM_PATH=$(dirname $POM_FILE)

echo -en "正在主机${HOST_NAME}上编译项目, 这需要一些时间，请耐心等待 ...... "
cd $POM_PATH && $MVN clean > maven.tmp 2>&1  && $MVN $ARG >> maven.tmp 2>&1
if [ `echo $?` = 0 ];then
    echo -e "[ OK ]"
    /bin/rm -f maven.tmp
else
    echo -e "[ FAILURE ]\n编译日志如下: \n"
    cat maven.tmp
    /bin/rm -f maven.tmp
    exit 68
fi

exit 0
