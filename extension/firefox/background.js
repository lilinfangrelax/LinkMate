// LinkMate Background Service Worker

// Cross-browser compatibility
const api = (typeof browser !== 'undefined') ? browser : chrome;

// Determine browser type (simple heuristic)
let BROWSER_TYPE = "chrome";
if (typeof browser !== 'undefined') {
  BROWSER_TYPE = "firefox";
} else if (navigator.userAgent.indexOf("Edg") > -1) {
  BROWSER_TYPE = "edge";
}

// Helper function to get all tabs and groups
async function getAllTabsAndGroups() {
  try {
    const storage = await api.storage.local.get(['localProfileUuid', 'localProfileName']);

    // 1. Stable accountId for history
    let accountId = storage.localProfileUuid;
    if (!accountId) {
      accountId = 'id-' + Math.random().toString(36).substr(2, 9);
      await api.storage.local.set({ localProfileUuid: accountId });
    }

    // 2. Changeable display name
    let profileName = storage.localProfileName || BROWSER_TYPE;

    // Fetch all tabs
    const tabs = await api.tabs.query({});

    // Fetch all tab groups (Firefox might not support tabGroups yet)
    let groups = [];
    if (api.tabGroups) {
      groups = await api.tabGroups.query({});
    }

    // Construct the payload
    const payload = {
      type: "TABS_SYNC",
      browser: BROWSER_TYPE,
      accountId: accountId,
      profileName: profileName,
      timestamp: Date.now(),
      data: {
        tabs: tabs.map(tab => ({
          tabId: tab.id,
          title: tab.title,
          url: tab.url,
          favIconUrl: tab.favIconUrl,
          groupId: tab.groupId
        })),
        groups: groups.map(group => ({
          groupId: group.id,
          title: group.title,
          color: group.color
        }))
      }
    };

    console.log("LinkMate Sync Data:", JSON.stringify(payload, null, 2));

    // Send to Native Host
    try {
      const port = api.runtime.connectNative('com.linkmate.host');
      port.postMessage(payload);
      port.onMessage.addListener((msg) => {
        console.log("Received from host:", msg);
      });
      port.onDisconnect.addListener(() => {
        if (api.runtime.lastError) {
          console.log("Native Host Disconnected:", api.runtime.lastError.message);
        } else {
          console.log("Native Host Disconnected");
        }
      });
    } catch (e) {
      console.error("Failed to connect to native host:", e);
    }

    return payload;
  } catch (error) {
    console.error("Error fetching tabs:", error);
  }
}

// --- Event Listeners ---

// On Extension Install/Update
api.runtime.onInstalled.addListener(() => {
  console.log("LinkMate Extension Installed");
  getAllTabsAndGroups();
});

// Tab Created
api.tabs.onCreated.addListener((tab) => {
  console.log("Tab Created:", tab);
  getAllTabsAndGroups();
});

// Tab Updated (URL, Title, Status changes)
api.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete') {
    console.log("Tab Updated:", tab);
    getAllTabsAndGroups();
  }
});

// Tab Removed (Closed)
api.tabs.onRemoved.addListener((tabId, removeInfo) => {
  console.log("Tab Removed:", tabId);
  getAllTabsAndGroups();
});

// Tab Activated (Switched)
api.tabs.onActivated.addListener((activeInfo) => {
  console.log("Tab Activated:", activeInfo);
  getAllTabsAndGroups();
});

// Tab Group Updated
if (api.tabGroups) {
  api.tabGroups.onUpdated.addListener((group) => {
    console.log("Group Updated:", group);
    getAllTabsAndGroups();
  });
}

// Manual Sync Request (from Popup)
api.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "TRIGGER_SYNC") {
    getAllTabsAndGroups().then(payload => {
      sendResponse({ status: "success", data: payload });
    });
    return true; // Keep channel open for async response
  }
});
