#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd /usr/local/bin

ip_file="ip.txt"

ip=$(nslookup ee1.eter.cloud | sed -n '6p' | sed -n 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\n\1/;s/^.*\n//p')
if [ -f $ip_file ]; then
	old_ip=$(cat $ip_file)
       	if [ $ip == $old_ip ]; then
       		echo "IP has not changed."
       		exit 0
    	fi
fi
echo ${ip} > $ip_file

Set_Config(){
	forwarding_port="1000"
	forwarding_ip=$(nslookup a.example.com | sed -n '6p' | sed -n 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\n\1/;s/^.*\n//p')
	local_port="1000"
	local_ip="192.168.X.X"
	forwarding_type="TCP+UDP"
}

Set_Config1(){
	forwarding_port="20000"
	forwarding_ip=$(nslookup b.example.com | sed -n '6p' | sed -n 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\n\1/;s/^.*\n//p')
	local_port="20000"
	local_ip="192.168.X.X"
	forwarding_type="TCP+UDP"
}

Add_forwarding(){
	Set_Config
	local_port=$(echo ${local_port} | sed 's/-/:/g')
	forwarding_port_1=$(echo ${forwarding_port} | sed 's/-/:/g')
	Add_iptables "tcp"
	Add_iptables "udp"
	Save_iptables

	sleep 3
	Set_Config1
	local_port=$(echo ${local_port} | sed 's/-/:/g')
	forwarding_port_1=$(echo ${forwarding_port} | sed 's/-/:/g')
	Add_iptables "tcp"
	Add_iptables "udp"
	Save_iptables
}

Uninstall_forwarding(){
	forwarding_text=$(iptables -t nat -vnL PREROUTING|tail -n +3)
	echo ${forwarding_text}
	forwarding_total=$(echo -e "${forwarding_text}"|wc -l)
	echo ${forwarding_total}
	for((integer = 1; integer < ${forwarding_total}; integer++))
	do
		forwarding_type=$(echo -e "${forwarding_text}"| awk '{print $4}' | sed -n "${integer}p")
                forwarding_listen=$(echo -e "${forwarding_text}"| awk '{print $11}' | sed -n "${Del_forwarding_num}p" | awk -F "dpt:" '{print $2}' | sed 's/-/:/g')
                [[ -z ${forwarding_listen} ]] && forwarding_listen=$(echo -e "${forwarding_text}"| awk '{print $11}' |sed -n "${Del_forwarding_num}p" | awk -F "dpts:" '{print $2}')
		forwarding_type=$(echo -e "${forwarding_text}"|awk '{print $4}'|sed -n "${integer}p")
		forwarding_listen=$(echo -e "${forwarding_text}"|awk '{print $11}'|sed -n "${integer}p"|awk -F "dpt:" '{print $2}')
		[[ -z ${forwarding_listen} ]] && forwarding_listen=$(echo -e "${forwarding_text}"| awk '{print $11}'|sed -n "${integer}p"|awk -F "dpts:" '{print $2}')
		# echo -e "${forwarding_text} ${forwarding_type} ${forwarding_listen}"
		Del_iptables "${forwarding_type}" "${integer}"
	done
	Save_iptables
}

Add_iptables(){
	iptables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}":"${forwarding_port}"
	iptables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j SNAT --to-source "${local_ip}"
	echo "iptables -t nat -A PREROUTING -p $1 --dport ${local_port} -j DNAT --to-destination ${forwarding_ip}:${forwarding_port}"
	echo "iptables -t nat -A POSTROUTING -p $1 -d ${forwarding_ip} --dport ${forwarding_port_1} -j SNAT --to-source ${local_ip}"
	echo "${local_port}"
	iptables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
}

Del_iptables(){
	iptables -t nat -D POSTROUTING "$2"
	iptables -t nat -D PREROUTING "$2"
	iptables -D INPUT -m state --state NEW -m "$1" -p "$1" --dport "${forwarding_listen}" -j ACCEPT
}

Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}

Uninstall_all(){
	for i in $(iptables -t nat --line-numbers -L PREROUTING | grep ^[0-9] | awk '{ print $1 }' | tac )
	do
		iptables -t nat -D PREROUTING $i
        done
}

Uninstall_all
sleep 3
Add_forwarding
