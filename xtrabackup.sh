#!/bin/bash
##安装mysql之xtrabackup备份脚本
##数据库出现故障，通过完整备份+到现在为止的所有增量备份+最后一次增量备份到现在的二进制日志来恢复。
sourceinstall=/usr/local/src/mysql5.7
chmod -R 777 $sourceinstall
##时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate ntp1.aliyun.com
hwclock -w
echo "*/30 * * * * root ntpdate -s ntp1.aliyun.com" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm

# yum -y install epel-release
# yum -y install wget
# wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.12/binary/redhat/7/x86_64/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
# yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm


##1、数据库全备份的脚本,每周六凌晨一次的全备份
mkdir -pv /home/mysql/dump/full
chown -R mysql:mysql /home/mysql

echo '#!/bin/bash
User=root
PassWord=Root_123456*0987
dateformat=`date +"%Y%m%d"`

fulldir=/home/mysql/dump/full

if [[ ! -d $fulldir/$dateformat ]]; then
        mkdir -pv $fulldir/$dateformat
fi

cd "$fulldir/$dateformat"
echo "Begin backup full Database........"
 innobackupex --defaults-file=/usr/local/mysql/conf/my.cnf --user=$User --password=$PassWord --no-timestamp --host=127.0.0.1 $fulldir/$dateformat > $fulldir/$dateformat/fullbackup.log 2>&1 &

 while true; do
   installRes=`tail -1 $fulldir/$dateformat/fullbackup.log |cut -d " " -f 3-4`
   if   [[ "${installRes}" = "completed OK!" ]];then
            echo "full database ok............" 
            sleep 10
            break
   elif [[ "${installRes}" = "completed OK!" ]];then
            echo "full database ok............" 
            sleep 10
            break
   else
         sleep 10
         continue
   fi
done


#***********需要修改要删除的数据库开头名称************#
before=`date -d "7 day ago" +"%Y%m%d"`
fullbackupdata="$fulldir"/"$before"

if [ -d $fullbackupdata ] ;then
        rm -rf $fullbackupdata
        exit 1
fi
' >  /home/mysql/innobackupex_fullbackupdata.sh
chmod a+x  /home/mysql/innobackupex_fullbackupdata.sh

##2、每天一次的全增量（以全备份为基础的增量），每两个小时一次的增量备份（以全增量为基础的增量）
echo '#!/bin/bash
# define some variables
User=root
PassWord=Root_123456*0987
dateFull=`date +"%Y%m%d"`
dateIncre=`date +"%Y%m%d_%H%M%S"`
fulldir=/home/mysql/dump/full
Increment=/home/mysql/dump/increment
Increment-twohour=/home/mysql/dump/increment-twohour
# The first incremental backup of a week is full backup.
if [ ! -d $Increment/$dateFull ]; then
        rm -rf  $Increment/*
        mkdir -pv $Increment/$dateFull
        fullfilename=`ls -lt $fulldir | sed -n 2p | cut -d " " -f 10`
        cd "$Increment/$dateFull"
        echo "Begin The first incremental backup of a week is full backup........"
        innobackupex --defaults-file=/usr/local/mysql/conf/my.cnf --user=$User --password=$PassWord --use-memory=1024MB --no-timestamp --host=127.0.0.1 --incremental $Increment/$dateFull --incremental-basedir=$fulldir/$fullfilename > $Increment/$dateFull/incre-oneday.log 2>&1 &
        while true; do
          installRes=`tail -1 $Increment/$dateFull/incre-oneday.log |cut -d " " -f 3-4`
          if   [[ "${installRes}" = "completed OK!" ]];then
               echo "The first incremental backup of a week is full backup ok............" 
               sleep 10
               break
         elif [[ "${installRes}" = "completed OK!" ]];then
              echo "The first incremental backup of a week is full backup ok............" 
              sleep 10
              break
        else
         sleep 10
         continue
       fi
       done
fi

# Incremental backups from the first incremental backups.
if [ ! -d $Increment-twohour/$dateFull ]; then
        rm -rf $Increment-twohour/*
        mkdir -pv $Increment-twohour/$dateFull
        fileName=`ls -lt $Increment | sed -n 2p | cut -d " " -f 10`
        echo "Begin Incremental backups from the first incremental backups........."
        innobackupex --defaults-file=/usr/local/mysql/conf/my.cnf --user=$User --password=$PassWord --use-memory=1024MB --no-timestamp --host=127.0.0.1 --incremental $Increment-twohour/$dateFull --incremental-basedir=$Increment/$fileName > $Increment-twohour/$dateFull/incre-twohour.log  2>&1 &
        while true; do
          installRes=`tail -1 $Increment-twohour/$dateFull/incre-twohour.log |cut -d " " -f 3-4`
          if   [[ "${installRes}" = "completed OK!" ]];then
               echo "Incremental backups from the first incremental backups ok............" 
               sleep 10
               break
         elif [[ "${installRes}" = "completed OK!" ]];then
              echo "Incremental backups from the first incremental backups ok............" 
              sleep 10
              break
        else
         sleep 10
         continue
       fi
       done
       exit 1
fi

if [ -d $Increment-twohour/$dateFull ]; then
        mkdir -pv $Increment-twohour/$dateIncre
        fileName=`ls -lt $Increment | sed -n 2p | cut -d " " -f 10`
        echo "Begin Incremental backups from the first incremental backups........."
        innobackupex --defaults-file=/usr/local/mysql/conf/my.cnf --user=$User --password=$PassWord --use-memory=1024MB --no-timestamp --host=127.0.0.1 --incremental $Increment-twohour/$dateIncre --incremental-basedir=$Increment/$fileName > $Increment-twohour/$dateIncre/incre-twohour.log  2>&1 &
        while true; do
          installRes=`tail -1 $Increment-twohour/$dateIncre/incre-twohour.log |cut -d " " -f 3-4`
          if   [[ "${installRes}" = "completed OK!" ]];then
               echo "Incremental backups from the first incremental backups ok............" 
               sleep 10
               break
         elif [[ "${installRes}" = "completed OK!" ]];then
              echo "Incremental backups from the first incremental backups ok............" 
              sleep 10
              break
        else
         sleep 10
         continue
       fi
       done
fi
' > /home/mysql/innobackupex_incrementbackupdata.sh
chmod a+x  /home/mysql/innobackupex_incrementbackupdata.sh

###3、开启定时任务  
cat >> /etc/crontab <<EOF
#每周六凌晨一次的全备份 
10 2 * * 6 root /home/mysql/innobackupex_fullbackupdata.sh > /dev/null 2>&1 
#每天一次的全增量（以全备份为基础的增量），每两个小时一次的增量备份（以全增量为基础的增量）
50 1-23/2 * * * root /home/mysql/innobackupex_incrementbackupdata.sh > /dev/null 2>&1 
EOF
crontab /etc/crontab
crontab -l


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


#注意恢复之前的准备工作：
#1、备份文件拷贝到一个文件夹，防止出错后无法二次恢复（全备文件和二进制日志文件，权限及属主）
#2、关闭二进制日志文件（注释配置文件二进制日志记录，重启mysql）
#3、整合完整备份和增量备份：
    #注意：一定要按照完整备份、第一次增量备份、第二次增量备份的顺序进行整合，在整合最后一次增量备份时不要使用–redo-only参数
    #innobackupex --apply-log --redo-only /home/mysql/dump/full/20190419/
    #innobackupex --apply-log --redo-only /home/mysql/dump/full/20190419/ --incremental-dir=/home/mysql/dump/increment/20190419/
    #innobackupex --apply-log /home/mysql/dump/full/20190419/ --incremental-dir=/home/mysql/dump/increment-twohour/20190419_161703
    #innobackupex --apply-log /home/mysql/dump/full/20190419/
    #开始还原
    #innobackupex --copy-back /home/mysql/dump/full/20190419/
#4、恢复二进制：mysqlbinlog --no-defaults --start-position=235 [--database=test --set-charset=utf8mb4] mysql-bin.00001 | mysql -uroot -pRoot_123456*0987 [test]
#               mysqlbinlog --no-defaults --start-datetime="2019-04-19 22:01:08" [--database=test --set-charset=utf8mb4] mysql-bin.00001 | mysql -uroot -pRoot_123456*0987 [test]