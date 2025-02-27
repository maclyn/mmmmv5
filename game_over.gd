@tool
extends Control

signal done_showing()

const TIMER_LENGTH_S = 2.0
const HALF_TIMER_DURATION_MS = (TIMER_LENGTH_S / 2.0) * 1000.0

var start_time_ms = Time.get_ticks_msec()
var is_timer_active = false

func _ready():
	if Engine.is_editor_hint():
		visible = true
		$EndState.visible = true
		new_high_score(1000)
		$Timer.stop()

func _process(delta: float):
	if !is_timer_active:
		return
	modulate.a = pct_faded_in()
	print("Fade is " + str(modulate.a))

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
	if elapsed < HALF_TIMER_DURATION_MS:
		# Fade in
		var pct_in = elapsed / HALF_TIMER_DURATION_MS
		return pct_in
	else:
		return 1.0
	
func _start_timer():
	if !$Timer.is_stopped():
		push_warning("Tried to start timer when already running!")
		return
	start_time_ms = Time.get_ticks_msec()
	is_timer_active = true
	modulate.a = 0.0
	visible = true
	$Timer.start(TIMER_LENGTH_S)

func _on_timer_timeout() -> void:
	is_timer_active = false
	visible = false
	modulate.a = 1.0
	done_showing.emit()
