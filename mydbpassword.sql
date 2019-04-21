update mysql.user set authentication_string=PASSWORD('Root_123456*0987') where User='root';
flush privileges;
set names utf8mb4;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Root_123456*0987';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Root_123456*0987' WITH GRANT OPTION;
flush privileges;
/*
set global validate_password_policy=0;
set global validate_password_length=4;
*/