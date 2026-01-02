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
    // Attempt to get profile info (Chrome/Edge)
    let accountId = null;

    // 1. Try to get logged in email
    try {
      if (api.identity && api.identity.getProfileUserInfo) {
        const userInfo = await api.identity.getProfileUserInfo();
        accountId = userInfo.email || null;
      }
    } catch (e) {
      console.warn("Could not fetch profile info:", e);
    }

    // 2. Fallback to a persistent local profile ID if no email
    if (!accountId) {
      const storage = await api.storage.local.get(['localProfileId']);
      if (storage.localProfileId) {
        accountId = storage.localProfileId;
      } else {
        // Generate a random ID (e.g., Profile-1234)
        const randomId = 'Profile-' + Math.floor(1000 + Math.random() * 9000);
        await api.storage.local.set({ localProfileId: randomId });
        accountId = randomId;
      }
    }

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
