// LinkMate Background Service Worker

// Constants
const BROWSER_TYPE = "chrome";

// Helper function to get all tabs and groups
async function getAllTabsAndGroups() {
  try {
    // Fetch all tabs
    const tabs = await chrome.tabs.query({});
    
    // Fetch all tab groups
    const groups = await chrome.tabGroups.query({});

    // Construct the payload
    const payload = {
      type: "TABS_SYNC",
      browser: BROWSER_TYPE,
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

    // For prototype Step 1: Log to console
    console.log("LinkMate Sync Data:", JSON.stringify(payload, null, 2));

    return payload;
  } catch (error) {
    console.error("Error fetching tabs:", error);
  }
}

// --- Event Listeners ---

// On Extension Install/Update
chrome.runtime.onInstalled.addListener(() => {
  console.log("LinkMate Extension Installed");
  getAllTabsAndGroups();
});

// Tab Created
chrome.tabs.onCreated.addListener((tab) => {
  console.log("Tab Created:", tab);
  getAllTabsAndGroups();
});

// Tab Updated (URL, Title, Status changes)
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  // Only sync when loading is complete to avoid partial data
  if (changeInfo.status === 'complete') {
    console.log("Tab Updated:", tab);
    getAllTabsAndGroups();
  }
});

// Tab Removed (Closed)
chrome.tabs.onRemoved.addListener((tabId, removeInfo) => {
  console.log("Tab Removed:", tabId);
  getAllTabsAndGroups();
});

// Tab Activated (Switched)
chrome.tabs.onActivated.addListener((activeInfo) => {
  console.log("Tab Activated:", activeInfo);
  // Optional: Send a specific 'TAB_SWITCHED' event
  // For now, we just sync full state in logging
  getAllTabsAndGroups();
});

// Tab Group Updated
if (chrome.tabGroups) {
    chrome.tabGroups.onUpdated.addListener((group) => {
        console.log("Group Updated:", group);
        getAllTabsAndGroups();
    });
}
