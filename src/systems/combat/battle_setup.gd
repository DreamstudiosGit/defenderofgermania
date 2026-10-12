class_name BattleSetup
extends RefCounted
## Input of a battle, shared by auto-resolve and the real-time battle; both answer with a
## BattleResult whose health arrays follow the company order given here.

var attacker := BattleSide.new()
var defender := BattleSide.new()
## Map terrain id of the province (e.g. "farmland", "hills"); picks the battlefield.
var terrain: String = "farmland"
## Wall level the defender fights behind; 0 is an open-field battle.
var defender_wall: int = 0
var is_winter: bool = false
## GameState.Season (0 spring … 3 winter); the battlefield takes its light and landscape.
var season: int = 1
