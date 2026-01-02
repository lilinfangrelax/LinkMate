# Privacy Policy for LinkMate

**Last Updated: January 02, 2026**

LinkMate ("we", "us", or "our") operates the LinkMate browser extension and the LinkMate desktop application. This page informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service.

## 1. Information Collection and Use

LinkMate is a local tab management utility. The primary purpose of the Service is to synchronize browser tab metadata with the companion desktop application on your local machine.

### Data Collected:
*   **Tab Metadata**: We collect information about your open browser tabs, including URLs, page titles, favicons (icons), and tab group information.
*   **Profile Identification**: We may store a locally-generated unique identifier (UUID) or a user-provided alias (Profile Name) in your browser's local storage to identify the source of the tabs in the desktop application.

## 2. Data Storage and Transfer (Local Only)

**Your privacy is our priority. No data is transmitted to our servers.**

*   **Local Communication**: All collected information is sent directly from the browser extension to the LinkMate desktop application via the **Native Messaging** protocol. 
*   **No Third-Party Transmission**: We do not sell, trade, or otherwise transfer your information to external parties or third-party servers.
*   **Local Database**: The data is stored in a local SQLite database on your computer (`linkmate.db`) for display and management within the desktop app.

## 3. User Controls

*   **Manual Sync**: Users can trigger or stop the synchronization at any time by interacting with the extension's popup.
*   **Custom Labels**: Users can manually set or clear their profile aliases through the extension settings.
*   **Data Deletion**: Deleting the desktop application or its local database file will remove all synced history.

## 4. Permissions Justification

*   `tabs`: Required to retrieve the URLs and titles of your open tabs for organization.
*   `nativeMessaging`: Required to communicate with the companion desktop application.
*   `identity`: (Optional/If enabled) Used only to pre-fill your profile name for better multi-profile recognition.
*   `storage`: Used to save your custom profile preferences.

## 5. Changes to This Privacy Policy

We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.

## 6. Contact Us

If you have any questions about this Privacy Policy, please contact us via our GitHub repository: **[您的 GitHub 仓库地址]**
