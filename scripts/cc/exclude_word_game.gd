extends Node

const _MAX_WORD_LENGTH: int = 12

@export var button_group: ContainerButtonGroup
@export var words_resource: String
@export var default_text_color: Color = Color.HOT_PINK
@export var disabled_text_color: Color = Color.DIM_GRAY
@export var delays_factor: float = 1.0

var _enemies: Array[GridEnemy]
var _player: GridPlayer
var _groups: Array[WordGroup]
var _group_history: Array[String]
var _labels: Array[CensoringLabel]
var _hotkeys: Array[CensoringLabel]
var _active_words: Array[String]
var _sacrificing: bool
var _playing: bool:
    get():
        return !_sacrificing && _enemies.size() > 0

class WordGroup:
    var title: String
    var words: Array[String]

    @warning_ignore_start("shadowed_variable")
    func _init(title: String, line: String) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.title = title.strip_edges()
        for word: String in line.split(","):
            word = word.strip_edges()
            if word.length() > _MAX_WORD_LENGTH:
                push_warning("Omitting word '%s' because too long, max %s" % [word, _MAX_WORD_LENGTH])
            elif !word.is_empty():
                words.append(word)

    func pick_words(count: int = 3) -> Array[String]:
        words.shuffle()
        return words.slice(0, count)

    func pick_outlier(in_group: WordGroup) -> String:
        var options: Array[String] = words.filter(
            func (word: String) -> bool: return !in_group.words.has(word)
        )
        if options.is_empty():
            return ""

        return options.pick_random()

    func has_outlier(in_group: WordGroup) -> bool:
        return words.any(
            func (word: String) -> bool: return !in_group.words.has(word)
        )

func _ready() -> void:
    button_group.visible = false

    if __SignalBus.on_play_exclude_word_game.connect(_play_game) != OK:
        push_error("Failed to connect play exclude word game")

    if __SignalBus.on_update_lost_letters.connect(_handle_update_lost_letters) != OK:
        push_error("Failed to connect update lost letters")

    if __SignalBus.on_start_sacrifice.connect(_handle_start_sacrifice) != OK:
        push_error("Failed to connect start sacrifice")

    if __SignalBus.on_start_offer.connect(_handle_start_sacrifice) != OK:
        push_error("Failed to connect start offer")

    if __SignalBus.on_complete_sacrifice.connect(_handle_complete_sacrifice) != OK:
        push_error("Failed to connect complete sacrifice")

    _load_words()

func _unhandled_key_input(event: InputEvent) -> void:
    if !_playing || event.is_echo():
        return

    if event.is_action_pressed("hot_key_1"):
        _handle_hotkey_button(0)
    elif event.is_action_pressed("hot_key_2"):
        _handle_hotkey_button(1)
    elif event.is_action_pressed("hot_key_3"):
        _handle_hotkey_button(2)
    elif event.is_action_pressed("hot_key_4"):
        _handle_hotkey_button(3)

func _handle_start_sacrifice(__player: GridPlayer) -> void:
    _sacrificing = true

func _handle_complete_sacrifice() -> void:
    _sacrificing = false

func _handle_hotkey_button(idx: int) -> void:
    var btn: ContainerButton = button_group.buttons[idx]
    if btn.interactable && btn.visible:
        btn.focused = true
        _handle_click_word(btn, _active_words[idx])

func _handle_update_lost_letters(letters: String) -> void:
    for label: CensoringLabel in _labels:
        label.censored_letters = letters

    for label: CensoringLabel in _hotkeys:
        label.censored_letters = letters

func _load_words() -> void:
    _groups.clear()

    if !ResourceUtils.valid_abs_resource_path(words_resource):
        return

    var file = FileAccess.open(words_resource, FileAccess.READ)
    if file == null:
        return

    var title: String
    for line: String in file.get_as_text().split("\n"):
        line = line.strip_edges()
        if line.is_empty() || line.begins_with("#"):
            continue

        if line.begins_with("-"):
            title = line.trim_prefix("-").strip_edges()
        else:
            if title.is_empty():
                push_warning("Ignoring line '%s' because not part of a group/lacking title" % line)
            else:
                _groups.append(WordGroup.new(title, line))
                title = ""

    print_debug("[Exclude Word Game] loaded %s groups" % _groups.size())

func _play_game(enemy: GridEnemy, player: GridPlayer) -> void:
    print_debug("[Exclude Word Game] playing %s vs %s" % [enemy, player])
    _enemies.append(enemy)
    if _enemies.size() == 1:
        _player = player

        player.cinematic = true

        _make_next_word_set()

var _wrong_word: String

func _get_outlier_group(in_group: WordGroup) -> WordGroup:
    var options: Array[WordGroup] = _groups.filter(
        func (group: WordGroup) -> bool:
            if group == in_group:
                return false

            return group.has_outlier(in_group)
    )

    if options.is_empty():
        return null

    return options.pick_random()

func _pick_random_group() -> WordGroup:
    var shuffled: Array[WordGroup] = _groups.duplicate()
    shuffled.shuffle()
    var prioritized: Array[WordGroup] = shuffled.duplicate()
    prioritized.sort_custom(
        func (a: WordGroup, b: WordGroup) -> bool:
            var count_a: int = _group_history.count(a.title)
            var count_b: int = _group_history.count(b.title)

            if count_a == count_b:
                return shuffled.find(a) < shuffled.find(b)

            return count_a < count_b
    )

    return prioritized.slice(0, 5).pick_random()

func _make_next_word_set() -> void:
    if !_groups.is_empty():
        for _idx: int in range(3):
            var group: WordGroup = _pick_random_group()

            var words: Array[String] = group.pick_words()
            print_debug("[Exclude Word Game] Considering '%s' using words %s" % [group.title, words])
            var outlier_group: WordGroup = _get_outlier_group(group)
            if outlier_group != null:
                var word: String = outlier_group.pick_outlier(group)
                if !word.is_empty():

                    _wrong_word = word
                    words.append(word)

                    _group_history.append(group.title)

                    print_debug("[Exclude Word Game] Using '%s': '%s' as outlier to %s" % [outlier_group.title, word, group.title])

                    _sync_words(words)
                    return

    _wrong_word = "1234568901"
    _sync_words(["123456789012", "123456789012", "123456789012", "123456789012"])

func _sync_words(words: Array[String]) -> void:
    _guessed = false

    words.shuffle()

    _active_words = words.duplicate()

    print_debug("[Exclude Word Game] Playing words %s with '%s' not belonging" % [words, _wrong_word])

    var idx = 0
    for button: ContainerButton in button_group.buttons:
        for connection: Dictionary in button.on_click.get_connections():
            button.on_click.disconnect(connection["callable"])

        for connection: Dictionary in button.on_change_interactable.get_connections():
            button.on_change_interactable.disconnect(connection["callable"])

        if idx < words.size():
            var word: String = words[idx]
            var l_idx: int = 0
            for label: CensoringLabel in button.find_children("", "CensoringLabel"):
                label.censored_letters = __GlobalGameState.lost_letters
                label.color = default_text_color

                if l_idx == 0:
                    label.text = word.to_upper()
                    if !_labels.has(label):
                        _labels.append(label)

                elif l_idx == 1:
                    # TODO: Actual binding hints
                    label.text = " %s" % (idx + 1)
                    if !_hotkeys.has(label):
                        _hotkeys.append(label)

                l_idx += 1

            button.on_change_interactable.connect(func (btn: ContainerButton) -> void:
                _labels[idx].color = default_text_color if btn.interactable else disabled_text_color
                _hotkeys[idx].color = default_text_color if btn.interactable else disabled_text_color
            )

            button.on_click.connect(
                func (btn: ContainerButton) -> void:
                    _handle_click_word(btn, word)
            )


            button.visible = true
            button.interactable = true
            if idx == 0:
                button.focused = true
            else:
                button.focused = false
        else:
            button.visible = false

        idx += 1

    await get_tree().create_timer(0.2 * delays_factor).timeout
    button_group.visible = true

var _guessed: bool

func _handle_click_word(button: ContainerButton, word: String) -> void:
    if _guessed:
        return

    _guessed = true

    await get_tree().create_timer(0.5 * delays_factor).timeout

    if word == _wrong_word:
        _handle_hurt_enemy(button)
    else:
        button.interactable = false

        await get_tree().create_timer(0.5 * delays_factor).timeout
        _player.hurt(_enemies[0].hurt_on_guess_wrong)

        if button_group.interactables == 1:
            _handle_hurt_enemy(button)
        else:
            button_group.select_next()


            _guessed = false

    print_debug("[Exclude Word Game] Selected '%s'" % word)


func _handle_hurt_enemy(button: ContainerButton) -> void:
    for btn: ContainerButton in button_group.buttons:
        if btn != button:
            btn.interactable = false
            # await get_tree().create_timer(0.05 * delays_factor).timeout

    await get_tree().create_timer(1 * delays_factor).timeout

    var enemy: GridEnemy = _enemies[0]

    enemy.hurt()

    if enemy.is_alive():
        await get_tree().create_timer(0.2 * delays_factor).timeout

        _make_next_word_set()

    else:
        _enemies.erase(enemy)

        if _enemies.is_empty():
            await get_tree().create_timer(0.2 * delays_factor).timeout

            enemy.kill()

            await get_tree().create_timer(0.5 * delays_factor).timeout

            button_group.visible = false

            await get_tree().create_timer(0.5 * delays_factor).timeout

            _player.cinematic = false

            _player = null
            _enemies.clear()
        else:
            await get_tree().create_timer(0.2 * delays_factor).timeout

            _make_next_word_set()
