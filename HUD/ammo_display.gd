extends Control

@export var shell_full: Texture2D
@export var shell_empty: Texture2D

@onready var ammo_label: Label = %AmmoLabel

@onready var shells := [
	%ShellFilled,
	%ShellFilled2,
	%ShellFilled3,
	%ShellFilled4,
	%ShellFilled5,
	%ShellFilled6,
]

func set_ammo(current: int, reserve_ammo: int) -> void:
	ammo_label.text = str(current) + " | " + str(reserve_ammo)
	for i in shells.size():
		shells[i].texture = (
			shell_full if i < current else shell_empty
		)
