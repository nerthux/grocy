#!/bin/bash
# Arranque de la imagen propia: prepara data/ y levanta php-fpm y nginx.
# Si cualquiera de los dos muere, el contenedor sale y decide la política de reinicio.
set -euo pipefail

cd /var/www/grocy

if [ ! -w data ]; then
	echo "grocy: $(pwd)/data no es escribible por $(id -un) (uid $(id -u))." >&2
	echo "grocy: usa un volumen con nombre, o dale ese dueño a la carpeta montada." >&2
	exit 1
fi

if [ ! -f data/config.php ]; then
	echo "grocy: no hay data/config.php; se copia de config-dist.php"
	cp config-dist.php data/config.php
fi

mkdir -p /tmp/nginx

php-fpm -F &
nginx -g 'daemon off;' &

# La imagen php:fpm declara STOPSIGNAL SIGQUIT; QUIT es el apagado ordenado
# de nginx y de php-fpm, así que se les reenvía ésa sea cual sea la que llegue
stopping=0
trap 'stopping=1; kill -QUIT $(jobs -p) 2>/dev/null' TERM INT QUIT

# Sale en cuanto termine uno de los dos (o llegue una señal)
set +e
wait -n
status=$?
kill -QUIT $(jobs -p) 2>/dev/null
wait

# Una parada pedida sale con 0; la caída de un proceso, con error
if [ "$stopping" = 1 ]; then
	exit 0
fi
echo "grocy: un proceso terminó solo (código $status); se baja el contenedor" >&2
exit "$(( status == 0 ? 1 : status ))"
