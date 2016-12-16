#!/bin/bash

mkdir -p /data/logs/redis
mkdir -p /data/logs/nginx
mkdir -p /data/casino/logs/logic
mkdir -p /data/casino/logs/login
mkdir -p /data/casino/backup/logic
mkdir -p /data/casino/backup/login

mkdir -p ~/csdeploy/app/exec
ln -s /data/casino/backup ~/csdeploy/app/exec/backup
mkdir -p ~/csdeploy/app/tool
mkdir -p ~/csdeploy/excel
mkdir -p ~/csdeploy/config
mkdir -p ~/csdeploy/conf
mkdir -p ~/csdeploy/sql
mkdir -p ~/csdeploy/robot

cat >~/csdeploy/logic.sh <<EOF
#!/bin/bash

config_path=\$HOME/csdeploy/config
args=(1,2)

TEMP=\`getopt -o o:P:p:h --long operate:,process:,passwd:,help -- "\$@"\`
eval set -- "\${TEMP}"
while true ; do
    case "\${1}" in
        -o|--operate)
            OPERATE="\${2}"
            shift 2
            ;;
        -P|--process)
            PROCESS_ID="\${2}"
            shift 2
            ;;
        -p|--passwd)
            PASSWD="\${2}"
            shift 2
            ;;
        -h|--help)
            echo "-o/--operate      restart | start | stop"
            echo "-P/--process      1 | 2"
            echo "-p/--passwd       casino | 空"
            exit
            ;;
        --)
            shift # 移动一位参数
            break
            ;;
    esac
done

if [ -z \${PROCESS_ID} ]; then
    echo "lose process_id."
    exit
fi
if [[ "\${args[@]}" =~ "\${PROCESS_ID}" ]]; then
    echo "process_id is \${PROCESS_ID}"
else
    echo "process_id is 1 or 2, not \${PROCESS_ID}"
    exit
fi
# 验证密码
if [ -z \${PASSWD} ]; then
    echo 'please input password:'
    read PASSWD
fi
if [ "\${PASSWD}" != "casino" ]; then
    exit
fi

# 设置参数
if [ \${PROCESS_ID} == 1 ]; then
    logic_port=8082
elif [ \${PROCESS_ID} == 2 ]; then
    logic_port=8088
fi
gmt_port=\$((\$logic_port+1))
http_port=\$((\$logic_port+100))

if [ "\${OPERATE}" != "stop" ]; then
    sed \\
        -e "s|process-id|\$PROCESS_ID|g" \\
        -e "s|logic-port|\$logic_port|g" \\
        -e "s|http-port|\$http_port|g" \\
        -e "s|gmt-port|\$gmt_port|g" \\
        \$config_path/logic.ini.back > \$config_path/logic.ini
fi

/home/casino/python/bin/supervisorctl -s http://localhost:9500 -u 'casino' -p 'casino!!@@__))' \${OPERATE} casino_logic\${PROCESS_ID}
EOF

cat >~/csdeploy/login.sh <<EOF
#!/bin/bash

if [ \$# -gt 0 ]; then
    op_type=\$1
else
    op_type='restart'
fi

/home/casino/python/bin/supervisorctl -s http://localhost:9500 -u 'casino' -p 'casino!!@@__))' \${op_type} casino_login
EOF

cat >~/csdeploy/excel/dump.sh <<EOF
#!/bin/bash

if [ \$# != 2 ]; then
    echo "args number is 2."
    exit
fi
locale=(en,zh)
if [[ ! "\${locale[@]}" =~ "\${2}" ]]; then
    echo "arg is error."
    exit
fi
db_user='casino'
db_passwd='casino!!@@__))'

mysql -t -u \$db_user -p\$db_passwd -h\${1} casino_pro_excel < schema_\${2}.sql
mysql -t -u \$db_user -p\$db_passwd -h\${1} casino_pro_excel < data_\${2}.sql
EOF

cat >~/csdeploy/excel/dump_slot.sh <<EOF
#!/bin/bash

if [ \$# != 1 ]; then
    echo 'lose db host.'
    exit
fi
db_user='casino'
db_passwd='casino!!@@__))'

mysql -t -u \$db_user -p\$db_passwd -h\${1} casino_pro_excel < slotlist.sql
EOF

cat >~/csdeploy/sql/exec_upsql.sh <<EOF
#!/bin/bash

while getopts :h:o: opt; do
    case \$opt in
        h)
            HOST=\$OPTARG
            ;;
        o)
            OPERATE=\$OPTARG
            ;;
        \\?)
            echo '-h: db host'
            echo '-o: file type for (schema, update)'
            exit
    esac
done

db_user='casino'
db_passwd='casino!!@@__))'
mysql -t -u \$db_user -p\$db_passwd -h \${HOST} < \${OPERATE}.sql
mysql -t -u \$db_user -p\$db_passwd -h \${HOST} < \${OPERATE}_log.sql
EOF