







# 该项目用于jenkins发布 

## 发布流程

- run.py
  - build.sh
  - nginx.sh
  - check_tcp.sh
  - init.sh
  - publish.sh

## 回滚流程

- run_rollback.py
  - build.sh
  - nginx.sh
  - check_tcp.sh
  - rollback.sh

## 注意事项

1. 该项目运行用户只能是root或者拥有sudo权限的普通用户
2. 该项目只支持service启动管理项目
3. 该项目发布前项目目录必须手动创建，其他均可自动完成

## 部署方法

1. 在生产或者测试环境中找一台服务器
2. 在该服务器上安装maven/java,并配置maven私服
3. 拷贝脚本到jenkins缓存目录(默认/opt/jenkins)
4. 解决该服务器到发布服务器及nginx服务免验证问题

## 参数说明

| 参数 | 参数选项                    | 是否必须 | 默认值                                               | 备注                                            |
| ---- | --------------------------- | -------- | ---------------------------------------------------- | ----------------------------------------------- |
| -d   | jenkins转存目录             | N        | 该脚本的上一级目录                                   |                                                 |
| -e   | prod/dev                    | Y        |                                                      |                                                 |
| -k   | SSH秘钥                     | N        | keys/jenkins.ppk                                     | keys/jenkins.pub为公钥                          |
| -n   | 项目名称                    | Y        |                                                      |                                                 |
| -t   | war/jar                     | Y        |                                                      |                                                 |
| -j   | 项目端口                    | Y        |                                                      |                                                 |
| -x   | 后端服务器1                 | Y        |                                                      | 支持集群，多个配置("0.0.0.0 1.1.1.1")用空格隔开 |
| -y   | 后端服务器2                 | Y        |                                                      | 支持集群，多个配置("0.0.0.0 1.1.1.1")用空格隔开 |
| -u   | 后端SSH用户                 | N        | uenpay                                               | 需要在后端服务器手动创建                        |
| -p   | 后端SSH端口                 | N        | 22                                                   |                                                 |
| -h   | 项目路径                    | N        | /opt/software/[tomcat-]项目名                        |                                                 |
| -v   | 项目用户                    | N        | uenpay                                               | 需要在后端服务器手动创建                        |
| -Z   | Nginx服务器                 | Y        |                                                      | 支持集群，多个配置("0.0.0.0 1.1.1.1")用空格隔开 |
| -U   | Nginx服务器SSH用户          | N        | uenpay                                               |                                                 |
| -P   | Nginx服务器SSH端口          | N        | 22                                                   |                                                 |
| -F   | Nginx服务器Upstream文件位置 | N        | /data/software/nginx/conf/vhost/ups_stream_list.conf | 一个测试文件                                    |
| -L   | 集群标签                    | N        | 项目名称_项目端口                                    |                                                 |
| -D   | daemon文件git地址           | N        | git@10.10.21.100:operations/conf/daemon.git          | 项目启动脚本通用git地址                         |
| -C   | 环境配置git地址             | Y        |                                                      |                                                 |

以上所有参数默认值可以在run*.sh中修改