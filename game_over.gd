extends Control

const TIMER_LENGTH_S = 2.0
const HALF_TIMER = TIMER_LENGTH_S / 2

var start_time_ms = Time.get_ticks_msec()

func _process(delta: float):
	if !$Timer.is_stopped():
		modulate.a = pct_faded_in()
	else:
		modulate.a = 1.0

func win(score: int, is_new_high_score: bool):
	$WinState.visible = true
	$LoseState.visible = false
	$WinState/Container/ScoreLabel.text = "%d Points" % [score]
	if is_new_high_score:
		$WinState/Container/ScoreLabel.text += " (New high score!)"
	_start_timer()
	
func lose():
	$WinState.visible = false
	$LoseState.visible = true
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
