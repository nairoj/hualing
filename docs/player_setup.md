# Player Setup (Godot 4.5)

## 1. Node tree
Use this structure in your player scene:

```text
Player (CharacterBody2D)  <- attach scripts/player_controller.gd
|- AnimatedSprite2D
|- CollisionShape2D
`- AttackArea (Area2D)
   `- CollisionShape2D
```

Notes:
- `AnimatedSprite2D` and `AttackArea/CollisionShape2D` names should stay exactly as above.
- The script can auto-build basic animations from `Asset/Sprites/player_spritesheet`.

## 2. Controls
- Move: `WASD` (arrow keys are also mapped by default).
- Attack: `Left Mouse Button`.

## 3. Enemy damage entry
When `AttackArea` overlaps a body, the script calls:

```gdscript
take_damage(amount: int)
```

Any enemy with this method can receive player attack damage.
