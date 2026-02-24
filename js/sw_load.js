if ("serviceWorker" in navigator) {
    const ver = "3.12.0";
    navigator.serviceWorker
        .register(`/sw.min.js?v=${ver}`, { scope: "/" })
        .then(() => console.info("SW Loaded: /sw.min.js?v=" + ver))
        .catch((err) => console.error("SW error: ", err));

    navigator.serviceWorker.ready.then(() => {
        console.info("SW Ready");
    });
}
