#!/bin/bash

PCAP="$1"	    # pcap filename
CLIENT_IP="$2"	    # IP address of the reqesting host
RESOLVER_IP="$3"    # IP address of the resolver
NAME_OUTFILE="$4" # name of the outfile csv

NAME_OUTFILE_PROV="prov_${NAME_OUTFILE}"
echo "$NAME_OUTFILE_PROV"


# Initialisation of csv outfile provisoire
rm -f $NAME_OUTFILE_PROV
touch $NAME_OUTFILE_PROV

echo "slot,time_begin,time_end,nb_request" > "$NAME_OUTFILE_PROV"

# Treatment of requests data
# Extrait les timestamps epoch des paquets répondant aux critères du filtre
tshark -r $PCAP -Y "dns && !icmp && dns.flags.response == 0 && ip.src == $CLIENT_IP && ip.dst == $RESOLVER_IP && !dns.retransmit_request" -T fields -e frame.time_epoch | 

awk -v outfile_prov="$NAME_OUTFILE_PROV" '
NR==1 {
    nb_slot = 1
    prev = $1
    last_slot_begin = $1
    nb_req = 1
    next
}

{
    gap = $1 - prev          # FLOAT MATH (awk handles float natively)

    if (gap > 2.0) {         # FLOAT COMPARISON, works naturally in awk
        slot_end = prev

        # CSV output
        print nb_slot "," last_slot_begin "," slot_end "," nb_req >> outfile_prov

        last_slot_begin = $1
        nb_req = 0
        nb_slot += 1
    }

    nb_req += 1
    prev = $1
}

END {
    print nb_slot "," last_slot_begin "," prev "," nb_req >> outfile_prov
}

'

# Treatment of responses data
# Extrait les timestamps epoch et les délais de réponse des paquets répondant aux critères du filtre
tshark -r $PCAP -Y "dns && !icmp && dns.flags.response == 1 && ip.dst == $CLIENT_IP && ip.src == $RESOLVER_IP && !dns.retransmit_response" -T fields -e frame.time_epoch -e dns.time | 

awk -v outfile_prov="$NAME_OUTFILE_PROV" -v outfile="$NAME_OUTFILE" '
BEGIN {
    # Charger les intervalles
    
    n=0

    while ((getline < outfile_prov) > 0) {

        if (n == 0) { 
            header = $0 
            n++ 
            continue 
        }

        split($0, fields,",")
        
        times_end[n]=fields[3] # Tableau associatif de time_end
        line[n]=$0 #  Tableau associatif avec la ligne entière
        n++
    }
    slot=1
    count = 1
}

NR==1 {
    epoch = $1
    delay = $2
    delay_square = delay * delay
    
    delay_cumulative = delay
    delay_square_cumulative = delay_square
    tend = times_end[slot]
    next
}

{
    epoch = $1
    delay = $2
    delay_square = delay * delay
    
    if (epoch>tend+5) {
        nb_responses[slot]=count
        delay_cumul[slot] = delay_cumulative

        delay_moy[slot] = delay_cumulative / count
        delay_var[slot] = (delay_square_cumulative / count) - (delay_cumulative / count)^2
        
        slot += 1
        tend = times_end[slot]
        count = 0
        delay_cumulative = 0
        delay_square_cumulative = 0
    }
    count += 1
    delay_cumulative += delay
    delay_square_cumulative += delay_square

    
    
    
    
}

END {
    nb_responses[slot]=count
    delay_cumul[slot] = delay_cumulative
    delay_moy[slot] = delay_cumulative / count
    delay_var[slot] = (delay_square_cumulative / count) - (delay_cumulative / count)^2

    # Header + nouvelle colonne
    print "slot,time_begin,time_end,nb_request,nb_response,delay_resp_cumulative,mean_delay,var_delay" >> outfile

    for (i = 1; i < n; i++) {
        print line[i] "," nb_responses[i] "," delay_cumul[i] "," delay_moy[i] "," delay_var[i] >> outfile
    }
    
}

'