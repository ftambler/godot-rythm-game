# Juego de ritmo


| Integrantes |
| --- |
| Santiago Pereira | 
| Federico Tambler | 

**Curso / materia:** completar  
**Institución:** completar  
**Año:** 2026

## Resumen del juego

Juego de ritmo en el que una pelota parte del centro de la pantalla en una de ocho direcciones: arriba, abajo, izquierda, derecha y sus cuatro diagonales. Al chocar contra una pared (horizontal, vertical o diagonal), la pelota refleja su dirección como la luz en un espejo.

El jugador debe orientar el escudo hacia la pared en el momento del impacto y presionar la barra espaciadora al pasar por los orbes. Los activadores de velocidad aceleran o frenan la pelota y cambian el ritmo de la partida. El juego es 2D, con vista desde arriba, y sus niveles están sincronizados con una canción.

Los aciertos aumentan el puntaje y el combo. Los errores reducen la vida; acertar permite recuperarla.

## Cómo jugar

- **Escudo:** WASD o flechas.
- **Orbes:** barra espaciadora.
- **Pausa:** P o Escape.

Para ejecutar el juego, abrí `project.godot` con Godot 4.7 y ejecutá el proyecto.

## Generar un nivel

Desde `scripts/level_builder`, ejecutá:

```powershell
.\.venv\Scripts\python main.py --bpm 120 --duration 5 --pattern orb wall --name test
```

El generador guarda el nivel como `levels/test.json` y crea una vista previa `levels/test.png`.