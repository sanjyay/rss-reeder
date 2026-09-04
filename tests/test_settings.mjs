import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const Model = require(join(dirname(fileURLToPath(import.meta.url)), "..", "Model.js"));

test("bar section is left, center, or right", () => {
  assert.equal(Model.barSection("left"), "left");
  assert.equal(Model.barSection("CENTER"), "center");
  assert.equal(Model.barSection("nope"), "right");
  assert.equal(
    Model.sectionFromLayout(
      { left: [], center: [{ id: "io.github.sanjyay.rss-reeder" }], right: [] },
      "io.github.sanjyay.rss-reeder"
    ),
    "center"
  );
  assert.deepEqual(
    Model.entryFromLayout(
      { left: [], center: [{ id: "io.github.rafaelvzago.rss", feedUrls: "https://legacy.example/rss" }], right: [] },
      ["io.github.sanjyay.rss-reeder", "io.github.rafaelvzago.rss"]
    ),
    { id: "io.github.rafaelvzago.rss", feedUrls: "https://legacy.example/rss" }
  );
});

test("poll interval defaults to 15 minutes", () => {
  assert.equal(Model.pollIntervalMinutes(undefined), 15);
  assert.equal(Model.pollIntervalMinutes(null), 15);
  assert.equal(Model.pollIntervalMinutes(""), 15);
});

test("poll interval cannot go below 5 minutes", () => {
  assert.equal(Model.pollIntervalMinutes(1), 5);
  assert.equal(Model.pollIntervalMinutes(0), 5);
  assert.equal(Model.pollIntervalMinutes(-3), 5);
  assert.equal(Model.pollIntervalMinutes(5), 5);
  assert.equal(Model.pollIntervalMinutes(30), 30);
});

test("recent list size defaults to 20", () => {
  assert.equal(Model.recentListSize(undefined), 20);
});

test("recent list size is at least 1", () => {
  assert.equal(Model.recentListSize(0), 1);
  assert.equal(Model.recentListSize(-2), 1);
  assert.equal(Model.recentListSize(7), 7);
});

test("feed URLs are one per line, blanks ignored", () => {
  assert.deepEqual(Model.feedUrls(undefined), []);
  assert.deepEqual(Model.feedUrls(""), []);
  assert.deepEqual(Model.feedUrls("  \n  "), []);
  assert.deepEqual(
    Model.feedUrls("https://a.example/rss\n\nhttps://b.example/feed.xml\n"),
    ["https://a.example/rss", "https://b.example/feed.xml"]
  );
  assert.deepEqual(Model.feedUrls(["https://a.example/rss", "https://b.example/feed.xml"]), [
    "https://a.example/rss",
    "https://b.example/feed.xml",
  ]);
});

test("merged items are unique by identity and newest first", () => {
  const mixed = Model.uniqueItems([
    { identity: "a", pubDateMs: 1 },
    { identity: "b", pubDateMs: 3 },
    { identity: "a", pubDateMs: 2 },
  ]);
  assert.deepEqual(
    mixed.map((item) => item.identity),
    ["b", "a"]
  );
});

test("no feed URLs uses the add-settings empty copy", () => {
  assert.equal(Model.emptyPanelCopy([]), "Add feed URLs in Settings.");
});

test("page size defaults to 10 and stays between 1 and 100", () => {
  assert.equal(Model.pageSize(), 10);
  assert.equal(Model.pageSize(0), 1);
  assert.equal(Model.pageSize(7), 7);
  assert.equal(Model.pageSize(101), 100);
});

test("pageItems returns at most 10 items for the requested page", () => {
  const items = Array.from({ length: 23 }, (_, i) => ({ identity: String(i) }));
  assert.equal(Model.pageCount(items), 3);
  assert.deepEqual(
    Model.pageItems(items, 0).map((item) => item.identity),
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  );
  assert.deepEqual(
    Model.pageItems(items, 2).map((item) => item.identity),
    ["20", "21", "22"]
  );
  assert.equal(Model.pageIndex(items, 99), 2);
  assert.equal(Model.pageIndex([], 3), 0);
});

test("pagination accepts a configured page size", () => {
  const items = Array.from({ length: 11 }, (_, i) => ({ identity: String(i) }));
  assert.equal(Model.pageCount(items, 4), 3);
  assert.deepEqual(
    Model.pageItems(items, 1, 4).map((item) => item.identity),
    ["4", "5", "6", "7"]
  );
  assert.equal(Model.pageIndex(items, 99, 4), 2);
});

test("share payload round-trips and import merges unique feeds", () => {
  const shared = Model.sharePayload(["https://a.example/rss", "https://b.example/feed.xml"]);
  assert.deepEqual(Model.parseSharePayload(shared), [
    "https://a.example/rss",
    "https://b.example/feed.xml",
  ]);
  const opml = `<opml><outline xmlUrl="https://c.example/atom.xml"/></opml>`;
  assert.deepEqual(Model.parseSharePayload(opml), ["https://c.example/atom.xml"]);
  assert.deepEqual(
    Model.parseSharePayload("https://ok.example/rss\nhttp://no.example/rss\nfile:///tmp/x"),
    ["https://ok.example/rss"]
  );
  assert.deepEqual(
    Model.mergeFeedLists(["https://a.example/rss"], ["https://a.example/rss", "https://d.example/rss"]),
    ["https://a.example/rss", "https://d.example/rss"]
  );
});

test("add and remove feed URLs, serialized one per line", () => {
  const added = Model.addFeedUrl(["https://a.example/rss"], "https://b.example/feed.xml");
  assert.deepEqual(added, ["https://a.example/rss", "https://b.example/feed.xml"]);
  assert.deepEqual(Model.addFeedUrl(added, "https://a.example/rss"), added);
  assert.deepEqual(Model.addFeedUrl(added, "http://insecure.example/rss"), added);
  assert.deepEqual(Model.addFeedUrl(added, "file:///tmp/feed.xml"), added);
  assert.deepEqual(Model.removeFeedUrl(added, "https://a.example/rss"), ["https://b.example/feed.xml"]);
  assert.equal(Model.serializeFeedUrls(added), "https://a.example/rss\nhttps://b.example/feed.xml");
});

test("activate uses the item https link and refuses guid-only rows", () => {
  assert.equal(Model.activateUrl({ link: "https://example.com/post" }), "https://example.com/post");
  assert.equal(Model.activateUrl({ identity: "tag:x", link: "" }), "");
  assert.equal(Model.activateUrl({ link: "http://example.com/post" }), "");
  assert.equal(Model.activateUrl({ link: "file:///etc/passwd" }), "");
  assert.equal(Model.activateUrl({ link: "javascript:alert(1)" }), "");
  assert.equal(Model.activateUrl({ link: "data:text/html,hi" }), "");
});

test("max items per feed defaults to 10 and is at least 1", () => {
  assert.equal(Model.maxItemsPerFeed(undefined), 10);
  assert.equal(Model.maxItemsPerFeed(0), 1);
  assert.equal(Model.maxItemsPerFeed(4), 4);
});

test("each feed is capped before the lists are mixed", () => {
  const feedA = [
    { identity: "a1", feedName: "A", pubDateMs: 300 },
    { identity: "a2", feedName: "A", pubDateMs: 200 },
    { identity: "a3", feedName: "A", pubDateMs: 100 },
  ];
  const feedB = [
    { identity: "b1", feedName: "B", pubDateMs: 250 },
    { identity: "b2", feedName: "B", pubDateMs: 50 },
  ];
  const mixed = Model.mergeFeeds([feedA, feedB], 2);
  assert.deepEqual(
    mixed.map((item) => item.identity),
    ["a1", "b1", "a2", "b2"]
  );
});

test("unread count is the New tab size", () => {
  const items = [
    { identity: "a" },
    { identity: "b" },
    { identity: "c" },
  ];
  const readSet = Model.markRead([], items[0]);
  assert.equal(Model.unreadCount(items, readSet), 2);
});

test("compact counts display at most 99+", () => {
  assert.equal(Model.compactCount(0), "0");
  assert.equal(Model.compactCount(99), "99");
  assert.equal(Model.compactCount(100), "99+");
});

test("text filter matches title excerpt and feed name on any tab", () => {
  const items = [
    { identity: "1", title: "Ghostty Is Leaving GitHub", feedName: "Mitchell Hashimoto", excerpt: "" },
    { identity: "2", title: "Endless execution", feedName: "David Heinemeier Hansson", excerpt: "agents" },
  ];
  assert.deepEqual(
    Model.filterItems(items, "ghostty").map((item) => item.identity),
    ["1"]
  );
  assert.deepEqual(
    Model.filterItems(items, "HANSSON").map((item) => item.identity),
    ["2"]
  );
  assert.deepEqual(Model.filterItems(items, "").length, 2);
});

test("local state round-trips items and the read set", () => {
  const payload = {
    items: [{ identity: "a", title: "A", link: "https://a.example/", feedName: "F", excerpt: "", pubDateMs: 1 }],
    readIdentities: ["a"],
  };
  const parsed = Model.parseState(Model.serializeState(payload.items, payload.readIdentities));
  assert.deepEqual(parsed.readIdentities, ["a"]);
  assert.equal(parsed.items[0].title, "A");
  assert.equal(parsed.items[0].identity, "a");
});

test("activating an item moves it from New to Read", () => {
  const items = [
    { identity: "a", link: "https://a.example/" },
    { identity: "b", link: "https://b.example/" },
  ];
  const after = Model.markRead([], items[0]);
  assert.deepEqual(
    Model.tabItems(items, after, "new").map((item) => item.identity),
    ["b"]
  );
  assert.deepEqual(
    Model.tabItems(items, after, "read").map((item) => item.identity),
    ["a"]
  );
  assert.equal(Model.isRead(after, items[0]), true);
});

test("https feed URLs are required; opaque read identities are not filtered", () => {
  assert.equal(Model.isHttpsUrl("https://example.com/rss"), true);
  assert.equal(Model.isHttpsUrl("HTTPS://Example.com/rss"), true);
  assert.equal(Model.isHttpsUrl("http://example.com/rss"), false);
  assert.equal(Model.isHttpsUrl("file:///etc/passwd"), false);
  assert.equal(Model.isHttpsUrl("javascript:alert(1)"), false);
  assert.equal(Model.isHttpsUrl("example.com/rss"), false);
  assert.equal(Model.isHttpsUrl("https://"), false);
  assert.deepEqual(
    Model.httpsFeedUrls("https://a.example/rss\nhttp://b.example/rss\nfile:///tmp/x"),
    ["https://a.example/rss"]
  );
  assert.deepEqual(Model.feedUrls("tag:world.hey.com,2005:Post/1\nolder-1"), [
    "tag:world.hey.com,2005:Post/1",
    "older-1",
  ]);
  assert.deepEqual(Model.readIdentities("tag:world.hey.com,2005:Post/1\nolder-1"), [
    "tag:world.hey.com,2005:Post/1",
    "older-1",
  ]);
});

test("fetched bodies must be feed or HTML text under the size cap", () => {
  const rss = `<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>`;
  const split = Model.splitFetchedBody(rss + "\n__OMARCHY_CT__:application/rss+xml");
  assert.equal(split.body, rss);
  assert.equal(split.contentType, "application/rss+xml");
  assert.equal(Model.isFeedTextResponse("application/rss+xml", rss), true);
  assert.equal(Model.isFeedTextResponse("text/html; charset=utf-8", "<!DOCTYPE html><html></html>"), true);
  assert.equal(Model.isFeedTextResponse("image/png", rss), false);
  assert.equal(Model.isFeedTextResponse("application/octet-stream", rss), false);
  assert.equal(Model.isFeedTextResponse("application/xml", "ok\0binary"), false);
  assert.equal(Model.maxFeedBytes(), 2097152);
  assert.equal(Model.isFeedTextResponse("text/xml", "x".repeat(Model.maxFeedBytes() + 1)), false);
});

test("normalizeRetentionDays validates and normalizes feed retention days", () => {
  // Defaults & missing migration
  assert.equal(Model.normalizeRetentionDays(undefined), 30);
  assert.equal(Model.normalizeRetentionDays(null), 30);
  assert.equal(Model.normalizeRetentionDays(""), 30);

  // Minimum & Maximum boundaries
  assert.equal(Model.normalizeRetentionDays(1), 1);
  assert.equal(Model.normalizeRetentionDays("1"), 1);
  assert.equal(Model.normalizeRetentionDays(30), 30);
  assert.equal(Model.normalizeRetentionDays("30"), 30);
  assert.equal(Model.normalizeRetentionDays(3650), 3650);
  assert.equal(Model.normalizeRetentionDays("3650"), 3650);

  // Custom valid values
  assert.equal(Model.normalizeRetentionDays(7), 7);
  assert.equal(Model.normalizeRetentionDays("14"), 14);
  assert.equal(Model.normalizeRetentionDays(90), 90);
  assert.equal(Model.normalizeRetentionDays(365), 365);

  // Invalid values fallback to default or provided fallback
  assert.equal(Model.normalizeRetentionDays(0), 30);
  assert.equal(Model.normalizeRetentionDays(-5), 30);
  assert.equal(Model.normalizeRetentionDays(30.5), 30);
  assert.equal(Model.normalizeRetentionDays("30.5"), 30);
  assert.equal(Model.normalizeRetentionDays("abc"), 30);
  assert.equal(Model.normalizeRetentionDays("30days"), 30);
  assert.equal(Model.normalizeRetentionDays(5000), 30);
  assert.equal(Model.normalizeRetentionDays(true), 30);
  assert.equal(Model.normalizeRetentionDays(false), 30);

  // Custom fallback preservation
  assert.equal(Model.normalizeRetentionDays("invalid", 14), 14);
  assert.equal(Model.normalizeRetentionDays(0, 7), 7);
});

test("pruneArticlesByRetention filters articles by publication date cutoff", () => {
  const nowMs = 1700000000000; // Fixed reference point
  const oneDayMs = 24 * 60 * 60 * 1000;

  const exactCutoffMs = nowMs - (30 * oneDayMs);
  const newerMs = nowMs - (10 * oneDayMs);
  const olderMs = nowMs - (31 * oneDayMs);
  const oneDayOldMs = nowMs - (1 * oneDayMs);
  const twoDaysOldMs = nowMs - (2 * oneDayMs);

  const items = [
    { identity: "newer", title: "Newer Post", pubDateMs: newerMs },
    { identity: "exact", title: "Exact Cutoff Post", pubDateMs: exactCutoffMs },
    { identity: "older", title: "Older Expired Post", pubDateMs: olderMs },
    { identity: "no_timestamp", title: "No Timestamp Post" },
    { identity: "pubdate_string", title: "Parsed PubDate String Post", pubDate: new Date(newerMs).toUTCString() }
  ];

  // 1. 30-day retention
  const pruned30 = Model.pruneArticlesByRetention(items, 30, nowMs);
  assert.deepEqual(
    pruned30.map((it) => it.identity),
    ["newer", "exact", "no_timestamp", "pubdate_string"]
  );

  // 2. 1-day retention
  const items1Day = [
    { identity: "today", pubDateMs: nowMs - (12 * 60 * 60 * 1000) },
    { identity: "boundary", pubDateMs: nowMs - oneDayMs },
    { identity: "yesterday", pubDateMs: twoDaysOldMs }
  ];
  const pruned1 = Model.pruneArticlesByRetention(items1Day, 1, nowMs);
  assert.deepEqual(
    pruned1.map((it) => it.identity),
    ["today", "boundary"]
  );

  // 3. Custom 7-day retention
  const items7Day = [
    { identity: "day3", pubDateMs: nowMs - (3 * oneDayMs) },
    { identity: "day8", pubDateMs: nowMs - (8 * oneDayMs) }
  ];
  const pruned7 = Model.pruneArticlesByRetention(items7Day, 7, nowMs);
  assert.deepEqual(
    pruned7.map((it) => it.identity),
    ["day3"]
  );
});

test("pruneArticlesByRetention preserves subscriptions and category structures untouched", () => {
  const subs = [
    { url: "https://archlinux.org/rss", title: "Arch", category: "Linux", categoryPath: ["Linux"], enabled: true },
    { url: "https://news.ycombinator.com/rss", title: "HN", category: "Tech", categoryPath: ["Tech"], enabled: true }
  ];

  const nowMs = Date.now();
  const oldMs = nowMs - (100 * 24 * 60 * 60 * 1000);
  const articles = [
    { identity: "old_arch", feedUrl: "https://archlinux.org/rss", pubDateMs: oldMs, category: "Linux" },
    { identity: "fresh_hn", feedUrl: "https://news.ycombinator.com/rss", pubDateMs: nowMs, category: "Tech" }
  ];

  const pruned = Model.pruneArticlesByRetention(articles, 30, nowMs);
  assert.equal(pruned.length, 1);
  assert.equal(pruned[0].identity, "fresh_hn");

  // Verify subscriptions list and categories are completely untouched
  assert.equal(subs.length, 2);
  assert.equal(subs[0].url, "https://archlinux.org/rss");
  assert.equal(subs[0].category, "Linux");
  assert.equal(subs[1].category, "Tech");
});

test("normalizeFeedInputUrl trims and prefixes https if protocol omitted", () => {
  assert.equal(Model.normalizeFeedInputUrl("  archlinux.org/feeds/news/  "), "https://archlinux.org/feeds/news/");
  assert.equal(Model.normalizeFeedInputUrl("https://example.com/rss"), "https://example.com/rss");
  assert.equal(Model.normalizeFeedInputUrl("http://example.com/rss"), "http://example.com/rss");
  assert.equal(Model.normalizeFeedInputUrl(""), "");
});

test("addSubscription adds valid HTTPS subscription and handles duplicates/invalids", () => {
  const initial = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch Linux", category: "Linux", categoryPath: ["Linux"], enabled: true }
  ];

  // 1. Successful add with custom title and category
  const res1 = Model.addSubscription(initial, "https://news.ycombinator.com/rss", "Hacker News", "Tech");
  assert.equal(res1.ok, true);
  assert.equal(res1.subscriptions.length, 2);
  assert.equal(res1.newSub.url, "https://news.ycombinator.com/rss");
  assert.equal(res1.newSub.title, "Hacker News");
  assert.equal(res1.newSub.category, "Tech");
  assert.deepEqual(res1.newSub.categoryPath, ["Tech"]);

  // 2. Duplicate detection
  const resDup = Model.addSubscription(res1.subscriptions, "  https://archlinux.org/feeds/news/  ");
  assert.equal(resDup.ok, false);
  assert.equal(resDup.error, "Already subscribed");
  assert.equal(resDup.subscriptions.length, 2);

  // 3. Invalid URL detection
  const resInv = Model.addSubscription(initial, "ftp://invalid-url/rss");
  assert.equal(resInv.ok, false);
  assert.equal(resInv.error, "Please enter a valid HTTPS feed URL");

  // 4. URL normalization with omitted https://
  const resAutoHttps = Model.addSubscription(initial, "lobste.rs/rss", "", "Tech");
  assert.equal(resAutoHttps.ok, true);
  assert.equal(resAutoHttps.newSub.url, "https://lobste.rs/rss");
  assert.equal(resAutoHttps.newSub.title, "lobste.rs");
});

test("removeSubscription removes target subscription cleanly", () => {
  const subs = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch" },
    { url: "https://news.ycombinator.com/rss", title: "HN" }
  ];

  const res = Model.removeSubscription(subs, "https://archlinux.org/feeds/news/");
  assert.equal(res.ok, true);
  assert.equal(res.subscriptions.length, 1);
  assert.equal(res.subscriptions[0].url, "https://news.ycombinator.com/rss");

  const resNotFound = Model.removeSubscription(res.subscriptions, "https://unknown.com/rss");
  assert.equal(resNotFound.ok, false);
  assert.equal(resNotFound.subscriptions.length, 1);
});

test("pruneArticlesBySubscriptions removes articles for deleted feeds and updates categories", () => {
  const subs = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch", category: "Linux", categoryPath: ["Linux"], enabled: true },
    { url: "https://reddit.com/r/linux/.rss", title: "Reddit", category: "Reddit", categoryPath: ["Reddit"], enabled: true }
  ];

  const articles = [
    { identity: "a1", feedUrl: "https://archlinux.org/feeds/news/", title: "Arch Post 1" },
    { identity: "a2", feedUrl: "https://archlinux.org/feeds/news/", title: "Arch Post 2" },
    { identity: "r1", feedUrl: "https://reddit.com/r/linux/.rss", title: "Reddit Post 1" }
  ];

  // Deleting reddit subscription
  const rem = Model.removeSubscription(subs, "https://reddit.com/r/linux/.rss");
  assert.equal(rem.ok, true);
  assert.equal(rem.subscriptions.length, 1);

  // Prune articles
  const remainingArticles = Model.pruneArticlesBySubscriptions(articles, rem.subscriptions);
  assert.equal(remainingArticles.length, 2);
  assert.deepEqual(remainingArticles.map(a => a.identity), ["a1", "a2"]);

  // Categories extraction reflects deletion of "Reddit" category
  const categories = Model.extractCategories(rem.subscriptions, remainingArticles, []);
  assert.deepEqual(categories.map(c => c.id), ["all", "Linux"]);
  assert.equal(categories.find(c => c.id === "Reddit"), undefined);
});

test("getAvailableCategories extracts sorted unique category paths", () => {
  const subs = [
    { url: "https://a.com/rss", category: "News", categoryPath: ["News"] },
    { url: "https://b.com/rss", category: "Linux", categoryPath: ["Technology", "Linux"] },
    { url: "https://c.com/rss", category: "AI", categoryPath: ["Technology", "AI"] },
    { url: "https://d.com/rss", category: "", categoryPath: [] },
    { url: "https://e.com/rss", category: "news", categoryPath: ["News"] }
  ];

  const cats = Model.getAvailableCategories(subs);
  assert.equal(cats.length, 3);
  assert.deepEqual(cats.map(c => c.display), [
    "News",
    "Technology / AI",
    "Technology / Linux"
  ]);
});

test("normalizeCategorySelection handles existing casing, empty, and new paths", () => {
  const subs = [
    { url: "https://a.com/rss", category: "Linux", categoryPath: ["Linux"] },
    { url: "https://b.com/rss", category: "AI", categoryPath: ["Technology", "AI"] }
  ];

  // 1. Empty / No category
  assert.deepEqual(Model.normalizeCategorySelection("", subs), { category: "", categoryPath: [] });
  assert.deepEqual(Model.normalizeCategorySelection("No category", subs), { category: "", categoryPath: [] });
  assert.deepEqual(Model.normalizeCategorySelection("  None  ", subs), { category: "", categoryPath: [] });

  // 2. Existing category case-insensitivity
  assert.deepEqual(Model.normalizeCategorySelection("linux", subs), { category: "Linux", categoryPath: ["Linux"] });
  assert.deepEqual(Model.normalizeCategorySelection("LINUX", subs), { category: "Linux", categoryPath: ["Linux"] });

  // 3. Existing nested path case-insensitivity
  assert.deepEqual(Model.normalizeCategorySelection("technology / ai", subs), { category: "AI", categoryPath: ["Technology", "AI"] });

  // 4. New simple category
  assert.deepEqual(Model.normalizeCategorySelection("Gaming", subs), { category: "Gaming", categoryPath: ["Gaming"] });

  // 5. New nested category
  assert.deepEqual(Model.normalizeCategorySelection("Science / Space", subs), { category: "Space", categoryPath: ["Science", "Space"] });
});

test("addSubscription with category selector and creation", () => {
  const initial = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch", category: "Linux", categoryPath: ["Linux"], enabled: true }
  ];

  // 1. Add with existing category
  const res1 = Model.addSubscription(initial, "https://kernel.org/feed.xml", "Kernel", "linux");
  assert.equal(res1.ok, true);
  assert.equal(res1.newSub.category, "Linux");
  assert.deepEqual(res1.newSub.categoryPath, ["Linux"]);

  // 2. Add with new category
  const res2 = Model.addSubscription(res1.subscriptions, "https://ign.com/rss", "IGN", "Gaming");
  assert.equal(res2.ok, true);
  assert.equal(res2.newSub.category, "Gaming");
  assert.deepEqual(res2.newSub.categoryPath, ["Gaming"]);

  // 3. Add with No category
  const res3 = Model.addSubscription(res2.subscriptions, "https://blog.example/rss", "Blog", "No category");
  assert.equal(res3.ok, true);
  assert.equal(res3.newSub.category, "");
  assert.deepEqual(res3.newSub.categoryPath, []);
});

test("generateOpml round-trip preserves categorized and uncategorized subscriptions", () => {
  const subs = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch Linux", category: "Linux", categoryPath: ["Linux"] },
    { url: "https://news.ycombinator.com/rss", title: "Hacker News", category: "Tech", categoryPath: ["Tech"] },
    { url: "https://standalone.com/feed", title: "Standalone", category: "", categoryPath: [] }
  ];

  const opmlText = Model.generateOpml(subs);
  assert.ok(opmlText.includes('version="2.0"'));
  assert.ok(opmlText.includes('<outline text="Linux"'));
  assert.ok(opmlText.includes('<outline text="Tech"'));
  assert.ok(opmlText.includes('xmlUrl="https://standalone.com/feed"'));

  const parsedResult = Model.parseOpmlStructured(opmlText);
  const parsed = parsedResult.subscriptions;
  assert.equal(parsed.length, 3);
  const arch = parsed.find(s => s.url === "https://archlinux.org/feeds/news/");
  assert.ok(arch);
  assert.equal(arch.title, "Arch Linux");
  assert.equal(arch.category, "Linux");

  const stand = parsed.find(s => s.url === "https://standalone.com/feed");
  assert.ok(stand);
  assert.equal(stand.title, "Standalone");
  assert.equal(stand.category, "");
});




