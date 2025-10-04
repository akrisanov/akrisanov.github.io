if ("serviceWorker" in navigator) {
    const ver = "3.12.0";
    const tryRegister = (url) => navigator.serviceWorker
        .register(url, { scope: "/" })
        .then(() => console.info("SW Loaded:", url))
        .catch((err) => {
            console.warn("SW register failed for", url, err);
            throw err;
        });

    // Prefer minified in production; fallback to unminified if needed.
    tryRegister(`/sw.min.js?v=${ver}`).catch(() => tryRegister(`/sw.js?v=${ver}`));

    navigator.serviceWorker.ready.then(() => {
        console.info("SW Ready");
    });
}
