package mods.full_inventory;

import brain.gameObject.GameObject;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import distributedObjects.DistributedDungeonSummary;
import mods.api.Context;
import mods.api.Mod;
import openfl.events.Event;
import town.InventoryTownSubState;
import uI.inventory.UIInventory;

/**
 * The inventory's weapon tab, chests included, has pages up to the storage limit only: past it, items
 * are there but no page shows them. Each frame an inventory is shown, after the game's work and before
 * it renders, `View` stacks identical chests into one slot and gives the tab the pages it needs. The
 * town's inventory and the dungeon summary's both get it.
 */
class Main extends Mod {
	var town:InventoryTownSubState;

	var summary:DistributedDungeonSummary;

	var views:haxe.ds.ObjectMap<UIInventory, View> = new haxe.ds.ObjectMap();

	override public function init(ctx:Context):Void {
		var core = ctx.core;
		core.onStateEnter(function(_:StateMachine, state:State) {
			if (Std.isOfType(state, InventoryTownSubState))
				town = cast state;
		});
		core.onStateExit(function(_:StateMachine, state:State) {
			if (state == town)
				town = null;
		});
		core.onObjectReady(function(object:GameObject) {
			if (Std.isOfType(object, DistributedDungeonSummary))
				summary = cast object;
		});
		core.onObjectGone(function(object:GameObject) {
			if (object != summary)
				return;
			views.remove(@:privateAccess summary.mUIInventory);
			summary = null;
		});
		ctx.overlay.addEventListener(Event.EXIT_FRAME, function(_) {
			if (town != null)
				fix(@:privateAccess town.mUIInventory);
			if (summary != null)
				fix(@:privateAccess summary.mUIInventory);
		});
	}

	function fix(inventory:UIInventory):Void {
		if (inventory == null || inventory.root.stage == null)
			return;
		var view = views.get(inventory);
		if (view == null) {
			view = new View(inventory);
			views.set(inventory, view);
		}
		view.fix();
	}
}
