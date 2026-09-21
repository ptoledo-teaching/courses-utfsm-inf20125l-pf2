# PF2: Depuración mediante trazas de estado

## Introducción

Este laboratorio profundiza la depuración mediante instrumentación iniciada en PF1. Se enfoca en la problemática que surge cuando un programa modifica su estado repetidamente: observar solamente el resultado final puede ser insuficiente para identificar en qué momento se origina un fallo. Esto hace necesario comparar los valores antes y después de cada operación relevante y acotar la observación para distinguir la información útil.

En este laboratorio se utilizarán trazas enviadas a `stderr` y condiciones que limitan cuándo se muestran. La metodología combina observación de los cambios de estado, formulación de hipótesis, corrección y ejecución repetida de la suite.

### Prerrequisitos

- Haber completado PF1
- Saber compilar programas en C con warnings estrictos
- Saber editar código con Vim
- Saber ejecutar y comparar test cases
- Saber separar `stdout` y `stderr` mediante redirecciones

### Objetivo general

- Diagnosticar fallos en un programa que modifica su estado durante una secuencia de eventos

### Objetivos específicos

- Implementar una función auxiliar que envíe trazas a `stderr`
- Comparar los estados observados para identificar cambios incorrectos
- Elegir qué valores y eventos conviene observar
- Combinar controles globales y locales para limitar el volumen de una traza
- Corregir fallos de manera incremental y comprobar la suite completa
- Mantener separadas las trazas de depuración y la salida especificada

### Estructura inicial

```text
workspace/
├── code/
│   └── escudos.c
├── scripts/
│   ├── check.sh
│   └── tests-run.sh
└── tests/
    ├── test001.expected
    ├── test001.in
    ├── ...
    ├── test010.expected
    └── test010.in
```

El programa se edita y compila dentro de `workspace/code`. El script `tests-run.sh` ejecuta la suite y compara cada salida con su archivo `.expected`. El script `check.sh` permite revisar qué actividades están completas y cuáles permanecen pendientes.

## Contexto

Para enfrentarse al Imperio Galáctico, las naves de la Alianza Rebelde disponen de escudos magnéticos para desviar los ataques de las naves imperiales. Como estos ataques pueden llegar desde cualquier dirección en el espacio, el sistema de escudos se divide en seis sectores: frente, atrás, izquierda, derecha, arriba y abajo. Cada sector puede almacenar hasta 40 unidades de energía de disipación. Además, existe una reserva compartida desde la cual se puede destinar energía para reforzar cualquiera de los sectores cuando los ataques provienen principalmente desde una dirección. Así, la energía total del sistema de escudos corresponde a la suma de la reserva y las energías de los seis sectores; sin embargo, dado el peso de las baterías de almacenamiento, la capacidad máxima disponible al inicio de un combate es de 120 unidades.

La energía de disipación puede transferirse desde la reserva hacia cualquier sector, así como entre sectores. Para realizar esta operación, el ingeniero de escudos decide explícitamente el origen, el destino y la cantidad de energía que desea trasladar. Así, una decisión como *toda la potencia a los escudos frontales* puede expresarse mediante varias transferencias desde la reserva o desde otros sectores hacia el escudo frontal.

La cantidad efectivamente trasladada puede ser menor que la solicitada si el origen no dispone de suficiente energía o si el destino no tiene espacio para recibirla. Ningún sector puede superar su capacidad máxima de 40 unidades y una transferencia nunca puede dejar al origen con energía negativa. Como la energía solo cambia de ubicación, la energía total del sistema se conserva durante estas operaciones.

Cuando la nave recibe un impacto, este afecta exclusivamente al sector indicado. Al recibirlo, el blindaje propio de la nave absorbe hasta dos unidades de daño; por ello, un ataque con potencia igual o inferior a dos no reduce la energía del escudo ni daña la nave. La potencia restante del ataque, después de la absorción del blindaje, se descuenta de la energía del sector afectado. Si esa energía no alcanza para disipar el ataque, el sector queda en cero y el daño excedente se transmite a la nave.

El sistema de escudos puede encontrarse en los estados `operativo` o `critico` dependiendo de su energía total, no de la energía de un sector en particular. Se considera `operativo` si, después de procesar todos los eventos, la energía total del sistema es al menos 30; si queda por debajo de ese valor, se considera `critico`. Sin embargo, si por una mala gestión de la energía de disipación la nave recibe 10 o más unidades de daño, se considera destruida. Es decir, puede suceder que una nave conserve un sistema de escudos en estado `operativo` pero, debido a una distribución inadecuada de la energía, la nave haya sido destruida de todos modos. La simulación procesa todos los eventos indicados, incluso si la nave alcanza antes el umbral de destrucción, para informar el daño acumulado al final.

### Entrada y salida

La entrada comienza con ocho números enteros, uno por línea, en el siguiente orden:

1. Energía inicial de la reserva
2. Energía inicial del escudo frontal
3. Energía inicial del escudo trasero
4. Energía inicial del escudo izquierdo
5. Energía inicial del escudo derecho
6. Energía inicial del escudo superior
7. Energía inicial del escudo inferior
8. Cantidad de eventos que se procesarán

A continuación aparece un evento por línea. Existen dos formatos:

- `impacto <SECTOR> <POTENCIA>` representa un impacto sobre un sector
- `transferencia <ORIGEN> <DESTINO> <CANTIDAD>` solicita trasladar energía entre dos ubicaciones

Los nombres de sector son `frente`, `atras`, `izquierda`, `derecha`, `arriba` y `abajo`. El origen de una transferencia también puede ser `reserva`, pero el destino siempre debe ser uno de los seis sectores. Por ejemplo, `transferencia atras frente 5` solicita trasladar cinco unidades desde el escudo trasero hacia el frontal.

Todas las cantidades numéricas de entrada deben ser no negativas. La energía inicial de cada sector no puede superar 40, la energía total inicial no puede superar 120 y la secuencia no puede contener más de 200 eventos. La potencia de un impacto no puede superar 100 y la cantidad solicitada en una transferencia no puede superar 120. El origen y el destino de una transferencia deben ser diferentes. Los test cases entregados utilizan entradas válidas.

Para una entrada válida, el programa muestra la energía total final, la reserva, los seis sectores, el daño acumulado por la nave y los estados de los escudos y de la nave, en este orden:

```text
Energia total: <VALOR>
Reserva: <VALOR>
Frente: <VALOR>
Atras: <VALOR>
Izquierda: <VALOR>
Derecha: <VALOR>
Arriba: <VALOR>
Abajo: <VALOR>
Dano nave: <VALOR>
Estado escudos: <operativo|critico>
Estado nave: <activa|destruida>
```

## Actividad

El laboratorio contiene diez test cases: cuatro casos de control que funcionan desde el comienzo y seis casos por resolver. Los dos primeros problemas se trabajarán paso a paso; los dos siguientes ofrecen sugerencias; los últimos dos requieren una investigación autónoma.

### 1. Preparar y observar el programa

#### 1.1. Inspeccionar los archivos

Ingresar a `workspace` y revisar `code/escudos.c`, `tests` y `scripts`. Identificar dónde se leen los datos iniciales, dónde se procesa la secuencia de eventos y dónde se construye el informe. Ubicar también la variable `debug_enabled` y el placeholder de la función `myprint`. Revisar al menos un caso de control y comprobar manualmente su resultado.

En `test004`, observar cómo una secuencia de transferencias utiliza tanto la reserva como distintos sectores de origen para aumentar la energía del escudo frontal.

El programa separa la lectura y validación de la entrada, la interpretación de cada evento, la actualización del estado y la construcción del informe. Un dato puede ser interpretado en una etapa, utilizado en otra y mostrado al final. La instrumentación permitirá seguir ese recorrido sin tener que comprender todas las funciones antes de comenzar.

#### 1.2. Compilar el programa

Construir el comando necesario para compilar `code/escudos.c` con `-Wall`, `-Wextra`, `-Werror` y `-std=c11`. El ejecutable debe llamarse `escudos` y quedar dentro de `code`.

El programa inicial compila sin warnings, pero como se ha visto anteriormente esto no implica que las actualizaciones de energía sean correctas.

#### 1.3. Ejecutar la suite inicial

Agregar permiso de ejecución para el propietario de `scripts/tests-run.sh` y ejecutar la suite. El script recibe la ruta del ejecutable y el directorio de test cases. El resultado inicial debe ser:

```text
PASS:  test001
PASS:  test002
PASS:  test003
PASS:  test004
FAIL:  test005
FAIL:  test006
FAIL:  test007
FAIL:  test008
FAIL:  test009
FAIL:  test010
```

Los cuatro primeros casos son controles: deben seguir entregando `PASS` después de cada corrección.

### 2. Investigar paso a paso un impacto

#### 2.1. Reproducir `test005`

Examinar su entrada y su resultado esperado. Ejecutar solamente ese caso, guardar `stdout` en un archivo `.out` y `stderr` en un archivo `.err`, y comparar la salida con `diff -u`. El caso contiene doce eventos y uno de ellos origina la diferencia observada. Calcular manualmente cuánta energía debería conservar el sector después de cada impacto.

#### 2.2. Instrumentar y observar la actualización

Completar el placeholder de `myprint`, que recibe una etiqueta, un valor y una condición local. La función debe enviar `DEBUG: <ETIQUETA>=<VALOR>` a `stderr` solamente cuando `debug_enabled` y la condición local sean distintos de cero. De este modo, la variable global permite activar o desactivar todas las trazas desde un único lugar, mientras cada llamada decide si su información resulta pertinente. No es necesario encerrar las llamadas a `myprint` en nuevos `if` ni comentarlas cada vez que se recompila.

Ubicar la operación que aplica un impacto y utilizar `myprint` para observar el sector afectado, su energía antes del impacto, la potencia recibida, el daño calculado y la energía posterior. Establecer condiciones locales que permitan examinar el evento pertinente sin imprimir la secuencia completa. Recompilar y repetir `test005`.

Contrastar los valores observados con el comportamiento descrito en el contexto. En particular, revisar cómo cambia la energía del sector afectado. Una vez resuelto el problema, la traza puede permanecer en el código con su activación global deshabilitada.

#### 2.3. Corregir y volver a probar

Utilizar la evidencia para corregir la actualización del sector. Desactivar globalmente las trazas, recompilar y verificar que `test005` entregue `PASS`. Ejecutar la suite completa: desde `test001` hasta `test005` deben entregar `PASS`.

### 3. Investigar paso a paso una transferencia

#### 3.1. Reproducir `test006`

Inspeccionar la secuencia de doce eventos. Determinar en qué transferencia se produce el primer resultado inesperado y, para esa operación, cuánta energía tiene el origen, cuánta se solicita trasladar y cuánto espacio tiene el destino.

#### 3.2. Observar la transferencia

Activar `debug_enabled` y utilizar `myprint` para observar el origen y el destino antes y después de la transferencia, así como la cantidad efectivamente trasladada. Utilizar la condición local para mostrar solamente los eventos que puedan explicar el fallo y repetir `test006`.

Comparar también la energía total antes y después de la transferencia. Las trazas deben permitir reconocer tanto la cantidad trasladada como el efecto de la operación sobre el estado completo.

#### 3.3. Corregir y volver a probar

Corregir el comportamiento respaldado por la traza. Desactivar globalmente las trazas, recompilar y comprobar que `test006` entregue `PASS`. Al ejecutar la suite, desde `test001` hasta `test006` deben entregar `PASS`.

### 4. Investigar con orientación general

#### 4.1. Investigar `test007`

Este caso combina doce eventos dirigidos a sectores diferentes. Comparar el sector indicado en cada evento con los valores de los seis sectores en el informe. Una traza breve y condicionada durante la interpretación de los eventos puede ayudar a comprobar cuál sector utiliza el programa. Investigar y corregir la causa sin modificar el test case.

Recompilar y confirmar que desde `test001` hasta `test007` entreguen `PASS`.

#### 4.2. Investigar `test008`

Este caso contiene doce eventos y más de una transferencia. Una de ellas se solicita cuando el destino tiene poco espacio disponible. Comparar la energía del origen y del destino antes y después de las operaciones pertinentes con la capacidad máxima del sector. Instrumentar solo los valores necesarios para explicar la diferencia.

Recompilar y confirmar que desde `test001` hasta `test008` entreguen `PASS`.

### 5. Investigar con mayor autonomía

En los siguientes casos se debe decidir qué información observar y dónde instrumentar. Reproducir cada problema, interpretar la evidencia, corregir su causa y ejecutar nuevamente la suite.

#### 5.1. Investigar `test009`

Este caso contiene treinta eventos variados. Uno de ellos provoca un cambio que no se refleja correctamente en el informe final, pero imprimir cada paso dificultaría reconocerlo entre el resto de la traza. Elegir condiciones locales que muestren solamente los eventos relevantes para el comportamiento observado. Durante la investigación, limitar la traza a diez líneas como máximo.

Resolver el problema y desactivar globalmente las trazas. Al ejecutar la suite, desde `test001` hasta `test009` deben entregar `PASS`.

#### 5.2. Investigar `test010`

Este caso contiene veinte eventos. Investigarlo de manera autónoma: determinar qué parte del informe no coincide con lo esperado, seleccionar la información interna que permita explicar la diferencia y utilizar trazas acotadas para obtenerla. Corregir solamente la causa respaldada por la evidencia.

Recompilar y comprobar que los diez test cases entreguen `PASS`.

### 6. Comprobar todas las correcciones

#### 6.1. Desactivar las trazas

Conservar la función `myprint` y las llamadas que resultaron útiles durante la investigación, pero dejar `debug_enabled` desactivada. Así, las trazas pueden volver a habilitarse desde un único lugar si se necesitan más adelante. Con entradas válidas, `stdout` debe contener solamente las once líneas del informe y `stderr` no debe contener mensajes.

#### 6.2. Ejecutar la suite completa

Volver a compilar con las mismas opciones y ejecutar la suite completa. Los diez casos deben entregar `PASS`. Si algún test case entrega `FAIL`, revisar la comparación correspondiente antes de modificar otro sector del programa.

### 7. Verificación final

#### 7.1. Habilitar el script

Agregar permiso de ejecución para el propietario de `scripts/check.sh`.

#### 7.2. Ejecutar la verificación

Ejecutar `scripts/check.sh` desde `workspace`. El script informa qué actividades están completas y cuáles permanecen pendientes.
