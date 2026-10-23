extends Node
## 공원 음악 (시험): 다섯 줄기를 AudioStreamSynchronized 하나로 함께 돌리며 시간대 무게로 섞고(SoundMix),
## 가방을 들여다보는 만큼 World 버스에서 먹먹하게 한다.
## 지금 줄기는 사운드 세션의 '시간대 섞기 시험'(사용자 컴퓨터 `멀티 세션용 공유 폴더\사운드\1023 시간대 섞기 시험\`)이고
## 게임 곡이 아니다. M6 재미 시험부터 소리를 넣으므로(결정 기록 2026-10-23) 기본으로 켜고, 시험용 설정에서 끌 수 있다(--sound=0).
##
## 버스(`04_사운드 계획.md` '넘겨주기' 제안): Master(HardLimiter −1dB) ← World(저역 통과) ← Music.
## 환경음·새 소리가 생기면 World로, 효과음·UI는 Master로 바로 보낸다(먹먹해지지 않게).

const DIR := "res://assets/audio/tod_demo"
const FADE_IN := 1.5      # 켤 때 (초)
const FADE_OUT := 0.5     # 끌 때

var main: Node
var player: AudioStreamPlayer
var sync: AudioStreamSynchronized
var enabled := false
var level := 0.0          # 0~1, 켜고 끌 때 부드럽게


static func ensure_buses() -> void:
	var master := 0
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		has_limiter = has_limiter or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)
	if AudioServer.get_bus_index("World") < 0:
		AudioServer.add_bus()
		var w := AudioServer.bus_count - 1
		AudioServer.set_bus_name(w, "World")
		AudioServer.set_bus_send(w, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = SoundMix.OPEN_HZ
		lp.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(w, lp)
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var m := AudioServer.bus_count - 1
		AudioServer.set_bus_name(m, "Music")
		AudioServer.set_bus_send(m, "World")


## World 버스를 가방 흐림 정도 a에 맞춘다.
static func set_world(a: float) -> void:
	var w := AudioServer.get_bus_index("World")
	if w < 0:
		return
	var f := SoundMix.world_filter(a)
	var lp := AudioServer.get_bus_effect(w, 0) as AudioEffectLowPassFilter
	if lp:
		lp.cutoff_hz = f.x
	AudioServer.set_bus_volume_db(w, f.y)


func setup(main_node: Node) -> void:
	main = main_node
	add_to_group("sound_players")   # App.quit()이 끝내기 전에 stop_now()를 부른다
	ensure_buses()
	sync = AudioStreamSynchronized.new()
	sync.stream_count = SoundMix.STEMS.size()
	for i in SoundMix.STEMS.size():
		sync.set_sync_stream(i, load("%s/bgm_tod_demo_%s.ogg" % [DIR, SoundMix.STEMS[i]]))
	player = AudioStreamPlayer.new()
	player.stream = sync
	player.bus = "Music"
	player.volume_db = linear_to_db(SoundMix.FLOOR)
	add_child(player)


func set_enabled(on: bool) -> void:
	enabled = on
	if on and not player.playing:
		_mix()
		player.play()


func _process(delta: float) -> void:
	if not player:
		return
	var target := 1.0 if enabled else 0.0
	level = move_toward(level, target, delta / (FADE_IN if enabled else FADE_OUT))
	if player.playing:
		if level <= 0.0 and not enabled:
			player.stop()
		else:
			_mix()
	player.volume_db = linear_to_db(maxf(level, SoundMix.FLOOR))
	set_world(main.bag.focus() if main.bag else 0.0)


func _mix() -> void:
	var db := SoundMix.stem_db(main.clock_hour)
	for i in db.size():
		sync.set_sync_stream_volume(i, db[i])


## 앱이 뒤로 가면(홈 버튼, 다른 앱) 음악을 멈추고, 돌아오면 그 자리부터 잇는다 (안드로이드·iOS).
func _notification(what: int) -> void:
	if not player:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		player.stream_paused = false


## 바로 멈춘다 (앱을 끝낼 때).
func stop_now() -> void:
	enabled = false
	level = 0.0
	if player:
		player.stop()


func _exit_tree() -> void:
	# 재생을 멈추고 줄기를 놓는다. 앱은 App.quit()으로 끝내야 오디오 서버가 재생을 치운 뒤 끝난다.
	# 무비 메이커(--quit-after)처럼 엔진이 바로 끝나면 '자원이 남았다' 알림이 뜬다(tools/audio_check.py가 거른다).
	if player:
		player.stop()
		player.stream = null
	sync = null
