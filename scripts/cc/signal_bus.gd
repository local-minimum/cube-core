extends SignalBusCore
class_name SignalBus

@warning_ignore_start("unused_signal")
signal on_play_exclude_word_game(enemy: GridEnemy, player: GridPlayer)
signal on_reward_message(reward: String)
signal on_end_exclude_word_game()

signal on_award_key(coordinates: Vector3)

signal on_update_lost_letters(lost_letters: String)

signal on_hurt_player(player: GridPlayer, amount: int)
signal on_heal_player(player: GridPlayer, amount: int)
signal on_hurt_by_walk(player: GridPlayer)
signal on_track_back_on_trail(player: GridPlayer, steps: int)

signal on_start_sacrifice(player: GridPlayer)
signal on_start_offer(player: GridPlayer)
signal on_complete_sacrifice(letter: String)

signal on_activate_player_hunt(id: String)

signal on_cat_zone_entry(zone: String)
signal on_cat_subzone_entry(zone: String)
signal on_cat_zone_exit(zone: String)

signal on_roll_credits()
@warning_ignore_restore("unused_signal")
