extends SignalBusCore
class_name SignalBus

@warning_ignore_start("unused_signal")
signal on_play_exclude_word_game(enemy: GridEnemy, player: GridPlayer)
signal on_reward_word_game(reward: String)

signal on_award_key(coordinates: Vector3)

signal on_update_lost_letters(lost_letters: String)

signal on_hurt_player(player: GridPlayer, amount: int)
signal on_heal_player(player: GridPlayer, amount: int)

signal on_start_sacrifice(player: GridPlayer)
signal on_start_offer(player: GridPlayer)
signal on_complete_sacrifice()

signal on_activate_player_hunt(id: String)
@warning_ignore_restore("unused_signal")
