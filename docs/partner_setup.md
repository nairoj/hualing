# Partner Setup (Godot 4.5)

## Core script
- `res://scripts/partner_controller.gd`
- `sprite_sheet_dir` + `sprite_prefix` can be configured per partner.
  - Example Agui: `res://Asset/Sprites/Agui_spritesheet/` + `agui`
  - Example Aqi: `res://Asset/Sprites/Aqi_spritesheet/` + `aqi`

## Required node tree
```text
Partner (CharacterBody2D) <- attach partner_controller.gd
|- AnimatedSprite2D
|- CollisionShape2D
|- DetectionArea (Area2D)
|  `- CollisionShape2D
`- AttackArea (Area2D)
   `- CollisionShape2D
```

## Groups convention
- Player must be in group: `player`
- Enemy must be in group: `enemy`

## Damage contract
- Partner attack calls: `take_damage(amount: int)`
- Any enemy with this method can receive damage.
