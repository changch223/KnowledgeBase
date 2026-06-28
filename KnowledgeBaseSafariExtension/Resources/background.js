// background.js
// spec 020 — Safari Web Extension background script
//
// 役割:
// 1. ツールバーアイコンクリック → content script から URL 抽出 → native save
//    (popup なし、action click で即保存)
// 2. content.js からのメッセージを native handler に中継
//    (Safari 制約: content.js は sendNativeMessage を直接呼べない、
//     background.js 経由で中継する必要あり)
// 3. tabs.onUpdated 監視 (spec 020 fix 2026-05-06):
//    - 同タブ内の通常 navigation で content.js は再実行されない仕様への対応
//    - URL 変更 / load 完了を検知して content.js に "urlMaybeChanged" を通知
//

// ツールバーアイコンクリック (即時保存)
browser.action.onClicked.addListener(async (tab) => {
    try {
        const info = await browser.tabs.sendMessage(tab.id, {
            action: "extractPageInfo",
        });
        await browser.runtime.sendNativeMessage("application.id", {
            action: "saveURL",
            url: info?.url || tab.url,
            title: info?.title || tab.title || "",
            ogImage: info?.ogImage || "",
            source: "manual",
        });
    } catch (e) {
        // silent fail
        console.error("[iKnow] manual save failed:", e);
    }
});

// content.js → background → native 中継
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!message || typeof message !== "object") {
        sendResponse(null);
        return false;
    }
    const action = message.action;

    if (action === "getAutoSaveSettings") {
        // settings query を native handler に転送、response を content.js に返す
        browser.runtime
            .sendNativeMessage("application.id", message)
            .then((response) => sendResponse(response))
            .catch((e) => {
                console.error("[iKnow] getAutoSaveSettings relay failed:", e);
                sendResponse(null);
            });
        return true;  // async response (Safari 必須)
    }

    if (action === "saveURL") {
        // 自動保存リクエスト
        browser.runtime
            .sendNativeMessage("application.id", message)
            .then(() => sendResponse({ ok: true }))
            .catch((e) => {
                console.error("[iKnow] saveURL relay failed:", e);
                sendResponse({ ok: false });
            });
        return true;
    }

    sendResponse(null);
    return false;
});

// 同タブ内の URL 変更を検知して content.js に通知
// (Safari Web Extension の content.js は document_end で 1 度しか走らないため、
//  同じタブで別 URL に遷移した場合 content.js は再 inject されない。
//  manifest v3 + host_permissions で tabs.onUpdated.changeInfo.url が読める。)
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    // URL が変わった、または load が完了した時に通知
    // (changeInfo.url は loading 中に発火、changeInfo.status === "complete" は load 完了時)
    const urlChanged = typeof changeInfo.url === "string";
    const loadCompleted = changeInfo.status === "complete";
    if (!urlChanged && !loadCompleted) return;

    // content.js が inject されていないタブ (about:blank 等) では sendMessage が失敗するが silent
    browser.tabs
        .sendMessage(tabId, { action: "urlMaybeChanged" })
        .catch(() => {
            // content.js なし or まだ inject されていない → 次の event で拾われるので silent
        });
});
