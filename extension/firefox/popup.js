const api = (typeof browser !== 'undefined') ? browser : chrome;

// Load current name on popup open
document.addEventListener('DOMContentLoaded', async () => {
    const storage = await api.storage.local.get(['localProfileName']);
    if (storage.localProfileName) {
        document.getElementById('profileName').value = storage.localProfileName;
    }
});

// Save and Trigger Sync
document.getElementById('saveBtn').addEventListener('click', async () => {
    const newName = document.getElementById('profileName').value.trim();
    if (newName) {
        await api.storage.local.set({ localProfileName: newName });

        const status = document.getElementById('status');
        status.textContent = 'Saved! Syncing...';

        // Use message passing to tell background to trigger a fresh sync immediately
        // (Optional but helpful for instant feedback)
        try {
            const response = await api.runtime.sendMessage({ action: "TRIGGER_SYNC" });
            console.log("Sync response:", response);
        } catch (e) {
            console.log("No listener for TRIGGER_SYNC, will wait for next event.");
        }

        setTimeout(() => { window.close(); }, 800);
    }
});
