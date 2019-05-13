#!/bin/bash
##安装mysql之mysqldump备份脚本
sourceinstall=/usr/local/src/mysql5.7
chmod -R 777 $sourceinstall

##1、每天凌晨一次的全备份 
mkdir -pv /home/mysql/dump/mysqldump
chown -R mysql:mysql /home/mysql

echo '#!/bin/bash
DIR=/home/mysql/dump/mysqldump
USER=root
PASSWD=Root_123456*0987
HOST=localhost
time=`date +"%Y%m%d"`

cd "$DIR"
mkdir -pv "$time"
cd "$time"
/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"
echo "Begin backup all Single Database........"
for Database in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"`
do
        echo "Databases  backup Need wait...."
        /usr/local/mysql/bin/mysqldump  -u$USER -p$PASSWD -h$HOST $Database --lock-all-tables --master-data=2 > $Database-"$time".sql
done
echo "single database ok............"

echo "Database Full table backup............."
for db in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -h$HOST -e "show databases"|sed "1d"`
do
        mkdir -pv $db-"$time"
        for tables in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD $db -e "show tables"|sed "1d"`
        do
                /usr/local/mysql/bin/mysqldump  -h$HOST -u$USER -p$PASSWD $db $tables --master-data=2 > $db-"$time"/$tables
        done
done

echo "Full databases backup............."
/usr/local/mysql/bin/mysqldump  -u$USER -p$PASSWD -h$HOST --all-databases --lock-all-tables  --flush-logs --events  --master-data=2 > all-"$time".sql
if [[ $? == 0 ]];then
        echo "mysql backup Success"
else
        echo "mysql backup Fail"
fi

#***********需要修改要删除的数据库开头名称************#
before=`date -d "2 day ago" +"%Y%m%d"`
expirebackup="$DIR"/$before

#删除目录
if [ -d $expirebackup ] ;then
        rm -rf $expirebackup
else
        echo "Not 2 day ago expirebackup"
fi
' > /home/mysql/mysqldump.sh
chmod a+x /home/mysql/mysqldump.sh

###2、开启定时任务  
cat >> /etc/crontab <<EOF
#每天凌晨一次的全备份 
50 1 * * * root /home/mysql/mysqldump.sh > /dev/null 2>&1 
EOF
crontab /etc/crontab
crontab -l

# -E, --events：  备份指定库的事件调度器
# -R, --routines：备份存储过程和存储函数；
# --triggers：    备份触发器

#mysql之mysqldump恢复
#注意恢复之前的准备工作：
#1、备份文件拷贝到一个文件夹，防止出错后无法二次恢复（全备文件和二进制日志文件，权限及属主）
#2、关闭二进制日志文件（注释配置文件二进制日志记录，重启mysql）
#3、恢复全备点：/usr/local/mysql/bin/mysql -uroot -pRoot_123456*0987 < $Database-"$time".sql
#4、查找备份点：less $Database-"$time".sql
#5、恢复二进制：mysqlbinlog --no-defaults --start-position=235 [--database=test --set-charset=utf8mb4] mysql-bin.00001 | mysql -uroot -pRoot_123456*0987 [test]
#               mysqlbinlog --no-defaults --start-datetime="2019-04-17 22:01:08" [--database=test --set-charset=utf8mb4] mysql-bin.00001 | mysql -uroot -pRoot_123456*0987 [test]
