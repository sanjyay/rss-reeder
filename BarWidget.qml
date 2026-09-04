import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.sanjyay.rss-reeder"

  readonly property var legacySettings: {
    var fromLayout = Model.entryFromLayout(root.bar && root.bar.layoutConfig, [
      "io.github.sanjyay.rss-reeder",
      "io.github.sanjyay.rssreeder",
      "io.github.rafaelvzago.rss"
    ])
    return fromLayout || ({})
  }

  function getSetting(key, fallback) {
    var val = setting(key, undefined)
    if (val !== undefined && val !== null) return val
    if (root.legacySettings && root.legacySettings[key] !== undefined && root.legacySettings[key] !== null) {
      return root.legacySettings[key]
    }
    return fallback
  }

  readonly property var configuredSubscriptions: Model.normalizeSubscriptions(getSetting("subscriptions", ""), getSetting("feedUrls", ""))
  readonly property var configuredFeedUrls: {
    var urls = []
    for (var i = 0; i < configuredSubscriptions.length; i++) {
      if (configuredSubscriptions[i].enabled !== false) urls.push(configuredSubscriptions[i].url)
    }
    return urls
  }
  readonly property var configuredCategories: Model.extractCategories(configuredSubscriptions, root.items, root.readSet)
  readonly property var feedCategoryMap: {
    var map = {}
    for (var i = 0; i < configuredSubscriptions.length; i++) {
      map[configuredSubscriptions[i].url] = configuredSubscriptions[i].category || ""
    }
    return map
  }
  readonly property var subscriptionMap: {
    var map = {}
    var list = root.configuredSubscriptions || []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].url) map[list[i].url] = list[i]
    }
    return map
  }
  readonly property int configuredMaxItemsPerFeed: {
    var raw = getSetting("maxItemsPerFeed", null)
    if (raw === undefined || raw === null || raw === "")
      return Model.maxItemsPerFeed(getSetting("recentListSize", 10))
    return Model.maxItemsPerFeed(raw)
  }
  readonly property int configuredPollIntervalMinutes: Model.pollIntervalMinutes(getSetting("pollIntervalMinutes", 15))
  readonly property int configuredItemsPerPage: Model.pageSize(getSetting("itemsPerPage", 10))
  readonly property int configuredRetentionDays: Model.normalizeRetentionDays(getSetting("retentionDays", getSetting("feedRetentionDays", 30)))
  readonly property bool configuredUnreadOnlyDefault: getSetting("unreadOnlyDefault", false) === true
  readonly property string configuredBarSection: {
    var fromLayout = Model.sectionFromLayout(root.bar && root.bar.layoutConfig, root.moduleName)
    if (fromLayout) return fromLayout
    var legacyFromLayout = Model.sectionFromLayout(root.bar && root.bar.layoutConfig, "io.github.rafaelvzago.rss")
    if (legacyFromLayout) return legacyFromLayout
    return Model.barSection(getSetting("barSection", "right"))
  }
  readonly property var settingsReadSet: Model.readIdentities(getSetting("readIdentities", ""))
  property var localReadSet: []
  readonly property var readSet: root.localReadSet || []
  readonly property int badgeCount: Model.unreadCount(root.items, root.readSet)
  readonly property string statePath: {
    var home = Quickshell.env("HOME") || ""
    return home + "/.local/share/omarchy-rss-reeder/state.json"
  }
  property var items: []
  property var pendingFetchQueue: []
  property int totalFeeds: 0
  property int completedFeeds: 0
  property int failedFeeds: 0
  property bool isFetching: false
  property bool refreshPending: false
  property bool stateReady: false

  function applyRetentionCleanup() {
    if (!root.items || !root.items.length) return
    var pruned = Model.pruneArticlesByRetention(root.items, root.configuredRetentionDays)
    if (pruned.length !== root.items.length) {
      root.items = pruned
      persistState()
      injectPanel()
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("emptyCopy" in target) target.emptyCopy = Model.emptyPanelCopy(root.configuredFeedUrls)
    if ("items" in target) target.items = root.items
    if ("subscriptions" in target) target.subscriptions = root.configuredSubscriptions
    if ("feedUrls" in target) target.feedUrls = root.configuredFeedUrls
    if ("categories" in target) target.categories = root.configuredCategories
    if ("feedCategoryMap" in target) target.feedCategoryMap = root.feedCategoryMap
    if ("pollIntervalMinutes" in target) target.pollIntervalMinutes = root.configuredPollIntervalMinutes
    if ("maxItemsPerFeed" in target) target.maxItemsPerFeed = root.configuredMaxItemsPerFeed
    if ("itemsPerPage" in target) target.itemsPerPage = root.configuredItemsPerPage
    if ("retentionDays" in target) target.retentionDays = root.configuredRetentionDays
    if ("unreadOnlyDefault" in target) target.unreadOnlyDefault = root.configuredUnreadOnlyDefault
    if ("barSection" in target) target.barSection = root.configuredBarSection
    if ("readSet" in target) target.readSet = root.readSet
    if ("isFetching" in target) target.isFetching = root.isFetching
    if ("totalFeeds" in target) target.totalFeeds = root.totalFeeds
    if ("completedFeeds" in target) target.completedFeeds = root.completedFeeds
    if ("failedFeeds" in target) target.failedFeeds = root.failedFeeds
    if ("lastImportResult" in target) target.lastImportResult = root.lastImportResult
    if ("shareStatus" in target) target.shareStatus = root.lastImportMessage || ""
  }

  function clearImportMessage() {
    root.lastImportMessage = ""
    root.lastImportResult = null
    if (panelLoader.item) {
      panelLoader.item.shareStatus = ""
      panelLoader.item.lastImportResult = null
    }
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function persistState() {
    if (!root.stateReady) return
    stateFile.setText(Model.serializeState(root.items, root.readSet) + "\n")
  }

  function applyLocalRead(next) {
    var cleaned = Model.readIdentities(next)
    root.localReadSet = cleaned
    persistSettings({
      readIdentities: Model.serializeReadIdentities(cleaned)
    })
    persistState()
    injectPanel()
  }

  function applyBarSection(section) {
    var next = Model.barSection(section)
    persistSettings({ barSection: next })
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy bar move " + root.moduleName + " --section " + next)
  }

  property var lastImportResult: null
  property string lastImportMessage: ""
  property string selectedOpmlPath: ""

  function requestOpmlFileImport() {
    if (opmlSelectProcess.running || opmlValidateAndReadProcess.running) return
    root.selectedOpmlPath = ""
    console.log("[RSS-D696463-LIVE] requestOpmlFileImport entered")
    console.log("[RSS-D696463-LIVE] command passed to omarchy-file-select:", JSON.stringify(opmlSelectProcess.command))
    console.log("[RSS-D696463-LIVE] process started: opmlSelectProcess")
    opmlSelectProcess.running = true
  }

  function selectOpmlFile() {
    root.requestOpmlFileImport()
  }

  function handleSelectedOpmlFile(fileUrlOrPath) {
    var raw = String(fileUrlOrPath || "").trim()
    if (!raw) return
    console.log("[RSS-D696463-LIVE] handleSelectedOpmlFile entered with raw path/url:", JSON.stringify(raw))
    var resolvedPath = Model.filePathFromUrl(raw)
    if (!resolvedPath) return
    console.log("[RSS-D696463-LIVE] normalized selected path:", resolvedPath)
    root.selectedOpmlPath = resolvedPath
    opmlValidateAndReadProcess.sourcePath = resolvedPath
    opmlValidateAndReadProcess.command = [
      "python3", "-c",
      "import os, sys\n" +
      "path = sys.argv[1]\n" +
      "if not os.path.exists(path):\n" +
      "    sys.stderr.write('File not found\\n')\n" +
      "    sys.exit(1)\n" +
      "if os.path.isdir(path):\n" +
      "    sys.stderr.write('Selected path is a directory\\n')\n" +
      "    sys.exit(2)\n" +
      "if not os.path.isfile(path):\n" +
      "    sys.stderr.write('Selected path is not a regular file\\n')\n" +
      "    sys.exit(3)\n" +
      "size = os.path.getsize(path)\n" +
      "if size > 5242880:\n" +
      "    sys.stderr.write('File exceeds 5 MiB limit\\n')\n" +
      "    sys.exit(4)\n" +
      "with open(path, 'rb') as f:\n" +
      "    sys.stdout.buffer.write(f.read())\n",
      resolvedPath
    ]
    console.log("[RSS-D696463-LIVE] validation reader started for:", resolvedPath)
    opmlValidateAndReadProcess.running = true
  }

  function importSharedPayload(payloadText) {
    var raw = String(payloadText || "").trim()
    if (!raw) {
      root.lastImportMessage = "Nothing to import"
      root.lastImportResult = { status: "error", imported: 0, duplicates: 0, invalid: 0, message: "Nothing to import" }
      if (panelLoader.item) {
        panelLoader.item.shareStatus = "Nothing to import"
        panelLoader.item.lastImportResult = root.lastImportResult
      }
      return
    }
    var parseDetails = Model.parseOpmlDetails(raw)
    if (!parseDetails.feeds.length) {
      var parsed = Model.parseSharePayload(raw)
      parseDetails = { feeds: parsed, subscriptions: Model.normalizeSubscriptions([], parsed), categories: [], invalidCount: 0, totalFound: parsed.length }
    }
    var result = Model.calculateImportResult(root.configuredSubscriptions, parseDetails, "")
    root.lastImportResult = result
    root.lastImportMessage = result.message
    if (result.status === "success" && result.imported > 0) {
      persistSettings({
        subscriptions: Model.serializeSubscriptions(result.newSubscriptions),
        feedUrls: Model.serializeFeedUrls(result.newFeeds)
      })
      fetchFeed()
    }
    if (panelLoader.item) {
      panelLoader.item.subscriptions = root.configuredSubscriptions
      panelLoader.item.feedUrls = root.configuredFeedUrls
      panelLoader.item.shareStatus = result.message
      panelLoader.item.lastImportResult = result
    }
    injectPanel()
  }

  property string selectedExportPath: ""

  function defaultExportFilename() {
    var now = new Date()
    var year = now.getFullYear()
    var m = now.getMonth() + 1
    var d = now.getDate()
    var monthStr = m < 10 ? ("0" + m) : String(m)
    var dayStr = d < 10 ? ("0" + d) : String(d)
    return "rss-reeder-" + year + "-" + monthStr + "-" + dayStr + ".opml"
  }

  function requestOpmlFileExport() {
    if (opmlExportSelectProcess.running || opmlWriteProcess.running) return
    root.selectedExportPath = ""
    var defaultName = defaultExportFilename()
    console.log("[RSS-REEDER] requestOpmlFileExport entered, defaultName:", defaultName)
    opmlExportSelectProcess.command = [
      "python3", "-c",
      "import argparse, os, sys, gi\n" +
      "gi.require_version('Gio', '2.0')\n" +
      "from gi.repository import Gio, GLib\n" +
      "parser = argparse.ArgumentParser(add_help=False)\n" +
      "parser.add_argument('--title', default='Save OPML file')\n" +
      "parser.add_argument('--default-name', default='rss-reeder.opml')\n" +
      "parser.add_argument('--extensions', default='opml xml')\n" +
      "args, _ = parser.parse_known_args()\n" +
      "bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)\n" +
      "loop = GLib.MainLoop()\n" +
      "uris = []\n" +
      "def on_response(conn, sender, path, iface, sig, params):\n" +
      "    code, res = params.unpack()\n" +
      "    if code == 0:\n" +
      "        uris.extend(res.get('uris', []))\n" +
      "    loop.quit()\n" +
      "token = 'omarchysave%d' % os.getpid()\n" +
      "sender = bus.get_unique_name()[1:].replace('.', '_')\n" +
      "predicted = '/org/freedesktop/portal/desktop/request/%s/%s' % (sender, token)\n" +
      "bus.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', predicted, None, Gio.DBusSignalFlags.NONE, on_response)\n" +
      "exts = [e.lstrip('.').lower() for e in args.extensions.split()]\n" +
      "patterns = [(0, '*.' + e) for e in exts] + [(0, '*.' + e.upper()) for e in exts]\n" +
      "label = ' '.join('*.' + e for e in exts)\n" +
      "filters = GLib.Variant('a(sa(us))', [(label, patterns)])\n" +
      "options = {'handle_token': GLib.Variant('s', token), 'current_name': GLib.Variant('s', args.default_name), 'filters': filters, 'current_filter': GLib.Variant('(sa(us))', (label, patterns))}\n" +
      "try:\n" +
      "    handle = bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop', 'org.freedesktop.portal.FileChooser', 'SaveFile', GLib.Variant('(ssa{sv})', ('', args.title, options)), None, Gio.DBusCallFlags.NONE, -1, None).unpack()[0]\n" +
      "    if handle != predicted:\n" +
      "        bus.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', handle, None, Gio.DBusSignalFlags.NONE, on_response)\n" +
      "except Exception as e:\n" +
      "    sys.exit(2)\n" +
      "GLib.timeout_add_seconds(600, loop.quit)\n" +
      "loop.run()\n" +
      "for u in uris:\n" +
      "    print(GLib.filename_from_uri(u)[0])\n" +
      "sys.exit(0 if uris else 1)\n",
      "--title", "Export OPML file",
      "--default-name", defaultName,
      "--extensions", "opml xml"
    ]
    opmlExportSelectProcess.running = true
  }

  function handleSelectedExportFile(fileUrlOrPath) {
    var raw = String(fileUrlOrPath || "").trim()
    if (!raw) return
    var resolvedPath = Model.filePathFromUrl(raw)
    if (!resolvedPath) return
    if (!/\.opml$/i.test(resolvedPath) && !/\.xml$/i.test(resolvedPath)) {
      resolvedPath += ".opml"
    }
    console.log("[RSS-REEDER] handleSelectedExportFile target path:", resolvedPath)
    var opmlContent = Model.generateOpml(root.configuredSubscriptions)
    opmlWriteProcess.targetPath = resolvedPath
    opmlWriteProcess.exportedCount = root.configuredSubscriptions.length
    opmlWriteProcess.command = [
      "python3", "-c",
      "import sys\n" +
      "path = sys.argv[1]\n" +
      "content = sys.argv[2]\n" +
      "with open(path, 'w', encoding='utf-8') as f:\n" +
      "    f.write(content)\n",
      resolvedPath,
      opmlContent
    ]
    opmlWriteProcess.running = true
  }

  function updateSubscriptions(subs) {
    var normalized = Model.normalizeSubscriptions(subs)
    var feedList = []
    for (var i = 0; i < normalized.length; i++) {
      if (normalized[i].enabled !== false) feedList.push(normalized[i].url)
    }

    // Prune cached articles belonging exclusively to removed subscriptions
    var prunedItems = Model.pruneArticlesBySubscriptions(root.items, normalized)
    if (prunedItems.length !== root.items.length) {
      root.items = prunedItems
      persistState()
    }

    persistSettings({
      subscriptions: Model.serializeSubscriptions(normalized),
      feedUrls: Model.serializeFeedUrls(feedList)
    })
    fetchFeed()
    injectPanel()
    return normalized.length
  }

  function importFeeds(urls) {
    var incomingSubs = Model.normalizeSubscriptions([], urls)
    var merged = Model.mergeSubscriptions(root.configuredSubscriptions, incomingSubs)
    return updateSubscriptions(merged)
  }

  function saveConfig(subs, minutes, perFeed, perPage, section, defaultUnreadOnly, retention) {
    var normalized = Model.normalizeSubscriptions(subs !== undefined ? subs : root.configuredSubscriptions)
    var feedList = []
    for (var i = 0; i < normalized.length; i++) {
      if (normalized[i].enabled !== false) feedList.push(normalized[i].url)
    }
    var retDays = Model.normalizeRetentionDays(retention !== undefined ? retention : root.configuredRetentionDays)
    persistSettings({
      subscriptions: Model.serializeSubscriptions(normalized),
      feedUrls: Model.serializeFeedUrls(feedList),
      pollIntervalMinutes: Model.pollIntervalMinutes(minutes),
      maxItemsPerFeed: Model.maxItemsPerFeed(perFeed),
      itemsPerPage: Model.pageSize(perPage),
      barSection: Model.barSection(section),
      unreadOnlyDefault: defaultUnreadOnly === true,
      retentionDays: retDays
    })
    applyBarSection(section)
    applyRetentionCleanup()
    fetchFeed()
  }

  function markItemRead(item) {
    applyLocalRead(Model.markRead(root.readSet, item))
  }

  function markItemsRead(items) {
    applyLocalRead(Model.markAllRead(root.readSet, items))
  }

  function activateItem(item) {
    var url = Model.activateUrl(item)
    if (!url) return
    Qt.openUrlExternally(url)
    applyLocalRead(Model.markRead(root.readSet, item))
    if (panelLoader.item) panelLoader.item.close()
  }

  Timer {
    id: persistDebounceTimer
    interval: 1000
    repeat: false
    onTriggered: root.persistState()
  }

  function enqueueDiscovered(discoveredUrls) {
    if (!discoveredUrls || !discoveredUrls.length) return
    var queue = (root.pendingFetchQueue || []).slice()
    var added = 0
    for (var i = 0; i < discoveredUrls.length; i++) {
      var u = String(discoveredUrls[i] || "").trim()
      if (!Model.isHttpsUrl(u)) continue
      var already = false
      for (var q = 0; q < queue.length; q++) {
        if (queue[q] === u) { already = true; break }
      }
      if (!already) {
        queue.push(u)
        added++
      }
    }
    if (added > 0) {
      root.pendingFetchQueue = queue
      root.totalFeeds += added
      pumpQueue()
    }
  }

  function onWorkerFinished(worker, exitCode, rawOutput) {
    var url = worker.currentUrl
    worker.currentUrl = ""

    if (exitCode === 0 && rawOutput) {
      var split = Model.splitFetchedBody(rawOutput)
      var body = split.body
      if (Model.isFeedTextResponse(split.contentType, body)) {
        var parsed = Model.parseFeed(body)
        if (parsed.ok && parsed.items && parsed.items.length) {
          var sub = root.subscriptionMap[url] || {}
          var subCat = sub.category || ""
          var subCatPath = sub.categoryPath || (subCat ? [subCat] : [])
          var feedTitle = parsed.feedName || sub.title || Model.extractDomainTitle(url)

          var incoming = []
          var nowMs = Date.now()
          for (var j = 0; j < parsed.items.length; j++) {
            var it = parsed.items[j]
            it.feedUrl = url
            it.subscriptionUrl = url
            it.feedName = feedTitle
            it.feedTitle = feedTitle
            it.category = subCat
            it.categoryPath = subCatPath
            if (it.pubDateMs === undefined || it.pubDateMs === null) {
              it.fetchedAtMs = nowMs
            }
            incoming.push(it)
          }

          // Incrementally merge articles into root.items immediately!
          root.items = Model.mergeFeedArticles(
            root.items,
            incoming,
            url,
            root.configuredMaxItemsPerFeed,
            root.configuredRetentionDays,
            root.configuredSubscriptions
          )

          // Immediately update UI / Panel
          injectPanel()

          // Schedule debounced state save
          persistDebounceTimer.restart()
        } else if (Model.looksLikeHtml(body)) {
          var discovered = Model.discoverFeedUrls(body, url)
          if (!discovered || discovered.length === 0)
            discovered = Model.guessFeedUrls(url)
          enqueueDiscovered(discovered)
        }
      } else {
        root.failedFeeds++
      }
    } else {
      root.failedFeeds++
    }

    root.completedFeeds++
    injectPanel()
    pumpQueue()
  }

  function pumpQueue() {
    var pool = [fetchWorker0, fetchWorker1, fetchWorker2, fetchWorker3]
    var anyRunning = false

    for (var i = 0; i < pool.length; i++) {
      var w = pool[i]
      if (w.running) {
        anyRunning = true
        continue
      }

      if (root.pendingFetchQueue && root.pendingFetchQueue.length > 0) {
        var nextUrl = root.pendingFetchQueue[0]
        var rest = []
        for (var r = 1; r < root.pendingFetchQueue.length; r++) rest.push(root.pendingFetchQueue[r])
        root.pendingFetchQueue = rest

        if (!Model.isHttpsUrl(nextUrl)) {
          root.completedFeeds++
          root.failedFeeds++
          i--
          continue
        }

        w.currentUrl = nextUrl
        w.command = [
          "curl", "-fsSL",
          "--proto", "=https",
          "--proto-redir", "=https",
          "--max-redirs", "5",
          "--max-filesize", String(Model.maxFeedBytes()),
          "--max-time", "20",
          "-A", "omarchy-rss-reeder/0.1.0",
          "-H", "Accept: application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.9, text/html;q=0.8",
          "-w", "\n__OMARCHY_CT__:%{content_type}",
          nextUrl
        ]
        w.running = true
        anyRunning = true
      }
    }

    if (!anyRunning && (!root.pendingFetchQueue || root.pendingFetchQueue.length === 0)) {
      root.isFetching = false
      persistDebounceTimer.stop()
      root.persistState()
      if (root.refreshPending) {
        root.refreshPending = false
        root.startFetch()
        return
      }
      root.injectPanel()
    }
  }

  function startFetch() {
    var urls = root.configuredFeedUrls || []
    if (urls.length === 0) {
      root.pendingFetchQueue = []
      root.items = []
      root.totalFeeds = 0
      root.completedFeeds = 0
      root.failedFeeds = 0
      root.isFetching = false
      root.refreshPending = false
      persistDebounceTimer.stop()
      persistState()
      injectPanel()
      return
    }

    var queue = []
    var seen = {}
    for (var i = 0; i < urls.length; i++) {
      var u = String(urls[i] || "").trim()
      if (Model.isHttpsUrl(u) && !seen[u]) {
        seen[u] = true
        queue.push(u)
      }
    }

    root.pendingFetchQueue = queue
    root.totalFeeds = queue.length
    root.completedFeeds = 0
    root.failedFeeds = 0
    root.isFetching = true
    root.refreshPending = false
    injectPanel()
    pumpQueue()
  }

  function fetchFeed() {
    if (root.isFetching) {
      root.refreshPending = true
      return
    }
    root.startFetch()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    root.clearImportMessage()
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    root.clearImportMessage()
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onConfiguredFeedUrlsChanged: fetchFeed()
  onConfiguredRetentionDaysChanged: applyRetentionCleanup()

  Component.onCompleted: mkdirProcess.running = true

  Timer {
    interval: root.configuredPollIntervalMinutes * 60 * 1000
    repeat: true
    running: root.configuredFeedUrls && root.configuredFeedUrls.length > 0
    onTriggered: root.fetchFeed()
  }

  Process {
    id: mkdirProcess
    command: [
      "sh", "-c",
      "mkdir -p \"$HOME/.local/share/omarchy-rss-reeder\"; if [ ! -f \"$HOME/.local/share/omarchy-rss-reeder/state.json\" ] && [ -f \"$HOME/.local/share/omarchy-rss-plugin/state.json\" ]; then cp \"$HOME/.local/share/omarchy-rss-plugin/state.json\" \"$HOME/.local/share/omarchy-rss-reeder/state.json\"; fi"
    ]
    onExited: stateFile.reload()
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var parsed = Model.parseState(text())
      root.localReadSet = parsed.readIdentities || []
      if (parsed.items && parsed.items.length) {
        var pruned = Model.pruneArticlesByRetention(parsed.items, root.configuredRetentionDays)
        root.items = Model.enrichArticles(pruned, root.configuredSubscriptions)
      } else {
        root.items = []
      }
      root.stateReady = true
      root.injectPanel()
      root.fetchFeed()
    }
    onLoadFailed: {
      root.stateReady = true
      root.localReadSet = root.settingsReadSet || []
      root.fetchFeed()
    }
  }

  Process {
    id: fetchWorker0
    property string currentUrl: ""
    stdout: StdioCollector {
      id: fetchWorker0Stdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.onWorkerFinished(fetchWorker0, exitCode, fetchWorker0Stdout.text)
    }
  }

  Process {
    id: fetchWorker1
    property string currentUrl: ""
    stdout: StdioCollector {
      id: fetchWorker1Stdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.onWorkerFinished(fetchWorker1, exitCode, fetchWorker1Stdout.text)
    }
  }

  Process {
    id: fetchWorker2
    property string currentUrl: ""
    stdout: StdioCollector {
      id: fetchWorker2Stdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.onWorkerFinished(fetchWorker2, exitCode, fetchWorker2Stdout.text)
    }
  }

  Process {
    id: fetchWorker3
    property string currentUrl: ""
    stdout: StdioCollector {
      id: fetchWorker3Stdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.onWorkerFinished(fetchWorker3, exitCode, fetchWorker3Stdout.text)
    }
  }

  Process {
    id: opmlSelectProcess
    command: ["omarchy-file-select", "--title", "Select OPML file", "--extensions", "opml xml"]
    stdout: StdioCollector {
      id: opmlSelectStdout
      waitForEnd: true
      onStreamFinished: {
        console.log("[RSS-D696463-LIVE] raw stdout: " + JSON.stringify(opmlSelectStdout.text))
        var path = String(opmlSelectStdout.text || "").trim()
        if (path) root.selectedOpmlPath = path
      }
    }
    onExited: function(exitCode) {
      console.log("[RSS-D696463-LIVE] process exited: opmlSelectProcess, exit code: " + exitCode)
      console.log("[RSS-D696463-LIVE] raw selected path: " + JSON.stringify(root.selectedOpmlPath))
      if (exitCode === 0 && root.selectedOpmlPath) {
        root.handleSelectedOpmlFile(root.selectedOpmlPath)
      }
    }
  }

  Process {
    id: opmlValidateAndReadProcess
    property string sourcePath: ""
    stdout: StdioCollector {
      id: opmlStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: opmlStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      console.log("[RSS-D696463-LIVE] validation reader exit code: " + exitCode)
      if (exitCode !== 0) {
        var err = String(opmlStderr.text || "").trim() || "Failed to read file"
        root.lastImportResult = {
          status: "error",
          imported: 0,
          duplicates: 0,
          invalid: 0,
          message: err
        }
        root.lastImportMessage = err
        if (panelLoader.item) {
          panelLoader.item.shareStatus = err
          panelLoader.item.lastImportResult = root.lastImportResult
        }
        return
      }
      var content = String(opmlStdout.text || "")
      console.log("[RSS-D696463-LIVE] parser entered with payload length: " + content.length)
      var filename = Model.filenameFromPath(opmlValidateAndReadProcess.sourcePath)
      var parseDetails = Model.parseOpmlDetails(content)
      if (!parseDetails.feeds.length) {
        var parsed = Model.parseSharePayload(content)
        parseDetails = { feeds: parsed, subscriptions: Model.normalizeSubscriptions([], parsed), categories: [], invalidCount: 0, totalFound: parsed.length }
      }
      var result = Model.calculateImportResult(root.configuredSubscriptions, parseDetails, filename)
      console.log("[RSS-D696463-LIVE] parsed count: " + parseDetails.feeds.length + ", result: " + JSON.stringify(result))
      root.lastImportResult = result
      root.lastImportMessage = result.message
      if (result.status === "success" && (result.imported > 0 || result.duplicates > 0)) {
        persistSettings({
          subscriptions: Model.serializeSubscriptions(result.newSubscriptions),
          feedUrls: Model.serializeFeedUrls(result.newFeeds)
        })
        fetchFeed()
        console.log("[RSS-D696463-LIVE] persisted feed count: " + result.newFeeds.length)
      }
      if (panelLoader.item) {
        panelLoader.item.subscriptions = root.configuredSubscriptions
        panelLoader.item.feedUrls = root.configuredFeedUrls
        panelLoader.item.shareStatus = result.message
        panelLoader.item.lastImportResult = result
      }
      injectPanel()
    }
  }

  Process {
    id: opmlExportSelectProcess
    stdout: StdioCollector {
      id: opmlExportSelectStdout
      waitForEnd: true
      onStreamFinished: {
        var path = String(opmlExportSelectStdout.text || "").trim()
        if (path) root.selectedExportPath = path
      }
    }
    onExited: function(exitCode) {
      console.log("[RSS-REEDER] opmlExportSelectProcess exited with code:", exitCode, "path:", root.selectedExportPath)
      if (exitCode === 0 && root.selectedExportPath) {
        root.handleSelectedExportFile(root.selectedExportPath)
      }
    }
  }

  Process {
    id: opmlWriteProcess
    property string targetPath: ""
    property int exportedCount: 0
    stdout: StdioCollector { id: opmlWriteStdout; waitForEnd: true }
    stderr: StdioCollector { id: opmlWriteStderr; waitForEnd: true }
    onExited: function(exitCode) {
      console.log("[RSS-REEDER] opmlWriteProcess exited with code:", exitCode)
      if (exitCode !== 0) {
        var err = String(opmlWriteStderr.text || "").trim() || "Failed to write file"
        root.lastImportMessage = "Export failed: " + err
        root.lastImportResult = { status: "error", message: root.lastImportMessage }
      } else {
        var filename = Model.filenameFromPath(opmlWriteProcess.targetPath)
        var msg = "Saved " + filename + " (" + opmlWriteProcess.exportedCount + " feeds)"
        root.lastImportMessage = msg
        root.lastImportResult = { status: "success", message: msg, exported: opmlWriteProcess.exportedCount }
      }
      if (panelLoader.item) {
        panelLoader.item.shareStatus = root.lastImportMessage
        panelLoader.item.lastImportResult = root.lastImportResult
      }
      injectPanel()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰑫"
    tooltipText: root.badgeCount > 0 ? ("RSS-Reeder · " + root.badgeCount + " unread") : "RSS-Reeder"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.togglePanel()
    }
  }
}
