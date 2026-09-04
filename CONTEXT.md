# RSS-Reeder plugin

A compact native desktop RSS and Atom reader for Omarchy.

## Language

**Plugin**:
The installable Omarchy Quattro package people add from this repository. Permanent id is `io.github.sanjyay.rss-reeder`. Display name is **RSS-Reeder**. Only one bar-widget instance. Default bar section is right.
_Avoid_: applet, extension, widget-only, theme, `omarchy.*`, `rafaelvzago.rss` as the published id, Feeds, Blog posts

**Bar widget**:
The always-visible control in the Omarchy bar. It is the only declared plugin kind. Opening it reveals the panel.
_Avoid_: tray icon, indicator, standalone panel, overlay, menu, service, full bar

**Panel**:
The nested details surface loaded by the bar widget. It is not a second plugin kind.
_Avoid_: window, overlay, popup as a separate plugin, OSD

**Badge**:
The count of items on the New tab — recent items not in the read set. The widget stays visible at zero.
_Avoid_: desktop notification, toast, hidden-until-new, silent icon, lifetime unread total

**Recent list**:
The panel’s contents: the last N items across all configured feeds, newest first, mixed together, unread visually distinct. N is a setting. Items that fall out of this window leave the badge even if they were never read.
_Avoid_: inbox, unread-only list, full archive, per-feed newspaper, last-D-days

**Unread**:
An item the person has not activated and has not marked read, **and** that appeared after that feed’s baseline. Opening the panel does not change unread. Mark-all applies to items currently in the recent list, not to history.
_Avoid_: unseen, new (as a synonym), “opened the panel so it’s all read”, first-snapshot backlog

**Baseline**:
The set of item identities in a feed’s first successful fetch after that feed URL is added. Those items are not unread. Only identities that show up on a later fetch of that feed can become unread.
_Avoid_: backfill, import, catch-up

**Read set**:
The persisted identities the person has activated or marked read. It is stored on disk under the user’s local share directory and also mirrored on the widget settings row.
_Avoid_: session-only unread, sync, cloud read state

**New tab**:
The panel list of recent items that are not in the read set.
_Avoid_: inbox, unread tab (as the label)

**Read tab**:
The panel list of recent items in the read set. Activating an item moves it here.
_Avoid_: archive, history, readed

**Activate**:
The person chose an item in order to open its `link` in the default browser. That marks the item read. `guid` is not opened as a URL. An item with a `guid` and no `link` can appear in the list; activate does nothing, mark read still works.
_Avoid_: select, focus, hover, peek, open guid as permalink

**Failed feed**:
A configured URL that did not yield a usable RSS 2.0 document (network, timeout, or wrong format). The panel reports which feed failed. Last good items for that feed may still appear. A failed feed does not replace the badge.
_Avoid_: error badge, silent skip, drop last good items

**Row**:
One line in the recent list: title, or a plain excerpt of `description` if there is no title; plus a short feed name; plus relative time when `pubDate` exists. No HTML in the list.
_Avoid_: rendered HTML body, title-only (dropping description-only items)

**Settings**:
What the bar-widget entry stores: feed URLs, max items per feed, items per page, poll interval (default 15 minutes, not below 5), and bar section (left, center, or right). The panel Settings link edits those.
_Avoid_: side config file, OPML editor, sub-minute polling

**Mark read**:
An explicit action on one item or on all items in the current recent list, without activating. Distinct from activate; both clear unread.
_Avoid_: dismiss, archive, delete

**Item**:
One listable RSS 2.0 `<item>` or Atom `<entry>`. Same item means same `guid` or Atom `id` when present, otherwise same `link` (Atom: `rel="alternate"`). No identifier and no link means it is not an item — it is not listed.
_Avoid_: post, article, hash of raw XML

**Feed**:
One configured URL: an RSS 2.0 or Atom document, or an HTML blog page whose `<link rel="alternate">` (or a common `/feed.xml` path) points at such a document. The example site is `https://mitchellh.com/writing`. JSON Feed and RSS 1.0 are failed feeds.
_Avoid_: scraping article HTML as the item list, JSON Feed, RSS 1.0, OPML as the v1 editor
