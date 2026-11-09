// Where the viewer reads a share. Public values: the project's id is in every
// Firestore URL, and the security rules are what protect a share.
window.SAFERIDE_SHARE = {
  firestore:
    'https://firestore.googleapis.com/v1/projects/saferide-a9d9f/databases/(default)/documents',
  mapStyles: {
    light: 'https://tiles.openfreemap.org/styles/positron',
    dark: 'https://tiles.openfreemap.org/styles/dark',
  },
};
