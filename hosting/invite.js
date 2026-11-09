// Copies this page's address, token included. The token stays in the page: it
// comes after `#`, so no server saw it, and nothing here sends it anywhere.
(() => {
  const copy = document.getElementById('copy');
  const copied = document.getElementById('copied');
  if (!location.hash || !navigator.clipboard) return;
  copy.hidden = false;
  copy.addEventListener('click', async () => {
    await navigator.clipboard.writeText(location.href);
    copied.hidden = false;
  });
})();
