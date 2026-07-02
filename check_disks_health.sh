#!/bin/bash

BOT_TOKEN="EL TOKEN DE TU BOT"
CHAT_ID="EL ID DE TU CUENTA EN TELEGRAM"
LOG_FILE=/var/log/check_disks.log # El log se limpiará mediante logrotate.
HOSTNAME=$(hostname)

# Se añaden las rutas por si cron o anacron las necesitan
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

enviar_alerta() {
	local mensaje="$HOSTNAME tiene la siguiente alerta de disco: $1"

   # Enviar notificación a Telegram
   curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
	   -d "chat_id=$CHAT_ID" \
	   --data-urlencode "text=$mensaje" > /dev/null
   }

# sd[a-z]: Linux no mantiene fijo el fichero del disco sino que se lo asigna en función del orden de "llegada" (orden en que "despiertan" los discos)
for disco in /dev/sd[a-z]; do
	# Si no es un fichero de disco salta al siguiente dispositivo
	if ! test -b "$disco" ; then
		continue
	fi
	# El flag -n standby evita despertar al disco si está dormido, así se evita desgaste innecesario.
	LSTR=$(smartctl -H -n standby "$disco" 2>&1)

	# Los dormidos que sigan con Morfeo. El lector de tarjetas vacío (usb bridge) se ignora:
	if echo "$LSTR" | grep -iqE "Device is in Standby|unknown usb bridge"; then
		continue
	fi

	# Si la salud general no es PASSED, alerta al canto
	if ! echo "$LSTR" | grep -qE "PASSED|OK"; then
		# Extrae modelo y nº de serie del disco
		IDENTIDAD=$(lsblk -d -n -o MODEL,SERIAL "$disco" | xargs)

	    # fallback para embellecer el mensaje en el improbable caso de que lsblk salga con un chorro de babas
	    if test -z "$IDENTIDAD" ; then
		    IDENTIDAD="desconocido"
	    fi
	    MENSAJE="El disco [$IDENTIDAD] (actualmente $disco) reporta problemas. Output: $LSTR"
	    enviar_alerta "$MENSAJE"	    
	    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MENSAJE" >> $LOG_FILE
	fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Chequeo finalizado." >> $LOG_FILE
