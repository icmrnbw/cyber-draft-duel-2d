extends Node
## Autoload. Single choke point for rewarded ads.
##
## DELIBERATELY A STUB RIGHT NOW: there is no ad SDK in this project yet.
## Real rewarded video on Android needs a Godot Android plugin (AdMob or
## similar) -- a binary dependency plus a signed-up ad account, neither of
## which exists here. Rather than fake that, this grants the reward
## immediately and logs, so the REWARD FLOW and every call site can be built,
## played and balanced now.
##
## The contract that matters, and the reason this indirection exists at all:
## callers pass a callback that runs ONLY on a completed ad. Callers must
## never grant the reward themselves. When a real SDK is wired in, the only
## change is inside show_rewarded() -- present the video, invoke on_reward on
## the SDK's "user earned reward" signal, and do nothing on skip/failure.
## Every call site keeps working untouched, and a cancelled ad correctly pays
## nothing without any call site having to remember that.

## Flips to true once a real ad SDK is integrated; call sites can use this to
## hide ad buttons entirely rather than showing a button that fakes a reward.
const ADS_AVAILABLE := false


func show_rewarded(on_reward: Callable) -> void:
	if not on_reward.is_valid():
		return
	if ADS_AVAILABLE:
		# Real SDK goes here: load + show, then call on_reward from the
		# "earned reward" callback only.
		push_warning("AdService: ADS_AVAILABLE is true but no SDK is wired in.")
		return
	print("[AdService] stub rewarded ad -- granting reward immediately")
	on_reward.call()
