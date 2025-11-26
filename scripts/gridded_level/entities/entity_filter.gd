extends Resource
class_name EntityFilter

enum EntityType { NEVER, ALWAYS, ANY_ENTITY, PLAYER, ENEMY, OTHER }

@export var type: EntityType = EntityType.ANY_ENTITY

func applies(node: Node) -> bool:
    return applies_for(type, node)

static func applies_for(entity_type: EntityType, node: Node) -> bool:
    match entity_type:
        EntityType.NEVER:
            return false
        EntityType.ALWAYS:
            return true
        EntityType.ANY_ENTITY:
            return node is GridEntity
        EntityType.PLAYER:
            return node is GridPlayerCore
        EntityType.ENEMY:
            return node is GridEnemyCore
        EntityType.OTHER:
            # This exclues players and enemies by order in the switch statement
            return node is GridEntity
        _:
            push_error("Entity Filter %s not handled" % entity_type)
            return false
