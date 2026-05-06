// background.js
// spec 020 — Safari Web Extension background script
//
// 役割:
// 1. ツールバーアイコンクリック → content script から URL 抽出 → native save
//    (popup なし、action click で即保存)
// 2. content.js からのメッセージを native handler に中継
//    (Safari 制約: content.js は sendNativeMessage を直接呼べない、
//     background.js 経由で中継する必要あり)
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
        console.error("[知積] manual save failed:", e);
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
                console.error("[知積] getAutoSaveSettings relay failed:", e);
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
                console.error("[知積] saveURL relay failed:", e);
                sendResponse({ ok: false });
            });
        return true;
    }

    sendResponse(null);
    return false;
});
