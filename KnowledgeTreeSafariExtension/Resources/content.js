// content.js
// spec 020 — Safari Web Extension content script
//
// 役割:
// 1. main frame のみ実行 (iframe 除外)
// 2. ブラックリスト URL は除外 (検索結果 / login 等)
// 3. ツールバータップ時の即時抽出 (browser.runtime.onMessage)
// 4. 自動保存モード時、native handler から settings 取得 → 遅延後に save リクエスト
//

(function() {
    'use strict';

    // iframe 除外: main frame のみ実行
    if (window !== window.top) return;

    // 診断 log (Mac Safari Web Inspector で確認)
    console.log("[知積] content.js injected at", window.location.href);

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

    // ツールバータップ時の即時抽出 (background から問い合わせ)
    browser.runtime.onMessage.addListener((req, sender, sendResponse) => {
        if (req && req.action === "extractPageInfo") {
            sendResponse(extractPageInfo());
        }
        return true;
    });

    // 自動保存: 設定取得 → 遅延後に save (auto モード時のみ)
    // content.js は sendNativeMessage を直接呼べない (Safari 制約)、
    // background.js 経由で sendMessage → native handler に中継。
    const url = window.location.href;
    if (isBlacklisted(url)) return;

    console.log("[知積] requesting autoSave settings...");
    browser.runtime
        .sendMessage({ action: "getAutoSaveSettings" })
        .then((response) => {
            // response 形式: { autoSaveEnabled: bool, autoSaveDelaySeconds: int }
            console.log("[知積] settings response:", response);
            const settings = response || {};
            if (!settings.autoSaveEnabled) {
                console.log("[知積] autoSave is OFF, skip");
                return;
            }

            const delaySec = typeof settings.autoSaveDelaySeconds === "number"
                ? settings.autoSaveDelaySeconds
                : 10;
            const delayMs = Math.max(0, delaySec) * 1000;

            console.log("[知積] autoSave scheduled in", delaySec, "seconds");
            setTimeout(() => {
                const info = extractPageInfo();
                console.log("[知積] sending saveURL:", info.url);
                browser.runtime.sendMessage({
                    action: "saveURL",
                    url: info.url,
                    title: info.title,
                    ogImage: info.ogImage,
                    source: "auto",
                }).then((r) => console.log("[知積] saveURL response:", r))
                  .catch((e) => console.error("[知積] saveURL failed:", e));
            }, delayMs);
        })
        .catch((e) => {
            // silent fail (constitution V)
            console.error("[知積] settings query failed:", e);
        });
})();
