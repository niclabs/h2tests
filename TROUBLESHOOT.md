# Para referencia

El código consiste de los siguientes elementos
    
- tools/slip-radio código para nodo a8_m3 (sacado de https://github.com/cetic/contiki/tree/sixlbr/examples/ipv6/slip-radio) este implementa el protocolo SLIP para recibir paquetes por el serial del nodo A8
- tools/slip-bridge codigo para crear interfaz virtual tun que trasforma
    paquetes IPv6 en 6lowpan y vice versa, si se corre con -r permite al nodo
    servidor actuar como border router
- scripts/nghttpd.sh ejecuta el servidor nghttpd en el PATH (tambien busca bajo
    el directorio bin) y espera hasta recibir el caracter 'q' via la entrada
    estandar, al terminar imprime (o genera un archivo) con los datos de carga
    del proceso capturados con top
- scripts/h2load.sh ejecuta sh con los parametros dados y guarda los datos a un
    archivo (si -o está definido) o a stdout
- scripts/nghttpd.awk,h2load.awk,h2load-totals.awk el primero lee los datos
generados por nghttpd.sh e imprime una linea con los promedios de cpu y
memoria, el segundo extrae datos de la salida de h2load y el tercero promedia
los valores entregados finalmente por h2load.sh
- ./run_experiment.sh, ejecuta una serie de experimentos con los parámetros dados iterandos sobre los parámetros de configuracion de http2. Genera resultados bajo el directorio results con el valor dado por el parametro -n (name), los archivos generados son
    - results/<name>/[header_table_size.txt | max_frame_size | window_bits | max_header_list_size].txt compilado con resultados de variación del parametro dado por el nombre del archivo. Si el archivo ya existe, el script intenta reiniciar desde el punto dado
    - results/<name>/clients/h2load-<header_table_size>-<window_bits>-<max_frame_size>-<max_header_list_size>.txt resultados de la ejecución de h2load con los parametros dados
    - results/<name>/server/nghttp-<header_table_size>-<window_bits>-<max_frame_size>-<max_header_list_size>.txt resultados de la ejecución de nghttpd con los parametros dados

Ejemplos de uso

- ./run_experiment.sh -s 3 -c 1,2,4,5,7 -a 2001:dead:beef::1 -p 80 -n
    802.15.4-test --h2-clients=1 --h2-requests=100
    ejecuta el experimento con el servidor corriendo en el nodo iot-lab 3 y los
    clientes en los nodos iot-lab 1,2,3,4,7 asignando la ip
    '2001:dead:beef::1', ejecutando el servidor en el puerto 80, usando el
    nombre 802.15.4-test y ejecutando h2load con 1 cliente y 100 requests
- ./run_experiment.sh -s 3 -a 2001:660:5307:3000::3 -p 80 -n
    802.15.4-test --h2-clients=100 --h2-requests=1000, ejecuta el experimento
    en el nodo 3 como servidor y cliente en la maquina local y usando la IP del nodo 2001:660:5307:3000::3 y
    puerto http 80, 100 clientes y 1000 requests para h2load


IMPORTANTE
- el comando run-experiment.sh esta configurado para correr desde el servidor iot-lab hacia el
    nodo, en mi cuenta ya tengo el cliente y servidor compilado tanto para el
    nodo como para el servidor iot-lab Los binarios para el nodo estan en la carpeta
    bin/ y los de servidor estan en ~/.local/bin (evita recompilar que para el
    servidor fue un cacho)
- slip-bridge no soporta multiples threads escribiendo a la misma vez en la
    interfaz, si se quiere probar multiples clientes inalambricos se debe
    correr h2load usando multiples clientes iot-lab en run-experiment
- dependiendo de donde estan corriendo los clientes y el servidor,
    run-experiment sabe si tiene que crear un experimento o activar las
    interfaces tun. Si nghttpd va correr en el nodo y el cliente en el servidor
    iot-lab, es necesario usar la ip correcta del nodo (en interfaz eth0 del nodo)
- el script lanza el experimento automaticamente si no hay uno corriendo, pero
    si se quieren cambiar los parametros -c y -s (ej, pasar de 1
    a 2 nodos clientes), es necesario parar el experimento para volver a echar
    a andar, esto se puede hacer con 'make iotlab-stop' (ejecutar desde la raiz
    del directorio h2tests)
- para correr los comandos estoy usando TMUX con una configuracion propia, tmux
    tiene varios comandos para abrir y cerrar paneles y navegar entre ellos.
    La lista de key-bindings que estoy usando está acá
    https://github.com/samoshkin/tmux-config#key-bindings
