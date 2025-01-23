@tool
extends Control

const TIMER_LENGTH_S = 2.0
const HALF_TIMER = TIMER_LENGTH_S / 2

var start_time_ms = Time.get_ticks_msec()

func _ready():
	if Engine.is_editor_hint():
		visible = true
		$EndState.visible = true
		new_high_score(1000)
		$Timer.stop()

func _process(delta: float):
	if !$Timer.is_stopped():
		modulate.a = pct_faded_in()
	else:
		modulate.a = 1.0

func new_high_score(score: int):
	$EndState/LoseBG.visible = false
	$EndState/WinBG.visible = true
	$EndState/Container/LoseLabel.visible = false
	$EndState/Container/NewHighScoreLabel.visible = true
	$EndState/Container/ScoreLabel.visible = true
	$EndState/Container/ScoreLabel.text = "%d Points" % [score]
	_start_timer()
	
func game_over():
	$EndState/LoseBG.visible = true
	$EndState/WinBG.visible = false
	$EndState/Container/LoseLabel.visible = true
	$EndState/Container/ScoreLabel.visible = false
	$EndState/Container/NewHighScoreLabel.visible = false
	_start_timer()
	
func get_show_time_s() -> float:
	return TIMER_LENGTH_S
	
func pct_faded_in() -> float:
	var elapsed = Time.get_ticks_msec() - start_time_ms
	if elapsed < (HALF_TIMER * 1000):
		# Fade in
		var pct_in = elapsed / HALF_TIMER / 1000.0
		return pct_in
	else:
		return 1.0
	
func _start_timer():
	start_time_ms = Time.get_ticks_msec()
	$Timer.start(TIMER_LENGTH_S)

func _on_timer_timeout() -> void:
	visible = false
