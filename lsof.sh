#!/bin/bash
function begin() {
        echo -ne "$command\t$pid\t$user\t"
}
function info() {
        regdel=".*(deleted)"
        regsock="socket:\[.*\]"
        reganon="anon_inode:.*"
        regrun="/run/.*"
        regpipe="pipe:\[.*\]"
        if [[ -f $1 ]]; then type="REG";
        elif [[ -d $1 ]]; then type="DIR";
        elif [[ -c $1 ]]; then type="CHR";
        elif [[ -b $1 ]]; then type="BLK";
        elif [[ $1 =~ $regrun ]]; then type="FIFO";
        elif [[ $1 =~ $regdel ]]; then type="DEL";
        elif [[ $1 =~ $regpipe ]]; then
                printf "FIFO\t%-19s%-11s" "0,9" "0";
                number=`echo $1 | awk -F '[' '{print $2}' | awk -F ']' '{print $1}'`
                printf "%-11spipe\n" "$number"
                return
        elif [[ $1 =~ $reganon ]]; then
                printf "a_inode\t%-19s%-11s" "0,10" "0"
                printf "%-11s" `ls -lHi ./fd/$number | awk '{print $1}'`
                echo -ne `echo $1 | awk -F ':' '{print $2}'`
                echo ""
                return
        elif [[ $1 =~ $regsock ]]; then
                number=`echo $1 | awk -F '[' '{print $2}' | awk -F ']' '{print $1}'`
                result=`grep -rn $number /proc/net`
                domain=`echo $result | awk -F ':'  '{print $1}' | awk -F '/' '{print $NF}'`
                if [[ $domain == "netlink" ]]; then
                        printf "netlink\t%-19s%-11s" "" "0t0";
                        printf "%-11s" `echo $result | awk '{print $10}'`
                        netlink=`echo $result | awk '{print $2}'`
                        case $netlink in
                                0) echo -n ROUTE;;
                                1) echo -n UNUSED;;
                                2) echo -n USERSOCK;;
                                3) echo -n FIREWALL;;
                                4) echo -n SOCK_DIAG;;
                                5) echo -n NFLOG;;
                                6) echo -n XFRM;;
                                7) echo -n SELINUX;;
                                8) echo -n ISCSI;;
                                9) echo -n AUDIT;;
                                10) echo -n FIB_LOOKUP;;
                                11) echo -n CONNECTOR;;
                                12) echo -n NETFILTER;;
                                13) echo -n IP6_FW;;
                                14) echo -n DNRTMSG;;
                                15) echo -n KOBJECT_UEVENT;;
                                16) echo -n GENERIC;;
                                18) echo -n SCSITRANSPORT;;
                                19) echo -n ECRYPTFS;;
                                20) echo -n RDMA;;
                                21) echo -n CRYPTO;;
                                22) echo -n SMC;;
                        esac
                        echo ""
                        return
                elif [[ $domain == "unix" ]]; then
                        echo -ne "unix\t";
                        echo -ne "0x`echo $result | awk -F ':' '{print $3}'` "
                        printf "%-11s%-11s" "0t0" "$number"
                        mysock=`echo $result | awk '{print $8}'`
                        if [[ -z $mysock ]]; then echo -n "socket"; else echo -n $mysock; fi
                        echo ""
                        return
                elif [[ $domain == "tcp" || $domain == "udp" ]]; then
                        echo -ne "IPv4\t";
                        printf "%-19s%-11s" "$number" "0t0";
                        if [[ $domain -eq "tcp" ]]; then printf "%-11s" "TCP"; else printf "%-11s" "UDP"; fi;
                        echo $result | awk '{print $3" "$4" "$5}' | { read Local remote state
                        echo $Local | awk -F ':' '{print $1" "$2}' | { read local_ip local_port
                        echo $remote | awk -F ':' '{print $1" "$2}' | { read remote_ip remote_port
                        local_port=$((16#$local_port))
                        remote_port=$((16#$remote_port))
                        state=$((16#$state))
                        temp=`cat /etc/services | grep -w "${local_port}/${domain}" | awk '{print $1}'`
                        if [[ -n $temp ]]; then local_port=$temp; fi
                        temp=`cat /etc/services | grep -w "${remote_port}/${domain}" | awk '{print $1}'`
                        if [[ -n $temp ]]; then remote_port=$temp; fi
                        local_ip=`printf '%d.%d.%d.%d\n' $(echo $local_ip | sed 's/../0x& /g' |  tr ' ' '\n' | tac | tr '\n' ' ' )`
                        remote_ip=`printf '%d.%d.%d.%d\n' $(echo $remote_ip | sed 's/../0x& /g' |  tr ' ' '\n' | tac | tr '\n' ' ')`
                        temp=`getent hosts $local_ip | awk '{print $2}'`
                        if [[ -n $temp ]]; then local_ip=$temp; fi
                        temp=`getent hosts $remote_ip | awk '{print $2}'`
                        if [[ -n $temp ]]; then remote_ip=$temp; fi
                        echo -ne "$local_ip:$local_port->$remote_ip:$remote_port ("
                        arr=(ESTABLISHED SYN_SENT SYN_RECV FIN_WAIT1 FIN_WAIT2 TIME_WAIT CLOSE CLOSE_WAIT LAST_ACK LISTEN CLOSING NEW_SYN_RECV)
                        echo -ne "${arr[${state}-1]}"
                        echo ")"
                        }
                        }
                        }
                        return
                fi
        fi
        echo -ne "$type\t"
        fs=$(df $1 | tail -n +2 | awk '{print $1}')
        if [[ $fs == "cgroup" || $fs == "proc" || $fs == "tmpfs" ]]; then
                printf "%-19s" "0,`stat $1 | grep Device: | awk -F '/' '{print $2}' | awk -F 'd' '{print $1}'`"
        else
                if [[ $fs == "devtmpfs" || $fs == "devpts" ]]; then
                        fs=$1
                fi
                printf "%-19s" `ls -l $fs | awk '{print $5$6}'`
        fi
        if [[ $type == "CHR" || $type == "FIFO" ]]; then
                printf "%-11s" "0t0";
        else
                printf "%-11s" `ls -ld $1 | awk '{print $5}'`
        fi
        printf "%-11s" `ls -ldi $1 | awk '{print $1}'`
        echo -n $1
        echo ""
}
if [[ -z $1 ]]; then echo "Script must contain one argument!"; exit 1; fi
if [[ ! -d /proc/$1 ]]; then echo "No process with PID $1!"; exit 1; fi
cd /proc/$1
printf "COMMAND\tPID\tUSER\tFD\tTYPE\t%-19s%-11s%-11sNAME\n" "DEVICE" "SIZE/OFF" "NODE"
command=`cat comm`
pid=$1
user=`ls -ld ./ | awk '{print $3}'`
begin
echo -ne "cwd\t"
file=`ls -ld ./cwd | awk '{print $NF}'`
info $file
begin
echo -ne "rtd\t"
file=`ls -ld ./root | awk '{print $NF}'`
info $file
begin
echo -ne "txt\t"
file=`ls -ld ./exe | awk '{print $NF}'`
info $file
for memory in `ls -l ./map_files/ | tail -n +2 | awk '{print $NF}' | sort | uniq | grep -v $file `; do
begin
echo -ne "mem\t"
info $memory
done
IFS=$'\n'; for entry in `ls -l ./fd | tail -n +2 | awk '{print $1" "$9" "$11}' | sort -nk 2 `; do
IFS=' '; echo $entry | { read mode number file
begin
echo -n "$number"
regboth="lrw.*"
regread="lr-.*"
regwrite="l-w"
if [[ $mode =~ $regboth ]]; then
   echo -ne "u\t"
elif [[ $mode =~ $regread ]]; then
   echo -ne "r\t"
elif [[ $mode =~ $regwrite ]]; then
   echo -ne "w\t"
fi
info $file
}
done
cd - >/dev/null