#!/bin/bash
#centos7.4安装mariadb10.2脚本
sourceinstall=/usr/local/src/mariadb10.2
chmod -R 777  $sourceinstall
#时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate ntp1.aliyun.com
hwclock -w
echo "*/30 * * * * root ntpdate -s ntp1.aliyun.com" >> /etc/crontab

#sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
#sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
#sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
#sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
#setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

#1、卸载mariadb和marriadb
yum -y remove mysql*
yum -y remove mariadb*
rpm -e --nodeps `rpm -qa | grep mysql`
rpm -e --nodeps `rpm -qa | grep mariadb`
#2、配置mariadb服务
yum -y install epel-release
yum install -y git jemalloc* libaio* bison* zlib-devel openssl*  ncurses* libcurl-devel libarchive-devel boost* lsof wget gcc* make cmake perl kernel-headers kernel-devel pcre-devel 
yum install -y git jemalloc* libaio* bison* zlib-devel openssl*  ncurses* libcurl-devel libarchive-devel boost* lsof wget gcc* make cmake perl kernel-headers kernel-devel pcre-devel 
#禁止安装tokudb引擎，因为需要更高版本的gcc和动态链接库
#rpm -ivh $sourceinstall/rpm/*.rpm --force --nodeps
cd $sourceinstall
groupadd mariadb
useradd -g mariadb -s /sbin/nologin mariadb
mkdir -pv /usr/local/mariadb/{data,conf,logs}
tar -zxvf mariadb-10.2.18.tar.gz -C /usr/local/mariadb
cd /usr/local/mariadb/mariadb-10.2.18/
cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb -DMYSQL_DATADIR=/usr/local/mariadb/data -DTMPDIR=/usr/local/mariadb/data -DMYSQL_UNIX_ADDR=/usr/local/mariadb/logs/mariadb.sock -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_ARCHIVE_STORAGE_ENGINE=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=1 -DWITH_PERFSCHEMA_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DWITH_TOKUDB_STORAGE_ENGINE=1 -DWITH_XTRADB_STORAGE_ENGINE=1 -DWITH_ARIA_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_SPHINX_STORAGE_ENGINE=1 -DWITH_READLINE=1 -DMYSQL_TCP_PORT=3306 -DENABLED_LOCAL_INFILE=1 -DWITH_EXTRA_CHARSETS=all -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DCMAKE_EXE_LINKER_FLAGS='-ljemalloc' -DWITH_SAFEMALLOC=OFF -DWITH_SSL=system -DWITH_ZLIB=system -DWITH_LIBWRAP=0 
make 
make install
make clean
rm -rf CMakeCache.txt
chown -Rf mariadb:mariadb /usr/local/mariadb

#cp -r /usr/local/mariadb/support-files/my-large.cnf /usr/local/mariadb/conf/
cat > /usr/local/mariadb/conf/my.cnf <<EOF
[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4

[mysqld]
port = 3306
socket = /usr/local/mariadb/logs/mariadb.sock
pid-file = /usr/local/mariadb/mariadb.pid
basedir = /usr/local/mariadb
datadir = /usr/local/mariadb/data
tmpdir = /tmp
user = mariadb
log-error = /usr/local/mariadb/logs/mariadb.log
#server-id = 1 
#log-bin = mysql-bin
#max_allowed_packet = 32M
character-set-client-handshake = FALSE
character-set-server = utf8mb4 
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'
sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'
EOF
chown -Rf mariadb:mariadb /usr/local/mariadb

#二进制程序：
echo 'export PATH=/usr/local/mariadb/bin:$PATH' > /etc/profile.d/mariadb.sh 
source /etc/profile.d/mariadb.sh
#头文件输出给系统：
ln -sv /usr/local/mariadb/include /usr/include/mariadb
#库文件输出：mariadb数据库的动态链接库共享至系统链接库,一般mariadb数据库会被PHP等服务调用
echo '/usr/local/mariadb/lib' > /etc/ld.so.conf.d/mariadb.conf
ln -s /usr/local/mariadb/lib/libmariadbclient.so.20 /usr/lib/libmariadbclient.so.20
#让系统重新生成库文件路径缓存
ldconfig
#导出man文件：
echo 'MANDATORY_MANPATH                       /usr/local/mariadb/man' >> /etc/man_db.conf
source /etc/profile.d/mariadb.sh 
sleep 5
source /etc/profile.d/mariadb.sh 
cat >> /usr/lib/systemd/system/mariadb.service <<EOF
[Unit]
Description=mariadb Server
Documentation=man:mariadbd(8)
Documentation=http://dev.mariadb.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Service]
User=mariadb
Group=mariadb
ExecStart=/usr/local/mariadb/bin/mysqld --defaults-file=/usr/local/mariadb/conf/my.cnf
LimitNOFILE = 5000
Restart=on-failure
RestartPreventExitStatus=1
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

/usr/local/mariadb/scripts/mysql_install_db --user=mariadb --basedir=/usr/local/mariadb --datadir=/usr/local/mariadb/data/ --defaults-file=/usr/local/mariadb/conf/my.cnf
systemctl daemon-reload
systemctl enable mariadb.service
chown -Rf mariadb:mariadb /usr/local/mariadb
systemctl restart mariadb.service
sleep 5

#查看默认root本地登录密码如果不是用空密码初始化的数据库则：
#/usr/local/mariadb/bin/mysql_secure_installation 
'/usr/local/mariadb/bin/mysqladmin' -u root password 'Root_123456*0987'
ps aux |grep mariadb
firewall-cmd --permanent --zone=public --add-port=3306/tcp --permanent
firewall-cmd --permanent --query-port=3306/tcp
firewall-cmd --reload

#mysql -uroot -pRoot_123456*0987 -e "set names utf8;" 
#mysql -uroot -pRoot_123456*0987 -e "create database jumpserver default charset 'utf8mb4';"  
#mysql -uroot -pRoot_123456*0987 -e "grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by 'Jumpserver6688';"  
#mysql -uroot -pRoot_123456*0987 -e "flush privileges;" 

#echo 'skip-grant-tables' >> /usr/local/mariadb/conf/my.cnf
#systemctl restart mariadbd.service 
#sleep 5
#mariadb -uroot < $sourceinstall/mydbpassword.sql
#systemctl stop mariadbd.service
#cat >> /usr/local/mariadb/conf/my.cnf <<EOF
#[client]
#host=localhost
#user=root
#password='Root_123456*0987'
#EOF
#sed -i 's|skip-grant-tables|#skip-grant-tables|' /usr/local/mariadb/conf/my.cnf
#systemctl restart mariadbd.service 
#sleep 5
#mariadb -uroot --connect-expired-password < $sourceinstall/mydbgrant.sql
#sed -i '8,12d' /usr/local/mariadb/conf/my.cnf

#rm -rf  $sourceinstall
#修改root本地登录密码
#mariadb_secure_installation
#Change the password for root ? y
#New password:Xsssx1231231
#Remove anonymous users?  y
#Disallow root login remotely? y
#Remove test database and access to it?  y
#Reload privilege tables now?  y
#All done! 

#root用户登录测试
#mariadb -uroot -pRoot_123456*0987

#更改用户密码命令
#ALTER USER 'root'@'localhost' IDENTIFIED BY 'Root_123456*0987';

#防火墙开放mariadb端口
#firewall-cmd --add-service=mariadb --permanent
#firewall-cmd --reload
#lsof -i:3306

#开放 Root 远程连接权限
#GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Root_123456*0987' WITH GRANT OPTION; 

#创建用户：CREATE USER 'springdev'@'host' IDENTIFIED BY 'springdev_mysql';
#授权：GRANT ALL PRIVILEGES ON *.* TO 'springdev'@'%' IDENTIFIED BY 'springdev_mysql' WITH GRANT OPTION;
#刷新：flush privileges;
#创库：CREATE DATABASE springdev default charset 'utf8mb4';

#RHEL7使用xtrbackup还原增量备份:https://www.percona.com/downloads/
#chmod -R 777  $sourceinstall/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
#yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
#做一次完整备份
#innobackupex --password=Root_123456*0987 /data/db_backup/
#ls -ld /data/db_backup/2017-08-02_13-43-38/
#mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
#mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(1000);'
#第一次增量备份：第一次备份的–incremental-basedir参数应指向完整备份的时间戳目录
#innobackupex --password=Root_123456*0987 --incremental /data/db_backup/ --incremental-basedir=/data/db_backup/2017-08-02_13-43-38/
#ls -ld /data/db_backup/2017-08-02_13-49-29/
#mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(2000);'
#第二次增量备份：第二次备份的–incremental-basedir参数应指向第一次增量备份的时间戳目录
#innobackupex --password=Root_123456*0987 --incremental /data/db_backup/ --incremental-basedir=/data/db_backup/2017-08-02_13-49-29/
#还原数据
#systemctl daemon-reload && systemctl stop mysqld && netstat -lanput |grep 3306
#rm -rf /var/lib/mysql/*
#整合完整备份和增量备份：注意：一定要按照完整备份、第一次增量备份、第二次增量备份的顺序进行整合，在整合最后一次增量备份时不要使用–redo-only参数
#innobackupex --apply-log --redo-only /data/db_backup/2017-08-02_13-43-38/
#innobackupex --apply-log --redo-only /data/db_backup/2017-08-02_13-43-38/ --incremental-dir=/data/db_backup/2017-08-02_13-49-29/
#innobackupex --apply-log /data/db_backup/2017-08-02_13-43-38/ --incremental-dir=/data/db_backup/2017-08-02_13-52-59/ 
#innobackupex --apply-log /data/db_backup/2017-08-02_13-43-38/
#开始还原
#innobackupex --copy-back /data/db_backup/2017-08-02_13-43-38/
#chown -R mysql.mysql /var/lib/mysql 
#systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
#mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'


############################################（一）RHEL7上面搭建主从#########################################
###IP地址：192.168.8.20 Master   IP地址：192.168.8.21 Slave
###########------------------------------------主服务器（master）------------------------------#############
# mysql -uroot -pRoot_123456*0987 -e 'create database Yang default charset "utf8mb4";'
# mysql -uroot -pRoot_123456*0987 -e 'use Yang;create table T1(ID int);'
# mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values (100);'
# mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
# mysqldump -uroot -pRoot_123456*0987 -B Yang > Yang.sql
# scp Yang.sql 192.168.8.21:/root/
#systemctl daemon-reload && systemctl stop mysqld.service && netstat -lanput |grep 3306
#cat >> /usr/local/mysql/conf/my.cnf <<EOF 
#log-bin = mysql-bin
#server-id = 1 
#EOF
# systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
# mysql -uroot -pRoot_123456*0987 -e 'grant replication slave on *.* to slave@192.168.8.21 identified by "qwerASDF@123456";'
# mysql -uroot -pRoot_123456*0987 -e 'show master status;'

###########------------------------------------从服务器（slave）------------------------------#############
# mysql -uslave -pqwerASDF@Root_123456*0987 -h 192.168.8.20
# cd && mysql -uroot -pRoot_123456*0987 < Yang.sql
# cat >> /usr/local/mysql/conf/my.cnf <<EOF
# server-id = 2
# replicate_do_db=Yang
# relay-log= relay-mysql
# read-only=ON
# EOF
# systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
# mysql -uroot -pRoot_123456*0987 -e 'change master to master_host="192.168.8.20",master_user="slave",master_password="qwerASDF@123456"'
# mysql -uroot -pRoot_123456*0987 -e 'start slave;'
# mysql -uroot -pRoot_123456*0987 -e 'show slave status\G' |egrep "Slave_IO_Running|Slave_SQL_Running"

#连接测试：
#在主服务器上插入数据 mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(6666);'
#在主服务器上查看数据 mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
#在从服务器上查看数据 mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'



############################################（二）RHEL7上面搭建主主#########################################
###IP地址：192.168.8.20 Master   IP地址：192.168.8.21 Master 
###########------------------------------------主服务器A（master）------------------------------#############
#systemctl daemon-reload && systemctl stop mysqld.service && netstat -lanput |grep 3306
#cat >> /usr/local/mysql/conf/my.cnf <<EOF 
#server-id = 1  
#log-bin = mysql-bin
#relay-log = relay-mysql
#auto-increment-offset = 1
#auto-increment-increment = 2
#EOF
# systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
# mysql -uroot -pRoot_123456*0987 -e 'grant replication slave on *.* to slave@192.168.8.21 identified by "qwerASDF@123456";'
# mysql -uroot -pRoot_123456*0987 -e 'change master to master_host="192.168.8.21",master_user="slave",master_password="qwerASDF@123456"'
# mysql -uroot -pRoot_123456*0987 -e 'start slave;'
# mysql -uroot -pRoot_123456*0987 -e 'show master status;'

###########------------------------------------主服务器B（master）------------------------------#############
# mysql -uslave -pqwerASDF@Root_123456*0987 -h 192.168.8.20
# systemctl daemon-reload && systemctl stop mysqld.service && netstat -lanput |grep 3306
#cat >> /usr/local/mysql/conf/my.cnf <<EOF 
#server-id = 2  
#log-bin = mysql-bin
#relay-log = relay-mysql
#auto-increment-offset = 2 
#auto-increment-increment = 2
#EOF
# systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
# mysql -uroot -pRoot_123456*0987 -e 'grant replication slave on *.* to slave@192.168.8.20 identified by "qwerASDF@123456";'
# mysql -uroot -pRoot_123456*0987 -e 'change master to master_host="192.168.8.20",master_user="slave",master_password="qwerASDF@123456"'
# mysql -uroot -pRoot_123456*0987 -e 'start slave;'
# mysql -uroot -pRoot_123456*0987 -e 'show slave status\G' |egrep "Slave_IO_Running|Slave_SQL_Running"

#连接测试：
# mysql -uroot -pRoot_123456*0987 -e 'create database Yang default charset "utf8mb4";'
# mysql -uroot -pRoot_123456*0987 -e 'use Yang;create table T1(ID int);'
# mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values (1000);'
# mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
#在主服务器上插入数据 mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(6666);'
#在从服务器上插入数据 mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(7777);'
#在主服务器上查看数据 mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
#在从服务器上查看数据 mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'


#为了复制的安全性：
#			sync_master_info = 1    
#			sync_relay_log = 1   
#			sync_relay_log_info = 1
#从服务器意外崩溃时，建议使用pt-slave-start命令来启动slave; 
#评估主从服务表中的数据是否一致：pt-table-checksum

#如果数据不一致办法1、重新备份并在从服务器导入数据；2、pt-table-sync 


#为了提高复制时的数据安全性，在主服务器上的设定：
#	sync_binlog = 1
#	innodb_flush_log_at_trx_commit = 1
#此参数设定为1，性能下降严重；一般设为2等，此时主服务器崩溃依然有可能导致从服务器无法获取到全部的二进制日志事件；
#
#master崩溃导致二进制日志损坏，在从服务器使用参数忽略：sql_slave_skip_counter = 0






















