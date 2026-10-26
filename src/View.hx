package mods.full_inventory;

import account.ChestInfo;
import account.InventoryBaseInfo;
import account.ItemInfo;
import openfl.Vector;
import openfl.display.MovieClip;
import uI.inventory.UIInventory;

/**
 * One inventory's fix. The game rebuilds its weapon list, a new `Vector`, on each account change; a new
 * one is stacked in place, so every reader of the list (pages, selection, the new-item badge) sees the
 * stacks. The game then shows its page clamped to the storage limit's pages: the page shown before is
 * put back, the town's from one visit to the next as the game does.
 *
 * The game's `displayCategoryPage` throws on a page that starts past the storage limit: hiding the slot
 * frames past it, from the last one down, it reaches index -1. Frames off the stage, appended to its
 * list, keep that index above 0, so the game shows every page itself; it then hides the wrong frames,
 * and the right ones are set here, on every tab.
 */
@:privateAccess
class View {
	static inline final PER_PAGE = 15;

	/** The list `counts` is for. */
	var weapons:Vector<InventoryBaseInfo>;

	/** Each chest kept for a stack of more than one, and its size. */
	var counts:haxe.ds.ObjectMap<ChestInfo, Int> = new haxe.ds.ObjectMap();

	/** The weapon tab's page shown last frame, -1 before the first. */
	var page:Int = -1;

	var inventory:UIInventory;

	public function new(inventory:UIInventory) {
		this.inventory = inventory;
	}

	public function fix():Void {
		var list:Vector<InventoryBaseInfo> = cast inventory.mCategorizedItems.itemFor("WEAPON");
		if (list == null)
			return;
		var rebuilt = list != weapons;
		if (rebuilt) {
			weapons = list;
			stack(list);
		}
		var limit = Std.int(inventory.mDBFacade.dbAccountInfo.inventoryLimitWeapons);
		var pages = Std.int(Math.max(1, Math.max(Math.ceil(limit / PER_PAGE), Math.ceil(shownBefore(weapons.length) / PER_PAGE))));
		// On every tab: the game can jump to a weapon from another.
		pad(pages * PER_PAGE - limit);
		if (inventory.mCurrentTab == "WEAPON")
			paginate(rebuilt, pages);
		decorate();
	}

	function paginate(rebuilt:Bool, pages:Int):Void {
		var pagination = inventory.mPagination;
		if (Std.int(pagination.numPages) != pages) {
			pagination.numPages = pages;
			pagination.visible = pages > 1;
		}
		var wanted = Std.int(inventory.mCurrentPage);
		if (rebuilt) {
			// A weapon just revealed was jumped to by its place before stacking: its page is now another.
			var selected = inventory.mSelectedItemInfo;
			var index = Std.isOfType(selected, ItemInfo) ? weapons.indexOf(selected) : -1;
			if (index >= 0)
				wanted = Std.int(shownBefore(index) / PER_PAGE);
			else if (page >= 0)
				wanted = page;
		}
		// The right arrow goes one page past the last.
		wanted = Std.int(Math.min(wanted, pages - 1));
		if (rebuilt || wanted != Std.int(inventory.mCurrentPage)) {
			inventory.mCurrentPage = pagination.currentPage = wanted;
			inventory.displayCategoryPage();
		}
		page = wanted;
	}

	/** Appends frames off the stage until the game's frame hiding stays above index 0 `overflow` slots past the limit. */
	function pad(overflow:Int):Void {
		var frames = inventory.mInventoryGridElements;
		while (frames.length < 2 * PER_PAGE + overflow)
			frames.push(new MovieClip());
	}

	/** Keeps one chest per kind, a new one if any, at the place of the first. */
	function stack(list:Vector<InventoryBaseInfo>):Void {
		counts = new haxe.ds.ObjectMap();
		var kept:Array<InventoryBaseInfo> = [];
		var slotOf:Map<Int, Int> = new Map();
		var sizes:Array<Int> = [];
		for (info in list) {
			var chest = Std.downcast(info, ChestInfo);
			if (chest == null || chest.isFromDungeonSummary()) {
				kept.push(info);
				sizes.push(1);
				continue;
			}
			var kind = Std.int(chest.gmId);
			var slot = slotOf.get(kind);
			if (slot == null) {
				slotOf.set(kind, kept.length);
				kept.push(chest);
				sizes.push(1);
				continue;
			}
			sizes[slot]++;
			if (chest.isNew && !kept[slot].isNew)
				kept[slot] = chest;
		}
		list.splice(0, list.length);
		for (i in 0...kept.length) {
			list.push(kept[i]);
			if (sizes[i] > 1)
				counts.set(cast kept[i], sizes[i]);
		}
	}

	/** Entries before `end` that the pages count: the game skips equipped ones. */
	function shownBefore(end:Int):Int {
		var shown = 0;
		for (i in 0...end)
			if (!weapons[i].isEquipped)
				shown++;
		return shown;
	}

	/**
	 * The slot frames as the game means them: shown below its element count (the storage limit, for
	 * weapons), or all when it is 0; past it, where a slot is filled. And each stack's count.
	 */
	function decorate():Void {
		var items = inventory.mItems;
		var frames = inventory.mInventoryGridElements;
		var elements = Std.int(inventory.numElementsInCurrentCategory());
		var start = Std.int(inventory.mCurrentPage) * PER_PAGE;
		for (i in 0...items.length) {
			var item = items[i];
			var filled = item.root.visible && item.mInfo != null;
			if (i < frames.length)
				frames[i].visible = elements == 0 || start + i < elements || filled;
			var chest = filled ? Std.downcast(item.mInfo, ChestInfo) : null;
			if (chest == null)
				continue;
			var label = item.mStackCountLabel;
			var count = counts.get(chest);
			if (count != null) {
				var text = "x" + count;
				if (label.text != text)
					label.text = text;
				label.visible = true;
			} else {
				label.visible = false;
			}
		}
	}
}
