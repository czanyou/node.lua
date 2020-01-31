#!/bin/sh
#请把dns1,dns2修改成拼得通的DNS,开机自动运行,实时监控,断线自动重拨
# dns1="211.95.193.97"
# dns2="211.136.20.203"
# sleep 8
# pppd call quectel-ppp &
chat -s -v -f /etc/ppp/peers/quectel-chat-connect
 echo "hello"
# lnode /usr/local/lnode/app/lci/lua/ppp.lua 
# lnode -l /usr/local/lnode/app/lci/data/ppp
# sleep 12
# while true
# do
#        ping -s 1 -c 1 $dns1 #去PING第一个DNS
#        if [ "$?" != "0" ] #假如PING不通
#        then

#            ping -s 1 -c 2 $dns2 #去PING第二个DNS
#            if [ "$?" != "0" ] #假如PING不通 
#            then 
#               killall pppd #结束PPPD进程
#               pppd call quectel-ppp&  #再去拨号
#               sleep 12 #等待12秒
#               sleep 5 #如果是PING DNS2通的话就直接等待5秒
#            fi 
#        else
#               sleep 5 #如果是PING DNS1通的话就直接等待5秒（一般要设置多长时间去PING请改这里）
#        fi 
# done
