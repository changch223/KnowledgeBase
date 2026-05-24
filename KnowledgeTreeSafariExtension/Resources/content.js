// content.js
// spec 020 — Safari Web Extension content script
//
// 役割:
// 1. main frame のみ実行 (iframe 除外)
// 2. ブラックリスト URL は除外 (検索結果 / login 等)
// 3. ツールバータップ時の即時抽出 (browser.runtime.onMessage)
// 4. 自動保存モード時、native handler から settings 取得 → 遅延後に save リクエスト
// 5. 同タブ内 URL 変更検知 (spec 020 fix 2026-05-06):
//    - SPA: history.pushState / replaceState を hook + popstate
//    - 通常 navigation: background.js の tabs.onUpdated → "urlMaybeChanged" メッセージで再処理
//

(function() {
    'use strict';

    // iframe 除外: main frame のみ実行
    if (window !== window.top) return;

    // 診断 log (Mac Safari Web Inspector で確認)
    console.log("[iKnow] content.js injected at", window.location.href);

    const BLACKLIST_PATTERNS = [
        /^https?:\/\/[^/]*\.google\.[a-z.]+\/search/,
        /^https?:\/\/[^/]*\.bing\.com\/search/,
        /^https?:\/\/[^/]*\.duckduckgo\.com\//,
        /^https?:\/\/[^/]*\/login/i,
        /^https?:\/\/[^/]*\/signin/i,
        /^https?:\/\/[^/]*\/oauth/i,
        /^chrome-extension:/,
        /^about:/,
        /^safari-web-extension:/,
    ];

    function isBlacklisted(url) {
        return BLACKLIST_PATTERNS.some((p) => p.test(url));
    }

    function extractPageInfo() {
        return {
            title: document.title || "",
            url: window.location.href,
            ogImage:
                document.querySelector('meta[property="og:image"]')?.content ||
                document.querySelector('meta[name="twitter:image"]')?.content ||
                "",
        };
    }

    // 同 URL の重複保存抑止 (history hook 連発 + tabs.onUpdated 連発 を 1 度に)
    let lastProcessedURL = null;
    // 進行中の delay timer をキャンセルできるように保持 (URL 変更で前 timer をキャンセル)
    let pendingTimer = null;

    /// 自動保存フロー (初回 inject + URL 変更時に呼ばれる)
    function runAutoSaveFlow() {
        const url = window.location.href;
        if (url === lastProcessedURL) {
            // 同 URL を直前に処理済 → skip
            return;
        }
        if (isBlacklisted(url)) {
            console.log("[iKnow] blacklisted, skip:", url);
            lastProcessedURL = url;
            return;
        }
        lastProcessedURL = url;

        // 進行中 timer をキャンセル (URL がさらに変わった等)
        if (pendingTimer != null) {
            clearTimeout(pendingTimer);
            pendingTimer = null;
        }

        console.log("[iKnow] requesting autoSave settings for", url);
        browser.runtime
            .sendMessage({ action: "getAutoSaveSettings" })
            .then((response) => {
                console.log("[iKnow] settings response:", response);
                const settings = response || {};
                if (!settings.autoSaveEnabled) {
                    console.log("[iKnow] autoSave is OFF, skip");
                    return;
                }

                const delaySec = typeof settings.autoSaveDelaySeconds === "number"
                    ? settings.autoSaveDelaySeconds
                    : 10;
                const delayMs = Math.max(0, delaySec) * 1000;

                console.log("[iKnow] autoSave scheduled in", delaySec, "seconds for", url);
                pendingTimer = setTimeout(() => {
                    pendingTimer = null;
                    // 遅延中に再び URL が変わっていたら、最新 URL の info を抽出 (lastProcessedURL は更新済)
                    const info = extractPageInfo();
                    // 遅延中に異なる URL に遷移し、新フローが既に発火している場合は skip
                    if (info.url !== lastProcessedURL) {
                        console.log("[iKnow] URL changed during delay, skip stale save");
                        return;
                    }
                    console.log("[iKnow] sending saveURL:", info.url);
                    browser.runtime.sendMessage({
                        action: "saveURL",
                        url: info.url,
                        title: info.title,
                        ogImage: info.ogImage,
                        source: "auto",
                    }).then((r) => console.log("[iKnow] saveURL response:", r))
                      .catch((e) => console.error("[iKnow] saveURL failed:", e));
                }, delayMs);
            })
            .catch((e) => {
                // silent fail (constitution V)
                console.error("[iKnow] settings query failed:", e);
            });
    }

    // ツールバータップ時の即時抽出 + background からの URL 変更通知に応答
    browser.runtime.onMessage.addListener((req, sender, sendResponse) => {
        if (!req || typeof req !== "object") {
            sendResponse(null);
            return false;
        }
        if (req.action === "extractPageInfo") {
            sendResponse(extractPageInfo());
            return false;
        }
        if (req.action === "urlMaybeChanged") {
            // background.js の tabs.onUpdated 経由で来る通知。
            // 同 URL なら lastProcessedURL チェックで no-op、別 URL なら再処理。
            console.log("[iKnow] urlMaybeChanged event received");
            runAutoSaveFlow();
            sendResponse({ ok: true });
            return false;
        }
        sendResponse(null);
        return false;
    });

    // SPA navigation 検知: history API hook
    const origPushState = history.pushState;
    history.pushState = function (...args) {
        const ret = origPushState.apply(this, args);
        // pushState 直後の URL は同 microtask 内で更新済
        setTimeout(runAutoSaveFlow, 0);
        return ret;
    };
    const origReplaceState = history.replaceState;
    history.replaceState = function (...args) {
        const ret = origReplaceState.apply(this, args);
        setTimeout(runAutoSaveFlow, 0);
        return ret;
    };
    window.addEventListener('popstate', () => {
        setTimeout(runAutoSaveFlow, 0);
    });

    // 初回実行
    runAutoSaveFlow();
})();
