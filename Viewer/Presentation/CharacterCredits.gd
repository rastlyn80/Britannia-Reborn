extends RefCounted
## Notices travel with the source client as well as the local review renders.
const TEXT := "Human character art\n\nMakeHuman bodies, hair and source clothing: CC0 sources recorded in the project notices.\n\nCaesar sandals (elvs_caesar_sandals1)\nby Elvaerwyn, Creative Commons Attribution 4.0.\nSource: https://www.makehumancommunity.org/node/1915\nFitted to both Britannia Reborn bodies; calf straps shortened.\nLicense: https://creativecommons.org/licenses/by/4.0/\n\nLow leather shoes and doublet derived from RehmanPolanski Viking boots/tunic (CC0).\nLeather001 by ambientCG (CC0): https://ambientcg.com/a/Leather001\nLinen/fabric from MedievalKit / ambientCG (CC0).\nFull notices: THIRD_PARTY/Human-Wearables.md"
static func show_dialog(parent: Node) -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Character art credits"
	dialog.dialog_text=TEXT
	parent.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(780,360))
