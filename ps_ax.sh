#!/bin/bash
regex="pts.*"
echo -e "PID\tTTY\tSTAT\tTIME\tCOMMAND"
for i in `ls -1 /proc | grep -E "[0-9]+" | sort -n`; do
if [[ ! -d /proc/$i ]]; then
        continue
fi
echo -ne "$i\t"
if [[ ! -h /proc/$i/fd/0 ]]; then
        echo -ne "?\t";
else
tty=`ls -l /proc/$i/fd/0 | awk '{print substr($NF, 6)}'`
if [[ $tty =~ $regex ]]; then
        echo -ne "$tty\t";
else
        echo -ne "?\t"
fi
fi
echo -n `cat /proc/$i/stat | awk '{print $3}'`
if [[ `awk '{print $18}' /proc/$i/stat` -lt 20 ]]; then echo -n "<"; fi
if [[ `awk '{print $18}' /proc/$i/stat` -gt 20 ]]; then echo -n "N"; fi
locked=`cat /proc/$i/status | grep VmLck | awk '{print $2}'`
if [[ ! -z $locked && $locked -gt 0 ]]; then echo -n "L"; fi
if [[ `awk '{print $6}' /proc/$i/stat` -eq $i ]]; then echo -n "s"; fi
if [[ `ls -1 /proc/$i/task | wc -l` -gt 1 ]]; then echo -n "l"; fi
if [[ `awk '{print $5}' /proc/$i/stat` -eq `awk '{print $5}' /proc/self/stat` ]]; then echo -n "+"; fi
echo -ne "\t"
secs=$((`awk '{print $15+$14}' /proc/$i/stat`/`getconf CLK_TCK`))
echo -n $((secs/60)):$((secs%60/10))$((secs%10))
echo -ne "\t"
cmd=`cat /proc/$i/cmdline`
if [[ -z $cmd ]]; then
        echo -ne "[`cat /proc/$i/comm`]\n"
else
        cat /proc/$i/cmdline
        echo ""
fi
done