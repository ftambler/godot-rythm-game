# Juego de ritmo


| Integrantes |
| --- |
| Santiago Pereira | 
| Federico Tambler | 

**Curso / materia:** Desarrollo de Videojuegos 

**Año:** 2026

## Resumen del juego

Juego de ritmo en el que una pelota parte del centro de la pantalla en una de ocho direcciones: arriba, abajo, izquierda, derecha y sus cuatro diagonales. Al chocar contra una pared (horizontal, vertical o diagonal), la pelota refleja su dirección como la luz en un espejo.

El jugador debe orientar el escudo hacia la pared en el momento del impacto y presionar la barra espaciadora al pasar por los orbes. Los activadores de velocidad aceleran o frenan la pelota y cambian el ritmo de la partida. El juego es 2D, con vista desde arriba, y sus niveles están sincronizados con una canción.

Los aciertos aumentan el puntaje y el combo. Los errores reducen la vida; acertar permite recuperarla.

## Cómo jugar

Para ejecutar el juego, abrí `project.godot` con Godot 4.7 y ejecutá el proyecto.

O descargá el [Latest Release](https://github.com/ftambler/godot-rythm-game/releases/latest).

Dentro del juego:
- **Escudo:** WASD o flechas.
- **Orbes:** barra espaciadora.
- **Pausa:** P o Escape.

## Generar un nivel

Los niveles se generan a partir de la canción con un script de Python. Desde `scripts/level_builder`, la primera vez instalá las dependencias:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
```

Después, con la canción en `levels/music/`:

```powershell
.\.venv\Scripts\python main.py --analyze cancion.mp3 --difficulty normal --name cancion_normal
```

**Cómo funciona:**

1. **Análisis del audio** (`analyze.py`, con librosa): detecta el tempo y los pulsos de la canción, y mide la fuerza de cada golpe en una grilla de ½ o ¼ de pulso. Se quedan los golpes más fuertes; las partes más fuertes de la canción reciben más objetos y los silencios quedan vacíos. Los golpes con más graves (bombo, caja) se vuelven paredes y el resto orbes. Según el volumen de cada tramo de la canción se colocan cambios de velocidad.
2. **Chart:** el resultado se guarda en `charts/<nombre>.chart.json`, una lista de tiempos y tipos de objeto que se puede editar a mano.
3. **Ubicación:** el generador simula el recorrido de la pelota con la misma física del juego y coloca cada objeto donde va a estar la pelota en ese pulso. Elige la orientación de cada pared para que el recorrido no pase por encima de otros objetos visibles. El recorrido se arma por tramos de unas pocas paredes con distintas formas: vueltas (gira siempre para el mismo lado), zigzags (alterna y avanza por la pantalla) o al azar; cada cambio de velocidad empieza un tramo nuevo.

La dificultad (`easy`, `normal`, `hard`) cambia la densidad de objetos y la velocidad máxima. El nivel se guarda en `levels/<nombre>.json`. Para que aparezca en el juego, agregalo a `levels/index.json`.

Otras opciones:

- `--chart charts/<nombre>.chart.json`: regenera el nivel desde un chart editado, sin volver a analizar la canción.
- `--seed N`: genera otro recorrido con los mismos tiempos. La misma semilla da un recorrido distinto en cada canción.
- `--start-direction UP_LEFT`: dirección inicial de la pelota (por defecto, una diagonal elegida con la semilla). Con una dirección recta (`UP`, `RIGHT`, ...) todas las paredes son diagonales y piden escudos diagonales, que son más difíciles.
- `--duration 60`: usa solo los primeros 60 segundos. Si el nivel termina antes que la canción, el resto sigue sonando más bajo en la pantalla de resultados.
- `--preview`: guarda también una vista previa `levels/<nombre>.png` del recorrido.
- `--bpm 120 --pattern orb wall`: modo simple, coloca un objeto en cada pulso siguiendo el patrón, sin analizar el audio.